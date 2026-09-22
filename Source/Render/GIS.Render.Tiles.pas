unit GIS.Render.Tiles;

////////////////////////////////////////////////////////////////////////////////
//
// Author: Jaap Baak
// https://github.com/transportmodelling/GISlib
//
// Draws a tile layer on an IGISCanvas. This unit is RTL-only: tiles are held in
// the cache as the encoded bytes they arrived as, and the canvas decodes them,
// so no image codec is needed here.
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
interface
////////////////////////////////////////////////////////////////////////////////

Uses
  SysUtils, Classes, Math, Net.HttpClient, Generics.Collections,
  GIS.Render.Canvas, GIS.Render.PixelConv.Mercator;

Type
  TCustomTilesLayer = Class
  private
    Type
      TTilesCache = Class
      private
        Type
          TCachedTile = Class
          private
            Xindex,Yindex: Integer;
            Bytes: TBytes;
            Image: IGISImage;    // decoded on demand, see TCustomTilesLayer.TileImage
            ImageOwner: Pointer; // canvas that decoded Image
            Previous,Next: TCachedTile;
          end;
        Const
          Capacity = 256;
        Var
          Count: Integer;
          First,Last: TCachedTile;
        Procedure Unlink(const CachedTile: TCachedTile);
        Procedure PushFront(const CachedTile: TCachedTile);
        // Most recently used first, so eviction takes the tile scrolled away from
        Function Find(Xindex,Yindex: Integer): TCachedTile;
        Function Add(Xindex,Yindex: Integer; const Bytes: TBytes): TCachedTile;
        Destructor Destroy; override;
      end;
    Const
      MaxZoomLevel = 23;
    Var
      HTTP: THTTPClient;
      TilesCache: array[1..MaxZoomLevel] of TTilesCache;
    Function TileImage(const CachedTile: TTilesCache.TCachedTile;
                       const Canvas: IGISCanvas): IGISImage;
  strict protected
    Function DownloadTile(const URL: String): TBytes;
    // The encoded bytes of one tile, as downloaded. Any format the canvas can
    // decode will do; OpenStreetMap serves PNG.
    Function GetTile(Level,Xindex,Yindex: Integer): TBytes; virtual; abstract;
  public
    Constructor Create;
    Procedure DrawLayer(const Canvas: IGISCanvas; const PixelConverter: TWebMercatorPixelConverter);
    Destructor Destroy; override;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Procedure TCustomTilesLayer.TTilesCache.Unlink(const CachedTile: TCachedTile);
begin
  if First = CachedTile then First := CachedTile.Next;
  if Last = CachedTile then Last := CachedTile.Previous;
  if CachedTile.Previous <> nil then CachedTile.Previous.Next := CachedTile.Next;
  if CachedTile.Next <> nil then CachedTile.Next.Previous := CachedTile.Previous;
  CachedTile.Previous := nil;
  CachedTile.Next := nil;
end;

Procedure TCustomTilesLayer.TTilesCache.PushFront(const CachedTile: TCachedTile);
begin
  CachedTile.Previous := nil;
  CachedTile.Next := First;
  if First = nil then Last := CachedTile else First.Previous := CachedTile;
  First := CachedTile;
end;

Function TCustomTilesLayer.TTilesCache.Find(Xindex,Yindex: Integer): TCachedTile;
begin
  Result := nil;
  var Current := First;
  while Current <> nil do
  if (Current.Xindex = Xindex) and (Current.Yindex = Yindex) then
  begin
    Result := Current;
    // Move to front: this tile is on screen, so it must not be evicted next
    if First <> Current then
    begin
      Unlink(Current);
      PushFront(Current);
    end;
    Break;
  end else
    Current := Current.Next;
end;

Function TCustomTilesLayer.TTilesCache.Add(Xindex,Yindex: Integer; const Bytes: TBytes): TCachedTile;
begin
  if Count = Capacity then
  begin
    var Evict := Last;
    Unlink(Evict);
    Evict.Free;
    Dec(Count);
  end;
  Result := TCachedTile.Create;
  Result.Xindex := Xindex;
  Result.Yindex := Yindex;
  Result.Bytes := Bytes;
  PushFront(Result);
  Inc(Count);
end;

Destructor TCustomTilesLayer.TTilesCache.Destroy;
begin
  var Current := First;
  while Current <> nil do
  begin
    var Next := Current.Next;
    Current.Free;
    Current := Next;
  end;
  inherited Destroy;
end;

////////////////////////////////////////////////////////////////////////////////

Constructor TCustomTilesLayer.Create;
begin
  inherited Create;
  for var ZoomLevel := 1 to MaxZoomLevel do TilesCache[ZoomLevel] := TTilesCache.Create;
end;

Function TCustomTilesLayer.DownloadTile(const URL: String): TBytes;
begin
  var Stream := TBytesStream.Create;
  try
    if HTTP = nil then HTTP := THTTPClient.Create;
    HTTP.Get(URL,Stream);
    Result := Copy(Stream.Bytes,0,Stream.Size);
  finally
    Stream.Free;
  end;
end;

Function TCustomTilesLayer.TileImage(const CachedTile: TTilesCache.TCachedTile;
                                     const Canvas: IGISCanvas): IGISImage;
begin
  // Decoding belongs to the canvas, so a tile decoded for one back end is
  // rebuilt when a different one asks for it.
  if (CachedTile.Image = nil) or (CachedTile.ImageOwner <> Pointer(Canvas)) then
  begin
    CachedTile.Image := Canvas.CreateImage(CachedTile.Bytes);
    CachedTile.ImageOwner := Pointer(Canvas);
  end;
  Result := CachedTile.Image;
end;

Procedure TCustomTilesLayer.DrawLayer(const Canvas: IGISCanvas;
                                      const PixelConverter: TWebMercatorPixelConverter);
begin
  var Cache     := TilesCache[PixelConverter.ZoomLevel];
  var MaxTile   := (1 shl PixelConverter.ZoomLevel) - 1;
  var LeftTile  := PixelConverter.LeftTile;
  var TopTile   := PixelConverter.TopTile;
  var FirstX    := Max(0, LeftTile);
  var LastX     := Min(MaxTile, LeftTile + PixelConverter.HorizTilesCount - 1);
  var FirstY    := Max(0, TopTile);
  var LastY     := Min(MaxTile, TopTile + PixelConverter.VertTilesCount - 1);
  var Top := PixelConverter.TopTilePosition + (FirstY - TopTile) * PixelConverter.TileSize;
  for var Ytile := FirstY to LastY do
  begin
    var Left := PixelConverter.LeftTilePosition + (FirstX - LeftTile) * PixelConverter.TileSize;
    for var Xtile := FirstX to LastX do
    begin
      var CachedTile := Cache.Find(Xtile,Ytile);
      if CachedTile = nil then CachedTile := Cache.Add(Xtile,Ytile,GetTile(PixelConverter.ZoomLevel,Xtile,Ytile));
      var Image := TileImage(CachedTile,Canvas);
      if (Image.Width = PixelConverter.TileSize) and (Image.Height = PixelConverter.TileSize) then
        Canvas.DrawImage(Image,Left,Top)
      else
        raise Exception.Create('Invalid tile size');
      Left := Left + PixelConverter.TileSize;
    end;
    Top := Top + PixelConverter.TileSize;
  end;
end;

Destructor TCustomTilesLayer.Destroy;
begin
  for var ZoomLevel := 1 to MaxZoomLevel do TilesCache[ZoomLevel].Free;
  HTTP.Free;
  inherited Destroy;
end;

end.

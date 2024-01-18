unit GIS.Render.Tiles;

////////////////////////////////////////////////////////////////////////////////
//
// Author: Jaap Baak
// https://github.com/transportmodelling/GISlib
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
interface
////////////////////////////////////////////////////////////////////////////////

Uses
  SysUtils, Classes, Graphics, Generics.Collections, IdHTTP, GIS.Render.PixelConv.Mercator;

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
            Tile: TGraphic;
            Previous,Next: TCachedTile;
          end;
        Const
          Capacity = 256;
        Var
          Count: Integer;
          First,Last: TCachedTile;
        Procedure AddTileToCache(Xindex,Yindex: Integer; const Tile: TGraphic);
        Procedure RemoveTileFromCache(const CachedTile: TCachedTile; DestroyTile: Boolean);
        Function GetCachedTile(Xindex,Yindex: Integer): TGraphic;
        Destructor Destroy; override;
      end;
    Const
      MaxZoomLevel = 23;
    Var
      HTTP: TIdHTTP;
      TilesCache: array[1..MaxZoomLevel] of TTilesCache;
  strict protected
    Function DownloadTile<T: TGraphic,Constructor>(URL: String): T;
    Function GetTile(Level,Xindex,Yindex: Integer): TGraphic; virtual; abstract;
  public
    Constructor Create;
    Procedure DrawLayer(const Canvas: TCanvas; const PixelConverter: TWebMercatorPixelConverter); overload;
    Procedure DrawLayer(const Bitmap: TBitmap; const PixelConverter: TWebMercatorPixelConverter); overload;
    Destructor Destroy; override;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Procedure TCustomTilesLayer.TTilesCache.AddTileToCache(Xindex,Yindex: Integer; const Tile: TGraphic);
begin
  var CachedTile := TCachedTile.Create;
  CachedTile.Xindex := Xindex;
  CachedTile.Yindex := Yindex;
  CachedTile.Tile := Tile;
  if Count = Capacity then RemoveTileFromCache(Last,true);
  CachedTile.Next := First;
  if First = nil then Last := CachedTile else First.Previous := CachedTile;
  First := CachedTile;
  Inc(Count);
end;

Procedure TCustomTilesLayer.TTilesCache.RemoveTileFromCache(const CachedTile: TCachedTile; DestroyTile: Boolean);
begin
  if CachedTile <> nil then
  begin
    if First = CachedTile then First := CachedTile.Next;
    if Last = CachedTile then Last := CachedTile.Previous;
    if CachedTile.Previous <> nil then CachedTile.Previous.Next := CachedTile.Next;
    if CachedTile.Next <> nil then CachedTile.Next.Previous := CachedTile.Previous;
    if DestroyTile then CachedTile.Tile.Free;
    CachedTile.Free;
    Dec(Count);
  end;
end;

Function TCustomTilesLayer.TTilesCache.GetCachedTile(Xindex,Yindex: Integer): TGraphic;
begin
  Result := nil;
  var Current := First;
  while Current <> nil do
  if (Current.Xindex=XIndex) and (Current.Yindex=Yindex) then
  begin
    Result := Current.Tile;
    RemoveTileFromCache(Current,false);
    Break;
  end else
    Current := Current.Next;
end;

Destructor TCustomTilesLayer.TTilesCache.Destroy;
begin
  var Current := First;
  while Current <> nil do
  begin
    var Next := Current.Next;
    Current.Tile.Free;
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

Function TCustomTilesLayer.DownloadTile<T>(URL: String): T;
begin
  var Stream := TMemoryStream.Create;
  try
    if HTTP = nil then HTTP := TIdHTTP.Create(nil);
    HTTP.Get(URL,Stream);
    Stream.Position := 0;
    Result := T.Create;
    Result.LoadFromStream(Stream);
  finally
    Stream.Free;
  end;
end;

Procedure TCustomTilesLayer.DrawLayer(const Canvas: TCanvas;
                                      const PixelConverter: TWebMercatorPixelConverter);
begin
  var LeftTile := PixelConverter.LeftTile;
  var TopTile := PixelConverter.TopTile;
  var HorizTilesCount := PixelConverter.HorizTilesCount;
  var VertTilesCount := PixelConverter.VertTilesCount;
  var Top := PixelConverter.TopTilePosition;
  for var Ytile := TopTile to TopTile+VertTilesCount-1 do
  begin
    var Left := PixelConverter.LeftTilePosition;
    for var Xtile := LeftTile to LeftTile+HorizTilesCount-1 do
    begin
      var Tile := TilesCache[PixelConverter.ZoomLevel].GetCachedTile(Xtile,Ytile);
      if Tile = nil then Tile := GetTile(PixelConverter.ZoomLevel,Xtile,Ytile);
      if (Tile.Width = PixelConverter.TileSize) and (Tile.Height = PixelConverter.TileSize) then
      begin
        TilesCache[PixelConverter.ZoomLevel].AddTileToCache(Xtile,Ytile,Tile);
        Canvas.Draw(Left,Top,Tile);
        Left := Left + PixelConverter.TileSize;
      end else
        raise Exception.Create('Invalid tile size');
    end;
    Top := Top + PixelConverter.TileSize;
  end;
end;

Procedure TCustomTilesLayer.DrawLayer(const Bitmap: TBitmap; const PixelConverter: TWebMercatorPixelConverter);
begin
  DrawLayer(Bitmap.Canvas,PixelConverter);
end;

Destructor TCustomTilesLayer.Destroy;
begin
  for var ZoomLevel := 1 to MaxZoomLevel do TilesCache[ZoomLevel].Free;
  HTTP.Free;
  inherited Destroy;
end;

end.

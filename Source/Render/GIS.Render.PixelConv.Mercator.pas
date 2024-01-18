unit GIS.Render.PixelConv.Mercator;

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
  SysUtils, Classes, Math, Types, GIS, GIS.Render.PixelConv, GIS.CoordConv, GIS.Mercator;

Type
  TWebMercatorPixelConverter = Class(TCustomPixelConverter)
  // The object takes ownership of the CoordinateConverter-object
  private
    FZoomLevel,FMaxZoomLevel: Byte;
    FTileSize: UInt16;
    MercatorMapSize: UInt64;
    MercatorMapLeft,MercatorMapTop: Float64;
    FCoordinateConverter: TCoordinateConverter;
    WebMercatorProjection: TWebMercatorProjection;
    Procedure SetZoomLevel(ZoomLevel: Integer);
    Procedure ZoomIn(const Pixel: TPointF; const DeltaZoom: Integer); overload;
  strict protected
    Procedure WriteState(const Writer: TBinaryWriter); override;
    Procedure ReadState(const Reader: TBinaryReader); override;
  public
    Constructor Create(const CoordinateConverter: TCoordinateConverter;
                       const MaxZoomLevel: Byte = 18;
                       const TileSize: UInt16 = 256);
    Destructor Destroy; override;
    // Convert between pixels and world geodetic coordinates
    Function GeodeticCoordToPixel(const Coord: TGeodeticCoordinate): TPointF;
    Function PixelToGeodeticCoord(const Pixel: TPointF): TGeodeticCoordinate;
    // Convert between pixels and world coordinates
    Function CoordToPixel(const Coord: TCoordinate): TPointF; override;
    Function PixelToCoord(const Pixel: TPointF): TCoordinate; override;
    // Control convertion between pixels and coordinates
    Procedure Initialize(const BoundingBox: TCoordinateRect; const PixelWidth,PixelHeight: Float32); override;
    Procedure ZoomIn(const Pixel: TPointF); overload; override;
    Procedure ZoomIn(const Pixels: TRectF); overload; override;
    Procedure ZoomOut(const Pixel: TPointF); overload; override;
    Procedure PanMap(const DeltaXPixel,DeltaYPixel: Float32); override;
    // Visible tiles query
    Function LeftTile: Integer;
    Function LeftTilePosition: Integer;
    Function HorizTilesCount: Integer;
    Function TopTile: Integer;
    Function TopTilePosition: Integer;
    Function VertTilesCount: Integer;
    // Get viewport
    Function GetViewport: TCoordinateRect; override;
  public
    Property ZoomLevel: Byte read FZoomLevel;
    Property MaxZoomLevel: Byte read FMaxZoomLevel;
    Property TileSize: UInt16 read FTileSize;
    Property CoordinateConverter: TCoordinateConverter read FCoordinateConverter;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Constructor TWebMercatorPixelConverter.Create(const CoordinateConverter: TCoordinateConverter;
                                              const MaxZoomLevel: Byte = 18;
                                              const TileSize: UInt16 = 256);
begin
  inherited Create;
  if MaxZoomLevel <= 1 then FMaxZoomLevel := 1 else
  if MaxZoomLevel >= 23 then FMaxZoomLevel := 23 else
  FMaxZoomLevel := MaxZoomLevel;
  FTileSize := TileSize;
  FCoordinateConverter := CoordinateConverter;
  WebMercatorProjection := TWebMercatorProjection.Create;
end;

Procedure TWebMercatorPixelConverter.WriteState(const Writer: TBinaryWriter);
begin
  Writer.Write(FZoomLevel);
  Writer.Write(MercatorMapLeft);
  Writer.Write(MercatorMapTop);
end;

Procedure TWebMercatorPixelConverter.ReadState(const Reader: TBinaryReader);
begin
  SetZoomLevel(Reader.ReadByte);
  MercatorMapLeft := Reader.ReadDouble;
  MercatorMapTop := Reader.ReadDouble;
end;

Procedure TWebMercatorPixelConverter.SetZoomLevel(ZoomLevel: Integer);
begin
  // Apply zoom level bounds
  if ZoomLevel <= 1 then FZoomLevel := 1 else
  if ZoomLevel >= MaxZoomLevel then FZoomLevel := FMaxZoomLevel else
  FZoomLevel := ZoomLevel;
  // Calculate Mercator map size
  MercatorMapSize := FTileSize;
  for var Cnt := 1 to FZoomLevel do MercatorMapSize := 2*MercatorMapSize;
end;

Function TWebMercatorPixelConverter.GeodeticCoordToPixel(const Coord: TGeodeticCoordinate): TPointF;
begin
  if FInitialized then
  begin
    var Xmercator := MercatorMapSize*WebMercatorProjection.LongitudeToXCoord(Coord.Longitude);
    var Ymercator := MercatorMapSize*WebMercatorProjection.LatitudeToYCoord(Coord.Latitude);
    Result.X := Xmercator - MercatorMapLeft;
    Result.Y := Ymercator - MercatorMapTop;
  end else
    raise Exception.Create('Pixel converter not initialized');
end;

Function TWebMercatorPixelConverter.PixelToGeodeticCoord(const Pixel: TPointF): TGeodeticCoordinate;
begin
  if FInitialized then
  begin
    var Xmercator := (MercatorMapLeft+Pixel.X)/MercatormapSize;
    var Ymercator := (MercatorMapTop+Pixel.Y)/MercatorMapSize;
    Result.Longitude := WebMercatorProjection.XCoordToLongitude(Xmercator);
    Result.Latitude := WebMercatorProjection.YCoordToLatitude(Ymercator);
  end else
    raise Exception.Create('Pixel converter not initialized');
end;

Function TWebMercatorPixelConverter.CoordToPixel(const Coord: TCoordinate): TPointF;
begin
  var GeodeticCoord := FCoordinateConverter.CoordToGeodeticCoord(Coord);
  Result := GeodeticCoordToPixel(GeodeticCoord);
end;

Function TWebMercatorPixelConverter.PixelToCoord(const Pixel: TPointF): TCoordinate;
begin
  var GeodeticCoord := PixelToGeodeticCoord(Pixel);
  Result := FCoordinateConverter.GeodeticCoordToCoord(GeodeticCoord);
end;

Procedure TWebMercatorPixelConverter.Initialize(const BoundingBox: TCoordinateRect; const PixelWidth,PixelHeight: Float32);
Const
  EarthCircumference = 40075017;
begin
  FInitialized := true;
  FPixelWidth := PixelWidth;
  FPixelHeight := PixelHeight;
  // Calculate bounding box size in meters
  var BoundingBoxWidth := FCoordinateConverter.MetersPerUnit*BoundingBox.Width;
  var BoundingBoxHeight := FCoordinateConverter.MetersPerUnit*BoundingBox.Height;
  // Calculate ground resolution in meters per pixel for a single tile
  var Center := BoundingBox.CenterPoint;
  var GeodeticCenter := FCoordinateConverter.CoordToGeodeticCoord(Center);
  var Resolution := cos(GeodeticCenter.Latitude*pi/180)*EarthCircumference/FTileSize;
  // Determine highest zoom level that contains the bounding box
  var Level := 0;
  repeat
    Inc(Level);
    Resolution := Resolution/2;
  until (Resolution*PixelWidth < BoundingBoxWidth) or (Resolution*PixelHeight < BoundingBoxHeight) or (Level > MaxZoomLevel);
  SetZoomLevel(Max(1,Level-1));
  // Calculate Mercator coordinates of bounding box center
  var Xmercator := MercatorMapSize*WebMercatorProjection.LongitudeToXCoord(GeodeticCenter.Longitude);
  var Ymercator := MercatorMapSize*WebMercatorProjection.LatitudeToYCoord(GeodeticCenter.Latitude);
  // Set TopLeft Mercator map
  MercatorMapLeft := Xmercator-0.5*PixelWidth;
  MercatorMapTop := Ymercator-0.5*PixelHeight;
  // Update history
  Changed;
end;

Procedure TWebMercatorPixelConverter.ZoomIn(const Pixel: TPointF; const DeltaZoom: Integer);
begin
  // Get geodetic coordinates of pont to zoom to
  var Coord := PixelToGeodeticCoord(Pixel);
  // Increase zoom level
  SetZoomLevel(FZoomLevel+DeltaZoom);
  // Calculate Mercator coordinates of coordinate
  var Xmercator := MercatorMapSize*WebMercatorProjection.LongitudeToXCoord(Coord.Longitude);
  var Ymercator := MercatorMapSize*WebMercatorProjection.LatitudeToYCoord(Coord.Latitude);
  // Set TopLeft Mercator map
  MercatorMapLeft := Xmercator-0.5*PixelWidth;
  MercatorMapTop := Ymercator-0.5*PixelHeight;
  // Update history
  Changed;
end;

Procedure TWebMercatorPixelConverter.ZoomIn(const Pixel: TPointF);
begin
  if FInitialized then
    ZoomIn(Pixel,1)
  else
    raise Exception.Create('Pixel converter not initialized');
end;

Procedure TWebMercatorPixelConverter.ZoomIn(const Pixels: TRectF);
begin
  if FInitialized then
  begin
    var DeltaZoom := 1;
    var ZoomFac := 2.0;
    var HorizZoom := FPixelWidth/Pixels.Width;
    var VertZoom := FPixelHeight/Pixels.Height;
    if HorizZoom < VertZoom then
      while ZoomFac < HorizZoom do
      begin
        Inc(DeltaZoom);
        ZoomFac := 2*ZoomFac;
      end
    else
      while ZoomFac < VertZoom do
      begin
        Inc(DeltaZoom);
        ZoomFac := 2*ZoomFac;
      end;
    ZoomIn(Pixels.CenterPoint,DeltaZoom);
  end else
    raise Exception.Create('Pixel converter not initialized');
end;

Procedure TWebMercatorPixelConverter.ZoomOut(const Pixel: TPointF);
begin
  if FInitialized then
  begin
    // Get geodetic coordinates of pont to zoom to
    var Coord := PixelToGeodeticCoord(Pixel);
    // Decrease zoom level
    SetZoomLevel(FZoomLevel-1);
    // Calculate Mercator coordinates of coordinate
    var Xmercator := MercatorMapSize*WebMercatorProjection.LongitudeToXCoord(Coord.Longitude);
    var Ymercator := MercatorMapSize*WebMercatorProjection.LatitudeToYCoord(Coord.Latitude);
    // Set TopLeft Mercator map
    MercatorMapLeft := Xmercator-0.5*PixelWidth;
    MercatorMapTop := Ymercator-0.5*PixelHeight;
    // Update history
    Changed;
  end else
    raise Exception.Create('Pixel converter not initialized');
end;

Procedure TWebMercatorPixelConverter.PanMap(const DeltaXPixel,DeltaYPixel: Float32);
begin
  if FInitialized then
  begin
    MercatorMapLeft := MercatorMapLeft-DeltaXPixel;
    MercatorMapTop := MercatorMapTop-DeltaYPixel;
    Changed;
  end else
    raise Exception.Create('Pixel converter not initialized');
end;

Function TWebMercatorPixelConverter.LeftTile: Integer;
begin
  Result := Floor(MercatorMapLeft/FTileSize);
end;

Function TWebMercatorPixelConverter.LeftTilePosition: Integer;
begin
  Result := Round(LeftTile*FTileSize-MercatorMapLeft);
end;

Function TWebMercatorPixelConverter.HorizTilesCount: Integer;
begin
  Result := Ceil((FPixelWidth-LeftTilePosition)/FTileSize);
end;

Function TWebMercatorPixelConverter.TopTile: Integer;
begin
  Result := Floor(MercatorMapTop/FTileSize);
end;

Function TWebMercatorPixelConverter.TopTilePosition: Integer;
begin
  Result := Round(TopTile*FTileSize-MercatorMapTop);
end;

Function TWebMercatorPixelConverter.VertTilesCount: Integer;
begin
  Result := Ceil((FPixelHeight-TopTilePosition)/FTileSize);
end;

Function TWebMercatorPixelConverter.GetViewport: TCoordinateRect;
begin
  Result.Left := NegInfinity;
  Result.Top := Infinity;
  Result.Right := Infinity;
  Result.Bottom := NegInfinity;
end;

Destructor TWebMercatorPixelConverter.Destroy;
begin
  FCoordinateConverter.Free;
  WebMercatorProjection.Free;
  inherited Destroy;
end;

end.

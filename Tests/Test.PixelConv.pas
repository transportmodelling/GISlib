unit Test.PixelConv;

////////////////////////////////////////////////////////////////////////////////
//
// Author: Jaap Baak
// https://github.com/transportmodelling/GISlib
//
// Test suite generated with assistance from Claude Sonnet 4.6
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
interface
////////////////////////////////////////////////////////////////////////////////

uses
  Types, DUnitX.TestFramework, GIS, GIS.CoordConv, GIS.CoordConv.WGS84, GIS.CoordConv.DutchGrid,
  GIS.Render.PixelConv, GIS.Render.PixelConv.Cartesian, GIS.Render.PixelConv.Mercator;

type
  [TestFixture]
  TCartesianPixelConverterTests = class
  private
    FConv: TCartesianPixelConverter;
  public
    [Setup]    procedure Setup;
    [TearDown] procedure TearDown;

    [Test] procedure NotInitializedByDefault;
    [Test] procedure CoordToPixel_PixelToCoord_RoundTrip;
    [Test] procedure Initialize_CenterMapsToHalfPixelDimensions;
  end;

  [TestFixture]
  TWebMercatorPixelConverterTests = class
  private
    FConvWGS84:  TWebMercatorPixelConverter;
    FConvDutchGrid: TWebMercatorPixelConverter;
    function NetherlandsBBox: TCoordinateRect;
  public
    [Setup]    procedure Setup;
    [TearDown] procedure TearDown;

    [Test] procedure NotInitializedByDefault;
    [Test] procedure Initialize_SetsInitializedFlag;
    // SyncFrom: two converters with different CRS show the same tile layout
    [Test] procedure SyncFrom_SameZoomLevelAndMapOrigin;
    // Resize + pan: geographic centre stays fixed
    [Test] procedure Resize_PreservesGeographicCentre;
    // PanMap: centre shifts by the expected amount
    [Test] procedure PanMap_MovesGeographicCentre;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

uses System.SysUtils, System.Math;

{ TCartesianPixelConverterTests }

procedure TCartesianPixelConverterTests.Setup;
begin
  FConv := TCartesianPixelConverter.Create;
end;

procedure TCartesianPixelConverterTests.TearDown;
begin
  FConv.Free;
end;

procedure TCartesianPixelConverterTests.NotInitializedByDefault;
begin
  Assert.IsFalse(FConv.Initialized);
end;

procedure TCartesianPixelConverterTests.CoordToPixel_PixelToCoord_RoundTrip;
var
  BB: TCoordinateRect;
  Original, Recovered: TCoordinate;
  Px: TPointF;
begin
  BB.Left := 0; BB.Right := 100; BB.Bottom := 0; BB.Top := 100;
  FConv.Initialize(BB, 800, 600);
  Original := TCoordinate.Create(50.0, 50.0);
  Px := FConv.CoordToPixel(Original);
  Recovered := FConv.PixelToCoord(Px);
  Assert.AreEqual(Original.X, Recovered.X, 1e-8);
  Assert.AreEqual(Original.Y, Recovered.Y, 1e-8);
end;

procedure TCartesianPixelConverterTests.Initialize_CenterMapsToHalfPixelDimensions;
var
  BB: TCoordinateRect;
  CentrePx: TPointF;
begin
  BB.Left := 0; BB.Right := 100; BB.Bottom := 0; BB.Top := 100;
  FConv.Initialize(BB, 800, 600);
  CentrePx := FConv.CoordToPixel(BB.CenterPoint);
  Assert.AreEqual(400.0, CentrePx.X, 1.0, 'Centre X should be half pixel width');
  Assert.AreEqual(300.0, CentrePx.Y, 1.0, 'Centre Y should be half pixel height');
end;

{ TWebMercatorPixelConverterTests }

function TWebMercatorPixelConverterTests.NetherlandsBBox: TCoordinateRect;
begin
  Result.Left := 3.2; Result.Right := 7.3; Result.Bottom := 50.7; Result.Top := 53.7;
end;

procedure TWebMercatorPixelConverterTests.Setup;
begin
  FConvWGS84    := TWebMercatorPixelConverter.Create(TWgs84CoordinateConverter.Create);
  FConvDutchGrid := TWebMercatorPixelConverter.Create(TDutchGridCoordinateConverter.Create);
end;

procedure TWebMercatorPixelConverterTests.TearDown;
begin
  FConvWGS84.Free;
  FConvDutchGrid.Free;
end;

procedure TWebMercatorPixelConverterTests.NotInitializedByDefault;
begin
  Assert.IsFalse(FConvWGS84.Initialized);
end;

procedure TWebMercatorPixelConverterTests.Initialize_SetsInitializedFlag;
begin
  FConvWGS84.Initialize(NetherlandsBBox, 1000, 800);
  Assert.IsTrue(FConvWGS84.Initialized);
end;

procedure TWebMercatorPixelConverterTests.SyncFrom_SameZoomLevelAndMapOrigin;
var
  // Initialize WGS84 converter with Netherlands bbox
  // Sync a Dutch Grid converter from it
  // Both should have the same tile layout (same ZoomLevel, same map origin)
  BBoxDutchGrid: TCoordinateRect;
begin
  FConvWGS84.Initialize(NetherlandsBBox, 1000, 800);
  FConvDutchGrid.SyncFrom(FConvWGS84);

  Assert.AreEqual(FConvWGS84.ZoomLevel,   FConvDutchGrid.ZoomLevel, 'Zoom levels must match');
  Assert.AreEqual(Integer(FConvWGS84.TileSize), Integer(FConvDutchGrid.TileSize), 'Tile sizes must match');
  // Same pixel -> should convert to same geographic location regardless of CRS
  var GeoWGS84     := FConvWGS84.PixelToGeodeticCoord(TPointF.Create(500, 400));
  var GeoDutchGrid := FConvDutchGrid.PixelToGeodeticCoord(TPointF.Create(500, 400));
  Assert.AreEqual(GeoWGS84.Longitude, GeoDutchGrid.Longitude, 1e-6, 'Longitude after SyncFrom');
  Assert.AreEqual(GeoWGS84.Latitude,  GeoDutchGrid.Latitude,  1e-6, 'Latitude after SyncFrom');
end;

procedure TWebMercatorPixelConverterTests.Resize_PreservesGeographicCentre;
var
  CentreBefore, CentreAfter: TGeodeticCoordinate;
  OldW, OldH, NewW, NewH: Integer;
begin
  FConvWGS84.Initialize(NetherlandsBBox, 1000, 800);
  OldW := 1000; OldH := 800;
  CentreBefore := FConvWGS84.PixelToGeodeticCoord(TPointF.Create(OldW / 2, OldH / 2));

  NewW := 1200; NewH := 900;
  FConvWGS84.Resize(NewW, NewH);
  FConvWGS84.PanMap((NewW - OldW) / 2, (NewH - OldH) / 2);

  CentreAfter := FConvWGS84.PixelToGeodeticCoord(TPointF.Create(NewW / 2, NewH / 2));
  Assert.AreEqual(CentreBefore.Longitude, CentreAfter.Longitude, 1e-6, 'Longitude after resize');
  Assert.AreEqual(CentreBefore.Latitude,  CentreAfter.Latitude,  1e-6, 'Latitude after resize');
end;

procedure TWebMercatorPixelConverterTests.PanMap_MovesGeographicCentre;
var
  PointBefore, PointAfter: TGeodeticCoordinate;
begin
  FConvWGS84.Initialize(NetherlandsBBox, 1000, 800);
  // PanMap(100,0) subtracts 100 from MercatorMapLeft, shifting everything
  // 100 pixels to the right - so the point that was at pixel 400 appears at 500.
  PointBefore := FConvWGS84.PixelToGeodeticCoord(TPointF.Create(400, 400));
  FConvWGS84.PanMap(100, 0);
  PointAfter  := FConvWGS84.PixelToGeodeticCoord(TPointF.Create(500, 400));
  Assert.AreEqual(PointBefore.Longitude, PointAfter.Longitude, 1e-6, 'PanMap longitude');
  Assert.AreEqual(PointBefore.Latitude,  PointAfter.Latitude,  1e-6, 'PanMap latitude');
end;

initialization
  TDUnitX.RegisterTestFixture(TCartesianPixelConverterTests);
  TDUnitX.RegisterTestFixture(TWebMercatorPixelConverterTests);

end.

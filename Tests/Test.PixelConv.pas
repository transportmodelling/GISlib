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
    [Setup]    Procedure Setup;
    [TearDown] Procedure TearDown;

    [Test] Procedure NotInitializedByDefault;
    [Test] Procedure CoordToPixel_PixelToCoord_RoundTrip;
    [Test] Procedure Initialize_CenterMapsToHalfPixelDimensions;
  end;

  [TestFixture]
  TWebMercatorPixelConverterTests = class
  private
    FConvWGS84:  TWebMercatorPixelConverter;
    FConvDutchGrid: TWebMercatorPixelConverter;
    Function NetherlandsBBox: TCoordinateRect;
  public
    [Setup]    Procedure Setup;
    [TearDown] Procedure TearDown;

    [Test] Procedure NotInitializedByDefault;
    [Test] Procedure Initialize_SetsInitializedFlag;
    // SyncFrom: two converters with different CRS show the same tile layout
    [Test] Procedure SyncFrom_SameZoomLevelAndMapOrigin;
    // Resize: geographic centre stays fixed
    [Test] Procedure Resize_PreservesGeographicCentre;
    // PanMap: centre shifts by the expected amount
    [Test] Procedure PanMap_MovesGeographicCentre;
    // History: previous and next views
    [Test] Procedure Previous_Next_RestoreViews;
    [Test] Procedure Resize_IsNotAddedToHistory;
    [Test] Procedure Previous_AfterResize_RestoresGeographicCentre;
    [Test] Procedure Change_AfterPrevious_ClearsNext;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

uses System.SysUtils, System.Math;

////////////////////////////////////////////////////////////////////////////////

Procedure TCartesianPixelConverterTests.Setup;
begin
  FConv := TCartesianPixelConverter.Create;
end;

Procedure TCartesianPixelConverterTests.TearDown;
begin
  FConv.Free;
end;

Procedure TCartesianPixelConverterTests.NotInitializedByDefault;
begin
  Assert.IsFalse(FConv.Initialized);
end;

Procedure TCartesianPixelConverterTests.CoordToPixel_PixelToCoord_RoundTrip;
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

Procedure TCartesianPixelConverterTests.Initialize_CenterMapsToHalfPixelDimensions;
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

////////////////////////////////////////////////////////////////////////////////

Function TWebMercatorPixelConverterTests.NetherlandsBBox: TCoordinateRect;
begin
  Result.Left := 3.2; Result.Right := 7.3; Result.Bottom := 50.7; Result.Top := 53.7;
end;

Procedure TWebMercatorPixelConverterTests.Setup;
begin
  FConvWGS84    := TWebMercatorPixelConverter.Create(TWgs84CoordinateConverter.Create);
  FConvDutchGrid := TWebMercatorPixelConverter.Create(TDutchGridCoordinateConverter.Create);
end;

Procedure TWebMercatorPixelConverterTests.TearDown;
begin
  FConvWGS84.Free;
  FConvDutchGrid.Free;
end;

Procedure TWebMercatorPixelConverterTests.NotInitializedByDefault;
begin
  Assert.IsFalse(FConvWGS84.Initialized);
end;

Procedure TWebMercatorPixelConverterTests.Initialize_SetsInitializedFlag;
begin
  FConvWGS84.Initialize(NetherlandsBBox, 1000, 800);
  Assert.IsTrue(FConvWGS84.Initialized);
end;

Procedure TWebMercatorPixelConverterTests.SyncFrom_SameZoomLevelAndMapOrigin;
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

Procedure TWebMercatorPixelConverterTests.Resize_PreservesGeographicCentre;
var
  CentreBefore, CentreAfter: TGeodeticCoordinate;
  OldW, OldH, NewW, NewH: Integer;
begin
  FConvWGS84.Initialize(NetherlandsBBox, 1000, 800);
  OldW := 1000; OldH := 800;
  CentreBefore := FConvWGS84.PixelToGeodeticCoord(TPointF.Create(OldW / 2, OldH / 2));

  NewW := 1200; NewH := 900;
  FConvWGS84.Resize(NewW, NewH);

  CentreAfter := FConvWGS84.PixelToGeodeticCoord(TPointF.Create(NewW / 2, NewH / 2));
  Assert.AreEqual(CentreBefore.Longitude, CentreAfter.Longitude, 1e-6, 'Longitude after resize');
  Assert.AreEqual(CentreBefore.Latitude,  CentreAfter.Latitude,  1e-6, 'Latitude after resize');
end;

Procedure TWebMercatorPixelConverterTests.PanMap_MovesGeographicCentre;
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

Procedure TWebMercatorPixelConverterTests.Previous_Next_RestoreViews;
var
  Initial, Panned: TGeodeticCoordinate;
begin
  FConvWGS84.Initialize(NetherlandsBBox, 1000, 800);
  Assert.IsFalse(FConvWGS84.PreviousAvail, 'No previous view after Initialize');
  Initial := FConvWGS84.PixelToGeodeticCoord(TPointF.Create(500, 400));
  FConvWGS84.PanMap(100, 0);
  Panned := FConvWGS84.PixelToGeodeticCoord(TPointF.Create(500, 400));

  Assert.IsTrue(FConvWGS84.Previous, 'Previous');
  var Centre := FConvWGS84.PixelToGeodeticCoord(TPointF.Create(500, 400));
  Assert.AreEqual(Initial.Longitude, Centre.Longitude, 1e-6, 'Longitude after Previous');
  Assert.AreEqual(Initial.Latitude,  Centre.Latitude,  1e-6, 'Latitude after Previous');
  Assert.IsFalse(FConvWGS84.PreviousAvail, 'Back at the first view');
  Assert.IsTrue(FConvWGS84.NextAvail, 'Next view available');

  Assert.IsTrue(FConvWGS84.Next, 'Next');
  Centre := FConvWGS84.PixelToGeodeticCoord(TPointF.Create(500, 400));
  Assert.AreEqual(Panned.Longitude, Centre.Longitude, 1e-6, 'Longitude after Next');
  Assert.AreEqual(Panned.Latitude,  Centre.Latitude,  1e-6, 'Latitude after Next');
  Assert.IsFalse(FConvWGS84.NextAvail, 'Back at the last view');
end;

Procedure TWebMercatorPixelConverterTests.Resize_IsNotAddedToHistory;
begin
  FConvWGS84.Initialize(NetherlandsBBox, 1000, 800);
  FConvWGS84.PanMap(100, 0);
  Assert.IsTrue(FConvWGS84.Previous, 'Previous');
  FConvWGS84.Resize(1200, 900);
  // A resize neither adds a view nor drops the view after the current one
  Assert.IsFalse(FConvWGS84.PreviousAvail, 'Resize added no previous view');
  Assert.IsTrue(FConvWGS84.NextAvail, 'Resize kept the next view');
end;

Procedure TWebMercatorPixelConverterTests.Previous_AfterResize_RestoresGeographicCentre;
var
  Initial: TGeodeticCoordinate;
begin
  FConvWGS84.Initialize(NetherlandsBBox, 1000, 800);
  Initial := FConvWGS84.PixelToGeodeticCoord(TPointF.Create(500, 400));
  FConvWGS84.PanMap(100, 50);
  FConvWGS84.Resize(1200, 900);
  Assert.IsTrue(FConvWGS84.Previous, 'Previous');
  // The earlier view comes back centred in the resized window
  var Centre := FConvWGS84.PixelToGeodeticCoord(TPointF.Create(600, 450));
  Assert.AreEqual(Initial.Longitude, Centre.Longitude, 1e-6, 'Longitude after Previous');
  Assert.AreEqual(Initial.Latitude,  Centre.Latitude,  1e-6, 'Latitude after Previous');
end;

Procedure TWebMercatorPixelConverterTests.Change_AfterPrevious_ClearsNext;
begin
  FConvWGS84.Initialize(NetherlandsBBox, 1000, 800);
  FConvWGS84.PanMap(100, 0);
  Assert.IsTrue(FConvWGS84.Previous, 'Previous');
  FConvWGS84.ZoomIn(TPointF.Create(500, 400));
  Assert.IsFalse(FConvWGS84.NextAvail, 'A new view drops the views after the current one');
  Assert.IsTrue(FConvWGS84.PreviousAvail, 'The view zoomed from is the previous view');
end;

initialization
  TDUnitX.RegisterTestFixture(TCartesianPixelConverterTests);
  TDUnitX.RegisterTestFixture(TWebMercatorPixelConverterTests);

end.

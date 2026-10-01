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
    FChanges: Integer;
    Procedure CountChange(Sender: TObject);
  public
    [Setup]    Procedure Setup;
    [TearDown] Procedure TearDown;

    [Test] Procedure NotInitializedByDefault;
    [Test] Procedure CoordToPixel_PixelToCoord_RoundTrip;
    [Test] Procedure Initialize_CenterMapsToHalfPixelDimensions;
    // Initialize: the bounding box spans the full height or the full width
    [Test] Procedure Initialize_WideBoundingBoxSpansPixelWidth;
    [Test] Procedure Initialize_TallBoundingBoxSpansPixelHeight;
    [Test] Procedure Initialize_SinglePoint_CentresOnThePoint;
    [Test] Procedure Initialize_HorizontalLine_FitsTheLine;
    [Test] Procedure Initialize_EmptyBoundingBox_Raises;
    [Test] Procedure Initialize_Margin_LeavesRoomAroundTheBox;
    [Test] Procedure Initialize_MarginLeavingNoRoom_Raises;
    [Test] Procedure OnChange_Assigned_FiresAtOnce;
    [Test] Procedure OnChange_FiresOnEveryChange;
    [Test] Procedure OnChange_Nil_IsAccepted;
    // Resize: centre and scale stay fixed
    [Test] Procedure Resize_PreservesCentreAndScale;
    [Test] Procedure Resize_IsNotAddedToHistory;
    [Test] Procedure Previous_AfterResize_RestoresCentre;
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
    [Test] Procedure Initialize_Margin_TakesTheZoomLevelThatFitsWithinIt;
    [Test] Procedure GeodeticCoordToPixel_BeyondTheMap_IsClampedToItsEdge;
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

Procedure TCartesianPixelConverterTests.CountChange(Sender: TObject);
begin
  Inc(FChanges);
end;

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
  Assert.AreEqual(400.0, CentrePx.X, 1e-3, 'Centre X should be half pixel width');
  Assert.AreEqual(300.0, CentrePx.Y, 1e-3, 'Centre Y should be half pixel height');
end;

Procedure TCartesianPixelConverterTests.Initialize_WideBoundingBoxSpansPixelWidth;
var
  BB: TCoordinateRect;
begin
  BB.Left := 1000; BB.Right := 5000; BB.Bottom := 200; BB.Top := 1200;
  FConv.Initialize(BB, 800, 600);
  var TopLeft := FConv.CoordToPixel(BB.Left,BB.Top);
  var BottomRight := FConv.CoordToPixel(BB.Right,BB.Bottom);
  Assert.AreEqual(0.0, TopLeft.X, 1e-3, 'Left edge');
  Assert.AreEqual(800.0, BottomRight.X, 1e-3, 'Right edge');
  // Centred over the height, at the scale of the width
  Assert.AreEqual(200.0, TopLeft.Y, 1e-3, 'Top edge');
  Assert.AreEqual(400.0, BottomRight.Y, 1e-3, 'Bottom edge');
end;

Procedure TCartesianPixelConverterTests.Initialize_TallBoundingBoxSpansPixelHeight;
var
  BB: TCoordinateRect;
begin
  BB.Left := 1000; BB.Right := 2000; BB.Bottom := 200; BB.Top := 3200;
  FConv.Initialize(BB, 800, 600);
  var TopLeft := FConv.CoordToPixel(BB.Left,BB.Top);
  var BottomRight := FConv.CoordToPixel(BB.Right,BB.Bottom);
  Assert.AreEqual(0.0, TopLeft.Y, 1e-3, 'Top edge');
  Assert.AreEqual(600.0, BottomRight.Y, 1e-3, 'Bottom edge');
  // Centred over the width, at the scale of the height
  Assert.AreEqual(300.0, TopLeft.X, 1e-3, 'Left edge');
  Assert.AreEqual(500.0, BottomRight.X, 1e-3, 'Right edge');
end;

Procedure TCartesianPixelConverterTests.Initialize_SinglePoint_CentresOnThePoint;
// A bounding box without width or height still gives a view, with the point in the middle
var
  BB: TCoordinateRect;
begin
  BB.Clear;
  BB.Enclose(TCoordinate.Create(1000, 200));
  FConv.Initialize(BB, 800, 600);
  var Pixel := FConv.CoordToPixel(1000, 200);
  Assert.AreEqual(400.0, Pixel.X, 1e-3, 'X');
  Assert.AreEqual(300.0, Pixel.Y, 1e-3, 'Y');
  Assert.IsTrue(FConv.CoordUnitsPerPixel > 0, 'Scale');
end;

Procedure TCartesianPixelConverterTests.Initialize_HorizontalLine_FitsTheLine;
// The line from (0,5) to (10,5) gets a 10 by 10 box, which 200 by 100 pixels show at 10 pixels per unit, centred
var
  BB: TCoordinateRect;
begin
  BB.Clear;
  BB.Enclose(TCoordinate.Create(0, 5));
  BB.Enclose(TCoordinate.Create(10, 5));
  FConv.Initialize(BB, 200, 100);
  var LeftEnd := FConv.CoordToPixel(0, 5);
  var RightEnd := FConv.CoordToPixel(10, 5);
  Assert.AreEqual(50.0, LeftEnd.X, 1e-3, 'Left end');
  Assert.AreEqual(150.0, RightEnd.X, 1e-3, 'Right end');
  Assert.AreEqual(50.0, LeftEnd.Y, 1e-3, 'Height');
end;

Procedure TCartesianPixelConverterTests.Initialize_EmptyBoundingBox_Raises;
var
  BB: TCoordinateRect;
begin
  BB.Clear;
  Assert.WillRaise(Procedure begin FConv.Initialize(BB, 800, 600) end, Exception);
  Assert.IsFalse(FConv.Initialized, 'Not initialized');
end;

Procedure TCartesianPixelConverterTests.Initialize_Margin_LeavesRoomAroundTheBox;
// A 10 by 10 box in 100 by 100 pixels with a margin of 10 fills the 80 pixels within the margin
var
  BB: TCoordinateRect;
begin
  BB.Left := 0; BB.Right := 10; BB.Bottom := 0; BB.Top := 10;
  FConv.Margin := 10;
  FConv.Initialize(BB, 100, 100);
  var TopLeft := FConv.CoordToPixel(BB.Left, BB.Top);
  var BottomRight := FConv.CoordToPixel(BB.Right, BB.Bottom);
  Assert.AreEqual(10.0, TopLeft.X, 1e-3, 'Left edge');
  Assert.AreEqual(10.0, TopLeft.Y, 1e-3, 'Top edge');
  Assert.AreEqual(90.0, BottomRight.X, 1e-3, 'Right edge');
  Assert.AreEqual(90.0, BottomRight.Y, 1e-3, 'Bottom edge');
end;

Procedure TCartesianPixelConverterTests.Initialize_MarginLeavingNoRoom_Raises;
var
  BB: TCoordinateRect;
begin
  BB.Left := 0; BB.Right := 10; BB.Bottom := 0; BB.Top := 10;
  FConv.Margin := 50;
  Assert.WillRaise(Procedure begin FConv.Initialize(BB, 100, 100) end, Exception);
  Assert.IsFalse(FConv.Initialized, 'Not initialized');
end;

Procedure TCartesianPixelConverterTests.OnChange_Assigned_FiresAtOnce;
// So that whatever shows the view is brought up to date on being connected
begin
  FChanges := 0;
  FConv.OnChange := CountChange;
  Assert.AreEqual(1, FChanges);
end;

Procedure TCartesianPixelConverterTests.OnChange_FiresOnEveryChange;
var
  BB: TCoordinateRect;
begin
  FChanges := 0;
  FConv.OnChange := CountChange;
  BB.Left := 0; BB.Right := 10; BB.Bottom := 0; BB.Top := 10;
  FConv.Initialize(BB, 100, 100);
  FConv.ZoomIn(TPointF.Create(50, 50));
  FConv.PanMap(5, 5);
  Assert.AreEqual(4, FChanges);
end;

Procedure TCartesianPixelConverterTests.OnChange_Nil_IsAccepted;
// Disconnecting must not call the handler that is no longer there
begin
  FConv.OnChange := CountChange;
  FConv.OnChange := nil;
  Assert.IsFalse(Assigned(FConv.OnChange));
end;

Procedure TCartesianPixelConverterTests.Resize_PreservesCentreAndScale;
var
  BB: TCoordinateRect;
begin
  BB.Left := 0; BB.Right := 100; BB.Bottom := 0; BB.Top := 100;
  FConv.Initialize(BB, 800, 600);
  var Scale := FConv.CoordUnitsPerPixel;
  FConv.Resize(1000, 700);
  var Centre := FConv.PixelToCoord(TPointF.Create(500, 350));
  Assert.AreEqual(50.0, Centre.X, 1e-8, 'Centre X');
  Assert.AreEqual(50.0, Centre.Y, 1e-8, 'Centre Y');
  Assert.AreEqual(Scale, FConv.CoordUnitsPerPixel, 1e-12, 'Scale');
  Assert.AreEqual(1000*Scale, FConv.Viewport.Width, 1e-8, 'Viewport width');
  Assert.AreEqual(700*Scale, FConv.Viewport.Height, 1e-8, 'Viewport height');
end;

Procedure TCartesianPixelConverterTests.Resize_IsNotAddedToHistory;
var
  BB: TCoordinateRect;
begin
  BB.Left := 0; BB.Right := 100; BB.Bottom := 0; BB.Top := 100;
  FConv.Initialize(BB, 800, 600);
  FConv.PanMap(100, 0);
  Assert.IsTrue(FConv.Previous, 'Previous');
  FConv.Resize(1000, 700);
  // A resize neither adds a view nor drops the view after the current one
  Assert.IsFalse(FConv.PreviousAvail, 'Resize added no previous view');
  Assert.IsTrue(FConv.NextAvail, 'Resize kept the next view');
end;

Procedure TCartesianPixelConverterTests.Previous_AfterResize_RestoresCentre;
var
  BB: TCoordinateRect;
begin
  BB.Left := 0; BB.Right := 100; BB.Bottom := 0; BB.Top := 100;
  FConv.Initialize(BB, 800, 600);
  FConv.PanMap(100, 50);
  FConv.Resize(1000, 700);
  Assert.IsTrue(FConv.Previous, 'Previous');
  // The earlier view comes back centred in the resized window
  var Centre := FConv.PixelToCoord(TPointF.Create(500, 350));
  Assert.AreEqual(50.0, Centre.X, 1e-8, 'Centre X after Previous');
  Assert.AreEqual(50.0, Centre.Y, 1e-8, 'Centre Y after Previous');
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

Procedure TWebMercatorPixelConverterTests.Initialize_Margin_TakesTheZoomLevelThatFitsWithinIt;
// 80 degrees of longitude at the equator is a little under a quarter of the earth, which is
// what 256 pixels show at zoom level 2; within a margin of 20 pixels that no longer fits
var
  BB: TCoordinateRect;
begin
  BB.Left := -40; BB.Right := 40; BB.Bottom := -1; BB.Top := 1;
  FConvWGS84.Initialize(BB, 256, 256);
  Assert.AreEqual(2, Integer(FConvWGS84.ZoomLevel), 'Without margin');
  FConvWGS84.Margin := 20;
  FConvWGS84.Initialize(BB, 256, 256);
  Assert.AreEqual(1, Integer(FConvWGS84.ZoomLevel), 'Within the margin');
end;

Procedure TWebMercatorPixelConverterTests.GeodeticCoordToPixel_BeyondTheMap_IsClampedToItsEdge;
// Web Mercator reaches neither pole; a vertex beyond its edge is drawn on the edge rather
// than aborting the layer
var
  BB: TCoordinateRect;
  Coord: TGeodeticCoordinate;
begin
  BB.Left := -10; BB.Right := 10; BB.Bottom := 40; BB.Top := 60;
  FConvWGS84.Initialize(BB, 256, 256);
  Coord.Longitude := 0;
  Coord.Latitude := 89;
  var Beyond := FConvWGS84.GeodeticCoordToPixel(Coord);
  Coord.Latitude := 85;
  var Edge := FConvWGS84.GeodeticCoordToPixel(Coord);
  Assert.IsTrue(Beyond.Y <= Edge.Y, 'At or above the 85th parallel');
  Coord.Latitude := 50;
  Coord.Longitude := 200;
  Beyond := FConvWGS84.GeodeticCoordToPixel(Coord);
  Coord.Longitude := 180;
  Edge := FConvWGS84.GeodeticCoordToPixel(Coord);
  Assert.AreEqual(Edge.X, Beyond.X, 1e-3, 'On the antimeridian');
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

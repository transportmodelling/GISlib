unit Test.Render.Shapes;

////////////////////////////////////////////////////////////////////////////////
//
// Author: Jaap Baak
// https://github.com/transportmodelling/GISlib
//
// Tests for TShapesLayer from GIS.Render.Shapes that need a canvas but not a
// device: the layer draws on the SVG canvas, so they build on every platform.
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
interface
////////////////////////////////////////////////////////////////////////////////

uses
  System.SysUtils, System.Classes, System.IOUtils,
  DUnitX.TestFramework,
  GIS, GIS.Shapes, GIS.Shapes.GeoJSON,
  GIS.Render.Canvas, GIS.Render.Canvas.SVG,
  GIS.Render.Shapes, GIS.Render.PixelConv.Cartesian;

type
  TLabeledShapesLayer = class(TShapesLayer)
  // Labels every shape, so that drawing the layer positions a label
  strict protected
    Function ShapeLabel(const Shape: Integer): String; override;
  end;

  [TestFixture]
  TShapesLayerTests = class
  private
    // Two 10x10 rings with a 2x2 hole, centred at (0,0) and at (20,0)
    Procedure AddDonuts(const Layer: TShapesLayer);
    Function TwoDonuts: TLabeledShapesLayer;
    // Draws the layer large enough for its labels to be placed
    Procedure Draw(const Layer: TShapesLayer);
    // A file name in the temp directory that no other test uses
    Function TempFileName: String;
    // The label positions the layer saves
    Function SavedLabelPositions(const Layer: TShapesLayer): TBytes;
    Procedure AssertSameBytes(const Expected,Actual: TBytes; const Message: String);
    // The number of heap blocks allocated at this moment
    Function AllocatedBlocks: Int64;
  public
    [Test] Procedure Add_EmptyShape_Raises;
    [Test] Procedure Clear_LeavesNoShapes;
    [Test] Procedure Clear_FreesTheRenderers;
    [Test] Procedure Read_SkipsFeaturesWithoutGeometry;
    [Test] Procedure SaveLabelPositions_WritesOnePositionPerOuterRing;
    [Test] Procedure SaveLabelPositions_AfterDrawing_WritesTheSamePositions;
    [Test] Procedure ReadLabelPositions_RoundTrips;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Function TLabeledShapesLayer.ShapeLabel(const Shape: Integer): String;
begin
  Result := 'A';
end;

////////////////////////////////////////////////////////////////////////////////

Procedure TShapesLayerTests.AddDonuts(const Layer: TShapesLayer);
var
  Parts: TMultiPoints;
  Shape: TGISShape;
begin
  for var Offset in [0,20] do
  begin
    SetLength(Parts,2);
    Parts[0] := [TCoordinate.Create(Offset-5,-5),TCoordinate.Create(Offset+5,-5),
                 TCoordinate.Create(Offset+5,5),TCoordinate.Create(Offset-5,5)];
    Parts[1] := [TCoordinate.Create(Offset-1,-1),TCoordinate.Create(Offset+1,-1),
                 TCoordinate.Create(Offset+1,1),TCoordinate.Create(Offset-1,1)];
    Shape.AssignPolyPolygon(Parts);
    Layer.Add(Shape);
  end;
end;

Function TShapesLayerTests.TwoDonuts: TLabeledShapesLayer;
begin
  Result := TLabeledShapesLayer.Create;
  try
    AddDonuts(Result);
  except
    Result.Free;
    raise;
  end;
end;

Procedure TShapesLayerTests.Draw(const Layer: TShapesLayer);
begin
  var Canvas: IGISCanvas := TSvgCanvas.Create(400,400);
  var Converter := TCartesianPixelConverter.Create;
  try
    Converter.Initialize(Layer.BoundingBox,400,400);
    Layer.DrawLayer(Canvas,Converter);
  finally
    Converter.Free;
  end;
end;

Function TShapesLayerTests.TempFileName: String;
begin
  Result := TPath.Combine(TPath.GetTempPath,'TestShapesLayer_' + TGUID.NewGuid.ToString + '.tmp');
end;

Function TShapesLayerTests.SavedLabelPositions(const Layer: TShapesLayer): TBytes;
begin
  var FileName := TempFileName;
  try
    Layer.SaveLabelPositions(FileName);
    Result := TFile.ReadAllBytes(FileName);
  finally
    TFile.Delete(FileName);
  end;
end;

Procedure TShapesLayerTests.AssertSameBytes(const Expected,Actual: TBytes; const Message: String);
begin
  Assert.AreEqual(Length(Expected),Length(Actual),Message + ': length');
  for var Index := low(Expected) to high(Expected) do
  if Expected[Index] <> Actual[Index] then Assert.Fail(Message + ': byte ' + Index.ToString);
end;

{$WARN SYMBOL_PLATFORM OFF}
Function TShapesLayerTests.AllocatedBlocks: Int64;
// Delphi's own memory manager keeps these counts on every platform it runs on
var
  State: TMemoryManagerState;
begin
  GetMemoryManagerState(State);
  Result := State.AllocatedMediumBlockCount + State.AllocatedLargeBlockCount;
  for var BlockType := low(State.SmallBlockTypeStates) to high(State.SmallBlockTypeStates) do
  Inc(Result, State.SmallBlockTypeStates[BlockType].AllocatedBlockCount);
end;
{$WARN SYMBOL_PLATFORM ON}

Procedure TShapesLayerTests.Add_EmptyShape_Raises;
var
  Shape: TGISShape;
begin
  Shape.Clear;
  var Layer := TShapesLayer.Create;
  try
    Assert.WillRaise(Procedure begin Layer.Add(Shape) end,Exception);
    Assert.AreEqual(0,Layer.Count,'Nothing was added');
  finally
    Layer.Free;
  end;
end;

Procedure TShapesLayerTests.Clear_LeavesNoShapes;
begin
  var Layer := TwoDonuts;
  try
    Layer.Clear;
    Assert.AreEqual(0,Layer.Count);
    Assert.AreEqual(0,Layer.ShapeCount(stPolygon));
    Assert.IsTrue(Layer.BoundingBox.Empty,'Bounding box');
  finally
    Layer.Free;
  end;
end;

Procedure TShapesLayerTests.Clear_FreesTheRenderers;
// Adding shapes after a Clear must not leave the shapes cleared away behind
begin
  var Layer := TwoDonuts;
  try
    Layer.Clear;
    var Before := AllocatedBlocks;
    AddDonuts(Layer);
    Layer.Clear;
    Assert.AreEqual(Before,AllocatedBlocks,'Heap blocks left allocated');
  finally
    Layer.Free;
  end;
end;

Procedure TShapesLayerTests.Read_SkipsFeaturesWithoutGeometry;
// GeoJSON allows a polygon with no rings; there is nothing to draw for it
begin
  var FileName := TempFileName;
  var Layer := TShapesLayer.Create;
  try
    TFile.WriteAllText(FileName,
      '{"type":"FeatureCollection","features":[' +
      '{"type":"Feature","geometry":{"type":"Polygon","coordinates":[]},"properties":{}},' +
      '{"type":"Feature","geometry":{"type":"Polygon","coordinates":[[[0,0],[1,0],[1,1],[0,1],[0,0]]]},"properties":{}}' +
      ']}');
    Layer.Read(FileName,TGeoJSONReader);
    Assert.AreEqual(1,Layer.Count,'Shapes');
    Assert.AreEqual(1,Layer.ShapeCount(stPolygon),'Polygons');
  finally
    Layer.Free;
    TFile.Delete(FileName);
  end;
end;

Procedure TShapesLayerTests.SaveLabelPositions_WritesOnePositionPerOuterRing;
// Two outer rings, each an X and a Y as doubles
begin
  var Layer := TwoDonuts;
  try
    Assert.AreEqual(32,Integer(Length(SavedLabelPositions(Layer))),'2 rings x 2 doubles of 8 bytes');
  finally
    Layer.Free;
  end;
end;

Procedure TShapesLayerTests.SaveLabelPositions_AfterDrawing_WritesTheSamePositions;
// Drawing positions the labels; saving afterwards must write those positions,
// which are the ones saving calculates for itself when nothing was drawn
begin
  var Undrawn := TwoDonuts;
  var Drawn := TwoDonuts;
  try
    Draw(Drawn);
    AssertSameBytes(SavedLabelPositions(Undrawn),SavedLabelPositions(Drawn),'Positions');
  finally
    Drawn.Free;
    Undrawn.Free;
  end;
end;

Procedure TShapesLayerTests.ReadLabelPositions_RoundTrips;
begin
  var Source := TwoDonuts;
  var Target := TwoDonuts;
  var FileName := TempFileName;
  try
    Source.SaveLabelPositions(FileName);
    Target.ReadLabelPositions(FileName);
    AssertSameBytes(TFile.ReadAllBytes(FileName),SavedLabelPositions(Target),'Positions');
  finally
    TFile.Delete(FileName);
    Target.Free;
    Source.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TShapesLayerTests);

end.

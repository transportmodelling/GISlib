unit Test.Render.Network;

////////////////////////////////////////////////////////////////////////////////
//
// Author: Jaap Baak
// https://github.com/transportmodelling/GISlib
//
// Tests for TNetworkLayer from GIS.Render.Shapes.Network. The layer draws on
// the SVG canvas, so they build on every platform.
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
interface
////////////////////////////////////////////////////////////////////////////////

uses
  System.SysUtils,
  DUnitX.TestFramework,
  GIS,
  GIS.Render.Canvas, GIS.Render.Canvas.SVG,
  GIS.Render.Shapes.Network, GIS.Render.PixelConv.Cartesian;

type
  [TestFixture]
  TNetworkLayerTests = class
  private
    Function Occurrences(const SubText,Text: String): Integer;
  public
    [Test] Procedure AddNode_ReturnsTheIndexOfTheNode;
    [Test] Procedure AddNode_EnclosesTheNodeInTheBoundingBox;
    [Test] Procedure AddNode_BeyondTheInitialCapacity_KeepsTheNodes;
    [Test] Procedure AddLink_KeepsItsNodes;
    [Test] Procedure Clear_LeavesNoNodesLinksOrBoundingBox;
    [Test] Procedure DrawLayer_DrawsOnePathPerLink;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Function TNetworkLayerTests.Occurrences(const SubText,Text: String): Integer;
begin
  Result := 0;
  var Position := Pos(SubText,Text);
  while Position > 0 do
  begin
    Inc(Result);
    Position := Pos(SubText,Text,Position+1);
  end;
end;

Procedure TNetworkLayerTests.AddNode_ReturnsTheIndexOfTheNode;
begin
  var Layer := TNetworkLayer.Create;
  try
    Assert.AreEqual(0,Layer.AddNode(0,0));
    Assert.AreEqual(1,Layer.AddNode(TCoordinate.Create(1,0)));
    Assert.AreEqual(2,Layer.AddNode(2,0));
    Assert.AreEqual(3,Layer.NodesCount);
  finally
    Layer.Free;
  end;
end;

Procedure TNetworkLayerTests.AddNode_EnclosesTheNodeInTheBoundingBox;
begin
  var Layer := TNetworkLayer.Create;
  try
    Assert.IsTrue(Layer.BoundingBox.Empty,'Empty before the first node');
    Layer.AddNode(1,2);
    Layer.AddNode(-3,5);
    Assert.AreEqual(-3.0,Layer.BoundingBox.Left,1e-12);
    Assert.AreEqual( 1.0,Layer.BoundingBox.Right,1e-12);
    Assert.AreEqual( 2.0,Layer.BoundingBox.Bottom,1e-12);
    Assert.AreEqual( 5.0,Layer.BoundingBox.Top,1e-12);
  finally
    Layer.Free;
  end;
end;

Procedure TNetworkLayerTests.AddNode_BeyondTheInitialCapacity_KeepsTheNodes;
begin
  var Layer := TNetworkLayer.Create(1,1);
  try
    for var Node := 0 to 9 do Layer.AddNode(Node,0);
    Assert.AreEqual(10,Layer.NodesCount);
    for var Node := 0 to 9 do Assert.AreEqual(Node*1.0,Layer.Nodes[Node].X,1e-12,'Node ' + Node.ToString);
  finally
    Layer.Free;
  end;
end;

Procedure TNetworkLayerTests.AddLink_KeepsItsNodes;
begin
  var Layer := TNetworkLayer.Create(1,1);
  try
    Layer.AddNode(0,0);
    Layer.AddNode(1,0);
    Layer.AddNode(1,1);
    Layer.AddLink(0,1);
    Layer.AddLink(TNetworkLink.Create(1,2));
    Assert.AreEqual(2,Layer.LinksCount);
    Assert.AreEqual(0,Layer[0].FromNode);
    Assert.AreEqual(1,Layer[0].ToNode);
    Assert.AreEqual(1,Layer[1].FromNode);
    Assert.AreEqual(2,Layer[1].ToNode);
  finally
    Layer.Free;
  end;
end;

Procedure TNetworkLayerTests.Clear_LeavesNoNodesLinksOrBoundingBox;
begin
  var Layer := TNetworkLayer.Create;
  try
    Layer.AddNode(0,0);
    Layer.AddNode(1,1);
    Layer.AddLink(0,1);
    Layer.Clear;
    Assert.AreEqual(0,Layer.NodesCount,'Nodes');
    Assert.AreEqual(0,Layer.LinksCount,'Links');
    Assert.IsTrue(Layer.BoundingBox.Empty,'Bounding box');
  finally
    Layer.Free;
  end;
end;

Procedure TNetworkLayerTests.DrawLayer_DrawsOnePathPerLink;
var
  Viewport: TCoordinateRect;
begin
  var Svg := TSvgCanvas.Create(100,100);
  var Canvas: IGISCanvas := Svg;
  var Layer := TNetworkLayer.Create;
  var Converter := TCartesianPixelConverter.Create;
  try
    Layer.AddNode(0,0);
    Layer.AddNode(10,0);
    Layer.AddNode(10,10);
    Layer.AddLink(0,1);
    Layer.AddLink(1,2);
    Viewport.Clear;
    Viewport.Enclose(TCoordinate.Create(-1,-1));
    Viewport.Enclose(TCoordinate.Create(11,11));
    Converter.Initialize(Viewport,100,100);
    Layer.DrawLayer(Canvas,Converter);
    Assert.AreEqual(2,Occurrences('<path ',Svg.Document));
  finally
    Converter.Free;
    Layer.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TNetworkLayerTests);

end.

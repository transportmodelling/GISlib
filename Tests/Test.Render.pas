unit Test.Render;

////////////////////////////////////////////////////////////////////////////////
//
// Author: Jaap Baak
// https://github.com/transportmodelling/GISlib
//
// Test suite generated with assistance from Claude Opus 5
//
// Tests for the IGISCanvas abstraction and its VCL adapter. Drawing is verified
// by rendering to a bitmap and reading pixels back, which is the only way to
// tell that a polygon hole is really cut out rather than painted over.
//
// These tests need Vcl.Graphics and GDI+, unlike the rest of the suite.
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
interface
////////////////////////////////////////////////////////////////////////////////

{$IFDEF MSWINDOWS}

uses
  System.SysUtils, System.Classes, System.Types, System.UITypes,
  Vcl.Graphics, Vcl.Imaging.PngImage,
  DUnitX.TestFramework,
  GIS, GIS.Shapes,
  GIS.Render.Canvas, GIS.Render.Canvas.VCL,
  GIS.Render.Shapes, GIS.Render.PixelConv, GIS.Render.PixelConv.Cartesian;

type
  [TestFixture]
  TGISTextAlignTests = class
  // Pure geometry, no canvas involved: the convention every adapter follows.
  public
    [Test] procedure LeftTop_OriginIsAnchor;
    [Test] procedure CenterMiddle_OriginIsHalfSizeBack;
    [Test] procedure RightBottom_OriginIsFullSizeBack;
  end;

  [TestFixture]
  TGISStyleRecordTests = class
  // Equality drives the adapter's pen and brush caching, so a wrong comparison
  // would silently draw thousands of shapes in a stale style.
  public
    [Test] procedure Stroke_SameValues_AreEqual;
    [Test] procedure Stroke_DifferentWidth_AreNotEqual;
    [Test] procedure Stroke_DifferentColor_AreNotEqual;
    [Test] procedure Fill_SameValues_AreEqual;
    [Test] procedure Fill_DifferentStyle_AreNotEqual;
    [Test] procedure Stroke_ClearStyle_IsInvisible;
    [Test] procedure Stroke_ZeroAlpha_IsInvisible;
    [Test] procedure Stroke_Solid_IsVisible;
    [Test] procedure Fill_ClearStyle_IsInvisible;
    [Test] procedure Fill_ZeroAlpha_IsInvisible;
  end;

  [TestFixture]
  TGdiPlusCanvasTests = class
  private
    FBitmap: TBitmap;
    // Renders through a canvas that is released before the pixels are read, so
    // nothing is left buffered in GDI+.
    procedure Render(const Draw: TProc<IGISCanvas>);
    function Pixel(const X,Y: Integer): TColor;
    class function RedPngBytes(const Size: Integer): TBytes;
  public
    [Setup]    procedure Setup;
    [TearDown] procedure TearDown;

    [Test] procedure FillPolygon_Simple_FillsInterior;
    [Test] procedure FillPolygon_WithHole_LeavesHoleUnpainted;
    [Test] procedure FillPolygon_ClearFill_PaintsNothing;
    [Test] procedure FillRect_FillsBounds;
    [Test] procedure FillRect_ReversedBounds_StillFills;
    [Test] procedure DrawPolyline_DrawsAlongTheLine;
    [Test] procedure MeasureText_NonEmpty_HasPositiveSize;
    [Test] procedure MeasureText_Empty_IsZero;
    [Test] procedure MeasureText_LongerTextIsWider;
    [Test] procedure CreateImage_Png_HasSourceDimensions;
    [Test] procedure CreateImage_EmptyBuffer_Raises;
    [Test] procedure DrawImage_BlitsAtPosition;
    [Test] procedure CanvasReportsItsSize;
  end;

  [TestFixture]
  TShapesLayerRenderTests = class
  private
    FBitmap: TBitmap;
    FLayer: TShapesLayer;
    FConverter: TCartesianPixelConverter;
    // Viewport twice the size of the shapes, so the shape sits in the middle of
    // the bitmap and the corners are genuinely outside it.
    procedure RenderLayer;
    function Pixel(const X,Y: Integer): TColor;
    class function DonutShape: TGISShape;
  public
    [Setup]    procedure Setup;
    [TearDown] procedure TearDown;

    [Test] procedure Donut_RingIsFilled;
    [Test] procedure Donut_HoleIsNotFilled;
    [Test] procedure Donut_OutsideIsUntouched;
    [Test] procedure PointSymbol_ResourceLoads;
    [Test] procedure PointSymbol_SetsRenderSizeFromImage;
    [Test] procedure PointSymbol_Draws;
    [Test] procedure DefaultStyleIsOpaque;
  end;

  [TestFixture]
  TVclConversionTests = class
  public
    [Test] procedure AlphaColor_Red_RoundTrips;
    [Test] procedure AlphaColor_AppliesAlpha;
    [Test] procedure GISPenStyle_MapsDash;
    [Test] procedure GISPenStyle_MapsClear;
    [Test] procedure GISBrushStyle_MapsClear;
    [Test] procedure GISBrushStyle_MapsCross;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

const
  Background = clWhite;

{ TGISTextAlignTests }

procedure TGISTextAlignTests.LeftTop_OriginIsAnchor;
begin
  var Origin := TGISTextAlign.ResolveOrigin(100,50,TSizeF.Create(40,10),gahLeft,gavTop);
  Assert.AreEqual(100.0,Origin.X,1e-6);
  Assert.AreEqual(50.0,Origin.Y,1e-6);
end;

procedure TGISTextAlignTests.CenterMiddle_OriginIsHalfSizeBack;
begin
  var Origin := TGISTextAlign.ResolveOrigin(100,50,TSizeF.Create(40,10),gahCenter,gavMiddle);
  Assert.AreEqual(80.0,Origin.X,1e-6);
  Assert.AreEqual(45.0,Origin.Y,1e-6);
end;

procedure TGISTextAlignTests.RightBottom_OriginIsFullSizeBack;
begin
  var Origin := TGISTextAlign.ResolveOrigin(100,50,TSizeF.Create(40,10),gahRight,gavBottom);
  Assert.AreEqual(60.0,Origin.X,1e-6);
  Assert.AreEqual(40.0,Origin.Y,1e-6);
end;

{ TGISStyleRecordTests }

procedure TGISStyleRecordTests.Stroke_SameValues_AreEqual;
begin
  Assert.IsTrue(TGISStroke.Create(TAlphaColorRec.Red,2,gpsDash) =
                TGISStroke.Create(TAlphaColorRec.Red,2,gpsDash));
end;

procedure TGISStyleRecordTests.Stroke_DifferentWidth_AreNotEqual;
begin
  Assert.IsTrue(TGISStroke.Create(TAlphaColorRec.Red,2) <>
                TGISStroke.Create(TAlphaColorRec.Red,3));
end;

procedure TGISStyleRecordTests.Stroke_DifferentColor_AreNotEqual;
begin
  Assert.IsTrue(TGISStroke.Create(TAlphaColorRec.Red,2) <>
                TGISStroke.Create(TAlphaColorRec.Blue,2));
end;

procedure TGISStyleRecordTests.Fill_SameValues_AreEqual;
begin
  Assert.IsTrue(TGISFill.Create(TAlphaColorRec.Lime,gbsCross) =
                TGISFill.Create(TAlphaColorRec.Lime,gbsCross));
end;

procedure TGISStyleRecordTests.Fill_DifferentStyle_AreNotEqual;
begin
  Assert.IsTrue(TGISFill.Create(TAlphaColorRec.Lime,gbsCross) <>
                TGISFill.Create(TAlphaColorRec.Lime,gbsSolid));
end;

procedure TGISStyleRecordTests.Stroke_ClearStyle_IsInvisible;
begin
  Assert.IsTrue(TGISStroke.Create(TAlphaColorRec.Red,2,gpsClear).Invisible);
end;

procedure TGISStyleRecordTests.Stroke_ZeroAlpha_IsInvisible;
begin
  Assert.IsTrue(TGISStroke.Create(TAlphaColor($00FF0000),2).Invisible);
end;

procedure TGISStyleRecordTests.Stroke_Solid_IsVisible;
begin
  Assert.IsFalse(TGISStroke.Create(TAlphaColorRec.Red,1).Invisible);
end;

procedure TGISStyleRecordTests.Fill_ClearStyle_IsInvisible;
begin
  Assert.IsTrue(TGISFill.Create(TAlphaColorRec.Red,gbsClear).Invisible);
end;

procedure TGISStyleRecordTests.Fill_ZeroAlpha_IsInvisible;
begin
  Assert.IsTrue(TGISFill.Create(TAlphaColor($00FF0000)).Invisible);
end;

{ TGdiPlusCanvasTests }

procedure TGdiPlusCanvasTests.Setup;
begin
  FBitmap := TBitmap.Create;
  FBitmap.PixelFormat := pf32bit;
  FBitmap.SetSize(100,100);
  FBitmap.Canvas.Brush.Color := Background;
  FBitmap.Canvas.Brush.Style := bsSolid;
  FBitmap.Canvas.FillRect(Rect(0,0,100,100));
end;

procedure TGdiPlusCanvasTests.TearDown;
begin
  FBitmap.Free;
end;

procedure TGdiPlusCanvasTests.Render(const Draw: TProc<IGISCanvas>);
begin
  var Canvas := GISCanvas(FBitmap);
  try
    Draw(Canvas);
  finally
    Canvas := nil; // release GDI+ before the pixels are read back
  end;
end;

function TGdiPlusCanvasTests.Pixel(const X,Y: Integer): TColor;
begin
  Result := FBitmap.Canvas.Pixels[X,Y];
end;

class function TGdiPlusCanvasTests.RedPngBytes(const Size: Integer): TBytes;
begin
  var Png := TPngImage.CreateBlank(COLOR_RGB,8,Size,Size);
  var Stream := TBytesStream.Create;
  try
    Png.Canvas.Brush.Color := clRed;
    Png.Canvas.Brush.Style := bsSolid;
    Png.Canvas.FillRect(Rect(0,0,Size,Size));
    Png.SaveToStream(Stream);
    Result := Copy(Stream.Bytes,0,Stream.Size);
  finally
    Stream.Free;
    Png.Free;
  end;
end;

procedure TGdiPlusCanvasTests.FillPolygon_Simple_FillsInterior;
begin
  Render(procedure (Canvas: IGISCanvas)
  begin
    Canvas.FillPolygon([TPointF.Create(20,20),TPointF.Create(80,20),
                        TPointF.Create(80,80),TPointF.Create(20,80)],
                       nil,TGISFill.Create(TAlphaColorRec.Red),
                       TGISStroke.Create(TAlphaColorRec.Red));
  end);
  Assert.AreEqual(clRed,Pixel(50,50),'interior should be filled');
  Assert.AreEqual(Background,Pixel(5,5),'exterior should be untouched');
end;

procedure TGdiPlusCanvasTests.FillPolygon_WithHole_LeavesHoleUnpainted;
// The point of the even-odd path: a hole is cut out, not painted over in a
// background colour, so whatever is underneath shows through.
begin
  Render(procedure (Canvas: IGISCanvas)
  begin
    Canvas.FillPolygon([TPointF.Create(10,10),TPointF.Create(90,10),
                        TPointF.Create(90,90),TPointF.Create(10,90)],
                       [[TPointF.Create(40,40),TPointF.Create(60,40),
                         TPointF.Create(60,60),TPointF.Create(40,60)]],
                       TGISFill.Create(TAlphaColorRec.Red),
                       TGISStroke.Create(TAlphaColorRec.Red));
  end);
  Assert.AreEqual(clRed,Pixel(20,20),'ring should be filled');
  Assert.AreEqual(Background,Pixel(50,50),'hole should show the background');
end;

procedure TGdiPlusCanvasTests.FillPolygon_ClearFill_PaintsNothing;
begin
  Render(procedure (Canvas: IGISCanvas)
  begin
    Canvas.FillPolygon([TPointF.Create(20,20),TPointF.Create(80,20),
                        TPointF.Create(80,80),TPointF.Create(20,80)],
                       nil,TGISFill.Create(TAlphaColorRec.Red,gbsClear),
                       TGISStroke.Create(TAlphaColorRec.Red,1,gpsClear));
  end);
  Assert.AreEqual(Background,Pixel(50,50),'nothing should be painted');
end;

procedure TGdiPlusCanvasTests.FillRect_FillsBounds;
begin
  Render(procedure (Canvas: IGISCanvas)
  begin
    Canvas.FillRect(TRectF.Create(20,20,80,80),TGISFill.Create(TAlphaColorRec.Blue),
                    TGISStroke.Create(TAlphaColorRec.Blue));
  end);
  Assert.AreEqual(clBlue,Pixel(50,50));
  Assert.AreEqual(Background,Pixel(5,5));
end;

procedure TGdiPlusCanvasTests.FillRect_ReversedBounds_StillFills;
// Bounds given bottom-right first are normalized rather than dropped
begin
  Render(procedure (Canvas: IGISCanvas)
  begin
    Canvas.FillRect(TRectF.Create(80,80,20,20),TGISFill.Create(TAlphaColorRec.Blue),
                    TGISStroke.Create(TAlphaColorRec.Blue));
  end);
  Assert.AreEqual(clBlue,Pixel(50,50));
end;

procedure TGdiPlusCanvasTests.DrawPolyline_DrawsAlongTheLine;
begin
  Render(procedure (Canvas: IGISCanvas)
  begin
    Canvas.DrawPolyline([TPointF.Create(10,50),TPointF.Create(90,50)],
                        TGISStroke.Create(TAlphaColorRec.Black,3));
  end);
  Assert.AreNotEqual(Background,Pixel(50,50),'line should be drawn');
  Assert.AreEqual(Background,Pixel(50,10),'well away from the line should be clear');
end;

procedure TGdiPlusCanvasTests.MeasureText_NonEmpty_HasPositiveSize;
begin
  Render(procedure (Canvas: IGISCanvas)
  begin
    var Size := Canvas.MeasureText('Amsterdam',TGISTextStyle.Create('Arial',12,TAlphaColorRec.Black));
    Assert.IsTrue(Size.cx > 0,'width should be positive');
    Assert.IsTrue(Size.cy > 0,'height should be positive');
  end);
end;

procedure TGdiPlusCanvasTests.MeasureText_Empty_IsZero;
begin
  Render(procedure (Canvas: IGISCanvas)
  begin
    var Size := Canvas.MeasureText('',TGISTextStyle.Create('Arial',12,TAlphaColorRec.Black));
    Assert.AreEqual(0.0,Size.cx,1e-6);
    Assert.AreEqual(0.0,Size.cy,1e-6);
  end);
end;

procedure TGdiPlusCanvasTests.MeasureText_LongerTextIsWider;
begin
  Render(procedure (Canvas: IGISCanvas)
  begin
    var Style := TGISTextStyle.Create('Arial',12,TAlphaColorRec.Black);
    Assert.IsTrue(Canvas.MeasureText('Noord-Holland',Style).cx >
                  Canvas.MeasureText('Utrecht',Style).cx);
  end);
end;

procedure TGdiPlusCanvasTests.CreateImage_Png_HasSourceDimensions;
// This is how a map tile reaches the screen now
begin
  Render(procedure (Canvas: IGISCanvas)
  begin
    var Image := Canvas.CreateImage(RedPngBytes(16));
    Assert.AreEqual(16,Image.Width);
    Assert.AreEqual(16,Image.Height);
  end);
end;

procedure TGdiPlusCanvasTests.CreateImage_EmptyBuffer_Raises;
begin
  Render(procedure (Canvas: IGISCanvas)
  begin
    Assert.WillRaise(
      procedure begin Canvas.CreateImage(nil) end,
      Exception);
  end);
end;

procedure TGdiPlusCanvasTests.DrawImage_BlitsAtPosition;
begin
  Render(procedure (Canvas: IGISCanvas)
  begin
    Canvas.DrawImage(Canvas.CreateImage(RedPngBytes(16)),20,20);
  end);
  Assert.AreEqual(clRed,Pixel(28,28),'image should be blitted at the position given');
  Assert.AreEqual(Background,Pixel(70,70),'elsewhere should be untouched');
end;

procedure TGdiPlusCanvasTests.CanvasReportsItsSize;
begin
  Render(procedure (Canvas: IGISCanvas)
  begin
    Assert.AreEqual(100.0,Canvas.Width,1e-6);
    Assert.AreEqual(100.0,Canvas.Height,1e-6);
  end);
end;

{ TShapesLayerRenderTests }

class function TShapesLayerRenderTests.DonutShape: TGISShape;
// Outer ring -5..5 with a -1..1 hole, both centred on the origin
var
  Parts: TMultiPoints;
begin
  SetLength(Parts,2);
  SetLength(Parts[0],4);
  Parts[0][0] := TCoordinate.Create(-5,-5);
  Parts[0][1] := TCoordinate.Create( 5,-5);
  Parts[0][2] := TCoordinate.Create( 5, 5);
  Parts[0][3] := TCoordinate.Create(-5, 5);
  SetLength(Parts[1],4);
  Parts[1][0] := TCoordinate.Create(-1,-1);
  Parts[1][1] := TCoordinate.Create( 1,-1);
  Parts[1][2] := TCoordinate.Create( 1, 1);
  Parts[1][3] := TCoordinate.Create(-1, 1);
  Result.AssignPolyPolygon(Parts);
end;

procedure TShapesLayerRenderTests.Setup;
begin
  FBitmap := TBitmap.Create;
  FBitmap.PixelFormat := pf32bit;
  FBitmap.SetSize(200,200);
  FBitmap.Canvas.Brush.Color := Background;
  FBitmap.Canvas.Brush.Style := bsSolid;
  FBitmap.Canvas.FillRect(Rect(0,0,200,200));
  FLayer := TShapesLayer.Create;
  FConverter := TCartesianPixelConverter.Create;
end;

procedure TShapesLayerRenderTests.TearDown;
begin
  FConverter.Free;
  FLayer.Free;
  FBitmap.Free;
end;

procedure TShapesLayerRenderTests.RenderLayer;
// 10 pixels per unit with the origin at pixel 100: the -5..5 ring spans
// pixels 50..150 and the -1..1 hole spans 90..110.
var
  Viewport: TCoordinateRect;
begin
  Viewport.Clear;
  Viewport.Enclose(TCoordinate.Create(-10,-10));
  Viewport.Enclose(TCoordinate.Create( 10, 10));
  FConverter.Initialize(Viewport,200,200);
  var Canvas := GISCanvas(FBitmap);
  try
    FLayer.DrawLayer(Canvas,FConverter);
  finally
    Canvas := nil;
  end;
end;

function TShapesLayerRenderTests.Pixel(const X,Y: Integer): TColor;
begin
  Result := FBitmap.Canvas.Pixels[X,Y];
end;

procedure TShapesLayerRenderTests.Donut_RingIsFilled;
begin
  FLayer.Add(DonutShape);
  var Style := FLayer.Style;
  Style.Fill := TGISFill.Create(TAlphaColorRec.Red);
  Style.Stroke := TGISStroke.Create(TAlphaColorRec.Red);
  FLayer.Style := Style;
  RenderLayer;
  Assert.AreEqual(clRed,Pixel(100,70),'ring should be filled');
end;

procedure TShapesLayerRenderTests.Donut_HoleIsNotFilled;
begin
  FLayer.Add(DonutShape);
  var Style := FLayer.Style;
  Style.Fill := TGISFill.Create(TAlphaColorRec.Red);
  Style.Stroke := TGISStroke.Create(TAlphaColorRec.Red);
  FLayer.Style := Style;
  RenderLayer;
  Assert.AreEqual(Background,Pixel(100,100),'hole should show the background');
end;

procedure TShapesLayerRenderTests.Donut_OutsideIsUntouched;
begin
  FLayer.Add(DonutShape);
  var Style := FLayer.Style;
  Style.Fill := TGISFill.Create(TAlphaColorRec.Red);
  Style.Stroke := TGISStroke.Create(TAlphaColorRec.Red);
  FLayer.Style := Style;
  RenderLayer;
  Assert.AreEqual(Background,Pixel(3,3),'outside the polygon should be untouched');
end;

procedure TShapesLayerRenderTests.PointSymbol_ResourceLoads;
// The built-in symbols are RT_BITMAP resources, which hold a DIB with no file
// header, so the layer has to put a BITMAPFILEHEADER back in front of them.
begin
  FLayer.PointRenderStyle := rsStation_24dp;
  Assert.IsTrue(Length(FLayer.PointImageBytes) > 0,'symbol bytes should be loaded');
  Assert.AreEqual(Word($4D42),PWord(@FLayer.PointImageBytes[0])^,'should start with the BM signature');
end;

procedure TShapesLayerRenderTests.PointSymbol_SetsRenderSizeFromImage;
begin
  FLayer.PointRenderStyle := rsStation_24dp;
  Assert.AreEqual(24,FLayer.PointRenderSize);
end;

procedure TShapesLayerRenderTests.PointSymbol_Draws;
var
  Shape: TGISShape;
begin
  Shape.AssignPoint(0,0);
  FLayer.Add(Shape);
  FLayer.PointRenderStyle := rsStation_24dp;
  RenderLayer;
  var Painted := 0;
  for var X := 85 to 115 do
  for var Y := 85 to 115 do
  if Pixel(X,Y) <> Background then Inc(Painted);
  Assert.IsTrue(Painted > 0,'symbol should paint pixels at the point position');
  Assert.AreEqual(Background,Pixel(3,3),'corner should be untouched');
end;

procedure TShapesLayerRenderTests.DefaultStyleIsOpaque;
// A layer drawn without the caller setting a style must still be visible
begin
  Assert.IsFalse(FLayer.Style.Fill.Invisible,'default fill should paint');
  Assert.IsFalse(FLayer.Style.Stroke.Invisible,'default stroke should paint');
end;

{ TVclConversionTests }

procedure TVclConversionTests.AlphaColor_Red_RoundTrips;
begin
  var Color := AlphaColor(clRed);
  Assert.AreEqual(255,Integer(TAlphaColorRec(Color).R),'red channel');
  Assert.AreEqual(0,Integer(TAlphaColorRec(Color).G),'green channel');
  Assert.AreEqual(0,Integer(TAlphaColorRec(Color).B),'blue channel');
  Assert.AreEqual(255,Integer(TAlphaColorRec(Color).A),'opaque by default');
end;

procedure TVclConversionTests.AlphaColor_AppliesAlpha;
begin
  Assert.AreEqual(128,Integer(TAlphaColorRec(AlphaColor(clRed,128)).A));
end;

procedure TVclConversionTests.GISPenStyle_MapsDash;
begin
  Assert.AreEqual(Ord(gpsDash),Ord(GISPenStyle(psDash)));
end;

procedure TVclConversionTests.GISPenStyle_MapsClear;
begin
  Assert.AreEqual(Ord(gpsClear),Ord(GISPenStyle(psClear)));
end;

procedure TVclConversionTests.GISBrushStyle_MapsClear;
begin
  Assert.AreEqual(Ord(gbsClear),Ord(GISBrushStyle(bsClear)));
end;

procedure TVclConversionTests.GISBrushStyle_MapsCross;
begin
  Assert.AreEqual(Ord(gbsCross),Ord(GISBrushStyle(bsCross)));
end;

initialization
  TDUnitX.RegisterTestFixture(TGISTextAlignTests);
  TDUnitX.RegisterTestFixture(TGISStyleRecordTests);
  TDUnitX.RegisterTestFixture(TGdiPlusCanvasTests);
  TDUnitX.RegisterTestFixture(TShapesLayerRenderTests);
  TDUnitX.RegisterTestFixture(TVclConversionTests);

{$ENDIF}

end.

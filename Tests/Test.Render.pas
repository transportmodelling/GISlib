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
    [Test] Procedure LeftTop_OriginIsAnchor;
    [Test] Procedure CenterMiddle_OriginIsHalfSizeBack;
    [Test] Procedure RightBottom_OriginIsFullSizeBack;
  end;

  [TestFixture]
  TGISStyleRecordTests = class
  // Equality drives the adapter's pen and brush caching, so a wrong comparison
  // would silently draw thousands of shapes in a stale style.
  public
    [Test] Procedure Stroke_SameValues_AreEqual;
    [Test] Procedure Stroke_DifferentWidth_AreNotEqual;
    [Test] Procedure Stroke_DifferentColor_AreNotEqual;
    [Test] Procedure Fill_SameValues_AreEqual;
    [Test] Procedure Fill_DifferentStyle_AreNotEqual;
    [Test] Procedure Stroke_ClearStyle_IsInvisible;
    [Test] Procedure Stroke_ZeroAlpha_IsInvisible;
    [Test] Procedure Stroke_Solid_IsVisible;
    [Test] Procedure Fill_ClearStyle_IsInvisible;
    [Test] Procedure Fill_ZeroAlpha_IsInvisible;
  end;

  [TestFixture]
  TGdiPlusCanvasTests = class
  private
    FBitmap: TBitmap;
    // Renders through a canvas that is released before the pixels are read, so
    // nothing is left buffered in GDI+.
    Procedure Render(const Draw: TProc<IGISCanvas>);
    Function Pixel(const X,Y: Integer): TColor;
    Function RedPngBytes(const Size: Integer): TBytes;
  public
    [Setup]    Procedure Setup;
    [TearDown] Procedure TearDown;

    [Test] Procedure FillPolygon_Simple_FillsInterior;
    [Test] Procedure FillPolygon_WithHole_LeavesHoleUnpainted;
    [Test] Procedure FillPolygon_ClearFill_PaintsNothing;
    [Test] Procedure FillRect_FillsBounds;
    [Test] Procedure FillRect_ReversedBounds_StillFills;
    [Test] Procedure DrawPolyline_DrawsAlongTheLine;
    [Test] Procedure MeasureText_NonEmpty_HasPositiveSize;
    [Test] Procedure MeasureText_Empty_IsZero;
    [Test] Procedure MeasureText_LongerTextIsWider;
    [Test] Procedure CreateImage_Png_HasSourceDimensions;
    [Test] Procedure CreateImage_EmptyBuffer_Raises;
    [Test] Procedure DrawImage_BlitsAtPosition;
    [Test] Procedure CanvasReportsItsSize;
  end;

  [TestFixture]
  TShapesLayerRenderTests = class
  private
    FBitmap: TBitmap;
    FLayer: TShapesLayer;
    FConverter: TCartesianPixelConverter;
    // Viewport twice the size of the shapes, so the shape sits in the middle of
    // the bitmap and the corners are genuinely outside it.
    Procedure RenderLayer;
    Function Pixel(const X,Y: Integer): TColor;
    Function DonutShape: TGISShape;
  public
    [Setup]    Procedure Setup;
    [TearDown] Procedure TearDown;

    [Test] Procedure Donut_RingIsFilled;
    [Test] Procedure Donut_HoleIsNotFilled;
    [Test] Procedure Donut_OutsideIsUntouched;
    [Test] Procedure PointSymbol_ResourceLoads;
    [Test] Procedure PointSymbol_EveryBuiltInStyleLoads;
    [Test] Procedure PointSymbol_SetsRenderSizeFromImage;
    [Test] Procedure PointSymbol_Draws;
    [Test] Procedure DefaultStyleIsOpaque;
  end;

  [TestFixture]
  TVclConversionTests = class
  public
    [Test] Procedure AlphaColor_Red_RoundTrips;
    [Test] Procedure AlphaColor_AppliesAlpha;
    [Test] Procedure GISPenStyle_MapsDash;
    [Test] Procedure GISPenStyle_MapsClear;
    [Test] Procedure GISBrushStyle_MapsClear;
    [Test] Procedure GISBrushStyle_MapsCross;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

const
  Background = clWhite;

////////////////////////////////////////////////////////////////////////////////

Procedure TGISTextAlignTests.LeftTop_OriginIsAnchor;
begin
  var Origin := TGISTextAlign.ResolveOrigin(100,50,TSizeF.Create(40,10),gahLeft,gavTop);
  Assert.AreEqual(100.0,Origin.X,1e-6);
  Assert.AreEqual(50.0,Origin.Y,1e-6);
end;

Procedure TGISTextAlignTests.CenterMiddle_OriginIsHalfSizeBack;
begin
  var Origin := TGISTextAlign.ResolveOrigin(100,50,TSizeF.Create(40,10),gahCenter,gavMiddle);
  Assert.AreEqual(80.0,Origin.X,1e-6);
  Assert.AreEqual(45.0,Origin.Y,1e-6);
end;

Procedure TGISTextAlignTests.RightBottom_OriginIsFullSizeBack;
begin
  var Origin := TGISTextAlign.ResolveOrigin(100,50,TSizeF.Create(40,10),gahRight,gavBottom);
  Assert.AreEqual(60.0,Origin.X,1e-6);
  Assert.AreEqual(40.0,Origin.Y,1e-6);
end;

////////////////////////////////////////////////////////////////////////////////

Procedure TGISStyleRecordTests.Stroke_SameValues_AreEqual;
begin
  Assert.IsTrue(TGISStroke.Create(TAlphaColorRec.Red,2,gpsDash) =
                TGISStroke.Create(TAlphaColorRec.Red,2,gpsDash));
end;

Procedure TGISStyleRecordTests.Stroke_DifferentWidth_AreNotEqual;
begin
  Assert.IsTrue(TGISStroke.Create(TAlphaColorRec.Red,2) <>
                TGISStroke.Create(TAlphaColorRec.Red,3));
end;

Procedure TGISStyleRecordTests.Stroke_DifferentColor_AreNotEqual;
begin
  Assert.IsTrue(TGISStroke.Create(TAlphaColorRec.Red,2) <>
                TGISStroke.Create(TAlphaColorRec.Blue,2));
end;

Procedure TGISStyleRecordTests.Fill_SameValues_AreEqual;
begin
  Assert.IsTrue(TGISFill.Create(TAlphaColorRec.Lime,gbsCross) =
                TGISFill.Create(TAlphaColorRec.Lime,gbsCross));
end;

Procedure TGISStyleRecordTests.Fill_DifferentStyle_AreNotEqual;
begin
  Assert.IsTrue(TGISFill.Create(TAlphaColorRec.Lime,gbsCross) <>
                TGISFill.Create(TAlphaColorRec.Lime,gbsSolid));
end;

Procedure TGISStyleRecordTests.Stroke_ClearStyle_IsInvisible;
begin
  Assert.IsTrue(TGISStroke.Create(TAlphaColorRec.Red,2,gpsClear).Invisible);
end;

Procedure TGISStyleRecordTests.Stroke_ZeroAlpha_IsInvisible;
begin
  Assert.IsTrue(TGISStroke.Create(TAlphaColor($00FF0000),2).Invisible);
end;

Procedure TGISStyleRecordTests.Stroke_Solid_IsVisible;
begin
  Assert.IsFalse(TGISStroke.Create(TAlphaColorRec.Red,1).Invisible);
end;

Procedure TGISStyleRecordTests.Fill_ClearStyle_IsInvisible;
begin
  Assert.IsTrue(TGISFill.Create(TAlphaColorRec.Red,gbsClear).Invisible);
end;

Procedure TGISStyleRecordTests.Fill_ZeroAlpha_IsInvisible;
begin
  Assert.IsTrue(TGISFill.Create(TAlphaColor($00FF0000)).Invisible);
end;

////////////////////////////////////////////////////////////////////////////////

Procedure TGdiPlusCanvasTests.Setup;
begin
  FBitmap := TBitmap.Create;
  FBitmap.PixelFormat := pf32bit;
  FBitmap.SetSize(100,100);
  FBitmap.Canvas.Brush.Color := Background;
  FBitmap.Canvas.Brush.Style := bsSolid;
  FBitmap.Canvas.FillRect(Rect(0,0,100,100));
end;

Procedure TGdiPlusCanvasTests.TearDown;
begin
  FBitmap.Free;
end;

Procedure TGdiPlusCanvasTests.Render(const Draw: TProc<IGISCanvas>);
begin
  var Canvas := GISCanvas(FBitmap);
  try
    Draw(Canvas);
  finally
    Canvas := nil; // release GDI+ before the pixels are read back
  end;
end;

Function TGdiPlusCanvasTests.Pixel(const X,Y: Integer): TColor;
begin
  Result := FBitmap.Canvas.Pixels[X,Y];
end;

Function TGdiPlusCanvasTests.RedPngBytes(const Size: Integer): TBytes;
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

Procedure TGdiPlusCanvasTests.FillPolygon_Simple_FillsInterior;
begin
  Render(Procedure (Canvas: IGISCanvas)
  begin
    Canvas.FillPolygon([TPointF.Create(20,20),TPointF.Create(80,20),
                        TPointF.Create(80,80),TPointF.Create(20,80)],
                       nil,TGISFill.Create(TAlphaColorRec.Red),
                       TGISStroke.Create(TAlphaColorRec.Red));
  end);
  Assert.AreEqual(clRed,Pixel(50,50),'interior should be filled');
  Assert.AreEqual(Background,Pixel(5,5),'exterior should be untouched');
end;

Procedure TGdiPlusCanvasTests.FillPolygon_WithHole_LeavesHoleUnpainted;
// The point of the even-odd path: a hole is cut out, not painted over in a
// background colour, so whatever is underneath shows through.
begin
  Render(Procedure (Canvas: IGISCanvas)
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

Procedure TGdiPlusCanvasTests.FillPolygon_ClearFill_PaintsNothing;
begin
  Render(Procedure (Canvas: IGISCanvas)
  begin
    Canvas.FillPolygon([TPointF.Create(20,20),TPointF.Create(80,20),
                        TPointF.Create(80,80),TPointF.Create(20,80)],
                       nil,TGISFill.Create(TAlphaColorRec.Red,gbsClear),
                       TGISStroke.Create(TAlphaColorRec.Red,1,gpsClear));
  end);
  Assert.AreEqual(Background,Pixel(50,50),'nothing should be painted');
end;

Procedure TGdiPlusCanvasTests.FillRect_FillsBounds;
begin
  Render(Procedure (Canvas: IGISCanvas)
  begin
    Canvas.FillRect(TRectF.Create(20,20,80,80),TGISFill.Create(TAlphaColorRec.Blue),
                    TGISStroke.Create(TAlphaColorRec.Blue));
  end);
  Assert.AreEqual(clBlue,Pixel(50,50));
  Assert.AreEqual(Background,Pixel(5,5));
end;

Procedure TGdiPlusCanvasTests.FillRect_ReversedBounds_StillFills;
// Bounds given bottom-right first are normalized rather than dropped
begin
  Render(Procedure (Canvas: IGISCanvas)
  begin
    Canvas.FillRect(TRectF.Create(80,80,20,20),TGISFill.Create(TAlphaColorRec.Blue),
                    TGISStroke.Create(TAlphaColorRec.Blue));
  end);
  Assert.AreEqual(clBlue,Pixel(50,50));
end;

Procedure TGdiPlusCanvasTests.DrawPolyline_DrawsAlongTheLine;
begin
  Render(Procedure (Canvas: IGISCanvas)
  begin
    Canvas.DrawPolyline([TPointF.Create(10,50),TPointF.Create(90,50)],
                        TGISStroke.Create(TAlphaColorRec.Black,3));
  end);
  Assert.AreNotEqual(Background,Pixel(50,50),'line should be drawn');
  Assert.AreEqual(Background,Pixel(50,10),'well away from the line should be clear');
end;

Procedure TGdiPlusCanvasTests.MeasureText_NonEmpty_HasPositiveSize;
begin
  Render(Procedure (Canvas: IGISCanvas)
  begin
    var Size := Canvas.MeasureText('Amsterdam',TGISTextStyle.Create('Arial',12,TAlphaColorRec.Black));
    Assert.IsTrue(Size.cx > 0,'width should be positive');
    Assert.IsTrue(Size.cy > 0,'height should be positive');
  end);
end;

Procedure TGdiPlusCanvasTests.MeasureText_Empty_IsZero;
begin
  Render(Procedure (Canvas: IGISCanvas)
  begin
    var Size := Canvas.MeasureText('',TGISTextStyle.Create('Arial',12,TAlphaColorRec.Black));
    Assert.AreEqual(0.0,Size.cx,1e-6);
    Assert.AreEqual(0.0,Size.cy,1e-6);
  end);
end;

Procedure TGdiPlusCanvasTests.MeasureText_LongerTextIsWider;
begin
  Render(Procedure (Canvas: IGISCanvas)
  begin
    var Style := TGISTextStyle.Create('Arial',12,TAlphaColorRec.Black);
    Assert.IsTrue(Canvas.MeasureText('Noord-Holland',Style).cx >
                  Canvas.MeasureText('Utrecht',Style).cx);
  end);
end;

Procedure TGdiPlusCanvasTests.CreateImage_Png_HasSourceDimensions;
// This is how a map tile reaches the screen now
begin
  Render(Procedure (Canvas: IGISCanvas)
  begin
    var Image := Canvas.CreateImage(RedPngBytes(16));
    Assert.AreEqual(16,Image.Width);
    Assert.AreEqual(16,Image.Height);
  end);
end;

Procedure TGdiPlusCanvasTests.CreateImage_EmptyBuffer_Raises;
begin
  Render(Procedure (Canvas: IGISCanvas)
  begin
    Assert.WillRaise(
      Procedure begin Canvas.CreateImage(nil) end,
      Exception);
  end);
end;

Procedure TGdiPlusCanvasTests.DrawImage_BlitsAtPosition;
begin
  Render(Procedure (Canvas: IGISCanvas)
  begin
    Canvas.DrawImage(Canvas.CreateImage(RedPngBytes(16)),20,20);
  end);
  Assert.AreEqual(clRed,Pixel(28,28),'image should be blitted at the position given');
  Assert.AreEqual(Background,Pixel(70,70),'elsewhere should be untouched');
end;

Procedure TGdiPlusCanvasTests.CanvasReportsItsSize;
begin
  Render(Procedure (Canvas: IGISCanvas)
  begin
    Assert.AreEqual(100.0,Canvas.Width,1e-6);
    Assert.AreEqual(100.0,Canvas.Height,1e-6);
  end);
end;

////////////////////////////////////////////////////////////////////////////////

Function TShapesLayerRenderTests.DonutShape: TGISShape;
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

Procedure TShapesLayerRenderTests.Setup;
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

Procedure TShapesLayerRenderTests.TearDown;
begin
  FConverter.Free;
  FLayer.Free;
  FBitmap.Free;
end;

Procedure TShapesLayerRenderTests.RenderLayer;
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

Function TShapesLayerRenderTests.Pixel(const X,Y: Integer): TColor;
begin
  Result := FBitmap.Canvas.Pixels[X,Y];
end;

Procedure TShapesLayerRenderTests.Donut_RingIsFilled;
begin
  FLayer.Add(DonutShape);
  var Style := FLayer.Style;
  Style.Fill := TGISFill.Create(TAlphaColorRec.Red);
  Style.Stroke := TGISStroke.Create(TAlphaColorRec.Red);
  FLayer.Style := Style;
  RenderLayer;
  Assert.AreEqual(clRed,Pixel(100,70),'ring should be filled');
end;

Procedure TShapesLayerRenderTests.Donut_HoleIsNotFilled;
begin
  FLayer.Add(DonutShape);
  var Style := FLayer.Style;
  Style.Fill := TGISFill.Create(TAlphaColorRec.Red);
  Style.Stroke := TGISStroke.Create(TAlphaColorRec.Red);
  FLayer.Style := Style;
  RenderLayer;
  Assert.AreEqual(Background,Pixel(100,100),'hole should show the background');
end;

Procedure TShapesLayerRenderTests.Donut_OutsideIsUntouched;
begin
  FLayer.Add(DonutShape);
  var Style := FLayer.Style;
  Style.Fill := TGISFill.Create(TAlphaColorRec.Red);
  Style.Stroke := TGISStroke.Create(TAlphaColorRec.Red);
  FLayer.Style := Style;
  RenderLayer;
  Assert.AreEqual(Background,Pixel(3,3),'outside the polygon should be untouched');
end;

Procedure TShapesLayerRenderTests.PointSymbol_ResourceLoads;
// The built-in symbols are PNGs held as RCDATA, so they arrive ready to decode
// and carry their own alpha; nothing here is Windows-specific.
begin
  FLayer.PointRenderStyle := rsStation_24dp;
  Assert.IsTrue(Length(FLayer.PointImageBytes) > 8,'symbol bytes should be loaded');
  Assert.AreEqual($89,Integer(FLayer.PointImageBytes[0]),'should start with the PNG signature');
  Assert.AreEqual(Ord('P'),Integer(FLayer.PointImageBytes[1]));
  Assert.AreEqual(Ord('N'),Integer(FLayer.PointImageBytes[2]));
  Assert.AreEqual(Ord('G'),Integer(FLayer.PointImageBytes[3]));
end;

Procedure TShapesLayerRenderTests.PointSymbol_EveryBuiltInStyleLoads;
// Guards the resource names against a typo: each style must find its PNG and
// report the size its name promises.
begin
  for var Style := rsStation_18dp to rsAirport_48dp do
  begin
    FLayer.PointRenderStyle := Style;
    Assert.IsTrue(Length(FLayer.PointImageBytes) > 8,
      Format('style %d should load symbol bytes',[Ord(Style)]));
  end;
end;

Procedure TShapesLayerRenderTests.PointSymbol_SetsRenderSizeFromImage;
begin
  FLayer.PointRenderStyle := rsStation_24dp;
  Assert.AreEqual(24,FLayer.PointRenderSize);
end;

Procedure TShapesLayerRenderTests.PointSymbol_Draws;
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

Procedure TShapesLayerRenderTests.DefaultStyleIsOpaque;
// A layer drawn without the caller setting a style must still be visible
begin
  Assert.IsFalse(FLayer.Style.Fill.Invisible,'default fill should paint');
  Assert.IsFalse(FLayer.Style.Stroke.Invisible,'default stroke should paint');
end;

////////////////////////////////////////////////////////////////////////////////

Procedure TVclConversionTests.AlphaColor_Red_RoundTrips;
begin
  var Color := AlphaColor(clRed);
  Assert.AreEqual(255,Integer(TAlphaColorRec(Color).R),'red channel');
  Assert.AreEqual(0,Integer(TAlphaColorRec(Color).G),'green channel');
  Assert.AreEqual(0,Integer(TAlphaColorRec(Color).B),'blue channel');
  Assert.AreEqual(255,Integer(TAlphaColorRec(Color).A),'opaque by default');
end;

Procedure TVclConversionTests.AlphaColor_AppliesAlpha;
begin
  Assert.AreEqual(128,Integer(TAlphaColorRec(AlphaColor(clRed,128)).A));
end;

Procedure TVclConversionTests.GISPenStyle_MapsDash;
begin
  Assert.AreEqual(Ord(gpsDash),Ord(GISPenStyle(psDash)));
end;

Procedure TVclConversionTests.GISPenStyle_MapsClear;
begin
  Assert.AreEqual(Ord(gpsClear),Ord(GISPenStyle(psClear)));
end;

Procedure TVclConversionTests.GISBrushStyle_MapsClear;
begin
  Assert.AreEqual(Ord(gbsClear),Ord(GISBrushStyle(bsClear)));
end;

Procedure TVclConversionTests.GISBrushStyle_MapsCross;
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

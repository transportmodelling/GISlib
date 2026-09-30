unit Test.Render.SVG;

////////////////////////////////////////////////////////////////////////////////
//
// Author: Jaap Baak
// https://github.com/transportmodelling/GISlib
//
// Test suite generated with assistance from Claude Opus 5
//
// Tests for the SVG adapter of IGISCanvas. Drawing is verified by looking for
// the elements in the document the canvas writes. The adapter is RTL-only, so
// unlike Test.Render these tests build on every platform.
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
interface
////////////////////////////////////////////////////////////////////////////////

uses
  System.SysUtils, System.Classes, System.Types, System.UITypes,
  DUnitX.TestFramework,
  GIS, GIS.Shapes,
  GIS.Render.Canvas, GIS.Render.Canvas.SVG,
  GIS.Render.Shapes, GIS.Render.PixelConv, GIS.Render.PixelConv.Cartesian;

type
  [TestFixture]
  TSvgCanvasTests = class
  private
    FSvg: TSvgCanvas;
    FCanvas: IGISCanvas;   // keeps FSvg alive
    // The header of an image file, which is all the canvas reads of it
    Function PngHeader(const Width,Height: Integer): TBytes;
    Function BmpHeader(const Width,Height: Integer): TBytes;
    Function Square(const Min,Max: Single): TArray<TPointF>;
    Function Occurrences(const SubText,Text: String): Integer;
  public
    [Setup]    Procedure Setup;
    [TearDown] Procedure TearDown;

    [Test] Procedure Document_HasRootWithSize;
    [Test] Procedure Document_Empty_HasNoDefs;
    [Test] Procedure CanvasReportsItsSize;
    [Test] Procedure FillPolygon_Simple_WritesClosedPath;
    [Test] Procedure FillPolygon_WithHole_WritesBothRingsEvenOdd;
    [Test] Procedure FillPolygon_ClearFillAndStroke_WritesNothing;
    [Test] Procedure FillPolygon_ClearFill_WritesFillNone;
    [Test] Procedure FillPolygon_TranslucentFill_WritesOpacity;
    [Test] Procedure FillPolygon_Hatch_DefinesPatternOnce;
    [Test] Procedure DrawPolyline_WritesOpenUnfilledPath;
    [Test] Procedure DrawPolyline_Dashed_WritesDashArray;
    [Test] Procedure FillRect_ReversedBounds_AreNormalized;
    [Test] Procedure FillEllipse_WritesCentreAndRadii;
    [Test] Procedure Coordinates_UseDecimalPoint;
    [Test] Procedure DrawText_EscapesMarkup;
    [Test] Procedure DrawText_Centered_AnchorsInTheMiddle;
    [Test] Procedure DrawText_Bold_WritesFontWeight;
    [Test] Procedure MeasureText_Empty_IsZero;
    [Test] Procedure MeasureText_LongerTextIsWider;
    [Test] Procedure MeasureText_ScalesWithFontSize;
    [Test] Procedure CreateImage_Png_HasSourceDimensions;
    [Test] Procedure CreateImage_Bmp_HasSourceDimensions;
    [Test] Procedure CreateImage_EmptyBuffer_Raises;
    [Test] Procedure CreateImage_UnknownFormat_Raises;
    [Test] Procedure DrawImage_Twice_EmbedsOnce;
    [Test] Procedure Group_WritesOpacity;
    [Test] Procedure Group_LeftOpen_IsClosedInDocument;
    [Test] Procedure EndGroup_WithoutBegin_Raises;
    [Test] Procedure SaveToStream_WritesUtf8;
    [Test] Procedure ShapesLayer_Donut_DrawsOnePathWithHole;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Procedure TSvgCanvasTests.Setup;
begin
  FSvg := TSvgCanvas.Create(200,100);
  FCanvas := FSvg;
end;

Procedure TSvgCanvasTests.TearDown;
begin
  FCanvas := nil;
  FSvg := nil;
end;

Function TSvgCanvasTests.PngHeader(const Width,Height: Integer): TBytes;
begin
  Result := [$89,$50,$4E,$47,$0D,$0A,$1A,$0A,0,0,0,13,Ord('I'),Ord('H'),Ord('D'),Ord('R'),
             Byte(Width shr 24),Byte(Width shr 16),Byte(Width shr 8),Byte(Width),
             Byte(Height shr 24),Byte(Height shr 16),Byte(Height shr 8),Byte(Height)];
end;

Function TSvgCanvasTests.BmpHeader(const Width,Height: Integer): TBytes;
begin
  SetLength(Result,26);
  Result[0] := Ord('B');
  Result[1] := Ord('M');
  PInteger(@Result[18])^ := Width;
  PInteger(@Result[22])^ := Height;
end;

Function TSvgCanvasTests.Square(const Min,Max: Single): TArray<TPointF>;
begin
  Result := [TPointF.Create(Min,Min),TPointF.Create(Max,Min),
             TPointF.Create(Max,Max),TPointF.Create(Min,Max)];
end;

Function TSvgCanvasTests.Occurrences(const SubText,Text: String): Integer;
begin
  Result := 0;
  var Position := Pos(SubText,Text);
  while Position > 0 do
  begin
    Inc(Result);
    Position := Pos(SubText,Text,Position+Length(SubText));
  end;
end;

Procedure TSvgCanvasTests.Document_HasRootWithSize;
begin
  var Document := FSvg.Document;
  Assert.StartsWith('<?xml version="1.0" encoding="UTF-8"?>',Document);
  Assert.Contains(Document,'<svg xmlns="http://www.w3.org/2000/svg"');
  Assert.Contains(Document,'width="200" height="100" viewBox="0 0 200 100"');
  Assert.EndsWith('</svg>'#10,Document);
end;

Procedure TSvgCanvasTests.Document_Empty_HasNoDefs;
begin
  Assert.DoesNotContain(FSvg.Document,'<defs>');
end;

Procedure TSvgCanvasTests.CanvasReportsItsSize;
begin
  Assert.AreEqual(200.0,FCanvas.Width,1e-6);
  Assert.AreEqual(100.0,FCanvas.Height,1e-6);
end;

Procedure TSvgCanvasTests.FillPolygon_Simple_WritesClosedPath;
begin
  FCanvas.FillPolygon(Square(20,80),nil,TGISFill.Create(TAlphaColorRec.Red),
                      TGISStroke.Create(TAlphaColorRec.Blue,2));
  var Document := FSvg.Document;
  Assert.Contains(Document,'<path d="M20,20 80,20 80,80 20,80Z"');
  Assert.Contains(Document,'fill="#FF0000"');
  Assert.Contains(Document,'stroke="#0000FF" stroke-width="2"');
end;

Procedure TSvgCanvasTests.FillPolygon_WithHole_WritesBothRingsEvenOdd;
// The hole is a ring of the same path, so an even-odd fill cuts it out
begin
  FCanvas.FillPolygon(Square(10,90),[Square(40,60)],TGISFill.Create(TAlphaColorRec.Red),
                      TGISStroke.Create(TAlphaColorRec.Red));
  Assert.Contains(FSvg.Document,
                  '<path d="M10,10 90,10 90,90 10,90ZM40,40 60,40 60,60 40,60Z" fill-rule="evenodd"');
end;

Procedure TSvgCanvasTests.FillPolygon_ClearFillAndStroke_WritesNothing;
begin
  FCanvas.FillPolygon(Square(20,80),nil,TGISFill.Create(TAlphaColorRec.Red,gbsClear),
                      TGISStroke.Create(TAlphaColorRec.Red,1,gpsClear));
  Assert.DoesNotContain(FSvg.Document,'<path');
end;

Procedure TSvgCanvasTests.FillPolygon_ClearFill_WritesFillNone;
// Without it a viewer would fill the path black
begin
  FCanvas.FillPolygon(Square(20,80),nil,TGISFill.Create(TAlphaColorRec.Red,gbsClear),
                      TGISStroke.Create(TAlphaColorRec.Red));
  Assert.Contains(FSvg.Document,'fill="none" stroke="#FF0000"');
end;

Procedure TSvgCanvasTests.FillPolygon_TranslucentFill_WritesOpacity;
begin
  FCanvas.FillPolygon(Square(20,80),nil,TGISFill.Create(TAlphaColor($80FF0000)),
                      TGISStroke.Create(TAlphaColorRec.Red,1,gpsClear));
  Assert.Contains(FSvg.Document,'fill="#FF0000" fill-opacity="0.5"');
end;

Procedure TSvgCanvasTests.FillPolygon_Hatch_DefinesPatternOnce;
begin
  var Fill := TGISFill.Create(TAlphaColorRec.Green,gbsCross);
  var Stroke := TGISStroke.Create(TAlphaColorRec.Black);
  FCanvas.FillPolygon(Square(10,40),nil,Fill,Stroke);
  FCanvas.FillPolygon(Square(50,90),nil,Fill,Stroke);
  var Document := FSvg.Document;
  Assert.AreEqual(1,Occurrences('<pattern ',Document),'one pattern for one fill');
  Assert.AreEqual(2,Occurrences('fill="url(#hatch1)"',Document),'both polygons refer to it');
end;

Procedure TSvgCanvasTests.DrawPolyline_WritesOpenUnfilledPath;
begin
  FCanvas.DrawPolyline([TPointF.Create(10,50),TPointF.Create(90,50)],
                       TGISStroke.Create(TAlphaColorRec.Black,3));
  Assert.Contains(FSvg.Document,'<path d="M10,50 90,50" fill="none" stroke="#000000" stroke-width="3"/>');
end;

Procedure TSvgCanvasTests.DrawPolyline_Dashed_WritesDashArray;
begin
  FCanvas.DrawPolyline([TPointF.Create(10,50),TPointF.Create(90,50)],
                       TGISStroke.Create(TAlphaColorRec.Black,2,gpsDash));
  Assert.Contains(FSvg.Document,'stroke-dasharray="6,2"');
end;

Procedure TSvgCanvasTests.FillRect_ReversedBounds_AreNormalized;
begin
  FCanvas.FillRect(TRectF.Create(80,70,20,30),TGISFill.Create(TAlphaColorRec.Blue),
                   TGISStroke.Create(TAlphaColorRec.Blue));
  Assert.Contains(FSvg.Document,'<rect x="20" y="30" width="60" height="40"');
end;

Procedure TSvgCanvasTests.FillEllipse_WritesCentreAndRadii;
begin
  FCanvas.FillEllipse(TRectF.Create(20,30,80,70),TGISFill.Create(TAlphaColorRec.Blue),
                      TGISStroke.Create(TAlphaColorRec.Blue));
  Assert.Contains(FSvg.Document,'<ellipse cx="50" cy="50" rx="30" ry="20"');
end;

Procedure TSvgCanvasTests.Coordinates_UseDecimalPoint;
// Whatever the locale of the machine, and rounded to a hundredth of a pixel
begin
  var Saved := FormatSettings.DecimalSeparator;
  FormatSettings.DecimalSeparator := ',';
  try
    // The canvas takes its format when it is created
    var Svg := TSvgCanvas.Create(10,10);
    var Canvas: IGISCanvas := Svg;
    Canvas.DrawPolyline([TPointF.Create(1.5,2.256),TPointF.Create(3,4)],
                        TGISStroke.Create(TAlphaColorRec.Black));
    Assert.Contains(Svg.Document,'d="M1.5,2.26 3,4"');
  finally
    FormatSettings.DecimalSeparator := Saved;
  end;
end;

Procedure TSvgCanvasTests.DrawText_EscapesMarkup;
begin
  FCanvas.DrawText(10,10,'A<B & "C"',TGISTextStyle.Create('Arial',12,TAlphaColorRec.Black),
                   gahLeft,gavTop);
  Assert.Contains(FSvg.Document,'>A&lt;B &amp; &quot;C&quot;</text>');
end;

Procedure TSvgCanvasTests.DrawText_Centered_AnchorsInTheMiddle;
// The viewer centres the text on the anchor, so x is the anchor itself
begin
  FCanvas.DrawText(100,50,'Utrecht',TGISTextStyle.Create('Arial',10,TAlphaColorRec.Black),
                   gahCenter,gavTop);
  var Document := FSvg.Document;
  Assert.Contains(Document,'<text x="100" y="59.05" text-anchor="middle"');
  Assert.Contains(Document,'font-family="Arial" font-size="10"');
end;

Procedure TSvgCanvasTests.DrawText_Bold_WritesFontWeight;
begin
  FCanvas.DrawText(10,10,'Utrecht',TGISTextStyle.Create('Arial',10,TAlphaColorRec.Black,true),
                   gahLeft,gavTop);
  Assert.Contains(FSvg.Document,'font-weight="bold"');
end;

Procedure TSvgCanvasTests.MeasureText_Empty_IsZero;
begin
  var Size := FCanvas.MeasureText('',TGISTextStyle.Create('Arial',12,TAlphaColorRec.Black));
  Assert.AreEqual(0.0,Size.cx,1e-6);
  Assert.AreEqual(0.0,Size.cy,1e-6);
end;

Procedure TSvgCanvasTests.MeasureText_LongerTextIsWider;
begin
  var Style := TGISTextStyle.Create('Arial',12,TAlphaColorRec.Black);
  Assert.IsTrue(FCanvas.MeasureText('Noord-Holland',Style).cx >
                FCanvas.MeasureText('Utrecht',Style).cx);
end;

Procedure TSvgCanvasTests.MeasureText_ScalesWithFontSize;
begin
  var Small := FCanvas.MeasureText('Utrecht',TGISTextStyle.Create('Arial',10,TAlphaColorRec.Black));
  var Large := FCanvas.MeasureText('Utrecht',TGISTextStyle.Create('Arial',20,TAlphaColorRec.Black));
  Assert.AreEqual(2*Small.cx,Large.cx,1e-3);
  Assert.AreEqual(2*Small.cy,Large.cy,1e-3);
end;

Procedure TSvgCanvasTests.CreateImage_Png_HasSourceDimensions;
begin
  var Image := FCanvas.CreateImage(PngHeader(256,128));
  Assert.AreEqual(256,Image.Width);
  Assert.AreEqual(128,Image.Height);
end;

Procedure TSvgCanvasTests.CreateImage_Bmp_HasSourceDimensions;
// A negative height marks a bitmap stored top-down
begin
  var Image := FCanvas.CreateImage(BmpHeader(24,-18));
  Assert.AreEqual(24,Image.Width);
  Assert.AreEqual(18,Image.Height);
end;

Procedure TSvgCanvasTests.CreateImage_EmptyBuffer_Raises;
begin
  Assert.WillRaise(
    Procedure begin FCanvas.CreateImage(nil) end,
    Exception);
end;

Procedure TSvgCanvasTests.CreateImage_UnknownFormat_Raises;
begin
  Assert.WillRaise(
    Procedure begin FCanvas.CreateImage(TEncoding.ASCII.GetBytes('This is no image, just some text')) end,
    Exception);
end;

Procedure TSvgCanvasTests.DrawImage_Twice_EmbedsOnce;
// A point symbol is drawn for every point but must not be stored for each
begin
  var Image := FCanvas.CreateImage(PngHeader(16,16));
  FCanvas.DrawImage(Image,20,20);
  FCanvas.DrawImage(Image,40.5,60);
  var Document := FSvg.Document;
  Assert.AreEqual(1,Occurrences('data:image/png;base64,',Document),'embedded once');
  Assert.Contains(Document,'<image id="image1" width="16" height="16"');
  Assert.Contains(Document,'<use xlink:href="#image1" x="20" y="20"/>');
  Assert.Contains(Document,'<use xlink:href="#image1" x="40.5" y="60"/>');
end;

Procedure TSvgCanvasTests.Group_WritesOpacity;
begin
  FSvg.BeginGroup(0.5);
  FCanvas.FillRect(TRectF.Create(0,0,10,10),TGISFill.Create(TAlphaColorRec.Red),
                   TGISStroke.Create(TAlphaColorRec.Red));
  FSvg.EndGroup;
  var Document := FSvg.Document;
  Assert.IsTrue(Pos('<g opacity="0.5">',Document) < Pos('<rect',Document),'group opens before the rect');
  Assert.IsTrue(Pos('<rect',Document) < Pos('</g>',Document),'and closes after it');
end;

Procedure TSvgCanvasTests.Group_LeftOpen_IsClosedInDocument;
begin
  FSvg.BeginGroup;
  FSvg.BeginGroup(0.25);
  var Document := FSvg.Document;
  Assert.AreEqual(2,Occurrences('</g>',Document));
end;

Procedure TSvgCanvasTests.EndGroup_WithoutBegin_Raises;
begin
  Assert.WillRaise(
    Procedure begin FSvg.EndGroup end,
    Exception);
end;

Procedure TSvgCanvasTests.SaveToStream_WritesUtf8;
begin
  FCanvas.DrawText(10,10,'Caf'#$00E9,TGISTextStyle.Create('Arial',12,TAlphaColorRec.Black),
                   gahLeft,gavTop);
  var Stream := TBytesStream.Create;
  try
    FSvg.SaveToStream(Stream);
    var Text := TEncoding.UTF8.GetString(Stream.Bytes,0,Stream.Size);
    Assert.AreEqual(FSvg.Document,Text);
    Assert.AreEqual(Length(FSvg.Document)+1,Integer(Stream.Size),'the accented letter takes two bytes');
  finally
    Stream.Free;
  end;
end;

Procedure TSvgCanvasTests.ShapesLayer_Donut_DrawsOnePathWithHole;
// The layer code draws on this canvas as on any other. 10 pixels per unit with
// the origin at pixel 100: the -5..5 ring spans pixels 50..150 and the -1..1
// hole spans 90..110.
var
  Parts: TMultiPoints;
  Shape: TGISShape;
  Viewport: TCoordinateRect;
begin
  SetLength(Parts,2);
  Parts[0] := [TCoordinate.Create(-5,-5),TCoordinate.Create(5,-5),
               TCoordinate.Create(5,5),TCoordinate.Create(-5,5)];
  Parts[1] := [TCoordinate.Create(-1,-1),TCoordinate.Create(1,-1),
               TCoordinate.Create(1,1),TCoordinate.Create(-1,1)];
  Shape.AssignPolyPolygon(Parts);
  Viewport.Clear;
  Viewport.Enclose(TCoordinate.Create(-10,-10));
  Viewport.Enclose(TCoordinate.Create( 10, 10));
  var Svg := TSvgCanvas.Create(200,200);
  var Canvas: IGISCanvas := Svg;
  var Layer := TShapesLayer.Create;
  var Converter := TCartesianPixelConverter.Create;
  try
    Layer.Add(Shape);
    Converter.Initialize(Viewport,200,200);
    Layer.DrawLayer(Canvas,Converter);
    var Document := Svg.Document;
    Assert.AreEqual(1,Occurrences('<path ',Document),'ring and hole share one path');
    Assert.AreEqual(2,Occurrences('Z',Document),'which has two closed rings');
    Assert.Contains(Document,'fill-rule="evenodd"');
  finally
    Converter.Free;
    Layer.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TSvgCanvasTests);

end.

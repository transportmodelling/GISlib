unit GIS.Render.Canvas.SVG;

////////////////////////////////////////////////////////////////////////////////
//
// Author: Jaap Baak
// https://github.com/transportmodelling/GISlib
//
// SVG adapter for IGISCanvas: everything drawn on it is recorded as an SVG
// document, written out with SaveToFile or SaveToStream. This unit is RTL-only,
// so a map can be exported where neither VCL nor FMX is available.
//
// Images are embedded as the encoded bytes they arrived as, once each, however
// often they are drawn. There is no device to measure text on, so MeasureText
// estimates; see TSvgCanvas.
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
interface
////////////////////////////////////////////////////////////////////////////////

Uses
  SysUtils, Classes, Types, UITypes, NetEncoding, Generics.Collections,
  GIS.Render.Canvas;

Type
  TSvgImage = Class(TInterfacedObject,IGISImage)
  // An image kept as its encoded bytes (PNG or BMP). Nothing is decoded: the
  // size is read from the file header and the bytes go into the document as
  // they are.
  private
    FBytes: TBytes;
    FMimeType: String;
    FWidth,FHeight: Integer;
    Function ReadPngHeader: Boolean;
    Function ReadBmpHeader: Boolean;
  public
    Constructor Create(const Bytes: TBytes);
    Function GetWidth: Integer;
    Function GetHeight: Integer;
    // The image as a data URI, the form it is embedded in the document in
    Function DataUri: String;
  end;

  TSvgCanvas = Class(TInterfacedObject,IGISCanvas)
  // Records what is drawn as SVG elements. Coordinates are pixels, as on any
  // IGISCanvas, and the document is Width by Height of them; what falls outside
  // is clipped by the viewer.
  //
  // MeasureText estimates from the character widths of Helvetica, whatever the
  // font asked for. The estimate only decides whether a label fits: DrawText
  // leaves the horizontal alignment to the viewer (text-anchor), so a label is
  // placed exactly even where its estimated width is off.
  private
    FWidth,FHeight: Single;
    FFormat: TFormatSettings;
    FDefs,FBody: TStringBuilder;
    FImages: TDictionary<IGISImage,String>;   // images embedded so far, and their ids
    FPatterns: TDictionary<String,String>;    // hatch patterns defined so far, and their ids
    FGroupDepth: Integer;
    Function Number(const Value: Single): String;
    Function Escape(const Text: String): String;
    Function ColorAttribute(const Name: String; const Color: TAlphaColor): String;
    Function DashArray(const Stroke: TGISStroke): String;
    Function HatchPath(const Style: TGISBrushStyle): String;
    Function PatternFor(const Fill: TGISFill): String;
    Function FillAttributes(const Fill: TGISFill): String;
    Function StrokeAttributes(const Stroke: TGISStroke): String;
    Procedure AppendRing(const Points: TArray<TPointF>; const Close: Boolean);
  public
    Constructor Create(const Width,Height: Single);
    Procedure FillPolygon(const Outer: TArray<TPointF>;
                          const Holes: TArray<TArray<TPointF>>;
                          const Fill: TGISFill;
                          const Stroke: TGISStroke);
    Procedure DrawPolyline(const Points: TArray<TPointF>; const Stroke: TGISStroke);
    Procedure FillRect(const Bounds: TRectF; const Fill: TGISFill; const Stroke: TGISStroke);
    Procedure FillEllipse(const Bounds: TRectF; const Fill: TGISFill; const Stroke: TGISStroke);
    Procedure DrawText(const X,Y: Single;
                       const Text: String;
                       const TextStyle: TGISTextStyle;
                       const AlignH: TGISTextAlignH;
                       const AlignV: TGISTextAlignV);
    Function MeasureText(const Text: String; const TextStyle: TGISTextStyle): TSizeF;
    Procedure DrawImage(const Image: IGISImage; const X,Y: Single);
    Function CreateImage(const Bytes: TBytes): IGISImage;
    Function Width: Single;
    Function Height: Single;
    // Everything drawn between BeginGroup and EndGroup forms one group, blended
    // as a whole with the opacity given: the way to draw a layer translucently.
    // Groups nest.
    Procedure BeginGroup(const Opacity: Single = 1.0);
    Procedure EndGroup;
    // The SVG document of everything drawn so far. Drawing can continue after.
    Function Document: String;
    // Write the document, UTF-8 encoded
    Procedure SaveToStream(const Stream: TStream);
    Procedure SaveToFile(const FileName: String);
    Destructor Destroy; override;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Const
  // Advance widths of the Helvetica characters ' ' to '~', in thousandths of
  // the font size
  CharWidths: array[32..126] of Word = (
    278,278,355,556,556,889,667,191,333,333,389,584,278,333,278,278,
    556,556,556,556,556,556,556,556,556,556,278,278,584,584,584,556,
    1015,667,667,722,722,667,611,778,722,278,500,667,556,833,722,778,
    667,778,722,667,611,722,667,944,667,667,611,278,278,278,469,556,
    333,556,556,500,556,556,278,556,556,222,222,500,222,833,556,556,
    556,556,333,500,278,556,500,722,500,500,500,334,260,334,584);
  // The width assumed for any other character
  DefaultCharWidth = 556;
  // Bold text runs this much wider
  BoldWidthFactor = 1.06;
  // Height of a line of text and distance from its top to the baseline, as
  // fractions of the font size
  TextLineHeight = 1.15;
  TextAscent = 0.905;
  // Hatch lines repeat at this distance, as the GDI+ hatch brushes do
  HatchSize = 8;

Constructor TSvgImage.Create(const Bytes: TBytes);
begin
  inherited Create;
  if Length(Bytes) = 0 then raise Exception.Create('Cannot create an image from an empty buffer');
  FBytes := Bytes;
  if not (ReadPngHeader or ReadBmpHeader) then raise Exception.Create('Unsupported image format');
end;

Function TSvgImage.ReadPngHeader: Boolean;
// The size sits in the IHDR chunk, which a PNG always puts first: an 8-byte
// signature, then the chunk length and type, then the width and the height as
// big-endian 32-bit values.
Const
  Signature: array[0..7] of Byte = ($89,$50,$4E,$47,$0D,$0A,$1A,$0A);
begin
  if Length(FBytes) < 24 then Exit(false);
  for var Index := low(Signature) to high(Signature) do
  if FBytes[Index] <> Signature[Index] then Exit(false);
  FWidth := (FBytes[16] shl 24) or (FBytes[17] shl 16) or (FBytes[18] shl 8) or FBytes[19];
  FHeight := (FBytes[20] shl 24) or (FBytes[21] shl 16) or (FBytes[22] shl 8) or FBytes[23];
  FMimeType := 'image/png';
  Result := true;
end;

Function TSvgImage.ReadBmpHeader: Boolean;
// A 14-byte file header starting with 'BM', then the info header with the
// width and the height as little-endian 32-bit values. The height is negative
// when the rows are stored top-down.
begin
  if Length(FBytes) < 26 then Exit(false);
  if (FBytes[0] <> Ord('B')) or (FBytes[1] <> Ord('M')) then Exit(false);
  FWidth := Integer(FBytes[18] or (FBytes[19] shl 8) or (FBytes[20] shl 16) or (FBytes[21] shl 24));
  FHeight := Abs(Integer(FBytes[22] or (FBytes[23] shl 8) or (FBytes[24] shl 16) or (FBytes[25] shl 24)));
  FMimeType := 'image/bmp';
  Result := true;
end;

Function TSvgImage.GetWidth: Integer;
begin
  Result := FWidth;
end;

Function TSvgImage.GetHeight: Integer;
begin
  Result := FHeight;
end;

Function TSvgImage.DataUri: String;
begin
  // Without line breaks, which a data URI does not take
  var Encoding := TBase64Encoding.Create(0);
  try
    Result := 'data:' + FMimeType + ';base64,' + Encoding.EncodeBytesToString(FBytes);
  finally
    Encoding.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////

Constructor TSvgCanvas.Create(const Width,Height: Single);
begin
  inherited Create;
  FWidth := Width;
  FHeight := Height;
  // A decimal point whatever the locale of the machine
  FFormat := TFormatSettings.Invariant;
  FDefs := TStringBuilder.Create;
  FBody := TStringBuilder.Create;
  FImages := TDictionary<IGISImage,String>.Create;
  FPatterns := TDictionary<String,String>.Create;
end;

Function TSvgCanvas.Number(const Value: Single): String;
begin
  // A hundredth of a pixel is as fine as a viewer can show
  Result := FormatFloat('0.##',Value,FFormat);
  if Result = '-0' then Result := '0';
end;

Function TSvgCanvas.Escape(const Text: String): String;
begin
  Result := '';
  for var Index := 1 to Length(Text) do
  case Text[Index] of
    '&': Result := Result + '&amp;';
    '<': Result := Result + '&lt;';
    '>': Result := Result + '&gt;';
    '"': Result := Result + '&quot;';
    #9,#10,#13: Result := Result + Text[Index];
    // The other control characters cannot appear in an XML document at all
    #0..#8,#11,#12,#14..#31: ;
    else Result := Result + Text[Index];
  end;
end;

Function TSvgCanvas.ColorAttribute(const Name: String; const Color: TAlphaColor): String;
begin
  Result := Format(' %s="#%.2x%.2x%.2x"',[Name,TAlphaColorRec(Color).R,
                                          TAlphaColorRec(Color).G,
                                          TAlphaColorRec(Color).B]);
  if TAlphaColorRec(Color).A < 255 then
  Result := Result + Format(' %s-opacity="%s"',[Name,Number(TAlphaColorRec(Color).A/255)]);
end;

Function TSvgCanvas.DashArray(const Stroke: TGISStroke): String;
// The dash patterns of GDI+, which scale with the width of the pen
begin
  var Dash := Number(3*Stroke.Width);
  var Dot := Number(Stroke.Width);
  case Stroke.Style of
    gpsDash: Result := Dash + ',' + Dot;
    gpsDot: Result := Dot + ',' + Dot;
    gpsDashDot: Result := Dash + ',' + Dot + ',' + Dot + ',' + Dot;
    else Result := '';
  end;
end;

Function TSvgCanvas.HatchPath(const Style: TGISBrushStyle): String;
// The lines of one pattern tile. A diagonal is repeated across the corners it
// cuts off, so that the line is not nicked where the tiles meet.
Const
  Horizontal = 'M0,4H8';
  Vertical = 'M4,0V8';
  FDiagonal = 'M0,0L8,8M-2,6L2,10M6,-2L10,2';
  BDiagonal = 'M0,8L8,0M-2,2L2,-2M6,10L10,6';
begin
  case Style of
    gbsHorizontal: Result := Horizontal;
    gbsVertical: Result := Vertical;
    gbsFDiagonal: Result := FDiagonal;
    gbsBDiagonal: Result := BDiagonal;
    gbsCross: Result := Horizontal + Vertical;
    gbsDiagCross: Result := FDiagonal + BDiagonal;
    else raise Exception.Create('Brush style is not a hatch');
  end;
end;

Function TSvgCanvas.PatternFor(const Fill: TGISFill): String;
begin
  var Key := Format('%d-%.8x',[Ord(Fill.Style),Fill.Color]);
  if not FPatterns.TryGetValue(Key,Result) then
  begin
    Result := 'hatch' + IntToStr(FPatterns.Count+1);
    FDefs.Append(Format('<pattern id="%s" width="%d" height="%d" patternUnits="userSpaceOnUse">',
                        [Result,HatchSize,HatchSize]));
    FDefs.Append('<path d="').Append(HatchPath(Fill.Style)).Append('" fill="none"');
    FDefs.Append(ColorAttribute('stroke',Fill.Color)).Append(' stroke-width="1"/></pattern>'#10);
    FPatterns.Add(Key,Result);
  end;
end;

Function TSvgCanvas.FillAttributes(const Fill: TGISFill): String;
begin
  if Fill.Invisible then
    Result := ' fill="none"'
  else
    if Fill.Style = gbsSolid then
      Result := ColorAttribute('fill',Fill.Color)
    else
      Result := ' fill="url(#' + PatternFor(Fill) + ')"';
end;

Function TSvgCanvas.StrokeAttributes(const Stroke: TGISStroke): String;
begin
  // Nothing is stroked unless the element says so
  if Stroke.Invisible then Exit('');
  Result := ColorAttribute('stroke',Stroke.Color) + ' stroke-width="' + Number(Stroke.Width) + '"';
  var Dashes := DashArray(Stroke);
  if Dashes <> '' then Result := Result + ' stroke-dasharray="' + Dashes + '"';
end;

Procedure TSvgCanvas.AppendRing(const Points: TArray<TPointF>; const Close: Boolean);
begin
  for var Point := low(Points) to high(Points) do
  begin
    // The points following a move are joined by lines without saying so
    if Point = low(Points) then FBody.Append('M') else FBody.Append(' ');
    FBody.Append(Number(Points[Point].X)).Append(',').Append(Number(Points[Point].Y));
  end;
  if Close then FBody.Append('Z');
end;

Procedure TSvgCanvas.FillPolygon(const Outer: TArray<TPointF>;
                                 const Holes: TArray<TArray<TPointF>>;
                                 const Fill: TGISFill;
                                 const Stroke: TGISStroke);
begin
  if Length(Outer) < 3 then Exit;
  if Fill.Invisible and Stroke.Invisible then Exit;
  // Even-odd fill: an interior ring cancels the area it encloses, which is what
  // makes a hole a hole without drawing it in a background colour.
  FBody.Append('<path d="');
  AppendRing(Outer,true);
  for var Hole := low(Holes) to high(Holes) do
  if Length(Holes[Hole]) >= 3 then AppendRing(Holes[Hole],true);
  FBody.Append('" fill-rule="evenodd"');
  FBody.Append(FillAttributes(Fill)).Append(StrokeAttributes(Stroke)).Append('/>'#10);
end;

Procedure TSvgCanvas.DrawPolyline(const Points: TArray<TPointF>; const Stroke: TGISStroke);
begin
  if Length(Points) < 2 then Exit;
  if Stroke.Invisible then Exit;
  FBody.Append('<path d="');
  AppendRing(Points,false);
  FBody.Append('" fill="none"').Append(StrokeAttributes(Stroke)).Append('/>'#10);
end;

Procedure TSvgCanvas.FillRect(const Bounds: TRectF; const Fill: TGISFill; const Stroke: TGISStroke);
begin
  if Fill.Invisible and Stroke.Invisible then Exit;
  var Normalized := Bounds;
  Normalized.NormalizeRect;
  FBody.Append(Format('<rect x="%s" y="%s" width="%s" height="%s"',
                      [Number(Normalized.Left),Number(Normalized.Top),
                       Number(Normalized.Width),Number(Normalized.Height)]));
  FBody.Append(FillAttributes(Fill)).Append(StrokeAttributes(Stroke)).Append('/>'#10);
end;

Procedure TSvgCanvas.FillEllipse(const Bounds: TRectF; const Fill: TGISFill; const Stroke: TGISStroke);
begin
  if Fill.Invisible and Stroke.Invisible then Exit;
  var Normalized := Bounds;
  Normalized.NormalizeRect;
  FBody.Append(Format('<ellipse cx="%s" cy="%s" rx="%s" ry="%s"',
                      [Number((Normalized.Left+Normalized.Right)/2),
                       Number((Normalized.Top+Normalized.Bottom)/2),
                       Number(Normalized.Width/2),Number(Normalized.Height/2)]));
  FBody.Append(FillAttributes(Fill)).Append(StrokeAttributes(Stroke)).Append('/>'#10);
end;

Procedure TSvgCanvas.DrawText(const X,Y: Single;
                              const Text: String;
                              const TextStyle: TGISTextStyle;
                              const AlignH: TGISTextAlignH;
                              const AlignV: TGISTextAlignV);
Const
  Anchors: array[TGISTextAlignH] of String = ('start','middle','end');
begin
  if Text = '' then Exit;
  // The viewer anchors the text horizontally, with the width it really has.
  // Vertically the top of the text box follows the shared convention, and the
  // baseline SVG positions text by lies an ascent below it.
  var Origin := TGISTextAlign.ResolveOrigin(X,Y,MeasureText(Text,TextStyle),gahLeft,AlignV);
  FBody.Append(Format('<text x="%s" y="%s" text-anchor="%s" font-family="%s" font-size="%s"',
                      [Number(X),Number(Origin.Y+TextAscent*TextStyle.Size),Anchors[AlignH],
                       Escape(TextStyle.FontName),Number(TextStyle.Size)]));
  if TextStyle.Bold then FBody.Append(' font-weight="bold"');
  FBody.Append(ColorAttribute('fill',TextStyle.Color));
  FBody.Append('>').Append(Escape(Text)).Append('</text>'#10);
end;

Function TSvgCanvas.MeasureText(const Text: String; const TextStyle: TGISTextStyle): TSizeF;
begin
  if Text = '' then Exit(TSizeF.Create(0,0));
  var TextWidth := 0;
  for var Index := 1 to Length(Text) do
  begin
    var Code := Ord(Text[Index]);
    if (Code >= low(CharWidths)) and (Code <= high(CharWidths)) then
      Inc(TextWidth,CharWidths[Code])
    else
      Inc(TextWidth,DefaultCharWidth);
  end;
  Result := TSizeF.Create(TextWidth*TextStyle.Size/1000,TextLineHeight*TextStyle.Size);
  if TextStyle.Bold then Result.cx := BoldWidthFactor*Result.cx;
end;

Procedure TSvgCanvas.DrawImage(const Image: IGISImage; const X,Y: Single);
Var
  Id: String;
begin
  if Image = nil then Exit;
  // An image goes into the document the first time it is drawn, and is only
  // referred to after that: a point symbol is drawn once for every point.
  // Holding the image keeps its identity from being reused by another one.
  if not FImages.TryGetValue(Image,Id) then
  begin
    var SvgImage := Image as TSvgImage;
    Id := 'image' + IntToStr(FImages.Count+1);
    FDefs.Append(Format('<image id="%s" width="%d" height="%d" xlink:href="',
                        [Id,SvgImage.GetWidth,SvgImage.GetHeight]));
    FDefs.Append(SvgImage.DataUri).Append('"/>'#10);
    FImages.Add(Image,Id);
  end;
  FBody.Append(Format('<use xlink:href="#%s" x="%s" y="%s"/>'#10,[Id,Number(X),Number(Y)]));
end;

Function TSvgCanvas.CreateImage(const Bytes: TBytes): IGISImage;
begin
  Result := TSvgImage.Create(Bytes);
end;

Function TSvgCanvas.Width: Single;
begin
  Result := FWidth;
end;

Function TSvgCanvas.Height: Single;
begin
  Result := FHeight;
end;

Procedure TSvgCanvas.BeginGroup(const Opacity: Single = 1.0);
begin
  if Opacity < 1 then
    FBody.Append('<g opacity="').Append(Number(Opacity)).Append('">'#10)
  else
    FBody.Append('<g>'#10);
  Inc(FGroupDepth);
end;

Procedure TSvgCanvas.EndGroup;
begin
  if FGroupDepth = 0 then raise Exception.Create('EndGroup without BeginGroup');
  FBody.Append('</g>'#10);
  Dec(FGroupDepth);
end;

Function TSvgCanvas.Document: String;
begin
  var Builder := TStringBuilder.Create;
  try
    Builder.Append('<?xml version="1.0" encoding="UTF-8"?>'#10);
    Builder.Append('<svg xmlns="http://www.w3.org/2000/svg"');
    Builder.Append(' xmlns:xlink="http://www.w3.org/1999/xlink"');
    Builder.Append(Format(' width="%s" height="%s" viewBox="0 0 %0:s %1:s">'#10,
                          [Number(FWidth),Number(FHeight)]));
    if FDefs.Length > 0 then
    Builder.Append('<defs>'#10).Append(FDefs.ToString).Append('</defs>'#10);
    Builder.Append(FBody.ToString);
    // Groups still open are closed here only, so drawing can go on in them
    for var Group := 1 to FGroupDepth do Builder.Append('</g>'#10);
    Builder.Append('</svg>'#10);
    Result := Builder.ToString;
  finally
    Builder.Free;
  end;
end;

Procedure TSvgCanvas.SaveToStream(const Stream: TStream);
begin
  var Bytes := TEncoding.UTF8.GetBytes(Document);
  Stream.WriteBuffer(Bytes[0],Length(Bytes));
end;

Procedure TSvgCanvas.SaveToFile(const FileName: String);
begin
  var Stream := TFileStream.Create(FileName,fmCreate);
  try
    SaveToStream(Stream);
  finally
    Stream.Free;
  end;
end;

Destructor TSvgCanvas.Destroy;
begin
  FPatterns.Free;
  FImages.Free;
  FBody.Free;
  FDefs.Free;
  inherited Destroy;
end;

end.

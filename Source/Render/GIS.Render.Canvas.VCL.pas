unit GIS.Render.Canvas.VCL;

////////////////////////////////////////////////////////////////////////////////
//
// Author: Jaap Baak
// https://github.com/transportmodelling/GISlib
//
// VCL adapter for IGISCanvas, drawing through GDI+ so that polygons with holes
// are a single even-odd filled path and lines are antialiased. Use GISCanvas()
// to wrap a TCanvas or a TBitmap.
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
interface
////////////////////////////////////////////////////////////////////////////////

Uses
  Winapi.Windows, Winapi.GDIPAPI, Winapi.GDIPOBJ,
  SysUtils, Classes, Types, UITypes, Vcl.Graphics,
  GIS.Render.Canvas;

Type
  TGdiPlusImage = Class(TInterfacedObject,IGISImage)
  // An image decoded by GDI+, which handles BMP and PNG alike, so the point
  // symbol resources and the OSM tiles take the same path.
  private
    FBitmap: TGPBitmap;
    FStream: TStream;   // GDI+ reads lazily, so the bytes must outlive the bitmap
  public
    Constructor Create(const Bytes: TBytes);
    Function GetWidth: Integer;
    Function GetHeight: Integer;
    Destructor Destroy; override;
  public
    Property Bitmap: TGPBitmap read FBitmap;
  end;

  TGdiPlusCanvas = Class(TInterfacedObject,IGISCanvas)
  // Draws on a GDI+ graphics context. The pen and brush built from the last
  // stroke and fill are kept, so a layer drawing thousands of shapes in one
  // style allocates them once instead of once per shape.
  private
    FGraphics: TGPGraphics;
    FOwnsGraphics: Boolean;
    FWidth,FHeight: Single;
    FPen: TGPPen;
    FPenStroke: TGISStroke;
    FPenValid: Boolean;
    FBrush: TGPBrush;
    FBrushFill: TGISFill;
    FBrushValid: Boolean;
    FFont: TGPFont;
    FFontStyle: TGISTextStyle;
    FFontValid: Boolean;
    FFontFamily: TGPFontFamily;
    Function PenFor(const Stroke: TGISStroke): TGPPen;
    Function BrushFor(const Fill: TGISFill): TGPBrush;
    Function FontFor(const TextStyle: TGISTextStyle): TGPFont;
    Procedure BuildPath(const Path: TGPGraphicsPath;
                        const Outer: TArray<TPointF>;
                        const Holes: TArray<TArray<TPointF>>);
    Class Function ToGPPoints(const Points: TArray<TPointF>): TArray<TGPPointF>; static;
    Class Function ToGPColor(const Color: TAlphaColor): TGPColor; static;
    Class Function DashStyleFor(const Style: TGISPenStyle): TDashStyle; static;
  public
    Constructor Create(const Graphics: TGPGraphics;
                       const Width,Height: Single;
                       const OwnsGraphics: Boolean = false);
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
    Destructor Destroy; override;
  end;

// Wrap a VCL canvas or bitmap as an IGISCanvas. The returned interface borrows
// the canvas: it must not outlive it.
Function GISCanvas(const Canvas: TCanvas; const Width,Height: Integer): IGISCanvas; overload;
Function GISCanvas(const Bitmap: TBitmap): IGISCanvas; overload;

// Convert between VCL's TColor and the RTL TAlphaColor the canvas uses.
Function AlphaColor(const Color: TColor; const Alpha: Byte = 255): TAlphaColor;

// Convert VCL pen and brush styles to their canvas equivalents, so an app that
// binds VCL style pickers to its UI can pass the result straight through.
Function GISPenStyle(const Style: TPenStyle): TGISPenStyle;
Function GISBrushStyle(const Style: TBrushStyle): TGISBrushStyle;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Const
  // GDI+ measures a layout box rather than the ink, so give it room to avoid
  // wrapping a label that would otherwise fit on one line.
  MaxTextLayoutExtent = 10000.0;

Function AlphaColor(const Color: TColor; const Alpha: Byte = 255): TAlphaColor;
begin
  var RGB := ColorToRGB(Color);
  TAlphaColorRec(Result).R := Byte(RGB);
  TAlphaColorRec(Result).G := Byte(RGB shr 8);
  TAlphaColorRec(Result).B := Byte(RGB shr 16);
  TAlphaColorRec(Result).A := Alpha;
end;

Function GISPenStyle(const Style: TPenStyle): TGISPenStyle;
begin
  case Style of
    psDash: Result := gpsDash;
    psDot: Result := gpsDot;
    psDashDot,psDashDotDot: Result := gpsDashDot;
    psClear: Result := gpsClear;
    else Result := gpsSolid;
  end;
end;

Function GISBrushStyle(const Style: TBrushStyle): TGISBrushStyle;
begin
  case Style of
    bsClear: Result := gbsClear;
    bsHorizontal: Result := gbsHorizontal;
    bsVertical: Result := gbsVertical;
    bsFDiagonal: Result := gbsFDiagonal;
    bsBDiagonal: Result := gbsBDiagonal;
    bsCross: Result := gbsCross;
    bsDiagCross: Result := gbsDiagCross;
    else Result := gbsSolid;
  end;
end;

Function GISCanvas(const Canvas: TCanvas; const Width,Height: Integer): IGISCanvas;
begin
  var Graphics := TGPGraphics.Create(Canvas.Handle);
  Result := TGdiPlusCanvas.Create(Graphics,Width,Height,true);
end;

Function GISCanvas(const Bitmap: TBitmap): IGISCanvas;
begin
  Result := GISCanvas(Bitmap.Canvas,Bitmap.Width,Bitmap.Height);
end;

////////////////////////////////////////////////////////////////////////////////

Constructor TGdiPlusImage.Create(const Bytes: TBytes);
begin
  inherited Create;
  if Length(Bytes) = 0 then raise Exception.Create('Cannot create an image from an empty buffer');
  FStream := TBytesStream.Create(Bytes);
  FBitmap := TGPBitmap.Create(TStreamAdapter.Create(FStream));
  if FBitmap.GetLastStatus <> Ok then raise Exception.Create('Unsupported image format');
end;

Function TGdiPlusImage.GetWidth: Integer;
begin
  Result := FBitmap.GetWidth;
end;

Function TGdiPlusImage.GetHeight: Integer;
begin
  Result := FBitmap.GetHeight;
end;

Destructor TGdiPlusImage.Destroy;
begin
  FBitmap.Free;
  FStream.Free;
  inherited Destroy;
end;

////////////////////////////////////////////////////////////////////////////////

Constructor TGdiPlusCanvas.Create(const Graphics: TGPGraphics;
                                  const Width,Height: Single;
                                  const OwnsGraphics: Boolean = false);
begin
  inherited Create;
  FGraphics := Graphics;
  FOwnsGraphics := OwnsGraphics;
  FWidth := Width;
  FHeight := Height;
  FGraphics.SetSmoothingMode(SmoothingModeAntiAlias);
  FGraphics.SetTextRenderingHint(TextRenderingHintClearTypeGridFit);
end;

Class Function TGdiPlusCanvas.ToGPColor(const Color: TAlphaColor): TGPColor;
begin
  Result := MakeColor(TAlphaColorRec(Color).A,
                      TAlphaColorRec(Color).R,
                      TAlphaColorRec(Color).G,
                      TAlphaColorRec(Color).B);
end;

Class Function TGdiPlusCanvas.DashStyleFor(const Style: TGISPenStyle): TDashStyle;
begin
  case Style of
    gpsDash: Result := DashStyleDash;
    gpsDot: Result := DashStyleDot;
    gpsDashDot: Result := DashStyleDashDot;
    else Result := DashStyleSolid;
  end;
end;

Class Function TGdiPlusCanvas.ToGPPoints(const Points: TArray<TPointF>): TArray<TGPPointF>;
begin
  SetLength(Result,Length(Points));
  for var Point := low(Points) to high(Points) do
  begin
    Result[Point].X := Points[Point].X;
    Result[Point].Y := Points[Point].Y;
  end;
end;

Function TGdiPlusCanvas.PenFor(const Stroke: TGISStroke): TGPPen;
begin
  if FPenValid and (FPenStroke = Stroke) then Exit(FPen);
  FPen.Free;
  FPen := TGPPen.Create(ToGPColor(Stroke.Color),Stroke.Width);
  FPen.SetDashStyle(DashStyleFor(Stroke.Style));
  FPenStroke := Stroke;
  FPenValid := true;
  Result := FPen;
end;

Function TGdiPlusCanvas.BrushFor(const Fill: TGISFill): TGPBrush;
begin
  if FBrushValid and (FBrushFill = Fill) then Exit(FBrush);
  FBrush.Free;
  case Fill.Style of
    gbsSolid: FBrush := TGPSolidBrush.Create(ToGPColor(Fill.Color));
    gbsHorizontal: FBrush := TGPHatchBrush.Create(HatchStyleHorizontal,ToGPColor(Fill.Color),MakeColor(0,0,0,0));
    gbsVertical: FBrush := TGPHatchBrush.Create(HatchStyleVertical,ToGPColor(Fill.Color),MakeColor(0,0,0,0));
    gbsFDiagonal: FBrush := TGPHatchBrush.Create(HatchStyleForwardDiagonal,ToGPColor(Fill.Color),MakeColor(0,0,0,0));
    gbsBDiagonal: FBrush := TGPHatchBrush.Create(HatchStyleBackwardDiagonal,ToGPColor(Fill.Color),MakeColor(0,0,0,0));
    gbsCross: FBrush := TGPHatchBrush.Create(HatchStyleCross,ToGPColor(Fill.Color),MakeColor(0,0,0,0));
    gbsDiagCross: FBrush := TGPHatchBrush.Create(HatchStyleDiagonalCross,ToGPColor(Fill.Color),MakeColor(0,0,0,0));
    else FBrush := TGPSolidBrush.Create(MakeColor(0,0,0,0));
  end;
  FBrushFill := Fill;
  FBrushValid := true;
  Result := FBrush;
end;

Function TGdiPlusCanvas.FontFor(const TextStyle: TGISTextStyle): TGPFont;
begin
  if FFontValid and (FFontStyle = TextStyle) then Exit(FFont);
  FFont.Free;
  FFontFamily.Free;
  FFontFamily := TGPFontFamily.Create(TextStyle.FontName);
  if FFontFamily.GetLastStatus <> Ok then
  begin
    FFontFamily.Free;
    FFontFamily := TGPFontFamily.Create('Arial');
  end;
  var Style := FontStyleRegular;
  if TextStyle.Bold then Style := FontStyleBold;
  FFont := TGPFont.Create(FFontFamily,TextStyle.Size,Style,UnitPixel);
  FFontStyle := TextStyle;
  FFontValid := true;
  Result := FFont;
end;

Procedure TGdiPlusCanvas.BuildPath(const Path: TGPGraphicsPath;
                                   const Outer: TArray<TPointF>;
                                   const Holes: TArray<TArray<TPointF>>);
begin
  // Even-odd fill: an interior ring cancels the area it encloses, which is what
  // makes a hole a hole without drawing it in a background colour.
  Path.SetFillMode(FillModeAlternate);
  var OuterPoints := ToGPPoints(Outer);
  Path.AddPolygon(PGPPointF(@OuterPoints[0]),Length(OuterPoints));
  for var Hole := low(Holes) to high(Holes) do
  if Length(Holes[Hole]) >= 3 then
  begin
    var HolePoints := ToGPPoints(Holes[Hole]);
    Path.AddPolygon(PGPPointF(@HolePoints[0]),Length(HolePoints));
  end;
end;

Procedure TGdiPlusCanvas.FillPolygon(const Outer: TArray<TPointF>;
                                     const Holes: TArray<TArray<TPointF>>;
                                     const Fill: TGISFill;
                                     const Stroke: TGISStroke);
begin
  if Length(Outer) < 3 then Exit;
  if Fill.Invisible and Stroke.Invisible then Exit;
  var Path := TGPGraphicsPath.Create;
  try
    BuildPath(Path,Outer,Holes);
    if not Fill.Invisible then FGraphics.FillPath(BrushFor(Fill),Path);
    if not Stroke.Invisible then FGraphics.DrawPath(PenFor(Stroke),Path);
  finally
    Path.Free;
  end;
end;

Procedure TGdiPlusCanvas.DrawPolyline(const Points: TArray<TPointF>; const Stroke: TGISStroke);
begin
  if Length(Points) < 2 then Exit;
  if Stroke.Invisible then Exit;
  var GPPoints := ToGPPoints(Points);
  FGraphics.DrawLines(PenFor(Stroke),PGPPointF(@GPPoints[0]),Length(GPPoints));
end;

Procedure TGdiPlusCanvas.FillRect(const Bounds: TRectF; const Fill: TGISFill; const Stroke: TGISStroke);
begin
  var Normalized := Bounds;
  Normalized.NormalizeRect;
  var GPRect := MakeRect(Normalized.Left,Normalized.Top,Normalized.Width,Normalized.Height);
  if not Fill.Invisible then FGraphics.FillRectangle(BrushFor(Fill),GPRect);
  if not Stroke.Invisible then FGraphics.DrawRectangle(PenFor(Stroke),GPRect);
end;

Procedure TGdiPlusCanvas.FillEllipse(const Bounds: TRectF; const Fill: TGISFill; const Stroke: TGISStroke);
begin
  var Normalized := Bounds;
  Normalized.NormalizeRect;
  var GPRect := MakeRect(Normalized.Left,Normalized.Top,Normalized.Width,Normalized.Height);
  if not Fill.Invisible then FGraphics.FillEllipse(BrushFor(Fill),GPRect);
  if not Stroke.Invisible then FGraphics.DrawEllipse(PenFor(Stroke),GPRect);
end;

Function TGdiPlusCanvas.MeasureText(const Text: String; const TextStyle: TGISTextStyle): TSizeF;
Var
  Bounds: TGPRectF;
begin
  if Text = '' then Exit(TSizeF.Create(0,0));
  var Format := TGPStringFormat.Create;
  try
    // GenericTypographic drops the padding GDI+ otherwise adds, so a measured
    // width matches the ink a layer uses to decide whether a label fits.
    Format.SetFormatFlags(StringFormatFlagsMeasureTrailingSpaces);
    FGraphics.MeasureString(Text,Length(Text),FontFor(TextStyle),
                            MakeRect(0.0,0.0,MaxTextLayoutExtent,MaxTextLayoutExtent),
                            Format,Bounds);
  finally
    Format.Free;
  end;
  Result := TSizeF.Create(Bounds.Width,Bounds.Height);
end;

Procedure TGdiPlusCanvas.DrawText(const X,Y: Single;
                                  const Text: String;
                                  const TextStyle: TGISTextStyle;
                                  const AlignH: TGISTextAlignH;
                                  const AlignV: TGISTextAlignV);
begin
  if Text = '' then Exit;
  var Origin := TGISTextAlign.ResolveOrigin(X,Y,MeasureText(Text,TextStyle),AlignH,AlignV);
  var Brush := TGPSolidBrush.Create(ToGPColor(TextStyle.Color));
  var Format := TGPStringFormat.Create;
  try
    Format.SetFormatFlags(StringFormatFlagsMeasureTrailingSpaces);
    FGraphics.DrawString(Text,Length(Text),FontFor(TextStyle),
                         MakeRect(Origin.X,Origin.Y,MaxTextLayoutExtent,MaxTextLayoutExtent),
                         Format,Brush);
  finally
    Format.Free;
    Brush.Free;
  end;
end;

Procedure TGdiPlusCanvas.DrawImage(const Image: IGISImage; const X,Y: Single);
begin
  if Image = nil then Exit;
  var GdiImage := Image as TGdiPlusImage;
  FGraphics.DrawImage(GdiImage.Bitmap,X,Y,GdiImage.Bitmap.GetWidth,GdiImage.Bitmap.GetHeight);
end;

Function TGdiPlusCanvas.CreateImage(const Bytes: TBytes): IGISImage;
begin
  Result := TGdiPlusImage.Create(Bytes);
end;

Function TGdiPlusCanvas.Width: Single;
begin
  Result := FWidth;
end;

Function TGdiPlusCanvas.Height: Single;
begin
  Result := FHeight;
end;

Destructor TGdiPlusCanvas.Destroy;
begin
  FPen.Free;
  FBrush.Free;
  FFont.Free;
  FFontFamily.Free;
  if FOwnsGraphics then FGraphics.Free;
  inherited Destroy;
end;

end.

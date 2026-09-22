unit GIS.Render.Canvas;

////////////////////////////////////////////////////////////////////////////////
//
// Author: Jaap Baak
// https://github.com/transportmodelling/GISlib
//
// The drawing surface abstraction the render layer targets. Framework adapters
// (GIS.Render.Canvas.VCL, and later FMX or SVG) implement IGISCanvas, so the
// layer code itself stays RTL-only.
//
// Styles are passed per call rather than held as canvas state: an adapter is
// free to cache the framework objects it builds from them, and a layer can
// never leave state behind that changes how the next layer draws.
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
interface
////////////////////////////////////////////////////////////////////////////////

Uses
  SysUtils, Types, UITypes;

Type
  TGISPenStyle = (gpsSolid,gpsDash,gpsDot,gpsDashDot,gpsClear);

  TGISBrushStyle = (gbsSolid,gbsClear,gbsHorizontal,gbsVertical,
                    gbsFDiagonal,gbsBDiagonal,gbsCross,gbsDiagCross);

  TGISTextAlignH = (gahLeft,gahCenter,gahRight);

  TGISTextAlignV = (gavTop,gavMiddle,gavBottom);

  TGISStroke = record
  // The colour, width and dash pattern an outline is drawn with.
  public
    Color: TAlphaColor;
    Width: Single;
    Style: TGISPenStyle;
    Class Function Create(const Color: TAlphaColor;
                          const Width: Single = 1.0;
                          const Style: TGISPenStyle = gpsSolid): TGISStroke; static;
    Class Operator Equal(const Left,Right: TGISStroke): Boolean;
    Class Operator NotEqual(const Left,Right: TGISStroke): Boolean;
    // True when the stroke would not put down any pixels
    Function Invisible: Boolean;
  end;

  TGISFill = record
  // The colour and pattern an interior is filled with.
  public
    Color: TAlphaColor;
    Style: TGISBrushStyle;
    Class Function Create(const Color: TAlphaColor;
                          const Style: TGISBrushStyle = gbsSolid): TGISFill; static;
    Class Operator Equal(const Left,Right: TGISFill): Boolean;
    Class Operator NotEqual(const Left,Right: TGISFill): Boolean;
    // True when the fill would not put down any pixels
    Function Invisible: Boolean;
  end;

  TGISTextStyle = record
  // The font a label is drawn with.
  public
    FontName: String;
    Size: Single;
    Bold: Boolean;
    Color: TAlphaColor;
    Class Function Create(const FontName: String;
                          const Size: Single;
                          const Color: TAlphaColor;
                          const Bold: Boolean = false): TGISTextStyle; static;
    Class Operator Equal(const Left,Right: TGISTextStyle): Boolean;
    Class Operator NotEqual(const Left,Right: TGISTextStyle): Boolean;
  end;

  TGISShapeStyle = record
  // Everything a layer needs to draw one shape. Returned by
  // TCustomShapesLayer.ShapeStyle, so a subclass can vary it per shape without
  // reaching into the canvas.
  public
    Stroke: TGISStroke;
    Fill: TGISFill;
    Text: TGISTextStyle;
  end;

  IGISImage = interface
  // A raster the canvas can blit: a map tile or a point symbol. The adapter
  // owns whatever framework-native representation sits behind it.
  ['{6F2A7C41-3E5B-4A18-9D6C-1B84E0F52A37}']
    Function GetWidth: Integer;
    Function GetHeight: Integer;
    Property Width: Integer read GetWidth;
    Property Height: Integer read GetHeight;
  end;

  IGISCanvas = interface
  // The surface the render layer draws on. All coordinates are in pixels, as
  // floats: TCustomPixelConverter produces sub-pixel positions and an adapter
  // that antialiases can use them.
  ['{9C4D1E86-7A52-4B3F-8E01-5D2A6C93B7F4}']
    // Fills a polygon. Holes is empty for a simple polygon; otherwise the rings
    // are filled even-odd, so a caller never has to punch holes by hand.
    Procedure FillPolygon(const Outer: TArray<TPointF>;
                          const Holes: TArray<TArray<TPointF>>;
                          const Fill: TGISFill;
                          const Stroke: TGISStroke);
    Procedure DrawPolyline(const Points: TArray<TPointF>; const Stroke: TGISStroke);
    Procedure FillRect(const Bounds: TRectF; const Fill: TGISFill; const Stroke: TGISStroke);
    Procedure FillEllipse(const Bounds: TRectF; const Fill: TGISFill; const Stroke: TGISStroke);
    // Draws Text anchored at (X,Y) according to AlignH/AlignV, following the
    // convention TGISTextAlign.ResolveOrigin defines.
    Procedure DrawText(const X,Y: Single;
                       const Text: String;
                       const TextStyle: TGISTextStyle;
                       const AlignH: TGISTextAlignH;
                       const AlignV: TGISTextAlignV);
    Function MeasureText(const Text: String; const TextStyle: TGISTextStyle): TSizeF;
    Procedure DrawImage(const Image: IGISImage; const X,Y: Single);
    // Decodes an encoded image (BMP or PNG) into something this canvas can
    // blit. Keeps image codecs out of the layer code.
    Function CreateImage(const Bytes: TBytes): IGISImage;
    Function Width: Single;
    Function Height: Single;
  end;

  TGISTextAlign = Class
  // Turns an anchor point plus a measured size into the top-left corner a text
  // box is drawn at. The single source of truth for the alignment convention of
  // IGISCanvas.DrawText, so no adapter can disagree with the layout a layer
  // assumed when it decided a label would fit.
  public
    Class Function ResolveOrigin(const X,Y: Single;
                                 const Size: TSizeF;
                                 const AlignH: TGISTextAlignH;
                                 const AlignV: TGISTextAlignV): TPointF; static;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Class Function TGISStroke.Create(const Color: TAlphaColor;
                                 const Width: Single = 1.0;
                                 const Style: TGISPenStyle = gpsSolid): TGISStroke;
begin
  Result.Color := Color;
  Result.Width := Width;
  Result.Style := Style;
end;

Class Operator TGISStroke.Equal(const Left,Right: TGISStroke): Boolean;
begin
  Result := (Left.Color = Right.Color)
        and (Left.Width = Right.Width)
        and (Left.Style = Right.Style);
end;

Class Operator TGISStroke.NotEqual(const Left,Right: TGISStroke): Boolean;
begin
  Result := not (Left = Right);
end;

Function TGISStroke.Invisible: Boolean;
begin
  Result := (Style = gpsClear) or (Width <= 0) or (TAlphaColorRec(Color).A = 0);
end;

////////////////////////////////////////////////////////////////////////////////

Class Function TGISFill.Create(const Color: TAlphaColor;
                               const Style: TGISBrushStyle = gbsSolid): TGISFill;
begin
  Result.Color := Color;
  Result.Style := Style;
end;

Class Operator TGISFill.Equal(const Left,Right: TGISFill): Boolean;
begin
  Result := (Left.Color = Right.Color) and (Left.Style = Right.Style);
end;

Class Operator TGISFill.NotEqual(const Left,Right: TGISFill): Boolean;
begin
  Result := not (Left = Right);
end;

Function TGISFill.Invisible: Boolean;
begin
  Result := (Style = gbsClear) or (TAlphaColorRec(Color).A = 0);
end;

////////////////////////////////////////////////////////////////////////////////

Class Function TGISTextStyle.Create(const FontName: String;
                                    const Size: Single;
                                    const Color: TAlphaColor;
                                    const Bold: Boolean = false): TGISTextStyle;
begin
  Result.FontName := FontName;
  Result.Size := Size;
  Result.Color := Color;
  Result.Bold := Bold;
end;

Class Operator TGISTextStyle.Equal(const Left,Right: TGISTextStyle): Boolean;
begin
  Result := (Left.FontName = Right.FontName)
        and (Left.Size = Right.Size)
        and (Left.Bold = Right.Bold)
        and (Left.Color = Right.Color);
end;

Class Operator TGISTextStyle.NotEqual(const Left,Right: TGISTextStyle): Boolean;
begin
  Result := not (Left = Right);
end;

////////////////////////////////////////////////////////////////////////////////

Class Function TGISTextAlign.ResolveOrigin(const X,Y: Single;
                                           const Size: TSizeF;
                                           const AlignH: TGISTextAlignH;
                                           const AlignV: TGISTextAlignV): TPointF;
Var
  OriginX,OriginY: Single;
begin
  case AlignH of
    gahLeft: OriginX := X;
    gahCenter: OriginX := X - Size.cx/2;
    gahRight: OriginX := X - Size.cx;
    else raise Exception.Create('Unsupported horizontal text alignment');
  end;
  case AlignV of
    gavTop: OriginY := Y;
    gavMiddle: OriginY := Y - Size.cy/2;
    gavBottom: OriginY := Y - Size.cy;
    else raise Exception.Create('Unsupported vertical text alignment');
  end;
  Result := TPointF.Create(OriginX,OriginY);
end;

end.

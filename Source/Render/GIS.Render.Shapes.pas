unit GIS.Render.Shapes;

////////////////////////////////////////////////////////////////////////////////
//
// Author: Jaap Baak
// https://github.com/transportmodelling/GISlib
//
// Draws shape layers on an IGISCanvas. This unit is RTL-only: the framework it
// ends up rendering with is decided by the adapter the caller passes in.
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
interface
////////////////////////////////////////////////////////////////////////////////

Uses
  Classes, SysUtils, Types, UITypes, Generics.Defaults, Generics.Collections,
  GIS, GIS.Shapes, GIS.Shapes.Polygon, GIS.Shapes.Polygon.PolyLabel,
  GIS.Render.PixelConv, GIS.Render.Canvas;

Type
  TPointRenderStyle = (rsCircle,rsSquare,rsTriangleDown,rsTriangleUp,rsBitmap,
                       rsStation_18dp,rsStation_24dp,rsStation_36dp,rsStation_48dp,
                       rsAirport_18dp,rsAirport_24dp,rsAirport_36dp,rsAirport_48dp);

  TCustomShapesLayer = Class
  private
    FPointRenderSize: Integer;
    FPointRenderStyle: TPointRenderStyle;
    FPointImageBytes: TBytes;   // encoded symbol, empty unless a bitmap style is set
    FPointImage: IGISImage;     // decoded lazily, see PointImage
    FPointImageOwner: Pointer;  // canvas that decoded FPointImage
    FStyle: TGISShapeStyle;
    Viewport: TCoordinateRect;
    Function GetBoundingBoxes(Shape: Integer): TCoordinateRect;
    Procedure InitPointRenderStyle;
    Procedure SetPointRenderSize(PointRenderSize: Integer);
    Procedure SetPointRenderStyle(PointRenderStyle: TPointRenderStyle);
    Procedure SetPointImageBytes(const Bytes: TBytes);
    Function PointImage(const Canvas: IGISCanvas): IGISImage;
    Procedure LoadPointResource(const ResourceName: String);
    Class Function PngWidth(const Bytes: TBytes): Integer; static;
  strict protected
    Type
      TShapeRenderer = Class
      public
        Function Shape: TGISShape; virtual; abstract;
        Function BoundingBox: TCoordinateRect; virtual; abstract;
        Procedure WriteLabelPositions(const Writer: TBinaryWriter); virtual;
        Procedure ReadLabelPositions(const Reader: TBinaryReader); virtual;
        Procedure Draw(const ShapeLabel: String;
                       const Canvas: IGISCanvas;
                       const Style: TGISShapeStyle;
                       const PixelConverter: TCustomPixelConverter); virtual; abstract;
      end;
      TPointsRenderer = Class(TShapeRenderer)
      public
        Points: TShapePart;
        Layer: TCustomShapesLayer;
        Function Shape: TGISShape; override;
        Function BoundingBox: TCoordinateRect; override;
        Procedure Draw(const ShapeLabel: String;
                       const Canvas: IGISCanvas;
                       const Style: TGISShapeStyle;
                       const PixelConverter: TCustomPixelConverter); override;
      end;
      TLinesRenderer = Class(TShapeRenderer)
      public
        Lines: TGISShape;
        Function Shape: TGISShape; override;
        Function BoundingBox: TCoordinateRect; override;
        Procedure Draw(const ShapeLabel: String;
                       const Canvas: IGISCanvas;
                       const Style: TGISShapeStyle;
                       const PixelConverter: TCustomPixelConverter); override;
      end;
      TPolyPolygonsRenderer = Class(TShapeRenderer)
      private
        Type
          TLabelPosition = record
            Calculated: Boolean;
            Position: TCoordinate;
          end;
        Var
          LabelPositions: array of TLabelPosition;
        Function Ring(const Part: TShapePart;
                      const PixelConverter: TCustomPixelConverter): TArray<TPointF>;
      public
        PolyPolygons: TPolyPolygons;
        ShapeBoundingBox: TCoordinateRect;
        Layer: TCustomShapesLayer;
        Function Shape: TGISShape; override;
        Function BoundingBox: TCoordinateRect; override;
        Procedure WriteLabelPositions(const Writer: TBinaryWriter); override;
        Procedure ReadLabelPositions(const Reader: TBinaryReader); override;
        Procedure Draw(const Outer: Integer;
                       const ShapeLabel: String;
                       const Canvas: IGISCanvas;
                       const Style: TGISShapeStyle;
                       const PixelConverter: TCustomPixelConverter); overload;
        Procedure Draw(const ShapeLabel: String;
                       const Canvas: IGISCanvas;
                       const Style: TGISShapeStyle;
                       const PixelConverter: TCustomPixelConverter); overload; override;
      end;
    Const
      MaxPolyLabelIter = 100;
    Var
      FCount: Integer;
      FBoundingBox: TCoordinateRect;
    Function ShapeLabel(const Shape: Integer): String; virtual;
    Function ShapeRenderer(const Shape: Integer): TCustomShapesLayer.TShapeRenderer; virtual; abstract;
    Function PaintShape(const Shape: Integer): Boolean; virtual;
    // The style one shape is drawn with. The default returns the layer's Style
    // unchanged; override to vary it per shape.
    Function ShapeStyle(const Shape: Integer): TGISShapeStyle; virtual;
  public
    Constructor Create;
    Function PaintBoundingBox: TCoordinateRect;
    Procedure DrawLayer(const Canvas: IGISCanvas; const PixelConverter: TCustomPixelConverter);
    Destructor Destroy; override;
  public
    Property BoundingBox: TCoordinateRect read FBoundingBox;
    Property BoundingBoxes[Shape: Integer]: TCoordinateRect read GetBoundingBoxes;
    // The style the whole layer draws with, unless ShapeStyle overrides it
    Property Style: TGISShapeStyle read FStyle write FStyle;
  end;

  TShapesLayer = Class(TCustomShapesLayer)
  private
    FShapeCount: array[TShapeType] of Integer;
    ShapeRenderers: array of TCustomShapesLayer.TShapeRenderer;
    Procedure EnsureCapacity;
    Function GetShapes(Shape: Integer): TGISShape;
  strict protected
    Function ShapeRenderer(const Shape: Integer): TCustomShapesLayer.TShapeRenderer; override;
  public
    Constructor Create(InitialCapacity: Integer = 256);
    Procedure Clear;
    Procedure Add(Shape: TGISShape);
    Function ShapeCount(ShapeType: TShapeType): Integer;
    Procedure Read(const FileName: String; const FileFormat: TGISShapesFormat);
    Procedure SaveLabelPositions(const FileName: String);
    Procedure ReadLabelPositions(const FileName: String);
    Destructor Destroy; override;
  public
    Property Count: Integer read FCount;
    Property Shapes[Shape: Integer]: TGISShape read GetShapes; default;
    Property PointRenderSize: Integer read FPointRenderSize write SetPointRenderSize;
    Property PointRenderStyle: TPointRenderStyle read FPointRenderStyle write SetPointRenderStyle;
    // An encoded symbol (BMP or PNG) drawn for each point when PointRenderStyle
    // is rsBitmap. The canvas decodes it, so no framework image type is needed.
    Property PointImageBytes: TBytes read FPointImageBytes write SetPointImageBytes;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

{$R GIS.res}
{$R GIS.Symbols.res}

Const
  // The symbols are PNGs held as RCDATA, which is a plain blob on every
  // platform, so nothing here is Windows-specific.
  PointSymbolResources: array[rsStation_18dp..rsAirport_48dp] of String = (
    'STATION_18DP','STATION_24DP','STATION_36DP','STATION_48DP',
    'AIRPORT_18DP','AIRPORT_24DP','AIRPORT_36DP','AIRPORT_48DP');

Procedure TCustomShapesLayer.TShapeRenderer.WriteLabelPositions(const Writer: TBinaryWriter);
begin
end;

Procedure TCustomShapesLayer.TShapeRenderer.ReadLabelPositions(const Reader: TBinaryReader);
begin
end;

////////////////////////////////////////////////////////////////////////////////

Function TCustomShapesLayer.TPointsRenderer.Shape: TGISShape;
begin
  Result.AssignPoints(Points);
end;

Function TCustomShapesLayer.TPointsRenderer.BoundingBox: TCoordinateRect;
begin
   Result := Points.BoundingBox;
end;

Procedure TCustomShapesLayer.TPointsRenderer.Draw(const ShapeLabel: String;
                                                  const Canvas: IGISCanvas;
                                                  const Style: TGISShapeStyle;
                                                  const PixelConverter: TCustomPixelConverter);
begin
  var Radius := Layer.FPointRenderSize/2;
  var Image: IGISImage := nil;
  if Layer.FPointRenderStyle >= rsBitmap then Image := Layer.PointImage(Canvas);
  for var Point := 0 to Points.Count-1 do
  begin
    var Pixel := PixelConverter.CoordToPixel(Points[Point]);
    case Layer.FPointRenderStyle of
      rsCircle:
        Canvas.FillEllipse(TRectF.Create(Pixel.X-Radius,Pixel.Y-Radius,Pixel.X+Radius,Pixel.Y+Radius),
                           Style.Fill,Style.Stroke);
      rsSquare:
        Canvas.FillRect(TRectF.Create(Pixel.X-Radius,Pixel.Y-Radius,Pixel.X+Radius,Pixel.Y+Radius),
                        Style.Fill,Style.Stroke);
      rsTriangleUp:
        Canvas.FillPolygon([TPointF.Create(Pixel.X-Radius,Pixel.Y+Radius),
                            TPointF.Create(Pixel.X+Radius,Pixel.Y+Radius),
                            TPointF.Create(Pixel.X,Pixel.Y-Radius)],
                           nil,Style.Fill,Style.Stroke);
      rsTriangleDown:
        Canvas.FillPolygon([TPointF.Create(Pixel.X-Radius,Pixel.Y-Radius),
                            TPointF.Create(Pixel.X+Radius,Pixel.Y-Radius),
                            TPointF.Create(Pixel.X,Pixel.Y+Radius)],
                           nil,Style.Fill,Style.Stroke);
      else
        if Image <> nil then
        Canvas.DrawImage(Image,Pixel.X-Image.Width/2,Pixel.Y-Image.Height/2);
    end;
  end;
end;

////////////////////////////////////////////////////////////////////////////////

Function TCustomShapesLayer.TLinesRenderer.Shape: TGISShape;
begin
  Result := Lines;
end;

Function TCustomShapesLayer.TLinesRenderer.BoundingBox: TCoordinateRect;
begin
   Result := Lines.BoundingBox;
end;

Procedure TCustomShapesLayer.TLinesRenderer.Draw(const ShapeLabel: String;
                                                 const Canvas: IGISCanvas;
                                                 const Style: TGISShapeStyle;
                                                 const PixelConverter: TCustomPixelConverter);
Var
  Pixels: TArray<TPointF>;
begin
  for var Part := 0 to Lines.Count-1 do
  begin
    var PointsCount := Lines.Parts[Part].Count;
    SetLength(Pixels,PointsCount);
    for var Point := 0 to PointsCount-1 do
    Pixels[Point] := PixelConverter.CoordToPixel(Lines[Part,Point]);
    Canvas.DrawPolyline(Pixels,Style.Stroke);
  end;
end;

////////////////////////////////////////////////////////////////////////////////

Function TCustomShapesLayer.TPolyPolygonsRenderer.Shape: TGISShape;
Var
  Parts: array of TShapePart;
begin
  for var Outer := 0 to PolyPolygons.Count-1 do
  begin
    Parts := Parts + [PolyPolygons[Outer].OuterRing];
    for var Hole := 0 to PolyPolygons[Outer].HolesCount-1 do
    Parts := Parts + [PolyPolygons[Outer].Holes[Hole]];
  end;
  Result.AssignPolyPolygon(Parts);
end;

Function TCustomShapesLayer.TPolyPolygonsRenderer.BoundingBox: TCoordinateRect;
begin
   Result := ShapeBoundingBox;
end;

Procedure TCustomShapesLayer.TPolyPolygonsRenderer.WriteLabelPositions(const Writer: TBinaryWriter);
Var
  LabelPosition: TCoordinate;
begin
  for var Outer := 0 to PolyPolygons.Count-1 do
  begin
    // Calculate label positions
    if not LabelPositions[Outer].Calculated then
    begin
      LabelPosition := TPolyLabel.PolyLabel(PolyPolygons[Outer],MaxPolyLabelIter);
      LabelPositions[Outer].Calculated := true;
      LabelPositions[Outer].Position := LabelPosition;
    end;
    // Write label position to file
    Writer.Write(LabelPosition.X);
    Writer.Write(LabelPosition.Y);
  end;
end;

Procedure TCustomShapesLayer.TPolyPolygonsRenderer.ReadLabelPositions(const Reader: TBinaryReader);
begin
  for var Outer := 0 to PolyPolygons.Count-1 do
  begin
    LabelPositions[Outer].Calculated := true;
    LabelPositions[Outer].Position.X := Reader.ReadDouble;
    LabelPositions[Outer].Position.Y := Reader.ReadDouble;
  end;
end;

Function TCustomShapesLayer.TPolyPolygonsRenderer.Ring(const Part: TShapePart;
                                                       const PixelConverter: TCustomPixelConverter): TArray<TPointF>;
begin
  SetLength(Result,Part.Count);
  for var Point := 0 to Part.Count-1 do
  Result[Point] := PixelConverter.CoordToPixel(Part[Point]);
end;

Procedure TCustomShapesLayer.TPolyPolygonsRenderer.Draw(const Outer: Integer;
                                                        const ShapeLabel: String;
                                                        const Canvas: IGISCanvas;
                                                        const Style: TGISShapeStyle;
                                                        const PixelConverter: TCustomPixelConverter);
Var
  LabelPosition: TCoordinate;
  Holes: TArray<TArray<TPointF>>;
begin
  var PolyPolygon := PolyPolygons[Outer];
  var OuterPixels := Ring(PolyPolygon.OuterRing,PixelConverter);
  var PixelBoundingBox := TRectF.Create(TPointF.Create(OuterPixels[0].X,OuterPixels[0].Y),0,0);
  for var Point := low(OuterPixels) to high(OuterPixels) do
  begin
    if OuterPixels[Point].X < PixelBoundingBox.Left then PixelBoundingBox.Left := OuterPixels[Point].X;
    if OuterPixels[Point].X > PixelBoundingBox.Right then PixelBoundingBox.Right := OuterPixels[Point].X;
    if OuterPixels[Point].Y < PixelBoundingBox.Top then PixelBoundingBox.Top := OuterPixels[Point].Y;
    if OuterPixels[Point].Y > PixelBoundingBox.Bottom then PixelBoundingBox.Bottom := OuterPixels[Point].Y;
  end;
  if (PixelBoundingBox.Width > 0) and (PixelBoundingBox.Height > 0) then
  begin
    // The rings are filled even-odd in one path, so the holes are cut out of
    // the fill rather than painted over in a background colour.
    SetLength(Holes,PolyPolygon.HolesCount);
    for var Inner := 0 to PolyPolygon.HolesCount-1 do
    Holes[Inner] := Ring(PolyPolygon.Holes[Inner],PixelConverter);
    Canvas.FillPolygon(OuterPixels,Holes,Style.Fill,Style.Stroke);
    // Draw label
    if ShapeLabel <> '' then
    begin
      var LabelSize := Canvas.MeasureText(ShapeLabel,Style.Text);
      if (PixelBoundingBox.Width > 1.75*LabelSize.cx)
      and (PixelBoundingBox.Height > 1.75*LabelSize.cy) then
      begin
        if LabelPositions[Outer].Calculated then
          LabelPosition := LabelPositions[Outer].Position
        else
          begin
            LabelPosition := TPolyLabel.PolyLabel(PolyPolygon,MaxPolyLabelIter);
            LabelPositions[Outer].Calculated := true;
            LabelPositions[Outer].Position := LabelPosition;
          end;
        var LabelPixel := PixelConverter.CoordToPixel(LabelPosition);
        Canvas.DrawText(LabelPixel.X,LabelPixel.Y,ShapeLabel,Style.Text,gahCenter,gavMiddle);
      end;
    end;
  end;
end;

Procedure TCustomShapesLayer.TPolyPolygonsRenderer.Draw(const ShapeLabel: String;
                                                        const Canvas: IGISCanvas;
                                                        const Style: TGISShapeStyle;
                                                        const PixelConverter: TCustomPixelConverter);
begin
  for var Outer := 0 to Polypolygons.Count-1 do
  Draw(Outer,ShapeLabel,Canvas,Style,PixelConverter);
end;

////////////////////////////////////////////////////////////////////////////////

Constructor TCustomShapesLayer.Create;
begin
  inherited Create;
  FBoundingBox.Clear;
  FStyle.Stroke := TGISStroke.Create(TAlphaColorRec.Black);
  FStyle.Fill := TGISFill.Create(TAlphaColorRec.White);
  FStyle.Text := TGISTextStyle.Create('Arial',11,TAlphaColorRec.Black);
  InitPointRenderStyle;
end;

Function TCustomShapesLayer.GetBoundingBoxes(Shape: Integer): TCoordinateRect;
begin
  Result := ShapeRenderer(Shape).BoundingBox;
end;

Procedure TCustomShapesLayer.InitPointRenderStyle;
begin
  FPointRenderStyle := rsCircle;
  FPointRenderSize := 6;
  FPointImageBytes := nil;
  FPointImage := nil;
end;

Procedure TCustomShapesLayer.SetPointRenderSize(PointRenderSize: Integer);
begin
  if FPointRenderStyle < rsBitmap then FPointRenderSize := PointRenderSize;
end;

Class Function TCustomShapesLayer.PngWidth(const Bytes: TBytes): Integer;
// The width sits in the IHDR chunk, which a PNG always puts first: an 8-byte
// signature, then the chunk length and type, then the width as a big-endian
// 32-bit value. Read here so PointRenderSize is known without decoding.
Const
  Signature: array[0..7] of Byte = ($89,$50,$4E,$47,$0D,$0A,$1A,$0A);
begin
  if Length(Bytes) < 24 then raise Exception.Create('Point symbol is not a PNG');
  for var Index := low(Signature) to high(Signature) do
  if Bytes[Index] <> Signature[Index] then raise Exception.Create('Point symbol is not a PNG');
  Result := (Bytes[16] shl 24) or (Bytes[17] shl 16) or (Bytes[18] shl 8) or Bytes[19];
end;

Procedure TCustomShapesLayer.LoadPointResource(const ResourceName: String);
begin
  var Stream := TResourceStream.Create(HInstance,ResourceName,RT_RCDATA);
  try
    SetLength(FPointImageBytes,Stream.Size);
    if Stream.Size > 0 then Stream.ReadBuffer(FPointImageBytes[0],Stream.Size);
  finally
    Stream.Free;
  end;
  FPointRenderSize := PngWidth(FPointImageBytes);
  FPointImage := nil;
end;

Procedure TCustomShapesLayer.SetPointRenderStyle(PointRenderStyle: TPointRenderStyle);
begin
  FPointRenderStyle := PointRenderStyle;
  if FPointRenderStyle = rsBitmap then
  begin
    if Length(FPointImageBytes) = 0 then InitPointRenderStyle;
  end;
  if FPointRenderStyle > rsBitmap then LoadPointResource(PointSymbolResources[FPointRenderStyle]);
end;

Procedure TCustomShapesLayer.SetPointImageBytes(const Bytes: TBytes);
begin
  FPointImageBytes := Bytes;
  FPointImage := nil;
  if (FPointRenderStyle >= rsBitmap) and (Length(FPointImageBytes) = 0) then InitPointRenderStyle;
end;

Function TCustomShapesLayer.PointImage(const Canvas: IGISCanvas): IGISImage;
begin
  if Length(FPointImageBytes) = 0 then Exit(nil);
  // Decoding belongs to the canvas, so the image is rebuilt when a different
  // canvas (a different back end) asks for it.
  if (FPointImage = nil) or (FPointImageOwner <> Pointer(Canvas)) then
  begin
    FPointImage := Canvas.CreateImage(FPointImageBytes);
    FPointImageOwner := Pointer(Canvas);
  end;
  Result := FPointImage;
end;

Function TCustomShapesLayer.ShapeLabel(const Shape: Integer): String;
begin
  Result := '';
end;

Function TCustomShapesLayer.PaintShape(const Shape: Integer): Boolean;
begin
  Result := true;
end;

Function TCustomShapesLayer.ShapeStyle(const Shape: Integer): TGISShapeStyle;
begin
  Result := FStyle;
end;

Function TCustomShapesLayer.PaintBoundingBox: TCoordinateRect;
begin
  Result.Clear;
  for var Shape := 0 to FCount-1 do
  if PaintShape(Shape) then
  Result.Enclose(ShapeRenderer(Shape).BoundingBox);
end;

Procedure TCustomShapesLayer.DrawLayer(const Canvas: IGISCanvas;
                                       const PixelConverter: TCustomPixelConverter);
begin
  Viewport := PixelConverter.GetViewport;
  for var Shape := 0 to FCount-1 do
  if PaintShape(Shape) then
  begin
    var ShpRenderer := ShapeRenderer(Shape);
    if Viewport.IntersectsWith(ShpRenderer.BoundingBox) then
    ShpRenderer.Draw(ShapeLabel(Shape),Canvas,ShapeStyle(Shape),PixelConverter);
  end;
end;

Destructor TCustomShapesLayer.Destroy;
begin
  FPointImage := nil;
  inherited Destroy;
end;

////////////////////////////////////////////////////////////////////////////////

Constructor TShapesLayer.Create(InitialCapacity: Integer = 256);
begin
  inherited Create;
  SetLength(ShapeRenderers,InitialCapacity);
end;

Procedure TShapesLayer.EnsureCapacity;
begin
  if FCount = Length(ShapeRenderers) then
  begin
    var Delta := Round(0.25*FCount);
    if Delta < 256 then Delta := 256;
    SetLength(ShapeRenderers,FCount+Delta);
  end;
end;

Function TShapesLayer.GetShapes(Shape: Integer): TGISShape;
begin
  Result := ShapeRenderers[Shape].Shape;
end;

Function TShapesLayer.ShapeRenderer(const Shape: Integer): TCustomShapesLayer.TShapeRenderer;
begin
  Result := ShapeRenderers[Shape];
end;

Procedure TShapesLayer.Clear;
begin
  FCount := 0;
  for var ShapeType := low(TShapeType) to high(TShapeType) do FShapeCount[ShapeType] := 0;
  FBoundingBox.Clear;
end;

Procedure TShapesLayer.Add(Shape: TGISShape);
begin
  EnsureCapacity;
  case Shape.ShapeType of
    stPoint:
      begin
        var Renderer := TCustomShapesLayer.TPointsRenderer.Create;
        Renderer.Points := Shape.Parts[0];
        Renderer.Layer := Self;
        ShapeRenderers[FCount] := Renderer;
      end;
    stLine:
      begin
        var Renderer := TCustomShapesLayer.TLinesRenderer.Create;
        Renderer.Lines := Shape;
        ShapeRenderers[FCount] := Renderer;
      end;
    stPolygon:
      begin
        var Renderer := TCustomShapesLayer.TPolyPolygonsRenderer.Create;
        Renderer.PolyPolygons := TPolyPolygons.Create(Shape);
        Renderer.ShapeBoundingBox := Shape.BoundingBox;
        Renderer.Layer := Self;
        SetLength(Renderer.LabelPositions,Renderer.PolyPolygons.Count);
        ShapeRenderers[FCount] := Renderer;
      end;
  end;
  Inc(FCount);
  Inc(FShapeCount[Shape.ShapeType]);
  FBoundingBox.Enclose(Shape.BoundingBox);
end;

Function TShapesLayer.ShapeCount(ShapeType: TShapeType): Integer;
begin
  Result := FShapeCount[ShapeType];
end;

Procedure TShapesLayer.Read(const FileName: String; const FileFormat: TGISShapesFormat);
Var
  Shape: TGISShape;
begin
  var Reader := FileFormat.Create(FileName);
  try
    while Reader.ReadShape(Shape) do Add(Shape);
  finally
    Reader.Free;
  end;
end;

Procedure TShapesLayer.SaveLabelPositions(const FileName: String);
Var
  Stream: TStream;
  Writer: TBinaryWriter;
begin
  Stream := nil;
  Writer := nil;
  try
    Stream := TBufferedFileStream.Create(FileName,fmCreate or fmShareDenyWrite,4096);
    Writer := TBinaryWriter.Create(Stream);
    for var Shape := 0 to FCount-1 do ShapeRenderers[Shape].WriteLabelPositions(Writer);
  finally
    Stream.Free;
    Writer.Free;
  end;
end;

Procedure TShapesLayer.ReadLabelPositions(const FileName: String);
Var
  Stream: TStream;
  Reader: TBinaryReader;
begin
  Stream := nil;
  Reader := nil;
  try
    Stream := TBufferedFileStream.Create(FileName,fmOpenRead or fmShareDenyWrite,4096);
    Reader := TBinaryReader.Create(Stream);
    for var Shape := 0 to FCount-1 do ShapeRenderers[Shape].ReadLabelPositions(Reader);
  finally
    Stream.Free;
    Reader.Free;
  end;
end;

Destructor TShapesLayer.Destroy;
begin
  for var Renderer := low(ShapeRenderers) to high(ShapeRenderers) do ShapeRenderers[Renderer].Free;
  inherited Destroy;
end;

end.

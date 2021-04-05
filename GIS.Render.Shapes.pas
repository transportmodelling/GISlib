unit GIS.Render.Shapes;

////////////////////////////////////////////////////////////////////////////////
//
// Author: Jaap Baak
// https://github.com/transportmodelling/GISlib
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
interface
////////////////////////////////////////////////////////////////////////////////

Uses
  Types,Graphics,Generics.Defaults,Generics.Collections,GIS,GIS.Shapes,
  GIS.Shapes.Polygon,GIS.Shapes.Polygon.PolyLabel,GIS.Render.Shapes.PixelConv;

Type
  TPointRenderStyle = (rsCircle,rsSquare,rsTriangleDown,rsTriangleUp,rsBitmap);

  TCustomShapesLayer = Class
  private
    FPointRenderSize: Integer;
    FPointRenderStyle: TPointRenderStyle;
    FPointBitmap: TBitmap;
    Viewport: TCoordinateRect;
    PolygonBitmap: TBitmap;
    Procedure InitPointRenderStyle;
    Procedure SetPointRenderStyle(PointRenderStyle: TPointRenderStyle);
    Procedure SetPointBitmap(PointBitmap: TBitmap);
    Procedure PointBitmapChange(sender: TObject);
  strict protected
    FCount: Integer;
    FBoundingBox: TCoordinateRect;
    Function DrawShape(const [ref] ShapeBoundingBox: TCoordinateRect): Boolean; overload; virtual;
    Procedure DrawShape(const [ref] Shape: TGISShape;
                        const ShapeLabel: String;
                        const Canvas: TCanvas;
                        const PixelConverter: TCustomPixelConverter); overload;
  strict protected
    Procedure DrawShape(const Shape: Integer;
                        const Canvas: TCanvas;
                        const PixelConverter: TCustomPixelConverter);  overload; virtual; abstract;
  public
    Constructor Create(const TransparentColor: TColor);
    Procedure DrawLayer(const Canvas: TCanvas;
                        const PixelConverter: TCustomPixelConverter;
                        const Width,Height: Integer); overload;
    Procedure DrawLayer(const Bitmap: TBitmap; const PixelConverter: TCustomPixelConverter); overload;
    Destructor Destroy; override;
  public
    Property BoundingBox: TCoordinateRect read FBoundingBox;
  end;

  TShapesLayer = Class(TCustomShapesLayer)
  private
    FShapes: array of TGISShape;
    FShapeCount: array[TShapeType] of Integer;
    Procedure EnsureCapacity;
    Function GetShapes(Shape: Integer): TGISShape; inline;
  strict protected
    Procedure DrawShape(const Shape: Integer;
                        const Canvas: TCanvas;
                        const PixelConverter: TCustomPixelConverter);  override;
  strict protected
    Function ShapeLabel(const Shape: Integer): String; virtual;
    Procedure SetPaintStyle(const Shape: Integer; const Canvas: TCanvas); virtual;
  public
    Constructor Create(const TransparentColor: TColor; InitialCapacity: Integer = 256);
    Procedure Clear;
    Procedure Add(Shape: TGISShape);
    Function ShapeCount(ShapeType: TShapeType): Integer;
    Procedure Read(const FileName: String; const FileFormat: TShapesFormat);
  public
    Property Count: Integer read FCount;
    Property Shapes[Shape: Integer]: TGISShape read GetShapes; default;
    Property PointRenderSize: Integer read FPointRenderSize write FPointRenderSize;
    Property PointRenderStyle: TPointRenderStyle read FPointRenderStyle write SetPointRenderStyle;
    Property PointBitmap: TBitmap read FPointBitmap write SetPointBitmap;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Constructor TCustomShapesLayer.Create(const TransparentColor: TColor);
// TransparentColor designates an unused color to be used for polygon rendering
begin
  inherited Create;
  FBoundingBox.Clear;
  FPointBitmap := TBitmap.Create;
  FPointBitmap.OnChange := PointBitmapChange;
  PolygonBitmap := TBitmap.Create;
  PolygonBitmap.Transparent := true;
  PolygonBitmap.TransparentColor := TransparentColor;
  InitPointRenderStyle;
end;

Procedure TCustomShapesLayer.InitPointRenderStyle;
begin
  FPointRenderStyle := rsCircle;
  FPointRenderSize := 6;
end;

Procedure TCustomShapesLayer.SetPointRenderStyle(PointRenderStyle: TPointRenderStyle);
begin
  if (PointRenderStyle <> rsBitmap) or (not FPointBitmap.Empty) then FPointRenderStyle := PointRenderStyle;
end;

Procedure TCustomShapesLayer.SetPointBitmap(PointBitmap: TBitmap);
begin
  FPointBitmap.Assign(PointBitmap);
end;

Procedure TCustomShapesLayer.PointBitmapChange(sender: TObject);
begin
  if (FPointRenderStyle = rsBitmap) and FPointBitmap.Empty then InitPointRenderStyle;
end;

Function TCustomShapesLayer.DrawShape(const [ref] ShapeBoundingBox: TCoordinateRect): Boolean;
begin
  Result := Viewport.IntersectsWith(ShapeBoundingBox);
end;

Procedure TCustomShapesLayer.DrawShape(const [ref] Shape: TGISShape;
                                       const ShapeLabel: String;
                                       const Canvas: TCanvas;
                                       const PixelConverter: TCustomPixelConverter);
Var
  Pixels: array of TPoint;
begin
  case Shape.ShapeType of
    stPoint:
      begin
        var PointsCount := Shape.Parts[0].Count;
        var Radius := FPointRenderSize div 2;
        for var Point := 0 to PointsCount-1 do
        begin
          var Pixel := PixelConverter.CoordToPixel(Shape[0,Point]);
          case FPointRenderStyle of
            rsCircle: Canvas.Ellipse(Pixel.X-Radius,Pixel.Y-Radius,Pixel.X+Radius,Pixel.Y+Radius);
            rsSquare: Canvas.Rectangle(Pixel.X-Radius,Pixel.Y-Radius,Pixel.X+Radius,Pixel.Y+Radius);
            rsTriangleUp: Canvas.Polygon([Types.Point(Pixel.X-Radius,Pixel.Y+Radius),
                                          Types.Point(Pixel.X+Radius,Pixel.Y+Radius),
                                          Types.Point(Pixel.X,Pixel.Y-Radius)]);
            rsTriangleDown: Canvas.Polygon([Types.Point(Pixel.X-Radius,Pixel.Y-Radius),
                                            Types.Point(Pixel.X+Radius,Pixel.Y-Radius),
                                            Types.Point(Pixel.X,Pixel.Y+Radius)]);
            rsBitmap:
              begin
                var X := Pixel.X - (FPointBitmap.Width div 2);
                var Y := Pixel.Y - (FPointBitmap.Height div 2);
                Canvas.Draw(X,Y,FPointBitmap);
              end;
          end;
        end;
      end;
    stLine:
      begin
        for var Part := 0 to Shape.Count-1 do
        begin
          var PointsCount := Shape.Parts[Part].Count;
          var Pixel := PixelConverter.CoordToPixel(Shape[Part,0]);
          Canvas.MoveTo(Pixel.X,Pixel.Y);
          for var Point := 1 to PointsCount-1 do
          begin
            Pixel := PixelConverter.CoordToPixel(Shape[Part,Point]);
            Canvas.LineTo(Pixel.X,Pixel.Y);
          end;
        end;
      end;
    stPolygon:
      begin
        // Clear polygon bitmap
        PolygonBitmap.Canvas.Brush.Style := bsSolid;
        PolygonBitmap.Canvas.Brush.Color := PolygonBitmap.TransparentColor;
        PolygonBitmap.Canvas.FillRect(Rect(0,0,PolygonBitmap.Width,PolygonBitmap.Height));
        // Draw poly polygons on polygon bitmap
        var PolyPolygons := TPolyPolygons.Create(Shape);
        for var Outer := 0 to PolyPolygons.Count-1 do
        begin
          var PolyPolygon := PolyPolygons[Outer];
          // Calculate pixels outer ring
          var OuterRing := PolyPolygon.OuterRing;
          SetLength(Pixels,OuterRing.Count);
          for var Point := 0 to OuterRing.Count-1 do
          Pixels[Point] := PixelConverter.CoordToPixel(OuterRing[Point]);
          // Draw outer ring
          var PixelBoundingBox := TRect.Union(Pixels);
          if (PixelBoundingBox.Width > 0) and (PixelBoundingBox.Height > 0) then
          begin
            PolygonBitmap.Canvas.Brush := Canvas.Brush;
            PolygonBitmap.Canvas.Polygon(Pixels);
            // Draw label
            var LabelSize := PolygonBitmap.Canvas.TextExtent(ShapeLabel);
            if (PixelBoundingBox.Width > 1.75*LabelSize.cx)
            and (PixelBoundingBox.Height > 1.75*LabelSize.cy) then
            begin
              var LabelCoord := TPolyLabel.PolyLabel(PolyPolygon,100);
              var LabelPixel := PixelConverter.CoordToPixel(LabelCoord);
              var X := LabelPixel.X - (LabelSize.cx div 2);
              var Y := LabelPixel.Y - (LabelSize.cy div 2);
              PolygonBitmap.Canvas.TextOut(X,Y,ShapeLabel);
            end;
            // Draw holes
            for var Inner := 0 to PolyPolygon.HolesCount-1 do
            begin
              // Calculate pixels hole
              var Hole := PolyPolygon.Holes[Inner];
              SetLength(Pixels,Hole.Count);
              for var Point := 0 to Hole.Count-1 do
              Pixels[Point] := PixelConverter.CoordToPixel(Hole[Point]);
              // Draw hole
              PolygonBitmap.Canvas.Brush.Style := bsSolid;
              PolygonBitmap.Canvas.Brush.Color := PolygonBitmap.TransparentColor;
              PolygonBitmap.Canvas.Polygon(Pixels);
            end;
          end;
        end;
        // Draw polygon bitmap
        Canvas.Draw(0,0,PolygonBitmap);
      end;
  end;
end;

Procedure TCustomShapesLayer.DrawLayer(const Canvas: TCanvas;
                                       const PixelConverter: TCustomPixelConverter;
                                       const Width,Height: Integer);
begin
  Viewport := PixelConverter.PixelToCoord(Width,Height);
  PolygonBitmap.SetSize(Width,Height);
  PolygonBitmap.Canvas.Pen := Canvas.Pen;
  for var Shape := 0 to FCount-1 do DrawShape(Shape,Canvas,PixelConverter);
end;

Procedure TCustomShapesLayer.DrawLayer(const Bitmap: TBitmap; const PixelConverter: TCustomPixelConverter);
begin
  DrawLayer(Bitmap.Canvas,PixelConverter,Bitmap.Width,Bitmap.Height);
end;

Destructor TCustomShapesLayer.Destroy;
begin
  FPointBitmap.Free;
  PolygonBitmap.Free;
  inherited Destroy;
end;

////////////////////////////////////////////////////////////////////////////////

Constructor TShapesLayer.Create(const TransparentColor: TColor; InitialCapacity: Integer = 256);
begin
  inherited Create(TransparentColor);
  SetLength(FShapes,InitialCapacity);
end;

Procedure TShapesLayer.EnsureCapacity;
begin
  if FCount = Length(FShapes) then
  begin
    var Delta := Round(0.25*FCount);
    if Delta < 256 then Delta := 256;
    SetLength(FShapes,FCount+Delta);
  end;
end;

Function TShapesLayer.GetShapes(Shape: Integer): TGISShape;
begin
  Result := FShapes[Shape];
end;

Procedure TShapesLayer.DrawShape(const Shape: Integer;
                                 const Canvas: TCanvas;
                                 const PixelConverter: TCustomPixelConverter);
begin
  if DrawShape(FShapes[Shape].BoundingBox) then
  begin
    var ShpLbl := ShapeLabel(Shape);
    SetPaintStyle(Shape,Canvas);
    DrawShape(FShapes[Shape],ShpLbl,Canvas,PixelConverter);
  end;
end;

Function TShapesLayer.ShapeLabel(const Shape: Integer): String;
begin
  Result := '';
end;


Procedure TShapesLayer.SetPaintStyle(const Shape: Integer; const Canvas: TCanvas);
begin
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
  FShapes[FCount] := Shape;
  Inc(FCount);
  Inc(FShapeCount[Shape.ShapeType]);
  FBoundingBox.Enclose(Shape.BoundingBox);
end;

Function TShapesLayer.ShapeCount(ShapeType: TShapeType): Integer;
begin
  Result := FShapeCount[ShapeType];
end;

Procedure TShapesLayer.Read(const FileName: String; const FileFormat: TShapesFormat);
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

end.

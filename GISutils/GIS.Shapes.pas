unit GIS.Shapes;

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
  SysUtils,Generics.Collections,GIS;

Type
  TShapeType = (stEmpty,stPoint,stLine,stPolygon);

  TMultiPoint = array {point} of TCoordinate;
  TMultiPoints = array {part} of TMultiPoint;

  TShapePart = record
  private
    FPoints: array of TCoordinate;
    FBoundingBox: TCoordinateRect;
    Function GetPoints(Point: Integer): TCoordinate; inline;
  public
    Constructor Create(const Points: array of TCoordinate; ClosePart: Boolean = false);
    Procedure Clear;
    Function Empty: Boolean;
    Function Count: Integer;
    Function BoundingBox: TCoordinateRect;
  public
    Property Points[Point: Integer]: TCoordinate read GetPoints; default;
  end;

  TGISShape = record
  // Polygons must be non-intersecting (they may touch at vertices but not along segments)
  // Polygons with an even number of enclosing rings are outer rings
  // Polygons with an odd number of enclosing rings are holes
  private
    FShapeType: TShapeType;
    FParts: array of TShapePart;
    FBoundingBox: TCoordinateRect;
    Function GetParts(Part: Integer): TShapePart; inline;
    Function GetPoints(Part,Point: Integer): TCoordinate; inline;
  public
    // Manage content
    Procedure Clear;
    Procedure AssignPoint(const X,Y: Float64); overload;
    Procedure AssignPoint(const Point: TCoordinate); overload;
    Procedure AssignPoints(const Points: array of TCoordinate); overload;
    Procedure AssignPoints(const Points: TShapePart); overload;
    Procedure AssignLine(const Points: array of TCoordinate);
    Procedure AssignPolyLine(const Points: TMultiPoints);
    Procedure AssignPolygon(const Points: array of TCoordinate);
    Procedure AssignPolyPolygon(const Points: TMultiPoints); overload;
    Procedure AssignPolyPolygon(const Points: array of TShapePart); overload;
    // Query methods
    Function ShapeType: TShapeType;
    Function Empty: Boolean;
    Function Count: Integer;
    Function BoundingBox: TCoordinateRect;
  public
    Property Parts[Part: Integer]: TShapePart read GetParts;
    Property Points[Part,Point: Integer]: TCoordinate read GetPoints; default;
  end;

  TShapesReader = Class
  private
    FFileName: String;
  public
    Constructor Create(FileName: string); virtual;
    Function ReadShape(out Shape: TGISShape): Boolean; overload;
    Function ReadShape(out Shape: TGISShape; out Properies: TArray<TPair<String,Variant>>): Boolean; overload; virtual; abstract;
  end;

  TShapesFormat = Class of TShapesReader;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Constructor TShapePart.Create(const Points: array of TCoordinate; ClosePart: Boolean = false);
begin
  FBoundingBox.Clear;
  // Copy points
  SetLength(FPoints,Length(Points));
  for var Point := 0 to Count-1 do
  begin
    FPoints[Point] := Points[Point];
    FBoundingBox.Enclose(Points[Point]);
  end;
  // Close part
  if ClosePart then
  if (FPoints[0].X <> FPoints[Count-1].X) or (FPoints[0].Y <> FPoints[Count-1].Y) then
  FPoints := FPoints + [FPoints[0]];
end;

Function TShapePart.GetPoints(Point: Integer): TCoordinate;
begin
  Result := FPoints[Point];
end;

Procedure TShapePart.Clear;
begin
  Finalize(FPoints);
  FBoundingBox.Clear;
end;

Function TShapePart.Empty: Boolean;
begin
  Result := (Count=0);
end;

Function TShapePart.Count: Integer;
begin
  Result := Length(FPoints);
end;

Function TShapePart.BoundingBox: TCoordinateRect;
begin
  if Empty then Result.Clear else Result := FBoundingBox;
end;

////////////////////////////////////////////////////////////////////////////////

Function TGISShape.GetParts(Part: Integer): TShapePart;
begin
  Result := FParts[Part];
end;

Function TGISShape.GetPoints(Part,Point: Integer): TCoordinate;
begin
  Result := FParts[Part][Point];
end;

Procedure TGISShape.Clear;
begin
  Finalize(FParts);
  FBoundingBox.Clear;
end;

Procedure TGISShape.AssignPoint(const X,Y: Float64);
begin
  AssignPoint(TCoordinate.Create(X,Y));
end;

Procedure TGISShape.AssignPoint(const Point: TCoordinate);
begin
  Clear;
  FShapeType := stPoint;
  SetLength(FParts,1);
  FParts[0] := TShapePart.Create([Point]);
  FBoundingBox.Enclose(FParts[0].FBoundingBox);
end;

Procedure TGISShape.AssignPoints(const Points: array of TCoordinate);
begin
  Clear;
  FShapeType := stPoint;
  SetLength(FParts,1);
  FParts[0] := TShapePart.Create(Points);
  FBoundingBox.Enclose(FParts[0].FBoundingBox);
end;

Procedure TGISShape.AssignPoints(const Points: TShapePart);
begin
  Clear;
  FShapeType := stPoint;
  SetLength(FParts,1);
  FParts[0] := Points;
end;

Procedure TGISShape.AssignLine(const Points: array of TCoordinate);
begin
  Clear;
  FShapeType := stLine;
  if Length(Points) > 1 then
  begin
    SetLength(FParts,1);
    FParts[0] := TShapePart.Create(Points);
    FBoundingBox.Enclose(FParts[0].FBoundingBox);
  end else
    raise Exception.Create('Invalid poly line');
end;

Procedure TGISShape.AssignPolyLine(const Points: TMultiPoints);
begin
  Clear;
  FShapeType := stLine;
  SetLength(FParts,Length(Points));
  for var Part := 0 to Count-1 do
  if Length(Points[Part]) > 1 then
  begin
    FParts[Part] := TShapePart.Create(Points[Part]);
    FBoundingBox.Enclose(FParts[Part].FBoundingBox);
  end else
    raise Exception.Create('Invalid poly line');
end;

Procedure TGISShape.AssignPolygon(const Points: array of TCoordinate);
begin
  Clear;
  FShapeType := stPolygon;
  if Length(Points) > 2 then
  begin
    SetLength(FParts,1);
    FParts[0] := TShapePart.Create(Points,true);
    FBoundingBox.Enclose(FParts[0].FBoundingBox);
  end else
    raise Exception.Create('Invalid polygon');
end;

Procedure TGISShape.AssignPolyPolygon(const Points: TMultiPoints);
begin
  Clear;
  FShapeType := stPolygon;
  SetLength(FParts,Length(Points));
  for var Part := 0 to Count-1 do
  if Length(Points[Part]) > 2 then
  begin
    FParts[Part] := TShapePart.Create(Points[Part],true);
    FBoundingBox.Enclose(FParts[Part].FBoundingBox);
  end else
    raise Exception.Create('Invalid polygon');
end;

Procedure TGISShape.AssignPolyPolygon(const Points: array of TShapePart);
begin
  Clear;
  FShapeType := stPolygon;
  SetLength(FParts,Length(Points));
  for var Part := 0 to Count-1 do
  if Points[Part].Count > 2 then
  begin
    FParts[Part] := Parts[Part];
    FBoundingBox.Enclose(FParts[Part].FBoundingBox);
  end else
    raise Exception.Create('Invalid polygon');
end;

Function TGISShape.ShapeType: TShapeType;
begin
  if Count = 0 then Result := stEmpty else Result := FShapeType;
end;

Function TGISShape.Empty: Boolean;
begin
  Result := (Count = 0);
end;

Function TGISShape.Count: Integer;
begin
  Result := Length(FParts);
end;

Function TGISShape.BoundingBox: TCoordinateRect;
begin
  if Empty then Result.Clear else  Result := FBoundingBox;
end;

////////////////////////////////////////////////////////////////////////////////

Constructor TShapesReader.Create(FileName: string);
begin
  inherited Create;
  FFileName := FileName;
end;

Function TShapesReader.ReadShape(out Shape: TGISShape): Boolean;
Var
  Properties: TArray<TPair<String,Variant>>;
begin
  Result := ReadShape(Shape,Properties);
end;

end.

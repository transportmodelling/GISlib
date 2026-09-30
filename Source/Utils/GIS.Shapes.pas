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
    FPoints: TMultiPoint;
    FBoundingBox: TCoordinateRect;
    Function GetPoints(Point: Integer): TCoordinate; inline;
    Function Intersecting(const Point,A,B: TCoordinate): Boolean;
    Function NrIntersections(const [ref] Point: TCoordinate): Integer;
  public
    Constructor Create(const Points: array of TCoordinate; ClosePart: Boolean = false);
    Procedure Clear;
    Function Empty: Boolean;
    Function Count: Integer;
    Function BoundingBox: TCoordinateRect;
    Function AsMultiPoint: TMultiPoint;
    // Whether the part, taken as a ring, encloses Point
    Function Contains(const [ref] Point: TCoordinate): Boolean;
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

  TGISShapeProperties = TArray<TPair<String,Variant>>; // Array of name-value pairs

  TGISShapePropertiesHelper = record helper for TGISShapeProperties
  private
    Function GetValueFromIndex(Index: Integer): Variant; inline;
    Function GetValueFromName(Name: String): Variant; inline;
  public
    Property ValueFromIndex[Index: Integer]: Variant read GetValueFromIndex;
    Property ValueFromName[Name: String]: Variant read GetValueFromName;
  end;

  TGISShapesReader = Class
  private
    FFileName: TFileName;
  public
    Constructor Create(const FileName: TFileName); virtual;
    Function ReadShape(out Shape: TGISShape): Boolean; overload;
    Function ReadShape(out Shape: TGISShape; out Properies: TGISShapeProperties): Boolean; overload; virtual; abstract;
  public
    Property FileName: TFileName read FFileName;
  end;

  TGISShapesFormat = Class of TGISShapesReader;

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

Function TShapePart.AsMultiPoint: TMultiPoint;
begin
  Result := Copy(FPoints);
end;

Function TShapePart.Intersecting(const Point,A,B: TCoordinate): Boolean;
// Tests whether the line from Point to (infinity,Point.Y) and line segment AB intersect
begin
  if (A.Y > Point.Y) and (B.Y > Point.Y) then Result := false else // AB positioned above line
  if (A.Y < Point.Y) and (B.Y < Point.Y) then Result := false else // AB positioned below line
  if (A.X < Point.X) and (B.X < Point.X) then Result := false else // AB positioned to the left of line
  if (A.X >= Point.X) and (B.X >= Point.X) then Result := true else
  if (A.Y = Point.Y) and (B.Y = Point.Y) then Result := true else
  if A.X < B.X then
    if A.Y < B.Y then
      Result := (Point.X-A.X)*(B.Y-A.Y) <= (Point.Y-A.Y)*(B.X-A.X)
    else
      Result := (Point.X-A.X)*(A.Y-B.Y) <= (A.Y-Point.Y)*(B.X-A.X)
  else
    if B.Y < A.Y then
      Result := (Point.X-B.X)*(A.Y-B.Y) <= (Point.Y-B.Y)*(A.X-B.X)
    else
      Result := (Point.X-B.X)*(B.Y-A.Y) <= (B.Y-Point.Y)*(A.X-B.X);
end;

Function TShapePart.NrIntersections(const [ref] Point: TCoordinate): Integer;
// Returns the number of intersection between the ring and the line from Point to (infinity,Point.Y).
Const
  Below = -1;
  Above = +1;
var
  CurrentPoint,PreviousPoint: TCoordinate;
begin
  Result := 0;
  if Count > 0 then
  begin
    // Find a vertex that is either above or below Point
    var First := 0;
    var Position := 0;
    repeat
      if FPoints[First].Y < Point.Y then Position := Below else
      if FPoints[First].Y > Point.Y then Position := Above else
      Inc(First);
    until (Position <> 0) or (First = Count);
   // Test whether edges intersect the line from Point to Point(infinite,Point.Y)
    if First < Count then
    begin
      var Previous := First;
      PreviousPoint := FPoints[First];
      for var Vertex := 1 to Count do
      begin
        var Current := (First+Vertex) mod Count;
        CurrentPoint := FPoints[Current];
        if CurrentPoint.Y = PreviousPoint.Y then
        begin
          if CurrentPoint.Y = Point.Y then
          if CurrentPoint.X < PreviousPoint.X then
          begin
           if (CurrentPoint.X <= Point.X) and (PreviousPoint.X >= Point.X) then Exit(1)
          end else
          begin
            if (PreviousPoint.X <= Point.X) and (CurrentPoint.X >= Point.X) then Exit(1)
          end;
        end else
        begin
          if (Position = Above) and (CurrentPoint.Y < Point.Y) then
          begin
            Position := Below;
            if Intersecting(Point,PreviousPoint,CurrentPoint) then Inc(Result)
          end else
          if (Position = Below) and (CurrentPoint.Y > Point.Y) then
          begin
            Position := Above;
            if Intersecting(Point,PreviousPoint,CurrentPoint) then Inc(Result)
          end;
        end;
        Previous := Current;
        PreviousPoint := CurrentPoint;
      end;
    end;
  end;
end;

Function TShapePart.Contains(const [ref] Point: TCoordinate): Boolean;
begin
  Result := ((NrIntersections(Point) mod 2) = 1);
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
  FBoundingBox.Enclose(FParts[0].FBoundingBox);
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
    FParts[Part] := Points[Part];
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

Function TGISShapePropertiesHelper.GetValueFromIndex(Index: Integer): Variant;
begin
  Result := Self[Index].Value;
end;

Function TGISShapePropertiesHelper.GetValueFromName(Name: String): Variant;
begin
  for var Prop := low(Self) to high(Self) do
  if SameText(Name,Self[Prop].Key) then Exit(Self[Prop].Value);
  raise Exception.Create('Property ' + Name + 'does not exist');
end;

////////////////////////////////////////////////////////////////////////////////

Constructor TGISShapesReader.Create(const FileName: TFileName);
begin
  inherited Create;
  FFileName := FileName;
end;

Function TGISShapesReader.ReadShape(out Shape: TGISShape): Boolean;
Var
  Properties: TGISShapeProperties;
begin
  Result := ReadShape(Shape,Properties);
end;

end.

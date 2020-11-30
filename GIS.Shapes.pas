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
  SysUtils,GIS;

Type
  TShapeType = (stEmpty,stPoint,stLine,stPolygon);

  TMultiPoints = array {part} of array {point} of TCoordinate;

  TGISData = record
  private
    FName,FValue: String;
  public
    Constructor Create(const Name,Value: String);
    Property Name: String read FName;
    Property Value: String read FValue;
  end;

  TGISShape = record
  // Polygons must be non-intersecting.
  // Counterclockwise oriented polygons are holes
  private
    FPoints: TMultiPoints;
    FShapeType: TShapeType;
    FBoundingBox: TCoordinateRect;
    FData: array of TGISData;
    Function GetPoints(Part,Point: Integer): TCoordinate; inline;
  public
    // Manage content
    Procedure Clear;
    Procedure AssignPoint(const X,Y: Float64); overload;
    Procedure AssignPoint(const Point: TCoordinate); overload;
    Procedure AssignPoints(const Points: array of TCoordinate);
    Procedure AssignLine(const Points: array of TCoordinate);
    Procedure AssignPolyLine(const Points: TMultiPoints);
    Procedure AssignPolygon(const Points: array of TCoordinate);
    Procedure AssignPolyPolygon(const Points: TMultiPoints);
    Procedure AddData(const Data: TGISData);
    // Query methods
    Function ShapeType: TShapeType;
    Function Empty: Boolean;
    Function PartsCount: Integer;
    Function PointsCount(Part: Integer): Integer;
    Function BoundingBox: TCoordinateRect;
    Function DataCount: Integer;
    Function IndexOf(const Name: string): Integer;
    Function Data(Index: Integer): TGISData;
  public
    Property Points[Part,Point: Integer]: TCoordinate read GetPoints; default;
  end;

  TShapesReader = Class
  private
    FFileName: String;
  public
    Constructor Create(const FileName: string); virtual;
    Function ReadShape(out Shape: TGISShape): Boolean; virtual; abstract;
  end;

  TShapesFormat = Class of TShapesReader;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Constructor TGISData.Create(const Name,Value: String);
begin
  if Name <> '' then
  begin
    FName := Name;
    FValue := Value;
  end else
    raise Exception.Create('Invalid GIS-data name');
end;

////////////////////////////////////////////////////////////////////////////////

Procedure TGISShape.Clear;
begin
  Finalize(FPoints);
  Finalize(FData);
  FBoundingBox.Clear;
end;

Function TGISShape.GetPoints(Part,Point: Integer): TCoordinate;
begin
  Result := FPoints[Part,Point];
end;

Procedure TGISShape.AssignPoint(const X,Y: Float64);
begin
  AssignPoint(TCoordinate.Create(X,Y));
end;

Procedure TGISShape.AssignPoint(const Point: TCoordinate);
begin
  Clear;
  FShapeType := stPoint;
  SetLength(FPoints,1,1);
  FPoints[0,0] := Point;
  FBoundingBox.Enclose(Point);
end;

Procedure TGISShape.AssignPoints(const Points: array of TCoordinate);
begin
  Clear;
  FShapeType := stPoint;
  SetLength(FPoints,1,Length(Points));
  for var Point := low(Points) to high(Points) do
  begin
    FPoints[0,Point] := Points[Point];
    FBoundingBox.Enclose(Points[Point]);
  end;
end;

Procedure TGISShape.AssignLine(const Points: array of TCoordinate);
begin
  Clear;
  FShapeType := stLine;
  SetLength(FPoints,1,Length(Points));
  for var Point := low(Points) to high(Points) do
  begin
    FPoints[0,Point] := Points[Point];
    FBoundingBox.Enclose(Points[Point]);
  end;
end;

Procedure TGISShape.AssignPolyLine(const Points: TMultiPoints);
begin
  Clear;
  FShapeType := stLine;
  SetLength(FPoints,Length(Points));
  for var Part := 0 to PartsCount-1 do
  begin
    SetLength(FPoints[Part],Length(Points[Part]));
    for var Point := 0 to PointsCount(Part)-1 do
    begin
      FPoints[Part,Point] := Points[Part,Point];
      FBoundingBox.Enclose(Points[Part,Point]);
    end;
  end;
end;

Procedure TGISShape.AssignPolygon(const Points: array of TCoordinate);
begin
  Clear;
  FShapeType := stPolygon;
  SetLength(FPoints,1,Length(Points));
  for var Point := low(Points) to high(Points) do
  begin
    FPoints[0,Point] := Points[Point];
    FBoundingBox.Enclose(Points[Point]);
  end;
  // Close polygon
  if (FPoints[0,0].X <> FPoints[0,Length(Points)-1].X)
  or (FPoints[0,0].Y <> FPoints[0,Length(Points)-1].Y) then
  FPoints[0] := FPoints[0] + [FPoints[0,0]];
end;

Procedure TGISShape.AssignPolyPolygon(const Points: TMultiPoints);
begin
  Clear;
  FShapeType := stPolygon;
  SetLength(FPoints,Length(Points));
  for var Part := 0 to PartsCount-1 do
  begin
    SetLength(FPoints[Part],Length(Points[Part]));
    for var Point := 0 to PointsCount(Part)-1 do
    begin
      FPoints[Part,Point] := Points[Part,Point];
      FBoundingBox.Enclose(Points[Part,Point]);
    end;
    // Close polygon
    if (FPoints[0,0].X <> FPoints[0,Length(Points)-1].X)
    or (FPoints[0,0].Y <> FPoints[0,Length(Points)-1].Y) then
    FPoints[Part] := FPoints[Part] + [FPoints[Part,0]];
  end;
end;

Function TGISShape.ShapeType: TShapeType;
begin
  if PartsCount = 0 then Result := stEmpty else Result := FShapeType;
end;

Function TGISShape.Empty: Boolean;
begin
  Result := (PartsCount = 0);
end;

Function TGISShape.PartsCount: Integer;
begin
  Result := Length(FPoints);
end;

Function TGISShape.PointsCount(Part: Integer): Integer;
begin
  Result := Length(FPoints[Part]);
end;

Function TGISShape.DataCount: Integer;
begin
  Result := Length(FData);
end;

Function TGISShape.IndexOf(const Name: string): Integer;
begin
  Result := -1;
  for var Index := 0 to DataCount-1 do
  if SameText(FData[Index].FName,Name) then Exit(Index);
end;

Function TGISShape.Data(Index: Integer): TGISData;
begin
  Result := FData[Index];
end;

Function TGISShape.BoundingBox: TCoordinateRect;
begin
  if Empty then Clear;
  Result := FBoundingBox;
end;

Procedure TGISShape.AddData(const Data: TGISData);
begin
  FData := FData + [Data];
end;

////////////////////////////////////////////////////////////////////////////////

Constructor TShapesReader.Create(const FileName: string);
begin
  inherited Create;
  FFileName := FileName;
end;

end.

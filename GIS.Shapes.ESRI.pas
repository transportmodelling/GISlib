unit GIS.Shapes.ESRI;

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
  Classes,SysUtils,GIS,GIS.Shapes;

Type
  TESRIShapeFile = Class(TShapesReader)
  private
    FileStream: TBufferedFileStream;
    FileReader: TBinaryReader;
    Function Swop(AInt: Integer): Integer;
    Function ReadPoints: TArray<TCoordinate>;
    Function ReadParts: TMultiPoints;
  public
    Constructor Create(const FileName: string); override;
    Function ReadShape(out Shape: TGISShape): Boolean; override;
    Destructor Destroy; override;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Constructor TESRIShapeFile.Create(const FileName: string);
begin
  inherited Create(FileName);
  FileStream := TBufferedFileStream.Create(FileName,fmOpenRead or fmShareDenyWrite);
  FileReader := TBinaryReader.Create(FileStream);
  var FileCode := FileReader.ReadInt32;
  if Swop(FileCode) = 9994 then
    for var Skip := 1 to 24 do FileReader.ReadInt32
  else
    raise exception.Create('Invalid File Code in Shape file header');
end;

Function TESRIShapeFile.Swop(AInt: Integer): Integer;
Var
  B1,B2,B3,B4: Byte;
begin
  B1 := AInt mod 256;
  B2 := (AInt div 256) mod 256;
  B3 := (AInt div 65536) mod 256;
  B4 := (AInt div 16777216) mod 256;
  Result := B4+B3*256+B2*65536+B1*16777216;
end;

Function TESRIShapeFile.ReadPoints: TArray<TCoordinate>;
begin
  // Skip bounding box
  for var Skip := 1 to 4 do FileReader.ReadDouble;
  // Read points
  var NPoints := FileReader.ReadInt32;
  SetLength(Result,NPoints);
  for var Point := 0 to NPoints-1 do
  begin
    Result[Point].X := FileReader.ReadDouble;
    Result[Point].Y := FileReader.ReadDouble;
  end;
end;

Function TESRIShapeFile.ReadParts: TMultiPoints;
Var
  Count: Integer;
  FirstPointInPart: array of Integer;
begin
  // Skip bounding box
  for var Skip := 1 to 4 do FileReader.ReadDouble;
  // Read offsets
  var NParts := FileReader.ReadInt32;
  var NPoints := FileReader.ReadInt32;
  SetLength(FirstPointInPart,NParts);
  for var Part := 0 to NParts-1 do FirstPointInPart[Part] := FileReader.ReadInt32;
  // Read parts
  SetLength(Result,NParts);
  for var Part := 0 to NParts-1 do
  begin
    // Calculate number of points in part
    if Part < NParts-1 then
      Count := FirstPointInPart[Part+1]-FirstPointInPart[Part]
    else
      Count := NPoints-FirstPointInPart[Part];
    // Read points
    SetLength(Result[Part],Count);
    for var Point := 0 to Count-1 do
    begin
      Result[Part,Point].X := FileReader.ReadDouble;
      Result[Part,Point].Y := FileReader.ReadDouble;
    end;
  end;
end;

Function TESRIShapeFile.ReadShape(out Shape: TGISShape): Boolean;
begin
  if FileStream.Position < FileStream.Size then
  begin
    Result := true;
    for var Skip := 1 to 2 do FileReader.ReadInt32;
    // Read shape
    var ShapeType := FileReader.ReadInt32;
    case ShapeType of
      0: // Null shape (proceed to next)
         Result := ReadShape(Shape);
      1: // Point
         Shape.AssignPoint(FileReader.ReadDouble,FileReader.ReadDouble);
      3: // Poly line
         Shape.AssignPolyLine(ReadParts);
      5: // Polygon
         Shape.AssignPolyPolygon(ReadParts);
      8: // Multi point
         Shape.AssignPoints(ReadPoints);
      else raise Exception.Create('Shape type not supported');
    end;
  end else
    Result := false;
end;

Destructor TESRIShapeFile.Destroy;
begin
  FileStream.Free;
  FileReader.Free;
  inherited Destroy;
end;

end.

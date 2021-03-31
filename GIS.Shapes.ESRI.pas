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
  TESRIShapeFileReader = Class(TShapesReader)
  private
    FileStream: TBufferedFileStream;
    FileReader: TBinaryReader;
    Function ReadPoints: TArray<TCoordinate>;
    Function ReadParts: TMultiPoints;
  public
    Constructor Create(const FileName: string); override;
    Function ReadShape(out Shape: TGISShape): Boolean; override;
    Destructor Destroy; override;
  end;

  TESRIShapeFileWriter = record
  private
    Class Procedure WriteFileHeader(const Writer: TBinaryWriter;
                                    const ShapeType,FileSize: Integer;
                                    const [ref] BoundingBox: TCoordinateRect); static;
  public
    Class Procedure WriteShapeFile(FileName: string; const Points: array of TCoordinate); static;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Const
  ShapeFileCode: Integer = 9994;
  Version: Integer = 1000;
  // Shape types
  NullShape = 0;
  PointShape = 1;
  PolyLineShape = 3;
  PolygonShape = 5;
  MultiPointShape = 8;

Function Swop(AInt: Integer): Integer;
Var
  B1,B2,B3,B4: Byte;
begin
  B1 := AInt mod 256;
  B2 := (AInt div 256) mod 256;
  B3 := (AInt div 65536) mod 256;
  B4 := (AInt div 16777216) mod 256;
  Result := B4+B3*256+B2*65536+B1*16777216;
end;

////////////////////////////////////////////////////////////////////////////////

Constructor TESRIShapeFileReader.Create(const FileName: string);
begin
  inherited Create(FileName);
  FileStream := TBufferedFileStream.Create(FileName,fmOpenRead or fmShareDenyWrite);
  FileReader := TBinaryReader.Create(FileStream);
  var FileCode := FileReader.ReadInt32;
  if Swop(FileCode) = ShapeFileCode then
    for var Skip := 1 to 24 do FileReader.ReadInt32
  else
    raise exception.Create('Invalid File Code in Shape file header');
end;

Function TESRIShapeFileReader.ReadPoints: TArray<TCoordinate>;
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

Function TESRIShapeFileReader.ReadParts: TMultiPoints;
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

Function TESRIShapeFileReader.ReadShape(out Shape: TGISShape): Boolean;
begin
  if FileStream.Position < FileStream.Size then
  begin
    Result := true;
    for var Skip := 1 to 2 do FileReader.ReadInt32;
    // Read shape
    var ShapeType := FileReader.ReadInt32;
    case ShapeType of
      NullShape:
         Result := ReadShape(Shape);
      PointShape:
         Shape.AssignPoint(FileReader.ReadDouble,FileReader.ReadDouble);
      PolyLineShape:
         Shape.AssignPolyLine(ReadParts);
      PolygonShape:
         Shape.AssignPolyPolygon(ReadParts);
      MultiPointShape:
         Shape.AssignPoints(ReadPoints);
      else raise Exception.Create('Shape type not supported');
    end;
  end else
    Result := false;
end;

Destructor TESRIShapeFileReader.Destroy;
begin
  FileStream.Free;
  FileReader.Free;
  inherited Destroy;
end;

////////////////////////////////////////////////////////////////////////////////

Class Procedure TESRIShapeFileWriter.WriteFileHeader(const Writer: TBinaryWriter;
                                                     const ShapeType,FileSize: Integer;
                                                     const [ref] BoundingBox: TCoordinateRect);
Const
  Unused: Integer = 0;
  MZCoord: Float64 = 0.0;
begin
  Writer.Write(Swop(ShapeFileCode));
  for var Cnt := 1 to 5 do Writer.Write(Unused);
  Writer.Write(Swop(FileSize));
  Writer.Write(Version);
  Writer.Write(ShapeType);
  Writer.Write(BoundingBox.Left);
  Writer.Write(BoundingBox.Bottom);
  Writer.Write(BoundingBox.Right);
  Writer.Write(BoundingBox.Top);
  for var Cnt := 1 to 4 do Writer.Write(MZCoord);
end;

Class Procedure TESRIShapeFileWriter.WriteShapeFile(FileName: string; const Points: array of TCoordinate);
Const
  ContentLength: Integer = 10;
Var
  BoundingBox: TCoordinateRect;
  ShapesWriter,IndexWriter: TBinaryWriter;
begin
  ShapesWriter := nil;
  IndexWriter := nil;
  try
    var NPoints := Length(Points);
    var ShapeType: Integer := PointShape;
    // Open files
    FileName := ChangeFileExt(FileName,'.shp');
    ShapesWriter := TBinaryWriter.Create(FileName,false);
    FileName := ChangeFileExt(FileName,'.shx');
    IndexWriter := TBinaryWriter.Create(FileName,false);
    // Calculate bounding box
    BoundingBox.Clear;
    BoundingBox.Enclose(Points);
    // Write headers
    WriteFileHeader(ShapesWriter,ShapeType,50+14*NPoints,BoundingBox);
    WriteFileHeader(IndexWriter,ShapeType,50+4*NPoints,BoundingBox);
    // Write points
    for var Point := low(Points) to high(Points) do
    begin
      // Write index file
      IndexWriter.Write(Swop(ShapesWriter.BaseStream.Position div 2));
      IndexWriter.Write(Swop(ContentLength));
      // Write shape file
      ShapesWriter.Write(Swop(Point+1));
      ShapesWriter.Write(Swop(ContentLength));
      ShapesWriter.Write(ShapeType);
      ShapesWriter.Write(Points[Point].X);
      ShapesWriter.Write(Points[Point].Y);
    end;
  finally
    ShapesWriter.Free;
    IndexWriter.Free;
  end;
end;

end.

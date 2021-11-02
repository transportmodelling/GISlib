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

  TESRIShapeFileWriter = Class
  private
    ShapeType,Count: Integer;
    BoundingBox: TCoordinateRect;
    ShapesWriter,IndexWriter: TBinaryWriter;
    Procedure WriteFileHeader(const Writer: TBinaryWriter);
    Procedure WriteMultiPoints(MultiPoints: TMultiPoints);
    Procedure UpdateFileHeader(const Writer: TBinaryWriter);
  public
    Constructor Create(FileName: string);
    Destructor Destroy; override;
  end;

  TESRIPointShapeFileWriter = Class(TESRIShapeFileWriter)
  private
    Const
      ContentLength: Integer = 10;
  public
    Constructor Create(FileName: string);
    Procedure Write(X,Y: Float64); overload;
    Procedure Write(Point: TCoordinate); overload;
  end;

  TESRIMultiPointShapeFileWriter = Class(TESRIShapeFileWriter)
  public
    Constructor Create(FileName: string);
    Procedure Write(MultiPoint: TMultiPoint);
  end;

  TESRIPolyLineShapeFileWriter = Class(TESRIShapeFileWriter)
  public
    Constructor Create(FileName: string);
    Procedure Write(Line: TMultiPoint); overload;
    Procedure Write(PolyLine: TMultiPoints); overload;
  end;

  TESRIPolygonShapeFileWriter = Class(TESRIShapeFileWriter)
  public
    Constructor Create(FileName: string);
    Procedure Write(Polygon: TMultiPoint); overload;
    Procedure Write(Polygons: TMultiPoints); overload;
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

Constructor TESRIShapeFileWriter.Create(FileName: string);
begin
  inherited Create;
  // Initialize bounding box
  BoundingBox.Clear;
  // Open shapes file
  FileName := ChangeFileExt(FileName,'.shp');
  ShapesWriter := TBinaryWriter.Create(FileName,false);
  WriteFileHeader(ShapesWriter);
  // Open index file
  FileName := ChangeFileExt(FileName,'.shx');
  IndexWriter := TBinaryWriter.Create(FileName,false);
  WriteFileHeader(IndexWriter);
end;

Procedure TESRIShapeFileWriter.WriteFileHeader(const Writer: TBinaryWriter);
Const
  Unused: Integer = 0;
  MZCoord: Float64 = 0.0;
begin
  Writer.Write(Swop(ShapeFileCode));
  for var Cnt := 1 to 6 do Writer.Write(Unused);
  Writer.Write(Version);
  Writer.Write(ShapeType);
  Writer.Write(BoundingBox.Left);
  Writer.Write(BoundingBox.Bottom);
  Writer.Write(BoundingBox.Right);
  Writer.Write(BoundingBox.Top);
  for var Cnt := 1 to 4 do Writer.Write(MZCoord);
end;

Procedure TESRIShapeFileWriter.WriteMultiPoints(MultiPoints: TMultiPoints);
Var
  Indices: array of Int32;
  ShapeBoundingBox: TCoordinateRect;
begin
  Inc(Count);
  var NParts: Int32 := Length(MultiPoints);
  // Calculate shape bounding box and set part indices
  var NPoints: Int32 := 0;
  ShapeBoundingBox.Clear;
  SetLength(Indices,NParts);
  for var Part := 0 to NParts-1 do
  begin
    Indices[Part] := NPoints;
    Inc(NPoints,Length(MultiPoints[Part]));
    ShapeBoundingBox.Enclose(MultiPoints[Part]);
  end;
  BoundingBox.Enclose(ShapeBoundingBox);
  // Write index file
  var ContentLength: Int32 := 22+2*NParts+8*NPoints;
  IndexWriter.Write(Swop(ShapesWriter.BaseStream.Position div 2));
  IndexWriter.Write(Swop(ContentLength));
  // Write shape file
  ShapesWriter.Write(Swop(Count));
  ShapesWriter.Write(Swop(ContentLength));
  ShapesWriter.Write(ShapeType);
  ShapesWriter.Write(ShapeBoundingBox.Left);
  ShapesWriter.Write(ShapeBoundingBox.Bottom);
  ShapesWriter.Write(ShapeBoundingBox.Right);
  ShapesWriter.Write(ShapeBoundingBox.Top);
  ShapesWriter.Write(NParts);
  ShapesWriter.Write(NPoints);
  for var Part := 0 to NParts-1 do ShapesWriter.Write(Indices[Part]);
  for var Part := 0 to NParts-1 do
  for var Point := low(MultiPoints[Part]) to high(MultiPoints[Part]) do
  begin
    ShapesWriter.Write(MultiPoints[Part,Point].X);
    ShapesWriter.Write(MultiPoints[Part,Point].Y);
  end;
end;

Procedure TESRIShapeFileWriter.UpdateFileHeader(const Writer: TBinaryWriter);
begin
  // Update file size
  var FileSize: Int32 := Writer.BaseStream.Size div 2;
  Writer.BaseStream.Position := 24;
  Writer.Write(Swop(FileSize));
  // Update bounding box
  Writer.BaseStream.Position := 36;
  Writer.Write(BoundingBox.Left);
  Writer.Write(BoundingBox.Bottom);
  Writer.Write(BoundingBox.Right);
  Writer.Write(BoundingBox.Top);
  // Close file
  Writer.Free;
end;

Destructor TESRIShapeFileWriter.Destroy;
begin
  // Close files
  UpdateFileHeader(ShapesWriter);
  UpdateFileHeader(IndexWriter);
  inherited Destroy;
end;

////////////////////////////////////////////////////////////////////////////////

Constructor TESRIPointShapeFileWriter.Create(FileName: string);
begin
  ShapeType := PointShape;
  inherited Create(FileName);
end;

Procedure TESRIPointShapeFileWriter.Write(X,Y: Float64);
begin
  Write(TCoordinate.Create(X,Y));
end;

Procedure TESRIPointShapeFileWriter.Write(Point: TCoordinate);
begin
  Inc(Count);
  BoundingBox.Enclose(Point);
  // Write index file
  IndexWriter.Write(Swop(ShapesWriter.BaseStream.Position div 2));
  IndexWriter.Write(Swop(ContentLength));
  // Write shape file
  ShapesWriter.Write(Swop(Count));
  ShapesWriter.Write(Swop(ContentLength));
  ShapesWriter.Write(ShapeType);
  ShapesWriter.Write(Point.X);
  ShapesWriter.Write(Point.Y);
end;

////////////////////////////////////////////////////////////////////////////////

Constructor TESRIMultiPointShapeFileWriter.Create(FileName: string);
begin
  ShapeType := MultiPointShape;
  inherited Create(FileName);
end;

Procedure TESRIMultiPointShapeFileWriter.Write(MultiPoint: TMultiPoint);
Var
  ShapeBoundingBox: TCoordinateRect;
begin
  Inc(Count);
  // Calculate content length
  var NPoints: Int32 := Length(MultiPoint);
  var ContentLength: Int32 := 20+8*NPoints;
  // Calculate bounding box
  ShapeBoundingBox.Clear;
  for var Point := 0 to NPoints-1 do ShapeBoundingBox.Enclose(MultiPoint[Point]);
  BoundingBox.Enclose(ShapeBoundingBox);
  // Write index file
  IndexWriter.Write(Swop(ShapesWriter.BaseStream.Position div 2));
  IndexWriter.Write(Swop(ContentLength));
  // Write shape file
  ShapesWriter.Write(Swop(Count));
  ShapesWriter.Write(Swop(ContentLength));
  ShapesWriter.Write(ShapeType);
  ShapesWriter.Write(ShapeBoundingBox.Left);
  ShapesWriter.Write(ShapeBoundingBox.Bottom);
  ShapesWriter.Write(ShapeBoundingBox.Right);
  ShapesWriter.Write(ShapeBoundingBox.Top);
  ShapesWriter.Write(NPoints);
  for var Point := 0 to NPoints-1 do
  begin
    ShapesWriter.Write(MultiPoint[Point].X);
    ShapesWriter.Write(MultiPoint[Point].Y);
  end;
end;

////////////////////////////////////////////////////////////////////////////////

Constructor TESRIPolyLineShapeFileWriter.Create(FileName: string);
begin
  ShapeType := PolyLineShape;
  inherited Create(FileName);
end;

Procedure TESRIPolyLineShapeFileWriter.Write(Line: TMultiPoint);
begin
  WriteMultiPoints([Line]);
end;

Procedure TESRIPolyLineShapeFileWriter.Write(PolyLine: TMultiPoints);
begin
  WriteMultiPoints(PolyLine);
end;

////////////////////////////////////////////////////////////////////////////////

Constructor TESRIPolygonShapeFileWriter.Create(FileName: string);
begin
  ShapeType := PolygonShape;
  inherited Create(FileName);
end;

Procedure TESRIPolygonShapeFileWriter.Write(Polygon: TMultiPoint);
begin
  Write([Polygon]);
end;

Procedure TESRIPolygonShapeFileWriter.Write(Polygons: TMultiPoints);
begin
  // Close polygons
  for var Part := low(Polygons) to high(Polygons) do
  begin
    var NPoints := Length(Polygons[Part]);
    if NPoints > 1 then
      if (Polygons[Part,0].X <> Polygons[Part,NPoints-1].X)
      or (Polygons[Part,0].Y <> Polygons[Part,NPoints-1].Y) then
      Polygons[Part] := Polygons[Part] + [Polygons[Part,0]]
    else
      raise Exception.Create('Invalid polygon');
  end;
  // Write polygons
  WriteMultiPoints(Polygons);
end;

end.

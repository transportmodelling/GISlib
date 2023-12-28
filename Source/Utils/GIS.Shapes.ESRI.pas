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
  Classes,SysUtils,Generics.Collections,DBF,GIS,GIS.Shapes;

Type
  TESRIShapeFileReader = Class(TGISShapesReader)
  private
    ShapesStream: TBufferedFileStream;
    ShapesReader: TBinaryReader;
    DBFReader: TDBFReader;
    Function ReadPoints: TArray<TCoordinate>;
    Function ReadParts: TMultiPoints;
  public
    Constructor Create(FileName: string); overload; override;
    Constructor Create(FileName: string; ReadProperties: Boolean); overload;
    Function IndexOf(const PropertyName: String; const MustExist: Boolean = false): Integer;
    Function ReadShape(out Shape: TGISShape; out Properties: TGISShapeProperties): Boolean; override;
    Destructor Destroy; override;
  end;

  TESRIShapeFileWriter = Class
  private
    ShapeType,Count: Integer;
    BoundingBox: TCoordinateRect;
    ShapesWriter,IndexWriter: TBinaryWriter;
    DBFWriter: TDBFWriter;
    Procedure WriteFileHeader(const Writer: TBinaryWriter);
    Procedure WriteMultiPoints(MultiPoints: TMultiPoints);
    Procedure UpdateFileHeader(const Writer: TBinaryWriter);
    Procedure WriteProperties(const Properties: array of Variant);
  public
    Constructor Create(FileName: string; const Properties: array of TDBFField);
    Destructor Destroy; override;
  end;

  TESRIPointShapeFileWriter = Class(TESRIShapeFileWriter)
  private
    Const
      ContentLength: Integer = 10;
  public
    Constructor Create(FileName: string; const Properties: array of TDBFField);
    Procedure Write(X,Y: Float64; const Properties: array of Variant); overload;
    Procedure Write(Point: TCoordinate; const Properties: array of Variant); overload;
  end;

  TESRIMultiPointShapeFileWriter = Class(TESRIShapeFileWriter)
  public
    Constructor Create(FileName: string; const Properties: array of TDBFField);
    Procedure Write(MultiPoint: TMultiPoint; const Properties: array of Variant);
  end;

  TESRIPolyLineShapeFileWriter = Class(TESRIShapeFileWriter)
  public
    Constructor Create(FileName: string; const Properties: array of TDBFField);
    Procedure Write(Line: TMultiPoint; const Properties: array of Variant); overload;
    Procedure Write(PolyLine: TMultiPoints; const Properties: array of Variant); overload;
  end;

  TESRIPolygonShapeFileWriter = Class(TESRIShapeFileWriter)
  public
    Constructor Create(FileName: string; const Properties: array of TDBFField);
    Procedure Write(Polygon: TMultiPoint; const Properties: array of Variant); overload;
    Procedure Write(Polygons: TMultiPoints; const Properties: array of Variant); overload;
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

Constructor TESRIShapeFileReader.Create(FileName: string);
begin
  Create(FileName,true);
end;

Constructor TESRIShapeFileReader.Create(FileName: string; ReadProperties: Boolean);
begin
  inherited Create(FileName);
  // Open shapes file
  FileName := ChangeFileExt(FileName,'.shp');
  ShapesStream := TBufferedFileStream.Create(FileName,fmOpenRead or fmShareDenyWrite);
  ShapesReader := TBinaryReader.Create(ShapesStream);
  var FileCode := ShapesReader.ReadInt32;
  if Swop(FileCode) = ShapeFileCode then
    for var Skip := 1 to 24 do ShapesReader.ReadInt32
  else
    raise exception.Create('Invalid File Code in Shape file header');
  // Open DBF-file
  if ReadProperties then
  begin
    FileName := ChangeFileExt(FileName,'.dbf');
    if FileExists(FileName) then DBFReader := TDBFReader.Create(FileName);
  end;
end;

Function TESRIShapeFileReader.IndexOf(const PropertyName: String; const MustExist: Boolean = false): Integer;
begin
  if DBFReader <> nil then
    Result := DBFReader.IndexOf(PropertyName,MustExist)
  else
    begin
      Result := -1;
      if MustExist then raise Exception.Create('dbf file is not read');
    end;
end;

Function TESRIShapeFileReader.ReadPoints: TArray<TCoordinate>;
begin
  // Skip bounding box
  for var Skip := 1 to 4 do ShapesReader.ReadDouble;
  // Read points
  var NPoints := ShapesReader.ReadInt32;
  SetLength(Result,NPoints);
  for var Point := 0 to NPoints-1 do
  begin
    Result[Point].X := ShapesReader.ReadDouble;
    Result[Point].Y := ShapesReader.ReadDouble;
  end;
end;

Function TESRIShapeFileReader.ReadParts: TMultiPoints;
Var
  Count: Integer;
  FirstPointInPart: array of Integer;
begin
  // Skip bounding box
  for var Skip := 1 to 4 do ShapesReader.ReadDouble;
  // Read offsets
  var NParts := ShapesReader.ReadInt32;
  var NPoints := ShapesReader.ReadInt32;
  SetLength(FirstPointInPart,NParts);
  for var Part := 0 to NParts-1 do FirstPointInPart[Part] := ShapesReader.ReadInt32;
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
      Result[Part,Point].X := ShapesReader.ReadDouble;
      Result[Part,Point].Y := ShapesReader.ReadDouble;
    end;
  end;
end;

Function TESRIShapeFileReader.ReadShape(out Shape: TGISShape; out Properties: TGISShapeProperties): Boolean;
begin
  if ShapesStream.Position < ShapesStream.Size then
  begin
    Result := true;
    for var Skip := 1 to 2 do ShapesReader.ReadInt32;
    // Read shape
    var ShapeType := ShapesReader.ReadInt32;
    case ShapeType of
      NullShape:
         Result := ReadShape(Shape);
      PointShape:
         Shape.AssignPoint(ShapesReader.ReadDouble,ShapesReader.ReadDouble);
      PolyLineShape:
         Shape.AssignPolyLine(ReadParts);
      PolygonShape:
         Shape.AssignPolyPolygon(ReadParts);
      MultiPointShape:
         Shape.AssignPoints(ReadPoints);
      else raise Exception.Create('Shape type not supported');
    end;
    // Read properties
    if DBFReader <> nil then
      if DBFReader.NextRecord then
        Properties := DBFReader.GetPairs
      else
        raise Exception.Create('Error reading properties')
    else
      Properties := []
  end else
    Result := false;
end;

Destructor TESRIShapeFileReader.Destroy;
begin
  ShapesStream.Free;
  ShapesReader.Free;
  DBFReader.Free;
  inherited Destroy;
end;

////////////////////////////////////////////////////////////////////////////////

Constructor TESRIShapeFileWriter.Create(FileName: string; const Properties: array of TDBFField);
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
  // Open DBF file
  if Length(Properties) > 0 then
  begin
    FileName := ChangeFileExt(FileName,'.dbf');
    DBFWriter := TDBFWriter.Create(FileName,Properties);
  end;
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

Procedure TESRIShapeFileWriter.WriteProperties(const Properties: array of Variant);
begin
  if DBFWriter <> nil then
    DBFWriter.AppendRecord(Properties)
  else
    if Length(Properties) > 0 then raise Exception.Create('Invalid number of propertries');
end;

Destructor TESRIShapeFileWriter.Destroy;
begin
  // Close files
  if ShapesWriter <> nil then UpdateFileHeader(ShapesWriter);
  if IndexWriter <> nil then UpdateFileHeader(IndexWriter);
  DBFWriter.Free;
  inherited Destroy;
end;

////////////////////////////////////////////////////////////////////////////////

Constructor TESRIPointShapeFileWriter.Create(FileName: string; const Properties: array of TDBFField);
begin
  ShapeType := PointShape;
  inherited Create(FileName,Properties);
end;

Procedure TESRIPointShapeFileWriter.Write(X,Y: Float64; const Properties: array of Variant);
begin
  Write(TCoordinate.Create(X,Y),Properties);
end;

Procedure TESRIPointShapeFileWriter.Write(Point: TCoordinate; const Properties: array of Variant);
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
  // Write properties
  WriteProperties(Properties);
end;

////////////////////////////////////////////////////////////////////////////////

Constructor TESRIMultiPointShapeFileWriter.Create(FileName: string; const Properties: array of TDBFField);
begin
  ShapeType := MultiPointShape;
  inherited Create(FileName,Properties);
end;

Procedure TESRIMultiPointShapeFileWriter.Write(MultiPoint: TMultiPoint; const Properties: array of Variant);
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
  // Write properties
  WriteProperties(Properties);
end;

////////////////////////////////////////////////////////////////////////////////

Constructor TESRIPolyLineShapeFileWriter.Create(FileName: string; const Properties: array of TDBFField);
begin
  ShapeType := PolyLineShape;
  inherited Create(FileName,Properties);
end;

Procedure TESRIPolyLineShapeFileWriter.Write(Line: TMultiPoint; const Properties: array of Variant);
begin
  WriteMultiPoints([Line]);
  WriteProperties(Properties);
end;

Procedure TESRIPolyLineShapeFileWriter.Write(PolyLine: TMultiPoints; const Properties: array of Variant);
begin
  WriteMultiPoints(PolyLine);
  WriteProperties(Properties);
end;

////////////////////////////////////////////////////////////////////////////////

Constructor TESRIPolygonShapeFileWriter.Create(FileName: string; const Properties: array of TDBFField);
begin
  ShapeType := PolygonShape;
  inherited Create(FileName,Properties);
end;

Procedure TESRIPolygonShapeFileWriter.Write(Polygon: TMultiPoint; const Properties: array of Variant);
begin
  Write([Polygon],Properties);
end;

Procedure TESRIPolygonShapeFileWriter.Write(Polygons: TMultiPoints; const Properties: array of Variant);
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
  // Write properties
  WriteProperties(Properties);
end;

end.

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
  Classes, SysUtils, IOUtils, Generics.Collections, DBF, GIS, GIS.Shapes, GIS.Shapes.Polygon;

Type
  TESRIShapeFileReader = Class(TGISShapesReader)
  private
    ShapesStream: TBufferedFileStream;
    ShapesReader: TBinaryReader;
    DBFReader: TDBFReader;
    DBFEncoding: TEncoding;
    Function CpgEncoding(const FileName: String): TEncoding;
    Function ReadPoints: TArray<TCoordinate>;
    Function ReadParts: TMultiPoints;
  public
    // The properties are read in the encoding a .cpg file next to the
    // shapefile names; without one, the dbf reader works it out
    Constructor Create(const FileName: TFileName); overload; override;
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
    Procedure WriteBoundingBox(const Writer: TBinaryWriter; const Box: TCoordinateRect);
    Procedure WriteRecordHeader(ContentLength: Int32);
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
  // Outer rings are written clockwise and holes counter-clockwise, each outer ring with its holes
  // after it, as the format requires, whatever direction and order they are given in
  private
    // The points of the ring in the direction asked for
    Function Oriented(const Ring: TShapePart; const Clockwise: Boolean): TMultiPoint;
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

Function SwapBytes(AInt: Integer): Integer;
// Reverses the byte order, converting between the big-endian integers of
// the shape file format and the native little-endian integers. Unsigned
// bit operations keep the function free of traps in overflow checked builds.
begin
  var Bytes := Cardinal(AInt);
  Result := Integer((Bytes shr 24) or ((Bytes shr 8) and $0000FF00) or
                    ((Bytes shl 8) and $00FF0000) or (Bytes shl 24));
end;

////////////////////////////////////////////////////////////////////////////////

Constructor TESRIShapeFileReader.Create(const FileName: TFileName);
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
  if SwapBytes(FileCode) = ShapeFileCode then
    for var Skip := 1 to 24 do ShapesReader.ReadInt32
  else
    raise exception.Create('Invalid File Code in Shape file header');
  // Open DBF-file
  if ReadProperties then
  begin
    FileName := ChangeFileExt(FileName,'.dbf');
    if FileExists(FileName) then
    begin
      DBFEncoding := CpgEncoding(ChangeFileExt(FileName,'.cpg'));
      DBFReader := TDBFReader.Create(FileName,DBFEncoding);
    end;
  end;
end;

Function TESRIShapeFileReader.CpgEncoding(const FileName: String): TEncoding;
// The encoding a .cpg file names: UTF-8, ISO 8859-n, or a name ending in the
// code page number ('1252', 'ANSI 1252', 'CP1252', 'Windows-1252'). nil when
// there is no .cpg file, or it names no code page this system has. The
// caller owns the result.
begin
  Result := nil;
  if FileExists(FileName) then
  begin
    var Name := UpperCase(Trim(TFile.ReadAllText(FileName)));
    var CodePage := 0;
    if (Name = 'UTF-8') or (Name = 'UTF8') then CodePage := 65001 else
    begin
      var ISO := Pos('8859',Name);
      if ISO > 0 then Name := Copy(Name,ISO+4,MaxInt);
      var Digits := '';
      for var Chr := Length(Name) downto 1 do
      if CharInSet(Name[Chr],['0'..'9']) then Digits := Name[Chr] + Digits else Break;
      if (Digits <> '') and TryStrToInt(Digits,CodePage) then
      begin
        if ISO > 0 then CodePage := 28590 + CodePage; // ISO 8859-n is code page 2859n
      end else
        CodePage := 0;
    end;
    if CodePage <> 0 then
    try
      Result := TEncoding.GetEncoding(CodePage);
    except
      // A code page this system does not have: leave it to the dbf reader
      on EEncodingError do Result := nil;
    end;
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
  DBFEncoding.Free;  // after the reader that uses it
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
  Writer.Write(SwapBytes(ShapeFileCode));
  for var Cnt := 1 to 6 do Writer.Write(Unused);
  Writer.Write(Version);
  Writer.Write(ShapeType);
  WriteBoundingBox(Writer,BoundingBox);
  for var Cnt := 1 to 4 do Writer.Write(MZCoord);
end;

Procedure TESRIShapeFileWriter.WriteBoundingBox(const Writer: TBinaryWriter; const Box: TCoordinateRect);
begin
  Writer.Write(Box.Left);
  Writer.Write(Box.Bottom);
  Writer.Write(Box.Right);
  Writer.Write(Box.Top);
end;

Procedure TESRIShapeFileWriter.WriteRecordHeader(ContentLength: Int32);
// Writes the index file entry and the record header in the shape file
begin
  IndexWriter.Write(SwapBytes(ShapesWriter.BaseStream.Position div 2));
  IndexWriter.Write(SwapBytes(ContentLength));
  ShapesWriter.Write(SwapBytes(Count));
  ShapesWriter.Write(SwapBytes(ContentLength));
  ShapesWriter.Write(ShapeType);
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
  // Write shape record
  WriteRecordHeader(22+2*NParts+8*NPoints);
  WriteBoundingBox(ShapesWriter,ShapeBoundingBox);
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
  Writer.Write(SwapBytes(FileSize));
  // Update bounding box
  Writer.BaseStream.Position := 36;
  WriteBoundingBox(Writer,BoundingBox);
  // Close file
  Writer.Free;
end;

Procedure TESRIShapeFileWriter.WriteProperties(const Properties: array of Variant);
begin
  if DBFWriter <> nil then
    DBFWriter.AppendRecord(Properties)
  else
    if Length(Properties) > 0 then raise Exception.Create('Invalid number of properties');
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
  // Write shape record
  WriteRecordHeader(ContentLength);
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
  // Write shape record
  WriteRecordHeader(ContentLength);
  WriteBoundingBox(ShapesWriter,ShapeBoundingBox);
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

Function TESRIPolygonShapeFileWriter.Oriented(const Ring: TShapePart; const Clockwise: Boolean): TMultiPoint;
// Twice the signed area of a closed ring is positive when it runs counter-clockwise
begin
  Result := Ring.AsMultiPoint;
  var Area := 0.0;
  for var Point := 1 to high(Result) do
  Area := Area + Result[Point-1].X*Result[Point].Y - Result[Point].X*Result[Point-1].Y;
  if (Area < 0) <> Clockwise then
  for var Point := 0 to (Length(Result) div 2)-1 do
  begin
    var Swap := Result[Point];
    Result[Point] := Result[high(Result)-Point];
    Result[high(Result)-Point] := Swap;
  end;
end;

Procedure TESRIPolygonShapeFileWriter.Write(Polygon: TMultiPoint; const Properties: array of Variant);
begin
  Write([Polygon],Properties);
end;

Procedure TESRIPolygonShapeFileWriter.Write(Polygons: TMultiPoints; const Properties: array of Variant);
Var
  Shape: TGISShape;
  Rings: TMultiPoints;
begin
  // Close the rings that are not closed yet; a ring takes at least two points
  SetLength(Rings,Length(Polygons));
  for var Part := low(Polygons) to high(Polygons) do
  begin
    var NPoints := Length(Polygons[Part]);
    if NPoints > 1 then
    begin
      Rings[Part] := Polygons[Part];
      if (Polygons[Part,0].X <> Polygons[Part,NPoints-1].X)
      or (Polygons[Part,0].Y <> Polygons[Part,NPoints-1].Y) then
      Rings[Part] := Rings[Part] + [Polygons[Part,0]];
    end else
      raise Exception.Create('Invalid polygon')
  end;
  // The format tells outer rings from holes by their direction: outer rings run clockwise and
  // holes counter-clockwise. Each outer ring is written with its holes after it.
  Shape.AssignPolyPolygon(Rings);
  var PolyPolygons := TPolyPolygons.Create(Shape);
  Rings := [];
  for var Polygon := 0 to PolyPolygons.Count-1 do
  begin
    Rings := Rings + [Oriented(PolyPolygons[Polygon].OuterRing,true)];
    for var Hole := 0 to PolyPolygons[Polygon].HolesCount-1 do
    Rings := Rings + [Oriented(PolyPolygons[Polygon].Holes[Hole],false)];
  end;
  // Write polygons
  WriteMultiPoints(Rings);
  // Write properties
  WriteProperties(Properties);
end;

end.

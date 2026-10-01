unit Test.Geopackage;

////////////////////////////////////////////////////////////////////////////////
//
// Author: Jaap Baak
// https://github.com/transportmodelling/GISlib
//
// Test suite generated with assistance from Claude Sonnet 4.6
//
// Tests for TGeopackage, TGeopackageReader and TGeopackageWriter.
// Reader tests require Data\Provincies.gpkg.
// Writer tests are self-contained (use a temp file).
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
interface
////////////////////////////////////////////////////////////////////////////////

uses
  System.SysUtils, System.Generics.Collections, DUnitX.TestFramework, GIS, GIS.Shapes,
  GIS.Shapes.ESRI, GIS.Shapes.Geopackage, GIS.CoordConv.WGS84;

const
  GpkgLayerName = 'Provincies';

type
  [TestFixture]
  TGeopackageTests = class
  private
    Function DataPath: String;
    Function GpkgFile: String;
    Procedure CheckFileExists;
    Function  TempFile: String;
    Procedure DeleteTempFile;
    // The first value the query yields on the temp file
    Function QueryValue(const SQL: String): Variant;
    // The geometry blob a layer writer stores for a shape
    Function WrittenGeometry(const Shape: TGISShape): TBytes;
    Function Int32At(const Bytes: TBytes; const Position: Integer): Int32;
    Function DoubleAt(const Bytes: TBytes; const Position: Integer): Double;
    // Writes Count points to a layer of the temp file
    Procedure WritePoints(const Count: Integer);
  public
    // Reader tests
    [Test] Procedure LayerNames_ContainsExpectedLayer;
    [Test] Procedure LayerNames_ReturnsNonEmptyList;
    [Test] Procedure Reader_ReadsTheTwelveProvinces;
    [Test] Procedure Reader_AllShapesArePolygons;
    [Test] Procedure Reader_BoundingBoxWithinNetherlandsDutchGrid;
    [Test] Procedure Reader_ShapeCountMatchesShapefile;
    [Test] Procedure Reader_SRID_MatchesStoredValue;

    // Writer tests (no external data file needed)
    [Test] Procedure Writer_CreatesFile;
    [Test] Procedure Writer_LayerAppearsInLayerNames;
    [Test] Procedure Writer_RoundTrip_Point;
    [Test] Procedure Writer_RoundTrip_Polygon;
    [Test] Procedure Writer_RoundTrip_ShapeCount;
    [Test] Procedure Writer_RoundTrip_ProvincesShapefile;
    [Test] Procedure Writer_ConverterOverload_StoresCorrectSRS;
    [Test] Procedure Writer_RoundTrip_SRID;
    [Test] Procedure Writer_TwoOuterRings_WritesMultiPolygon;
    [Test] Procedure Writer_HoleListedFirst_WritesOuterRingFirst;
    [Test] Procedure Writer_NamesNeedingQuotes_RoundTrip;
    [Test] Procedure Writer_ManyShapes_AllReadBack;
    [Test] Procedure Writer_NewFile_IdentifiesItselfAsGeoPackage;
    [Test] Procedure Writer_StoresTheLayerBounds;
    [Test] Procedure Writer_ConverterOverload_WritesProperties;
    [Test] Procedure Writer_PropertiesNamedLikeItsColumns_AreKept;
  end;

  // The reader on geometry blobs the writer does not produce, built by hand, and on errors
  [TestFixture]
  TGeopackageReaderTests = class
  private
    FFile: String;
    // Bytes of the numbers in either byte order
    Function LE32(const Value: Int32): TBytes;
    Function LEF64(const Value: Double): TBytes;
    Function BE32(const Value: Int32): TBytes;
    Function BEF64(const Value: Double): TBytes;
    // The GeoPackage header of a blob: magic, version, flags and SRID 4326
    Function Header(const Flags: Byte): TBytes;
    // A point in WKB, little-endian
    Function Point(const X, Y: Double): TBytes;
    // Inserts a row with the blob, or a NULL geometry for no bytes, into the one layer of the file
    Procedure InsertRow(const Blob: TBytes; const Name: String);
    // Reads all shapes of the layer with their names
    Procedure ReadAll(out Shapes: TArray<TGISShape>; out Names: TArray<String>);
  public
    [Setup]    Procedure Setup;
    [TearDown] Procedure TearDown;
    [Test] Procedure PointZ_DropsZ;
    [Test] Procedure PointZM_DropsZAndM;
    [Test] Procedure BigEndian_IsRead;
    [Test] Procedure Envelope_IsSkipped;
    [Test] Procedure NullGeometry_IsSkipped;
    [Test] Procedure EmptyGeometry_IsSkipped;
    [Test] Procedure MultiPoint_IsOneShapePerPoint_SharingTheProperties;
    [Test] Procedure MultiLineString_RoundTrip_IsOneShapeWithAPartPerLine;
    [Test] Procedure MultiPolygon_RoundTrip_IsOneShapeWithAllRings;
    [Test] Procedure MissingLayer_Raises;
    [Test] Procedure CreateWriter_OnAReadOnlyPackage_Raises;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

uses
  System.Classes, System.IOUtils, Data.DB, FireDAC.Comp.Client;

Function TGeopackageTests.DataPath: String;
begin
  Result := ExpandFileName(ExtractFilePath(ParamStr(0)) + '..\Data\');
end;

Function TGeopackageTests.GpkgFile: String;
begin
  Result := DataPath + 'Provincies.gpkg';
end;

Procedure TGeopackageTests.CheckFileExists;
begin
  Assert.IsTrue(FileExists(GpkgFile),
    'Test requires Data\Provincies.gpkg - create it with: ' +
    'ogr2ogr -f GPKG Data/Provincies.gpkg Data/Provincies_dutch_grid.shp');
end;

Procedure TGeopackageTests.LayerNames_ReturnsNonEmptyList;
var
  Pkg: TGeopackage;
begin
  CheckFileExists;
  Pkg := TGeopackage.Create(GpkgFile);
  try
    Assert.IsTrue(Length(Pkg.LayerNames) > 0, 'GeoPackage should contain at least one feature layer');
  finally
    Pkg.Free;
  end;
end;

Procedure TGeopackageTests.LayerNames_ContainsExpectedLayer;
var
  Pkg: TGeopackage;
  Names: TArray<String>;
  Found: Boolean;
begin
  CheckFileExists;
  Pkg := TGeopackage.Create(GpkgFile);
  try
    Names := Pkg.LayerNames;
    Found := False;
    for var N in Names do
      if SameText(N, GpkgLayerName) then
      begin
        Found := True;
        Break;
      end;
    Assert.IsTrue(Found, 'Expected layer ''' + GpkgLayerName + ''' not found in GeoPackage');
  finally
    Pkg.Free;
  end;
end;

Procedure TGeopackageTests.Reader_ReadsTheTwelveProvinces;
var
  Pkg: TGeopackage;
  Reader: TGeopackageReader;
  Shape: TGISShape;
  Props: TGISShapeProperties;
  Count: Integer;
begin
  CheckFileExists;
  Pkg := TGeopackage.Create(GpkgFile);
  try
    Reader := Pkg.CreateReader(GpkgLayerName);
    try
      Count := 0;
      while Reader.ReadShape(Shape, Props) do
        Inc(Count);
      Assert.AreEqual(12, Count, 'The twelve provinces');
    finally
      Reader.Free;
    end;
  finally
    Pkg.Free;
  end;
end;

Procedure TGeopackageTests.Reader_AllShapesArePolygons;
var
  Pkg: TGeopackage;
  Reader: TGeopackageReader;
  Shape: TGISShape;
  Props: TGISShapeProperties;
  Count: Integer;
begin
  CheckFileExists;
  Pkg := TGeopackage.Create(GpkgFile);
  try
    Reader := Pkg.CreateReader(GpkgLayerName);
    try
      Count := 0;
      while Reader.ReadShape(Shape, Props) do
      begin
        Assert.AreEqual(Ord(stPolygon), Ord(Shape.ShapeType), 'Expected polygon shape type');
        Inc(Count);
      end;
      Assert.AreEqual(12, Count, 'The twelve provinces');
    finally
      Reader.Free;
    end;
  finally
    Pkg.Free;
  end;
end;

Procedure TGeopackageTests.Reader_BoundingBoxWithinNetherlandsDutchGrid;
var
  Pkg: TGeopackage;
  Reader: TGeopackageReader;
  Shape: TGISShape;
  Props: TGISShapeProperties;
  BB: TCoordinateRect;
begin
  CheckFileExists;
  BB.Clear;
  Pkg := TGeopackage.Create(GpkgFile);
  try
    Reader := Pkg.CreateReader(GpkgLayerName);
    try
      while Reader.ReadShape(Shape, Props) do
        BB.Enclose(Shape.BoundingBox);
    finally
      Reader.Free;
    end;
  finally
    Pkg.Free;
  end;
  Assert.IsFalse(BB.Empty, 'Bounding box should not be empty');
  // Netherlands Dutch Grid: X 7000-300000, Y 289000-629000
  Assert.IsTrue(BB.Left   >   7000, 'Left bound');
  Assert.IsTrue(BB.Right  < 300000, 'Right bound');
  Assert.IsTrue(BB.Bottom > 289000, 'Bottom bound');
  Assert.IsTrue(BB.Top    < 629000, 'Top bound');
end;

Procedure TGeopackageTests.Reader_ShapeCountMatchesShapefile;
var
  Pkg: TGeopackage;
  Reader: TGeopackageReader;
  Shape: TGISShape;
  Props: TGISShapeProperties;
  GpkgCount: Integer;
  ShpReader: GIS.Shapes.ESRI.TESRIShapeFileReader;
  ShpCount: Integer;
begin
  CheckFileExists;
  // Count shapes from GeoPackage
  GpkgCount := 0;
  Pkg := TGeopackage.Create(GpkgFile);
  try
    Reader := Pkg.CreateReader(GpkgLayerName);
    try
      while Reader.ReadShape(Shape, Props) do
        Inc(GpkgCount);
    finally
      Reader.Free;
    end;
  finally
    Pkg.Free;
  end;
  // Count shapes from the source shapefile
  ShpCount := 0;
  ShpReader := GIS.Shapes.ESRI.TESRIShapeFileReader.Create(
    DataPath + 'Provincies_dutch_grid.shp');
  try
    while ShpReader.ReadShape(Shape, Props) do
      Inc(ShpCount);
  finally
    ShpReader.Free;
  end;
  Assert.AreEqual(ShpCount, GpkgCount,
    'GeoPackage and shapefile should contain the same number of shapes');
end;

Procedure TGeopackageTests.Reader_SRID_MatchesStoredValue;
// Data\Provincies.gpkg was built with ogr2ogr from a shapefile with no .prj
// sidecar, so GDAL stamped its "Undefined SRS" placeholder (srs_id 99999) on
// the layer rather than a real EPSG code.
var
  Pkg: TGeopackage;
  Reader: TGeopackageReader;
begin
  CheckFileExists;
  Pkg := TGeopackage.Create(GpkgFile);
  try
    Reader := Pkg.CreateReader(GpkgLayerName);
    try
      Assert.AreEqual(99999, Reader.SRID, 'Provincies.gpkg layer should carry GDAL''s "Undefined SRS" placeholder');
    finally
      Reader.Free;
    end;
  finally
    Pkg.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
// Writer helpers
////////////////////////////////////////////////////////////////////////////////

Function TGeopackageTests.TempFile: String;
begin
  Result := TPath.GetTempPath + 'TestGeopackage_tmp.gpkg';
end;

Procedure TGeopackageTests.DeleteTempFile;
begin
  if FileExists(TempFile) then
    DeleteFile(TempFile);
end;

////////////////////////////////////////////////////////////////////////////////
// Writer tests
////////////////////////////////////////////////////////////////////////////////

Function TGeopackageTests.QueryValue(const SQL: String): Variant;
begin
  var Pkg := TGeopackage.Create(TempFile);
  try
    var Q := TFDQuery.Create(nil);
    try
      Q.Connection := Pkg.Connection;
      Q.SQL.Text := SQL;
      Q.Open;
      Result := Q.Fields[0].Value;
    finally
      Q.Free;
    end;
  finally
    Pkg.Free;
  end;
end;

Function TGeopackageTests.WrittenGeometry(const Shape: TGISShape): TBytes;
begin
  DeleteTempFile;
  var Pkg := TGeopackage.Create(TempFile, gpReadWrite);
  try
    var Writer := Pkg.CreateWriter;
    try
      var LW := Writer.CreateLayerWriter('polys', 4326);
      try
        LW.WriteShape(Shape, nil);
      finally
        LW.Free;
      end;
    finally
      Writer.Free;
    end;
  finally
    Pkg.Free;
  end;
  Pkg := TGeopackage.Create(TempFile);
  try
    var Q := TFDQuery.Create(nil);
    try
      Q.Connection := Pkg.Connection;
      Q.SQL.Text := 'SELECT CAST(geom AS BLOB) FROM polys';
      Q.Open;
      Result := Q.Fields[0].AsBytes;
    finally
      Q.Free;
    end;
  finally
    Pkg.Free;
  end;
  DeleteTempFile;
end;

Function TGeopackageTests.Int32At(const Bytes: TBytes; const Position: Integer): Int32;
begin
  Move(Bytes[Position], Result, SizeOf(Result));
end;

Function TGeopackageTests.DoubleAt(const Bytes: TBytes; const Position: Integer): Double;
begin
  Move(Bytes[Position], Result, SizeOf(Result));
end;

Procedure TGeopackageTests.WritePoints(const Count: Integer);
var
  Shape: TGISShape;
begin
  DeleteTempFile;
  var Pkg := TGeopackage.Create(TempFile, gpReadWrite);
  try
    var Writer := Pkg.CreateWriter;
    try
      var LW := Writer.CreateLayerWriter('points', 4326);
      try
        for var Point := 1 to Count do
        begin
          Shape.AssignPoint(Point, Point);
          LW.WriteShape(Shape, nil);
        end;
      finally
        LW.Free;
      end;
    finally
      Writer.Free;
    end;
  finally
    Pkg.Free;
  end;
end;

Procedure TGeopackageTests.Writer_CreatesFile;
begin
  DeleteTempFile;
  var Pkg := TGeopackage.Create(TempFile, gpReadWrite);
  try
    var Writer := Pkg.CreateWriter;
    Writer.Free;
  finally
    Pkg.Free;
  end;
  Assert.IsTrue(FileExists(TempFile), 'GeoPackage file should have been created');
  DeleteTempFile;
end;

Procedure TGeopackageTests.Writer_LayerAppearsInLayerNames;
begin
  DeleteTempFile;
  var Pkg := TGeopackage.Create(TempFile, gpReadWrite);
  try
    var Writer := Pkg.CreateWriter;
    try
      Writer.CreateLayerWriter('testlayer', 4326).Free;
    finally
      Writer.Free;
    end;
  finally
    Pkg.Free;
  end;
  // Re-open read-only and check layer names
  Pkg := TGeopackage.Create(TempFile);
  try
    var Names := Pkg.LayerNames;
    Assert.IsTrue(Length(Names) > 0);
    Assert.AreEqual('testlayer', Names[0]);
  finally
    Pkg.Free;
  end;
  DeleteTempFile;
end;

Procedure TGeopackageTests.Writer_RoundTrip_Point;
var
  Written, Read: TGISShape;
  Props: TGISShapeProperties;
begin
  DeleteTempFile;
  Written.AssignPoint(5.0, 52.0);

  var Pkg := TGeopackage.Create(TempFile, gpReadWrite);
  try
    var Writer := Pkg.CreateWriter;
    try
      var LW := Writer.CreateLayerWriter('pts', 4326);
      LW.WriteShape(Written, nil);
      LW.Free;
    finally
      Writer.Free;
    end;
  finally
    Pkg.Free;
  end;

  Pkg := TGeopackage.Create(TempFile);
  try
    var Reader := Pkg.CreateReader('pts');
    try
      Assert.IsTrue(Reader.ReadShape(Read, Props));
      Assert.AreEqual(Ord(stPoint),  Ord(Read.ShapeType));
      Assert.AreEqual(5.0,  Read[0,0].X, 1e-10);
      Assert.AreEqual(52.0, Read[0,0].Y, 1e-10);
    finally
      Reader.Free;
    end;
  finally
    Pkg.Free;
  end;
  DeleteTempFile;
end;

Procedure TGeopackageTests.Writer_RoundTrip_Polygon;
var
  Written, Read: TGISShape;
  Props: TGISShapeProperties;
  Pts: array[0..3] of TCoordinate;
begin
  DeleteTempFile;
  Pts[0] := TCoordinate.Create(0, 0);
  Pts[1] := TCoordinate.Create(1, 0);
  Pts[2] := TCoordinate.Create(1, 1);
  Pts[3] := TCoordinate.Create(0, 1);
  Written.AssignPolygon(Pts);

  var Pkg := TGeopackage.Create(TempFile, gpReadWrite);
  try
    var Writer := Pkg.CreateWriter;
    try
      var LW := Writer.CreateLayerWriter('polys', 4326);
      LW.WriteShape(Written, nil);
      LW.Free;
    finally
      Writer.Free;
    end;
  finally
    Pkg.Free;
  end;

  Pkg := TGeopackage.Create(TempFile);
  try
    var Reader := Pkg.CreateReader('polys');
    try
      Assert.IsTrue(Reader.ReadShape(Read, Props));
      Assert.AreEqual(Ord(stPolygon), Ord(Read.ShapeType));
    finally
      Reader.Free;
    end;
  finally
    Pkg.Free;
  end;
  DeleteTempFile;
end;

Procedure TGeopackageTests.Writer_RoundTrip_ShapeCount;
const
  N = 5;
var
  Shape: TGISShape;
  Props: TGISShapeProperties;
  Count: Integer;
begin
  DeleteTempFile;

  var Pkg := TGeopackage.Create(TempFile, gpReadWrite);
  try
    var Writer := Pkg.CreateWriter;
    try
      var LW := Writer.CreateLayerWriter('shapes', 4326);
      for var I := 1 to N do
      begin
        Shape.AssignPoint(I, I);
        LW.WriteShape(Shape, nil);
      end;
      LW.Free;
    finally
      Writer.Free;
    end;
  finally
    Pkg.Free;
  end;

  Count := 0;
  Pkg := TGeopackage.Create(TempFile);
  try
    var Reader := Pkg.CreateReader('shapes');
    try
      while Reader.ReadShape(Shape, Props) do
        Inc(Count);
    finally
      Reader.Free;
    end;
  finally
    Pkg.Free;
  end;

  Assert.AreEqual(N, Count, 'Written and read shape counts must match');
  DeleteTempFile;
end;

Procedure TGeopackageTests.Writer_RoundTrip_ProvincesShapefile;
// The provinces with their attributes, the fields being those of the first shape
var
  Shape: TGISShape;
  Props: TGISShapeProperties;
  Shapes: TArray<TGISShape>;
  Properties: TArray<TGISShapeProperties>;
  FieldNames, Names: TArray<String>;
begin
  Assert.IsTrue(FileExists(DataPath + 'Provincies_dutch_grid.shp'), 'Test requires Data\Provincies_dutch_grid.shp');
  DeleteTempFile;
  // Read the shapefile
  var ShpReader := TESRIShapeFileReader.Create(DataPath + 'Provincies_dutch_grid.shp');
  try
    while ShpReader.ReadShape(Shape, Props) do
    begin
      Shapes := Shapes + [Shape];
      Properties := Properties + [Props];
    end;
  finally
    ShpReader.Free;
  end;
  Assert.AreEqual(12, Integer(Length(Shapes)), 'The twelve provinces');
  for var Prop in Properties[0] do FieldNames := FieldNames + [Prop.Key];
  // Write them to a new GeoPackage
  var Pkg := TGeopackage.Create(TempFile, gpReadWrite);
  try
    var Writer := Pkg.CreateWriter;
    try
      var LW := Writer.CreateLayerWriter('provinces', 28992, FieldNames);
      try
        for var I := 0 to High(Shapes) do LW.WriteShape(Shapes[I], Properties[I]);
      finally
        LW.Free;
      end;
    finally
      Writer.Free;
    end;
  finally
    Pkg.Free;
  end;
  // Read them back, with their names
  Pkg := TGeopackage.Create(TempFile);
  try
    var Reader := Pkg.CreateReader('provinces');
    try
      while Reader.ReadShape(Shape, Props) do Names := Names + [String(Props.ValueFromName['statnaam'])];
    finally
      Reader.Free;
    end;
  finally
    Pkg.Free;
  end;
  Assert.AreEqual(12, Integer(Length(Names)), 'Shapes read back');
  for var I := 0 to High(Names) do
    Assert.AreEqual(String(Properties[I].ValueFromName['statnaam']), Names[I], 'Name of province ' + I.ToString);
  DeleteTempFile;
end;

Procedure TGeopackageTests.Writer_ConverterOverload_StoresCorrectSRS;
var
  Conv: TWgs84CoordinateConverter;
  Pkg:  TGeopackage;
  Q:    FireDAC.Comp.Client.TFDQuery;
  SRID: Integer;
  Def:  String;
begin
  DeleteTempFile;
  Conv := TWgs84CoordinateConverter.Create;
  try
    Pkg := TGeopackage.Create(TempFile, gpReadWrite);
    try
      var Writer := Pkg.CreateWriter;
      try
        Writer.CreateLayerWriter('test', Conv).Free;
      finally
        Writer.Free;
      end;
    finally
      Pkg.Free;
    end;
  finally
    Conv.Free;
  end;

  // Re-open and query gpkg_spatial_ref_sys
  SRID := -1; Def := '';
  Pkg := TGeopackage.Create(TempFile);
  try
    Q := FireDAC.Comp.Client.TFDQuery.Create(nil);
    try
      Q.Connection := Pkg.Connection;
      Q.SQL.Text :=
        'SELECT srs_id, definition FROM gpkg_spatial_ref_sys WHERE srs_id = 4326';
      Q.Open;
      if not Q.IsEmpty then
      begin
        SRID := Q.Fields[0].AsInteger;
        Def  := Q.Fields[1].AsString;
      end;
    finally
      Q.Free;
    end;
  finally
    Pkg.Free;
  end;

  Assert.AreEqual(4326, SRID, 'SRID 4326 should be stored in gpkg_spatial_ref_sys');
  Assert.IsTrue(Pos('WGS', Def) > 0, 'SRS definition should contain WGS84 WKT');
  DeleteTempFile;
end;

Procedure TGeopackageTests.Writer_RoundTrip_SRID;
var
  ReadSRID: Integer;
begin
  DeleteTempFile;
  var Pkg := TGeopackage.Create(TempFile, gpReadWrite);
  try
    var Writer := Pkg.CreateWriter;
    try
      Writer.CreateLayerWriter('utm', 32631).Free; // UTM zone 31N
    finally
      Writer.Free;
    end;
  finally
    Pkg.Free;
  end;

  Pkg := TGeopackage.Create(TempFile);
  try
    var Reader := Pkg.CreateReader('utm');
    try
      ReadSRID := Reader.SRID;
    finally
      Reader.Free;
    end;
  finally
    Pkg.Free;
  end;

  Assert.AreEqual(32631, ReadSRID, 'Reader.SRID should match the SRID the layer was written with');
  DeleteTempFile;
end;

Procedure TGeopackageTests.Writer_TwoOuterRings_WritesMultiPolygon;
// Two outer rings in one WKB Polygon would read as an outer ring with a hole.
// The blob is the 8-byte GeoPackage header, then the WKB byte order, type and count.
var
  Parts: TMultiPoints;
  Shape: TGISShape;
begin
  SetLength(Parts, 2);
  Parts[0] := [TCoordinate.Create(0, 0), TCoordinate.Create(1, 0), TCoordinate.Create(1, 1), TCoordinate.Create(0, 1)];
  Parts[1] := [TCoordinate.Create(3, 0), TCoordinate.Create(4, 0), TCoordinate.Create(4, 1), TCoordinate.Create(3, 1)];
  Shape.AssignPolyPolygon(Parts);
  var Bytes := WrittenGeometry(Shape);
  Assert.AreEqual(1, Integer(Bytes[8]), 'Little-endian');
  Assert.AreEqual(6, Int32At(Bytes, 9), 'WKB MultiPolygon');
  Assert.AreEqual(2, Int32At(Bytes, 13), 'Polygons');
end;

Procedure TGeopackageTests.Writer_HoleListedFirst_WritesOuterRingFirst;
// WKB takes the first ring of a polygon as its outer ring, whatever order the shape holds them in.
// After the ring count comes the point count of the first ring, then its first point.
var
  Parts: TMultiPoints;
  Shape: TGISShape;
begin
  SetLength(Parts, 2);
  Parts[0] := [TCoordinate.Create(-1, -1), TCoordinate.Create(1, -1), TCoordinate.Create(1, 1), TCoordinate.Create(-1, 1)];
  Parts[1] := [TCoordinate.Create(-5, -5), TCoordinate.Create(5, -5), TCoordinate.Create(5, 5), TCoordinate.Create(-5, 5)];
  Shape.AssignPolyPolygon(Parts);
  var Bytes := WrittenGeometry(Shape);
  Assert.AreEqual(1, Integer(Bytes[8]), 'Little-endian');
  Assert.AreEqual(3, Int32At(Bytes, 9), 'WKB Polygon');
  Assert.AreEqual(2, Int32At(Bytes, 13), 'Rings');
  Assert.AreEqual(5, Int32At(Bytes, 17), 'Points of the first ring');
  Assert.AreEqual(-5.0, DoubleAt(Bytes, 21), 1e-12, 'First ring starts at the outer ring');
end;

Procedure TGeopackageTests.Writer_NamesNeedingQuotes_RoundTrip;
// A layer name with a space and a hyphen, a field name with a space and one that is a reserved word
const
  LayerName = 'road segments-2024';
var
  Written, Read: TGISShape;
  Props: TGISShapeProperties;
begin
  DeleteTempFile;
  Written.AssignPoint(4.9, 52.4);
  var Pkg := TGeopackage.Create(TempFile, gpReadWrite);
  try
    var Writer := Pkg.CreateWriter;
    try
      var LW := Writer.CreateLayerWriter(LayerName, 4326, ['road name', 'order']);
      try
        LW.WriteShape(Written, [TPair<String,Variant>.Create('road name', 'Main Street'),
                                TPair<String,Variant>.Create('order', 3)]);
      finally
        LW.Free;
      end;
    finally
      Writer.Free;
    end;
  finally
    Pkg.Free;
  end;
  Pkg := TGeopackage.Create(TempFile);
  try
    var Names := Pkg.LayerNames;
    Assert.AreEqual(1, Integer(Length(Names)), 'Layers');
    Assert.AreEqual(LayerName, Names[0]);
    var Reader := Pkg.CreateReader(LayerName);
    try
      Assert.IsTrue(Reader.ReadShape(Read, Props), 'A shape is read');
      Assert.AreEqual('Main Street', String(Props.ValueFromName['road name']));
      Assert.AreEqual('3', String(Props.ValueFromName['order']));
    finally
      Reader.Free;
    end;
  finally
    Pkg.Free;
  end;
  DeleteTempFile;
end;

Procedure TGeopackageTests.Writer_ManyShapes_AllReadBack;
// The shapes of a layer go in one transaction, which freeing the layer writer commits
var
  Shape: TGISShape;
  Props: TGISShapeProperties;
begin
  WritePoints(5000);
  var Pkg := TGeopackage.Create(TempFile);
  try
    var Reader := Pkg.CreateReader('points');
    try
      var Count := 0;
      while Reader.ReadShape(Shape, Props) do Inc(Count);
      Assert.AreEqual(5000, Count);
    finally
      Reader.Free;
    end;
  finally
    Pkg.Free;
  end;
  DeleteTempFile;
end;

Procedure TGeopackageTests.Writer_NewFile_IdentifiesItselfAsGeoPackage;
// The specification requires the application id 'GPKG' and the version, 10300 for 1.3.0
begin
  WritePoints(1);
  Assert.AreEqual(Int64($47504B47), Int64(QueryValue('PRAGMA application_id')), 'application_id');
  Assert.AreEqual(Int64(10300), Int64(QueryValue('PRAGMA user_version')), 'user_version');
  DeleteTempFile;
end;

Procedure TGeopackageTests.Writer_StoresTheLayerBounds;
var
  Shape: TGISShape;
begin
  DeleteTempFile;
  var Pkg := TGeopackage.Create(TempFile, gpReadWrite);
  try
    var Writer := Pkg.CreateWriter;
    try
      var LW := Writer.CreateLayerWriter('points', 4326);
      try
        Shape.AssignPoint(1, 2);
        LW.WriteShape(Shape, nil);
        Shape.AssignPoint(-3, 5);
        LW.WriteShape(Shape, nil);
      finally
        LW.Free;
      end;
    finally
      Writer.Free;
    end;
  finally
    Pkg.Free;
  end;
  Assert.AreEqual(-3.0, Double(QueryValue('SELECT min_x FROM gpkg_contents WHERE table_name = ''points''')), 1e-12, 'min_x');
  Assert.AreEqual( 2.0, Double(QueryValue('SELECT min_y FROM gpkg_contents WHERE table_name = ''points''')), 1e-12, 'min_y');
  Assert.AreEqual( 1.0, Double(QueryValue('SELECT max_x FROM gpkg_contents WHERE table_name = ''points''')), 1e-12, 'max_x');
  Assert.AreEqual( 5.0, Double(QueryValue('SELECT max_y FROM gpkg_contents WHERE table_name = ''points''')), 1e-12, 'max_y');
  DeleteTempFile;
end;

Procedure TGeopackageTests.Writer_ConverterOverload_WritesProperties;
var
  Written, Read: TGISShape;
  Props: TGISShapeProperties;
begin
  DeleteTempFile;
  Written.AssignPoint(5.4, 52.2);
  var Converter := TWgs84CoordinateConverter.Create;
  var Pkg := TGeopackage.Create(TempFile, gpReadWrite);
  try
    var Writer := Pkg.CreateWriter;
    try
      var LW := Writer.CreateLayerWriter('places', Converter, ['name']);
      try
        LW.WriteShape(Written, [TPair<String,Variant>.Create('name', 'Amersfoort')]);
      finally
        LW.Free;
      end;
    finally
      Writer.Free;
    end;
  finally
    Pkg.Free;
    Converter.Free;
  end;
  Pkg := TGeopackage.Create(TempFile);
  try
    var Reader := Pkg.CreateReader('places');
    try
      Assert.IsTrue(Reader.ReadShape(Read, Props));
      Assert.AreEqual(4326, Reader.SRID, 'SRID from the converter');
      Assert.AreEqual('Amersfoort', String(Props.ValueFromName['name']));
    finally
      Reader.Free;
    end;
  finally
    Pkg.Free;
  end;
  DeleteTempFile;
end;

Procedure TGeopackageTests.Writer_PropertiesNamedLikeItsColumns_AreKept;
// A shapefile exported by other tools often carries a fid attribute, and the writer has a key
// column of that name and a geometry column named geom
var
  Written, Read: TGISShape;
  Props: TGISShapeProperties;
begin
  DeleteTempFile;
  Written.AssignPoint(5.4, 52.2);
  var Pkg := TGeopackage.Create(TempFile, gpReadWrite);
  try
    var Writer := Pkg.CreateWriter;
    try
      var LW := Writer.CreateLayerWriter('places', 4326, ['fid', 'geom']);
      try
        LW.WriteShape(Written, [TPair<String,Variant>.Create('fid', 'A'), TPair<String,Variant>.Create('geom', 'B')]);
      finally
        LW.Free;
      end;
    finally
      Writer.Free;
    end;
  finally
    Pkg.Free;
  end;
  Pkg := TGeopackage.Create(TempFile);
  try
    var Reader := Pkg.CreateReader('places');
    try
      Assert.IsTrue(Reader.ReadShape(Read, Props));
      Assert.AreEqual(5.4, Read[0,0].X, 1e-9, 'The geometry');
      Assert.AreEqual('A', String(Props.ValueFromName['fid']));
      Assert.AreEqual('B', String(Props.ValueFromName['geom']));
    finally
      Reader.Free;
    end;
  finally
    Pkg.Free;
  end;
  DeleteTempFile;
end;

////////////////////////////////////////////////////////////////////////////////

Procedure TGeopackageReaderTests.Setup;
// A package with one layer, shapes, holding a name
begin
  FFile := TPath.Combine(TPath.GetTempPath, 'TestGeopackageReader_' + TGUID.NewGuid.ToString + '.gpkg');
  var Pkg := TGeopackage.Create(FFile, gpReadWrite);
  try
    var Writer := Pkg.CreateWriter;
    try
      Writer.CreateLayerWriter('shapes', 4326, ['name']).Free;
    finally
      Writer.Free;
    end;
  finally
    Pkg.Free;
  end;
end;

Procedure TGeopackageReaderTests.TearDown;
begin
  if FileExists(FFile) then TFile.Delete(FFile);
end;

Function TGeopackageReaderTests.LE32(const Value: Int32): TBytes;
begin
  SetLength(Result, 4);
  Move(Value, Result[0], 4);
end;

Function TGeopackageReaderTests.LEF64(const Value: Double): TBytes;
begin
  SetLength(Result, 8);
  Move(Value, Result[0], 8);
end;

Function TGeopackageReaderTests.BE32(const Value: Int32): TBytes;
begin
  Result := LE32(Value);
  Result := [Result[3], Result[2], Result[1], Result[0]];
end;

Function TGeopackageReaderTests.BEF64(const Value: Double): TBytes;
begin
  Result := LEF64(Value);
  Result := [Result[7], Result[6], Result[5], Result[4], Result[3], Result[2], Result[1], Result[0]];
end;

Function TGeopackageReaderTests.Header(const Flags: Byte): TBytes;
begin
  Result := [$47, $50, 0, Flags] + LE32(4326);
end;

Function TGeopackageReaderTests.Point(const X, Y: Double): TBytes;
begin
  Result := [1] + LE32(1) + LEF64(X) + LEF64(Y);
end;

Procedure TGeopackageReaderTests.InsertRow(const Blob: TBytes; const Name: String);
begin
  var Pkg := TGeopackage.Create(FFile, gpReadWrite);
  try
    var Q := TFDQuery.Create(nil);
    try
      Q.Connection := Pkg.Connection;
      Q.SQL.Text := 'INSERT INTO shapes (geom, name) VALUES (:geom, :name)';
      if Length(Blob) = 0 then
      begin
        Q.ParamByName('geom').DataType := ftBlob;
        Q.ParamByName('geom').Clear;
      end else
      begin
        var Stream := TBytesStream.Create(Blob);
        try
          Q.ParamByName('geom').LoadFromStream(Stream, ftBlob);
        finally
          Stream.Free;
        end;
      end;
      Q.ParamByName('name').AsString := Name;
      Q.ExecSQL;
    finally
      Q.Free;
    end;
  finally
    Pkg.Free;
  end;
end;

Procedure TGeopackageReaderTests.ReadAll(out Shapes: TArray<TGISShape>; out Names: TArray<String>);
var
  Shape: TGISShape;
  Props: TGISShapeProperties;
begin
  Shapes := [];
  Names := [];
  var Pkg := TGeopackage.Create(FFile);
  try
    var Reader := Pkg.CreateReader('shapes');
    try
      while Reader.ReadShape(Shape, Props) do
      begin
        Shapes := Shapes + [Shape];
        Names := Names + [String(Props.ValueFromName['name'])];
      end;
    finally
      Reader.Free;
    end;
  finally
    Pkg.Free;
  end;
end;

Procedure TGeopackageReaderTests.PointZ_DropsZ;
// Geometry type 1001 is a point with a Z coordinate
var
  Shapes: TArray<TGISShape>;
  Names: TArray<String>;
begin
  InsertRow(Header(1) + [1] + LE32(1001) + LEF64(1) + LEF64(2) + LEF64(99), 'z');
  ReadAll(Shapes, Names);
  Assert.AreEqual(1, Integer(Length(Shapes)));
  Assert.AreEqual(Ord(stPoint), Ord(Shapes[0].ShapeType), 'Shape type');
  Assert.AreEqual(1.0, Shapes[0][0,0].X, 1e-12, 'X');
  Assert.AreEqual(2.0, Shapes[0][0,0].Y, 1e-12, 'Y');
end;

Procedure TGeopackageReaderTests.PointZM_DropsZAndM;
// Geometry type 3001 is a point with Z and M coordinates
var
  Shapes: TArray<TGISShape>;
  Names: TArray<String>;
begin
  InsertRow(Header(1) + [1] + LE32(3001) + LEF64(1) + LEF64(2) + LEF64(99) + LEF64(98), 'zm');
  ReadAll(Shapes, Names);
  Assert.AreEqual(1, Integer(Length(Shapes)));
  Assert.AreEqual(1.0, Shapes[0][0,0].X, 1e-12, 'X');
  Assert.AreEqual(2.0, Shapes[0][0,0].Y, 1e-12, 'Y');
end;

Procedure TGeopackageReaderTests.BigEndian_IsRead;
// Byte order 0 is big-endian, for the type and the coordinates alike
var
  Shapes: TArray<TGISShape>;
  Names: TArray<String>;
begin
  InsertRow(Header(1) + [0] + BE32(1) + BEF64(1) + BEF64(2), 'be');
  ReadAll(Shapes, Names);
  Assert.AreEqual(1, Integer(Length(Shapes)));
  Assert.AreEqual(1.0, Shapes[0][0,0].X, 1e-12, 'X');
  Assert.AreEqual(2.0, Shapes[0][0,0].Y, 1e-12, 'Y');
end;

Procedure TGeopackageReaderTests.Envelope_IsSkipped;
// Flags 3: little-endian with an XY envelope of four doubles before the geometry
var
  Shapes: TArray<TGISShape>;
  Names: TArray<String>;
begin
  InsertRow(Header(3) + LEF64(1) + LEF64(1) + LEF64(2) + LEF64(2) + Point(1, 2), 'env');
  ReadAll(Shapes, Names);
  Assert.AreEqual(1, Integer(Length(Shapes)));
  Assert.AreEqual(1.0, Shapes[0][0,0].X, 1e-12, 'X');
  Assert.AreEqual(2.0, Shapes[0][0,0].Y, 1e-12, 'Y');
end;

Procedure TGeopackageReaderTests.NullGeometry_IsSkipped;
var
  Shapes: TArray<TGISShape>;
  Names: TArray<String>;
begin
  InsertRow([], 'nothing');
  InsertRow(Header(1) + Point(1, 2), 'something');
  ReadAll(Shapes, Names);
  Assert.AreEqual(1, Integer(Length(Shapes)));
  Assert.AreEqual('something', Names[0]);
end;

Procedure TGeopackageReaderTests.EmptyGeometry_IsSkipped;
// Bit 4 of the flags marks an empty geometry
var
  Shapes: TArray<TGISShape>;
  Names: TArray<String>;
begin
  InsertRow(Header($11), 'empty');
  InsertRow(Header(1) + Point(1, 2), 'something');
  ReadAll(Shapes, Names);
  Assert.AreEqual(1, Integer(Length(Shapes)));
  Assert.AreEqual('something', Names[0]);
end;

Procedure TGeopackageReaderTests.MultiPoint_IsOneShapePerPoint_SharingTheProperties;
// Geometry type 4, holding two points
var
  Shapes: TArray<TGISShape>;
  Names: TArray<String>;
begin
  InsertRow(Header(1) + [1] + LE32(4) + LE32(2) + Point(1, 2) + Point(3, 4), 'both');
  ReadAll(Shapes, Names);
  Assert.AreEqual(2, Integer(Length(Shapes)), 'Shapes');
  Assert.AreEqual(3.0, Shapes[1][0,0].X, 1e-12, 'Second point X');
  Assert.AreEqual('both', Names[0]);
  Assert.AreEqual('both', Names[1]);
end;

Procedure TGeopackageReaderTests.MultiLineString_RoundTrip_IsOneShapeWithAPartPerLine;
var
  Written: TGISShape;
  Parts: TMultiPoints;
  Shapes: TArray<TGISShape>;
  Names: TArray<String>;
begin
  SetLength(Parts, 2);
  Parts[0] := [TCoordinate.Create(0, 0), TCoordinate.Create(1, 1)];
  Parts[1] := [TCoordinate.Create(2, 2), TCoordinate.Create(3, 3), TCoordinate.Create(4, 4)];
  Written.AssignPolyLine(Parts);
  var Pkg := TGeopackage.Create(FFile, gpReadWrite);
  try
    var Writer := Pkg.CreateWriter;
    try
      var LW := Writer.CreateLayerWriter('shapes', 4326, ['name']);
      try
        LW.WriteShape(Written, [TPair<String,Variant>.Create('name', 'lines')]);
      finally
        LW.Free;
      end;
    finally
      Writer.Free;
    end;
  finally
    Pkg.Free;
  end;
  ReadAll(Shapes, Names);
  Assert.AreEqual(1, Integer(Length(Shapes)));
  Assert.AreEqual(Ord(stLine), Ord(Shapes[0].ShapeType), 'Shape type');
  Assert.AreEqual(2, Shapes[0].Count, 'Parts');
  Assert.AreEqual(3, Shapes[0].Parts[1].Count, 'Points of the second part');
end;

Procedure TGeopackageReaderTests.MultiPolygon_RoundTrip_IsOneShapeWithAllRings;
var
  Written: TGISShape;
  Parts: TMultiPoints;
  Shapes: TArray<TGISShape>;
  Names: TArray<String>;
begin
  SetLength(Parts, 2);
  Parts[0] := [TCoordinate.Create(0, 0), TCoordinate.Create(1, 0), TCoordinate.Create(1, 1), TCoordinate.Create(0, 1)];
  Parts[1] := [TCoordinate.Create(3, 0), TCoordinate.Create(4, 0), TCoordinate.Create(4, 1), TCoordinate.Create(3, 1)];
  Written.AssignPolyPolygon(Parts);
  var Pkg := TGeopackage.Create(FFile, gpReadWrite);
  try
    var Writer := Pkg.CreateWriter;
    try
      var LW := Writer.CreateLayerWriter('shapes', 4326, ['name']);
      try
        LW.WriteShape(Written, [TPair<String,Variant>.Create('name', 'islands')]);
      finally
        LW.Free;
      end;
    finally
      Writer.Free;
    end;
  finally
    Pkg.Free;
  end;
  ReadAll(Shapes, Names);
  Assert.AreEqual(1, Integer(Length(Shapes)));
  Assert.AreEqual(Ord(stPolygon), Ord(Shapes[0].ShapeType), 'Shape type');
  Assert.AreEqual(2, Shapes[0].Count, 'Rings');
end;

Procedure TGeopackageReaderTests.MissingLayer_Raises;
begin
  var Pkg := TGeopackage.Create(FFile);
  try
    Assert.WillRaise(Procedure begin Pkg.CreateReader('nothing').Free end, Exception);
  finally
    Pkg.Free;
  end;
end;

Procedure TGeopackageReaderTests.CreateWriter_OnAReadOnlyPackage_Raises;
begin
  var Pkg := TGeopackage.Create(FFile);
  try
    Assert.WillRaise(Procedure begin Pkg.CreateWriter.Free end, Exception);
  finally
    Pkg.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TGeopackageTests);
  TDUnitX.RegisterTestFixture(TGeopackageReaderTests);

end.

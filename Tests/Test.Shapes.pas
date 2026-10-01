unit Test.Shapes;

////////////////////////////////////////////////////////////////////////////////
//
// Author: Jaap Baak
// https://github.com/transportmodelling/GISlib
//
// Test suite generated with assistance from Claude Sonnet 4.6
//
// Tests the ESRI shapefile reader directly via TGISShapesReader.ReadShape.
// No VCL dependency - TGISShapesReader and TGISShape live in GIS.Shapes.
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
interface
////////////////////////////////////////////////////////////////////////////////

uses
  System.SysUtils, System.Variants, DUnitX.TestFramework, DBF,
  GIS, GIS.Shapes, GIS.Shapes.ESRI, GIS.Shapes.GeoJSON;

type
  [TestFixture]
  TESRIShapeFileReaderTests = class
  private
    Function DataPath: String;
    Function CountAndBounds(const FileName: String;
                            out ShapeCount: Integer; out BB: TCoordinateRect): TShapeType;
  public
    // Dutch Grid shapefile
    [Test] Procedure DutchGrid_ReadsExpectedShapeCount;
    [Test] Procedure DutchGrid_AllShapesArePolygons;
    [Test] Procedure DutchGrid_BoundingBoxWithinNetherlandsDutchGrid;

    // WGS84 shapefile
    [Test] Procedure WGS84_ReadsExpectedShapeCount;
    [Test] Procedure WGS84_AllShapesArePolygons;
    [Test] Procedure WGS84_BoundingBoxWithinNetherlandsWGS84;

    // Both files should read the same number of shapes (same provinces, different CRS)
    [Test] Procedure BothFiles_SameShapeCount;
  end;

  // The properties' encoding: Provincies_dutch_grid.dbf holds UTF-8 without
  // declaring it, with the province Frysl-a-circumflex-n as the bytes C3 A2
  // for the a-circumflex. These read a copy of it with various .cpg files.
  [TestFixture]
  TESRIShapeFileEncodingTests = class
  private
    FDir: String;
    // The name of that province read from the copy, with a .cpg holding
    // Cpg, or none when Cpg is empty
    Function ProvinceName(const Cpg: String): String;
  public
    [Setup]    Procedure Setup;
    [TearDown] Procedure TearDown;
    [Test] Procedure NoCpg_DetectsUTF8;
    [Test] Procedure CpgUTF8;
    [Test] Procedure CpgCodePageNumber;
    [Test] Procedure CpgISO8859;
    [Test] Procedure CpgUnknownCodePage_DetectsUTF8;
  end;

  // The reader on files it cannot read, and on files without properties
  [TestFixture]
  TESRIShapeFileReaderFileTests = class
  private
    FDir: String;
    // The base name of a point shapefile with one NAME field written in the temp directory
    Function PointFile: String;
  public
    [Setup]    Procedure Setup;
    [TearDown] Procedure TearDown;
    [Test] Procedure InvalidFileCode_Raises;
    [Test] Procedure UnsupportedShapeType_Raises;
    [Test] Procedure WithoutProperties_ReadsNone;
    [Test] Procedure WithoutDbf_ReadsNoProperties;
    [Test] Procedure IndexOf_MustExist_RaisesForAnUnknownField;
  end;

  // GeoJSON is UTF-8 by definition (RFC 7946), with or without a byte order mark
  [TestFixture]
  TGeoJSONReaderEncodingTests = class
  private
    FDir: String;
    // The name property of the one feature in a file holding Bytes
    Function FeatureName(const Bytes: TBytes): String;
    // A feature collection with one feature named Frysl-a-circumflex-n, as UTF-8
    Function Utf8Document: TBytes;
  public
    [Setup]    Procedure Setup;
    [TearDown] Procedure TearDown;
    [Test] Procedure Utf8WithoutBom;
    [Test] Procedure Utf8WithBom;
  end;

  [TestFixture]
  TGeoJSONReaderTests = class
  private
    FDir: String;
    // Reads every feature of the document given, as shapes with their properties
    Procedure ReadAll(const Json: String; out Shapes: TArray<TGISShape>; out Properties: TArray<TGISShapeProperties>);
    // A feature collection holding one feature with the geometry given
    Function Collection(const Geometry: String; const Properties: String = '{}'): String;
  public
    [Setup]    Procedure Setup;
    [TearDown] Procedure TearDown;
    [Test] Procedure PropertyValues_KeepTheirTypes;
    [Test] Procedure MultiPoint_IsOnePointsShape;
    [Test] Procedure MultiLineString_IsOneShapeWithAPartPerLine;
    [Test] Procedure MultiPolygon_IsOneShapeWithAllRings;
    [Test] Procedure NullGeometry_IsAnEmptyShapeWithItsProperties;
    [Test] Procedure GeometryCollection_Raises;
    [Test] Procedure NotAFeatureCollection_Raises;
    [Test] Procedure EndOfFile_AfterTheLastFeature;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

uses System.IOUtils;

Function TESRIShapeFileReaderTests.DataPath: String;
begin
  Result := ExpandFileName(ExtractFilePath(ParamStr(0)) + '..\Data\');
end;

Function TESRIShapeFileReaderTests.CountAndBounds(const FileName: String;
                                                  out ShapeCount: Integer; out BB: TCoordinateRect): TShapeType;
var
  Reader: TESRIShapeFileReader;
  Shape: TGISShape;
  Props: TGISShapeProperties;
begin
  ShapeCount := 0;
  BB.Clear;
  Result := stEmpty;
  Reader := TESRIShapeFileReader.Create(FileName);
  try
    while Reader.ReadShape(Shape, Props) do
    begin
      Inc(ShapeCount);
      BB.Enclose(Shape.BoundingBox);
      // The type of the shapes, or stEmpty when they are not all of one type
      if ShapeCount = 1 then Result := Shape.ShapeType else
      if Shape.ShapeType <> Result then Result := stEmpty;
    end;
  finally
    Reader.Free;
  end;
end;

Procedure TESRIShapeFileReaderTests.DutchGrid_ReadsExpectedShapeCount;
var
  Count: Integer;
  BB: TCoordinateRect;
begin
  CountAndBounds(DataPath + 'Provincies_dutch_grid.shp', Count, BB);
  Assert.AreEqual(12, Count, 'The twelve provinces');
end;

Procedure TESRIShapeFileReaderTests.DutchGrid_AllShapesArePolygons;
var
  Count: Integer;
  BB: TCoordinateRect;
begin
  Assert.AreEqual(Ord(stPolygon), Ord(CountAndBounds(DataPath + 'Provincies_dutch_grid.shp', Count, BB)),
                  'Every shape must be a polygon');
end;

Procedure TESRIShapeFileReaderTests.DutchGrid_BoundingBoxWithinNetherlandsDutchGrid;
var
  Count: Integer;
  BB: TCoordinateRect;
begin
  CountAndBounds(DataPath + 'Provincies_dutch_grid.shp', Count, BB);
  // Netherlands Dutch Grid: X roughly 7000-300000, Y roughly 289000-629000
  Assert.IsTrue(BB.Left   >   7000, 'Left bound');
  Assert.IsTrue(BB.Right  < 300000, 'Right bound');
  Assert.IsTrue(BB.Bottom > 289000, 'Bottom bound');
  Assert.IsTrue(BB.Top    < 629000, 'Top bound');
end;

Procedure TESRIShapeFileReaderTests.WGS84_ReadsExpectedShapeCount;
var
  Count: Integer;
  BB: TCoordinateRect;
begin
  CountAndBounds(DataPath + 'Provincies_wsg84.shp', Count, BB);
  Assert.AreEqual(12, Count, 'The twelve provinces');
end;

Procedure TESRIShapeFileReaderTests.WGS84_AllShapesArePolygons;
var
  Count: Integer;
  BB: TCoordinateRect;
begin
  Assert.AreEqual(Ord(stPolygon), Ord(CountAndBounds(DataPath + 'Provincies_wsg84.shp', Count, BB)),
                  'Every shape must be a polygon');
end;

Procedure TESRIShapeFileReaderTests.WGS84_BoundingBoxWithinNetherlandsWGS84;
var
  Count: Integer;
  BB: TCoordinateRect;
begin
  CountAndBounds(DataPath + 'Provincies_wsg84.shp', Count, BB);
  // Netherlands WGS84: lon 3.3-7.3 deg, lat 50.7-53.6 deg
  Assert.IsTrue(BB.Left   >  3.0, 'Left (longitude)');
  Assert.IsTrue(BB.Right  <  7.5, 'Right (longitude)');
  Assert.IsTrue(BB.Bottom > 50.5, 'Bottom (latitude)');
  Assert.IsTrue(BB.Top    < 54.0, 'Top (latitude)');
end;

Procedure TESRIShapeFileReaderTests.BothFiles_SameShapeCount;
var
  CountDG, CountWGS: Integer;
  BB: TCoordinateRect;
begin
  CountAndBounds(DataPath + 'Provincies_dutch_grid.shp', CountDG, BB);
  CountAndBounds(DataPath + 'Provincies_wsg84.shp',      CountWGS, BB);
  Assert.AreEqual(CountDG, CountWGS, 'Both files should contain the same number of provinces');
end;

////////////////////////////////////////////////////////////////////////////////

Procedure TESRIShapeFileEncodingTests.Setup;
begin
  FDir := TPath.Combine(TPath.GetTempPath, 'GISlibEncoding' + TGUID.NewGuid.ToString);
  TDirectory.CreateDirectory(FDir);
end;

Procedure TESRIShapeFileEncodingTests.TearDown;
begin
  TDirectory.Delete(FDir, true);
end;

Function TESRIShapeFileEncodingTests.ProvinceName(const Cpg: String): String;
var
  Shape: TGISShape;
  Props: TGISShapeProperties;
begin
  var Source := ExpandFileName(ExtractFilePath(ParamStr(0)) + '..\Data\Provincies_dutch_grid');
  var Target := TPath.Combine(FDir, 'Provincies');
  for var Ext in ['.shp', '.shx', '.dbf'] do TFile.Copy(Source + Ext, Target + Ext);
  if Cpg <> '' then TFile.WriteAllText(Target + '.cpg', Cpg);
  Result := '';
  var Reader := TESRIShapeFileReader.Create(Target + '.shp');
  try
    while Reader.ReadShape(Shape, Props) do
    begin
      var Name := String(Props.ValueFromName['statnaam']);
      if Name.StartsWith('Frysl') then Exit(Name);
    end;
  finally
    Reader.Free;
  end;
  Assert.Fail('Province not found');
end;

Procedure TESRIShapeFileEncodingTests.NoCpg_DetectsUTF8;
begin
  Assert.AreEqual('Frysl'#$E2'n', ProvinceName(''));
end;

Procedure TESRIShapeFileEncodingTests.CpgUTF8;
begin
  Assert.AreEqual('Frysl'#$E2'n', ProvinceName('UTF-8'));
end;

Procedure TESRIShapeFileEncodingTests.CpgCodePageNumber;
begin
  // Declared as Windows-1252, so the UTF-8 bytes read as two characters
  Assert.AreEqual('Frysl'#$C3#$A2'n', ProvinceName('ANSI 1252'));
end;

Procedure TESRIShapeFileEncodingTests.CpgISO8859;
begin
  // ISO 8859-1 has the same characters as Windows-1252 at C3 and A2
  Assert.AreEqual('Frysl'#$C3#$A2'n', ProvinceName('ISO 8859-1'));
end;

Procedure TESRIShapeFileEncodingTests.CpgUnknownCodePage_DetectsUTF8;
begin
  // A code page the system does not have is left to the dbf reader
  Assert.AreEqual('Frysl'#$E2'n', ProvinceName('99999'));
end;

////////////////////////////////////////////////////////////////////////////////

Procedure TESRIShapeFileReaderFileTests.Setup;
begin
  FDir := TPath.Combine(TPath.GetTempPath, 'GISlibReader' + TGUID.NewGuid.ToString);
  TDirectory.CreateDirectory(FDir);
end;

Procedure TESRIShapeFileReaderFileTests.TearDown;
begin
  TDirectory.Delete(FDir, true);
end;

Function TESRIShapeFileReaderFileTests.PointFile: String;
begin
  Result := TPath.Combine(FDir, 'Points');
  var W := TESRIPointShapeFileWriter.Create(Result + '.shp', [TDBFField.Create('NAME', 'C', 10, 0)]);
  try
    W.Write(1, 2, ['Amersfoort']);
  finally
    W.Free;
  end;
end;

Procedure TESRIShapeFileReaderFileTests.InvalidFileCode_Raises;
begin
  var FileName := TPath.Combine(FDir, 'Bogus.shp');
  TFile.WriteAllBytes(FileName, TBytes.Create(0, 0, 0, 0, 0, 0, 0, 0));
  Assert.WillRaise(Procedure begin TESRIShapeFileReader.Create(FileName).Free end, Exception);
end;

Procedure TESRIShapeFileReaderFileTests.UnsupportedShapeType_Raises;
// The shape type of the first record sits at offset 108: after the 100 byte file header
// and the 8 byte record header. 11 is PointZ, which the reader does not take.
var
  Shape: TGISShape;
  Props: TGISShapeProperties;
begin
  var Base := PointFile;
  var Bytes := TFile.ReadAllBytes(Base + '.shp');
  Bytes[108] := 11;
  TFile.WriteAllBytes(Base + '.shp', Bytes);
  var R := TESRIShapeFileReader.Create(Base + '.shp');
  try
    Assert.WillRaise(Procedure begin R.ReadShape(Shape, Props) end, Exception);
  finally
    R.Free;
  end;
end;

Procedure TESRIShapeFileReaderFileTests.WithoutProperties_ReadsNone;
var
  Shape: TGISShape;
  Props: TGISShapeProperties;
begin
  var R := TESRIShapeFileReader.Create(PointFile + '.shp', false);
  try
    Assert.AreEqual(-1, R.IndexOf('NAME'), 'No field is known');
    Assert.IsTrue(R.ReadShape(Shape, Props));
    Assert.AreEqual(0, Integer(Length(Props)), 'No properties');
    Assert.AreEqual(1.0, Shape[0,0].X, 1e-10, 'The shape is still read');
  finally
    R.Free;
  end;
end;

Procedure TESRIShapeFileReaderFileTests.WithoutDbf_ReadsNoProperties;
var
  Shape: TGISShape;
  Props: TGISShapeProperties;
begin
  var Base := PointFile;
  TFile.Delete(Base + '.dbf');
  var R := TESRIShapeFileReader.Create(Base + '.shp');
  try
    Assert.IsTrue(R.ReadShape(Shape, Props));
    Assert.AreEqual(0, Integer(Length(Props)), 'No properties');
  finally
    R.Free;
  end;
end;

Procedure TESRIShapeFileReaderFileTests.IndexOf_MustExist_RaisesForAnUnknownField;
begin
  var R := TESRIShapeFileReader.Create(PointFile + '.shp');
  try
    Assert.AreEqual(0, R.IndexOf('NAME'));
    Assert.AreEqual(-1, R.IndexOf('OTHER'));
    Assert.WillRaise(Procedure begin R.IndexOf('OTHER', true) end, Exception);
  finally
    R.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////

Procedure TGeoJSONReaderEncodingTests.Setup;
begin
  FDir := TPath.Combine(TPath.GetTempPath, 'GISlibGeoJSON' + TGUID.NewGuid.ToString);
  TDirectory.CreateDirectory(FDir);
end;

Procedure TGeoJSONReaderEncodingTests.TearDown;
begin
  TDirectory.Delete(FDir, true);
end;

Function TGeoJSONReaderEncodingTests.FeatureName(const Bytes: TBytes): String;
var
  Shape: TGISShape;
  Props: TGISShapeProperties;
begin
  var FileName := TPath.Combine(FDir, 'Feature.geojson');
  TFile.WriteAllBytes(FileName, Bytes);
  var Reader := TGeoJSONReader.Create(FileName);
  try
    Assert.IsTrue(Reader.ReadShape(Shape, Props), 'A feature is read');
    Result := String(Props.ValueFromName['name']);
  finally
    Reader.Free;
  end;
end;

Function TGeoJSONReaderEncodingTests.Utf8Document: TBytes;
begin
  Result := TEncoding.UTF8.GetBytes(
    '{"type":"FeatureCollection","features":[' +
    '{"type":"Feature","geometry":{"type":"Point","coordinates":[5.8,53.2]},' +
    '"properties":{"name":"Frysl'#$E2'n"}}]}');
end;

Procedure TGeoJSONReaderEncodingTests.Utf8WithoutBom;
begin
  Assert.AreEqual('Frysl'#$E2'n', FeatureName(Utf8Document));
end;

Procedure TGeoJSONReaderEncodingTests.Utf8WithBom;
begin
  Assert.AreEqual('Frysl'#$E2'n', FeatureName(TEncoding.UTF8.GetPreamble + Utf8Document));
end;

////////////////////////////////////////////////////////////////////////////////

Procedure TGeoJSONReaderTests.Setup;
begin
  FDir := TPath.Combine(TPath.GetTempPath, 'GISlibGeoJSONReader' + TGUID.NewGuid.ToString);
  TDirectory.CreateDirectory(FDir);
end;

Procedure TGeoJSONReaderTests.TearDown;
begin
  TDirectory.Delete(FDir, true);
end;

Procedure TGeoJSONReaderTests.ReadAll(const Json: String; out Shapes: TArray<TGISShape>; out Properties: TArray<TGISShapeProperties>);
var
  Shape: TGISShape;
  Props: TGISShapeProperties;
begin
  var FileName := TPath.Combine(FDir, 'Features.geojson');
  TFile.WriteAllText(FileName, Json);
  Shapes := [];
  Properties := [];
  var Reader := TGeoJSONReader.Create(FileName);
  try
    while Reader.ReadShape(Shape, Props) do
    begin
      Shapes := Shapes + [Shape];
      Properties := Properties + [Props];
    end;
  finally
    Reader.Free;
  end;
end;

Function TGeoJSONReaderTests.Collection(const Geometry: String; const Properties: String = '{}'): String;
begin
  Result := '{"type":"FeatureCollection","features":[' +
            '{"type":"Feature","geometry":' + Geometry + ',"properties":' + Properties + '}]}';
end;

Procedure TGeoJSONReaderTests.PropertyValues_KeepTheirTypes;
var
  Shapes: TArray<TGISShape>;
  Properties: TArray<TGISShapeProperties>;
begin
  ReadAll(Collection('{"type":"Point","coordinates":[1,2]}',
                     '{"i":3,"f":2.5,"b":true,"s":"text","n":null}'), Shapes, Properties);
  Assert.AreEqual(1, Integer(Length(Shapes)));
  var Props := Properties[0];
  Assert.AreEqual(5, Integer(Length(Props)), 'Property count');
  Assert.AreEqual(3, Integer(Props.ValueFromName['i']), 'Whole number');
  Assert.AreEqual(2.5, Double(Props.ValueFromName['f']), 1e-12, 'Fraction');
  Assert.IsTrue(Boolean(Props.ValueFromName['b']), 'Boolean');
  Assert.AreEqual('text', String(Props.ValueFromName['s']), 'Text');
  Assert.IsTrue(VarIsNull(Props.ValueFromName['n']), 'Null');
end;

Procedure TGeoJSONReaderTests.MultiPoint_IsOnePointsShape;
var
  Shapes: TArray<TGISShape>;
  Properties: TArray<TGISShapeProperties>;
begin
  ReadAll(Collection('{"type":"MultiPoint","coordinates":[[1,2],[3,4],[5,6]]}'), Shapes, Properties);
  Assert.AreEqual(1, Integer(Length(Shapes)));
  Assert.AreEqual(Ord(stPoint), Ord(Shapes[0].ShapeType), 'Shape type');
  Assert.AreEqual(3, Shapes[0].Parts[0].Count, 'Points');
  Assert.AreEqual(4.0, Shapes[0][0,1].Y, 1e-12, 'Second point Y');
end;

Procedure TGeoJSONReaderTests.MultiLineString_IsOneShapeWithAPartPerLine;
var
  Shapes: TArray<TGISShape>;
  Properties: TArray<TGISShapeProperties>;
begin
  ReadAll(Collection('{"type":"MultiLineString","coordinates":[[[0,0],[1,1]],[[2,2],[3,3],[4,4]]]}'), Shapes, Properties);
  Assert.AreEqual(1, Integer(Length(Shapes)));
  Assert.AreEqual(Ord(stLine), Ord(Shapes[0].ShapeType), 'Shape type');
  Assert.AreEqual(2, Shapes[0].Count, 'Parts');
  Assert.AreEqual(3, Shapes[0].Parts[1].Count, 'Points of the second part');
end;

Procedure TGeoJSONReaderTests.MultiPolygon_IsOneShapeWithAllRings;
var
  Shapes: TArray<TGISShape>;
  Properties: TArray<TGISShapeProperties>;
begin
  ReadAll(Collection('{"type":"MultiPolygon","coordinates":[' +
                     '[[[0,0],[1,0],[1,1],[0,1],[0,0]]],' +
                     '[[[5,5],[9,5],[9,9],[5,9],[5,5]],[[6,6],[7,6],[7,7],[6,7],[6,6]]]]}'), Shapes, Properties);
  Assert.AreEqual(1, Integer(Length(Shapes)));
  Assert.AreEqual(Ord(stPolygon), Ord(Shapes[0].ShapeType), 'Shape type');
  Assert.AreEqual(3, Shapes[0].Count, 'Rings of both polygons');
end;

Procedure TGeoJSONReaderTests.NullGeometry_IsAnEmptyShapeWithItsProperties;
// RFC 7946 allows a feature without geometry
var
  Shapes: TArray<TGISShape>;
  Properties: TArray<TGISShapeProperties>;
begin
  ReadAll(Collection('null', '{"name":"nowhere"}'), Shapes, Properties);
  Assert.AreEqual(1, Integer(Length(Shapes)), 'The feature is read');
  Assert.IsTrue(Shapes[0].Empty, 'with an empty shape');
  Assert.AreEqual('nowhere', String(Properties[0].ValueFromName['name']), 'and its properties');
end;

Procedure TGeoJSONReaderTests.GeometryCollection_Raises;
var
  Shapes: TArray<TGISShape>;
  Properties: TArray<TGISShapeProperties>;
begin
  Assert.WillRaise(Procedure begin
    ReadAll(Collection('{"type":"GeometryCollection","geometries":[{"type":"Point","coordinates":[1,2]}]}'), Shapes, Properties)
  end, Exception);
end;

Procedure TGeoJSONReaderTests.NotAFeatureCollection_Raises;
var
  Shapes: TArray<TGISShape>;
  Properties: TArray<TGISShapeProperties>;
begin
  Assert.WillRaise(Procedure begin ReadAll('[1,2,3]', Shapes, Properties) end, Exception);
end;

Procedure TGeoJSONReaderTests.EndOfFile_AfterTheLastFeature;
var
  Shape: TGISShape;
  Props: TGISShapeProperties;
begin
  var FileName := TPath.Combine(FDir, 'Features.geojson');
  TFile.WriteAllText(FileName, Collection('{"type":"Point","coordinates":[1,2]}'));
  var Reader := TGeoJSONReader.Create(FileName);
  try
    Assert.IsFalse(Reader.EndOfFile, 'Before the feature');
    Assert.IsTrue(Reader.ReadShape(Shape, Props));
    Assert.IsTrue(Reader.EndOfFile, 'After the feature');
    Assert.IsFalse(Reader.ReadShape(Shape, Props), 'Nothing more is read');
  finally
    Reader.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TESRIShapeFileReaderTests);
  TDUnitX.RegisterTestFixture(TESRIShapeFileEncodingTests);
  TDUnitX.RegisterTestFixture(TESRIShapeFileReaderFileTests);
  TDUnitX.RegisterTestFixture(TGeoJSONReaderEncodingTests);
  TDUnitX.RegisterTestFixture(TGeoJSONReaderTests);

end.

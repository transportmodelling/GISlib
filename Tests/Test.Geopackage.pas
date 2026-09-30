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
    // The geometry blob a layer writer stores for a shape
    Function WrittenGeometry(const Shape: TGISShape): TBytes;
    Function Int32At(const Bytes: TBytes; const Position: Integer): Int32;
    Function DoubleAt(const Bytes: TBytes; const Position: Integer): Double;
  public
    // Reader tests
    [Test] Procedure LayerNames_ContainsExpectedLayer;
    [Test] Procedure LayerNames_ReturnsNonEmptyList;
    [Test] Procedure Reader_ReadsNonZeroShapeCount;
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
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

uses
  System.IOUtils, Data.DB, FireDAC.Comp.Client;

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

Procedure TGeopackageTests.Reader_ReadsNonZeroShapeCount;
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
      Assert.IsTrue(Count > 0, 'Reader should return at least one shape');
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
begin
  CheckFileExists;
  Pkg := TGeopackage.Create(GpkgFile);
  try
    Reader := Pkg.CreateReader(GpkgLayerName);
    try
      while Reader.ReadShape(Shape, Props) do
        Assert.AreEqual(Ord(stPolygon), Ord(Shape.ShapeType), 'Expected polygon shape type');
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
var
  Shape: TGISShape;
  Props: TGISShapeProperties;
  Written, Read: Integer;
begin
  if not FileExists(DataPath + 'Provincies_dutch_grid.shp') then
    Assert.IsTrue(FileExists(DataPath + 'Provincies_dutch_grid.shp'),
      'Test requires Data\Provincies_dutch_grid.shp');
  DeleteTempFile;

  // Write all shapefile shapes to a new GeoPackage
  Written := 0;
  var Pkg := TGeopackage.Create(TempFile, gpReadWrite);
  try
    var Writer := Pkg.CreateWriter;
    try
      var LW := Writer.CreateLayerWriter('provinces', 28992);
      var ShpReader := TESRIShapeFileReader.Create(DataPath + 'Provincies_dutch_grid.shp');
      try
        while ShpReader.ReadShape(Shape, Props) do
        begin
          LW.WriteShape(Shape, Props);
          Inc(Written);
        end;
      finally
        ShpReader.Free;
      end;
      LW.Free;
    finally
      Writer.Free;
    end;
  finally
    Pkg.Free;
  end;

  // Read back and verify count
  Read := 0;
  Pkg := TGeopackage.Create(TempFile);
  try
    var Reader := Pkg.CreateReader('provinces');
    try
      while Reader.ReadShape(Shape, Props) do
        Inc(Read);
    finally
      Reader.Free;
    end;
  finally
    Pkg.Free;
  end;

  Assert.AreEqual(Written, Read, 'Round-trip shape count must match');
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

initialization
  TDUnitX.RegisterTestFixture(TGeopackageTests);

end.

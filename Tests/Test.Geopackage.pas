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
  DUnitX.TestFramework, GIS, GIS.Shapes, GIS.Shapes.ESRI, GIS.Shapes.Geopackage,
  GIS.CoordConv.WGS84;

const
  GpkgLayerName = 'Provincies';

type
  [TestFixture]
  TGeopackageTests = class
  private
    function DataPath: String;
    function GpkgFile: String;
    procedure CheckFileExists;
    function  TempFile: String;
    procedure DeleteTempFile;
  public
    // Reader tests
    [Test] procedure LayerNames_ContainsExpectedLayer;
    [Test] procedure LayerNames_ReturnsNonEmptyList;
    [Test] procedure Reader_ReadsNonZeroShapeCount;
    [Test] procedure Reader_AllShapesArePolygons;
    [Test] procedure Reader_BoundingBoxWithinNetherlandsDutchGrid;
    [Test] procedure Reader_ShapeCountMatchesShapefile;

    // Writer tests (no external data file needed)
    [Test] procedure Writer_CreatesFile;
    [Test] procedure Writer_LayerAppearsInLayerNames;
    [Test] procedure Writer_RoundTrip_Point;
    [Test] procedure Writer_RoundTrip_Polygon;
    [Test] procedure Writer_RoundTrip_ShapeCount;
    [Test] procedure Writer_RoundTrip_ProvincesShapefile;
    [Test] procedure Writer_ConverterOverload_StoresCorrectSRS;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

uses
  System.SysUtils, System.IOUtils, FireDAC.Comp.Client;

function TGeopackageTests.DataPath: String;
begin
  Result := ExpandFileName(ExtractFilePath(ParamStr(0)) + '..\Data\');
end;

function TGeopackageTests.GpkgFile: String;
begin
  Result := DataPath + 'Provincies.gpkg';
end;

procedure TGeopackageTests.CheckFileExists;
begin
  Assert.IsTrue(FileExists(GpkgFile),
    'Test requires Data\Provincies.gpkg - create it with: ' +
    'ogr2ogr -f GPKG Data/Provincies.gpkg Data/Provincies_dutch_grid.shp');
end;

procedure TGeopackageTests.LayerNames_ReturnsNonEmptyList;
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

procedure TGeopackageTests.LayerNames_ContainsExpectedLayer;
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

procedure TGeopackageTests.Reader_ReadsNonZeroShapeCount;
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

procedure TGeopackageTests.Reader_AllShapesArePolygons;
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

procedure TGeopackageTests.Reader_BoundingBoxWithinNetherlandsDutchGrid;
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

procedure TGeopackageTests.Reader_ShapeCountMatchesShapefile;
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

////////////////////////////////////////////////////////////////////////////////
// Writer helpers
////////////////////////////////////////////////////////////////////////////////

function TGeopackageTests.TempFile: String;
begin
  Result := TPath.GetTempPath + 'TestGeopackage_tmp.gpkg';
end;

procedure TGeopackageTests.DeleteTempFile;
begin
  if FileExists(TempFile) then
    DeleteFile(TempFile);
end;

////////////////////////////////////////////////////////////////////////////////
// Writer tests
////////////////////////////////////////////////////////////////////////////////

procedure TGeopackageTests.Writer_CreatesFile;
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

procedure TGeopackageTests.Writer_LayerAppearsInLayerNames;
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

procedure TGeopackageTests.Writer_RoundTrip_Point;
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

procedure TGeopackageTests.Writer_RoundTrip_Polygon;
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

procedure TGeopackageTests.Writer_RoundTrip_ShapeCount;
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

procedure TGeopackageTests.Writer_RoundTrip_ProvincesShapefile;
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

procedure TGeopackageTests.Writer_ConverterOverload_StoresCorrectSRS;
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

initialization
  TDUnitX.RegisterTestFixture(TGeopackageTests);

end.

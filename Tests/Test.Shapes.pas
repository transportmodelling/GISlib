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
  DUnitX.TestFramework, GIS, GIS.Shapes, GIS.Shapes.ESRI;

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

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

uses System.SysUtils, System.IOUtils;

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
      if ShapeCount = 1 then
        Result := Shape.ShapeType;
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
  Assert.IsTrue(Count > 0, 'Should read at least one shape');
end;

Procedure TESRIShapeFileReaderTests.DutchGrid_AllShapesArePolygons;
var
  Reader: TESRIShapeFileReader;
  Shape: TGISShape;
  Props: TGISShapeProperties;
begin
  Reader := TESRIShapeFileReader.Create(DataPath + 'Provincies_dutch_grid.shp');
  try
    while Reader.ReadShape(Shape, Props) do
      Assert.AreEqual(Ord(stPolygon), Ord(Shape.ShapeType), 'Every shape must be a polygon');
  finally
    Reader.Free;
  end;
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
  Assert.IsTrue(Count > 0, 'Should read at least one shape');
end;

Procedure TESRIShapeFileReaderTests.WGS84_AllShapesArePolygons;
var
  Reader: TESRIShapeFileReader;
  Shape: TGISShape;
  Props: TGISShapeProperties;
begin
  Reader := TESRIShapeFileReader.Create(DataPath + 'Provincies_wsg84.shp');
  try
    while Reader.ReadShape(Shape, Props) do
      Assert.AreEqual(Ord(stPolygon), Ord(Shape.ShapeType), 'Every shape must be a polygon');
  finally
    Reader.Free;
  end;
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

initialization
  TDUnitX.RegisterTestFixture(TESRIShapeFileReaderTests);
  TDUnitX.RegisterTestFixture(TESRIShapeFileEncodingTests);

end.

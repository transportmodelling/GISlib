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
    function DataPath: String;
    function CountAndBounds(const FileName: String;
      out ShapeCount: Integer; out BB: TCoordinateRect): TShapeType;
  public
    // Dutch Grid shapefile
    [Test] procedure DutchGrid_ReadsExpectedShapeCount;
    [Test] procedure DutchGrid_AllShapesArePolygons;
    [Test] procedure DutchGrid_BoundingBoxWithinNetherlandsDutchGrid;

    // WGS84 shapefile
    [Test] procedure WGS84_ReadsExpectedShapeCount;
    [Test] procedure WGS84_AllShapesArePolygons;
    [Test] procedure WGS84_BoundingBoxWithinNetherlandsWGS84;

    // Both files should read the same number of shapes (same provinces, different CRS)
    [Test] procedure BothFiles_SameShapeCount;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

uses System.SysUtils;

function TESRIShapeFileReaderTests.DataPath: String;
begin
  Result := ExpandFileName(ExtractFilePath(ParamStr(0)) + '..\Data\');
end;

function TESRIShapeFileReaderTests.CountAndBounds(const FileName: String;
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

procedure TESRIShapeFileReaderTests.DutchGrid_ReadsExpectedShapeCount;
var
  Count: Integer;
  BB: TCoordinateRect;
begin
  CountAndBounds(DataPath + 'Provincies_dutch_grid.shp', Count, BB);
  Assert.IsTrue(Count > 0, 'Should read at least one shape');
end;

procedure TESRIShapeFileReaderTests.DutchGrid_AllShapesArePolygons;
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

procedure TESRIShapeFileReaderTests.DutchGrid_BoundingBoxWithinNetherlandsDutchGrid;
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

procedure TESRIShapeFileReaderTests.WGS84_ReadsExpectedShapeCount;
var
  Count: Integer;
  BB: TCoordinateRect;
begin
  CountAndBounds(DataPath + 'Provincies_wsg84.shp', Count, BB);
  Assert.IsTrue(Count > 0, 'Should read at least one shape');
end;

procedure TESRIShapeFileReaderTests.WGS84_AllShapesArePolygons;
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

procedure TESRIShapeFileReaderTests.WGS84_BoundingBoxWithinNetherlandsWGS84;
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

procedure TESRIShapeFileReaderTests.BothFiles_SameShapeCount;
var
  CountDG, CountWGS: Integer;
  BB: TCoordinateRect;
begin
  CountAndBounds(DataPath + 'Provincies_dutch_grid.shp', CountDG, BB);
  CountAndBounds(DataPath + 'Provincies_wsg84.shp',      CountWGS, BB);
  Assert.AreEqual(CountDG, CountWGS, 'Both files should contain the same number of provinces');
end;

initialization
  TDUnitX.RegisterTestFixture(TESRIShapeFileReaderTests);

end.

unit Test.Writers;

////////////////////////////////////////////////////////////////////////////////
//
// Author: Jaap Baak
// https://github.com/transportmodelling/GISlib
//
// Test suite generated with assistance from Claude Sonnet 4.6
//
// Round-trip tests for TGeoJSONWriter and TESRIPolygonShapeFileWriter.
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
interface
////////////////////////////////////////////////////////////////////////////////

uses
  DUnitX.TestFramework, GIS, GIS.Shapes, GIS.Shapes.ESRI, GIS.Shapes.GeoJSON;

type
  [TestFixture]
  TGeoJSONWriterTests = class
  private
    function TempFile: String;
    procedure DeleteTempFile;
  public
    [Test] procedure WritePoint_RoundTrip;
    [Test] procedure WritePolygon_RoundTrip;
    [Test] procedure WritePolygon_RingClosedAutomatically;
    [Test] procedure WriteLineString_RoundTrip;
    [Test] procedure WriteMultipleShapes_AllRead;
  end;

  [TestFixture]
  TESRIWriterTests = class
  private
    function TempBase: String;
    procedure DeleteTempFiles;
  public
    [Test] procedure WritePolygon_RoundTrip;
    [Test] procedure WriteMultiplePolygons_CountMatches;
    [Test] procedure WriteLineString_RoundTrip;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

uses
  System.SysUtils, System.IOUtils;

{ TGeoJSONWriterTests }

function TGeoJSONWriterTests.TempFile: String;
begin
  Result := TPath.GetTempPath + 'TestWriter_tmp.geojson';
end;

procedure TGeoJSONWriterTests.DeleteTempFile;
begin
  if FileExists(TempFile) then DeleteFile(TempFile);
end;

procedure TGeoJSONWriterTests.WritePoint_RoundTrip;
var
  Written, Read: TGISShape;
  Props: TGISShapeProperties;
begin
  DeleteTempFile;
  Written.AssignPoint(5.0, 52.0);

  var W := TGeoJSONWriter.Create(TempFile);
  try
    W.WriteShape(Written);
  finally
    W.Free;
  end;

  var R := TGeoJSONReader.Create(TempFile);
  try
    Assert.IsTrue(R.ReadShape(Read, Props), 'Should read one shape');
    Assert.AreEqual(Ord(stPoint), Ord(Read.ShapeType), 'Shape type');
    Assert.AreEqual(5.0,  Read[0,0].X, 1e-10, 'X coordinate');
    Assert.AreEqual(52.0, Read[0,0].Y, 1e-10, 'Y coordinate');
    Assert.IsFalse(R.ReadShape(Read, Props), 'Should be only one shape');
  finally
    R.Free;
  end;
  DeleteTempFile;
end;

procedure TGeoJSONWriterTests.WritePolygon_RoundTrip;
var
  Written, Read: TGISShape;
  Props: TGISShapeProperties;
  Pts: array[0..4] of TCoordinate;
begin
  DeleteTempFile;
  // Closed ring (first = last)
  Pts[0] := TCoordinate.Create(0, 0);
  Pts[1] := TCoordinate.Create(1, 0);
  Pts[2] := TCoordinate.Create(1, 1);
  Pts[3] := TCoordinate.Create(0, 1);
  Pts[4] := TCoordinate.Create(0, 0);  // close
  Written.AssignPolygon(Pts);

  var W := TGeoJSONWriter.Create(TempFile);
  try
    W.WriteShape(Written);
  finally
    W.Free;
  end;

  var R := TGeoJSONReader.Create(TempFile);
  try
    Assert.IsTrue(R.ReadShape(Read, Props));
    Assert.AreEqual(Ord(stPolygon), Ord(Read.ShapeType), 'Shape type');
    Assert.IsTrue(Read.Count > 0, 'At least one ring');
  finally
    R.Free;
  end;
  DeleteTempFile;
end;

procedure TGeoJSONWriterTests.WritePolygon_RingClosedAutomatically;
var
  Written, Read: TGISShape;
  Props: TGISShapeProperties;
  OpenPts: array[0..3] of TCoordinate;
begin
  DeleteTempFile;
  // Deliberately open ring (first <> last) - writer should close it
  OpenPts[0] := TCoordinate.Create(0, 0);
  OpenPts[1] := TCoordinate.Create(2, 0);
  OpenPts[2] := TCoordinate.Create(2, 2);
  OpenPts[3] := TCoordinate.Create(0, 2);
  Written.AssignPolygon(OpenPts);

  var W := TGeoJSONWriter.Create(TempFile);
  try
    W.WriteShape(Written);
  finally
    W.Free;
  end;

  var R := TGeoJSONReader.Create(TempFile);
  try
    Assert.IsTrue(R.ReadShape(Read, Props));
    Assert.AreEqual(Ord(stPolygon), Ord(Read.ShapeType));
    // Ring must be closed: last point of first part should equal first point
    var Ring := Read.Parts[0];
    Assert.AreEqual(Ring[0].X, Ring[Ring.Count-1].X, 1e-10, 'Ring X closed');
    Assert.AreEqual(Ring[0].Y, Ring[Ring.Count-1].Y, 1e-10, 'Ring Y closed');
  finally
    R.Free;
  end;
  DeleteTempFile;
end;

procedure TGeoJSONWriterTests.WriteLineString_RoundTrip;
var
  Written, Read: TGISShape;
  Props: TGISShapeProperties;
  LinePts: array[0..2] of TCoordinate;
begin
  DeleteTempFile;
  LinePts[0] := TCoordinate.Create(0, 0);
  LinePts[1] := TCoordinate.Create(5, 5);
  LinePts[2] := TCoordinate.Create(10, 0);
  Written.AssignLine(LinePts);

  var W := TGeoJSONWriter.Create(TempFile);
  try
    W.WriteShape(Written);
  finally
    W.Free;
  end;

  var R := TGeoJSONReader.Create(TempFile);
  try
    Assert.IsTrue(R.ReadShape(Read, Props));
    Assert.AreEqual(Ord(stLine), Ord(Read.ShapeType), 'Shape type');
    Assert.AreEqual(3, Read.Parts[0].Count, 'Point count');
    Assert.AreEqual(5.0, Read[0,1].X, 1e-10, 'Mid X');
    Assert.AreEqual(5.0, Read[0,1].Y, 1e-10, 'Mid Y');
  finally
    R.Free;
  end;
  DeleteTempFile;
end;

procedure TGeoJSONWriterTests.WriteMultipleShapes_AllRead;
var
  Shape, Read: TGISShape;
  Props: TGISShapeProperties;
  Count: Integer;
  Pts: array[0..3] of TCoordinate;
begin
  DeleteTempFile;

  var W := TGeoJSONWriter.Create(TempFile);
  try
    Shape.AssignPoint(1, 1); W.WriteShape(Shape);
    Shape.AssignPoint(2, 2); W.WriteShape(Shape);
    Shape.AssignPoint(3, 3); W.WriteShape(Shape);
  finally
    W.Free;
  end;

  Count := 0;
  var R := TGeoJSONReader.Create(TempFile);
  try
    while R.ReadShape(Read, Props) do Inc(Count);
  finally
    R.Free;
  end;
  Assert.AreEqual(3, Count, 'All three shapes should be read back');
  DeleteTempFile;
end;

{ TESRIWriterTests }

function TESRIWriterTests.TempBase: String;
begin
  Result := TPath.GetTempPath + 'TestESRIWriter_tmp';
end;

procedure TESRIWriterTests.DeleteTempFiles;
begin
  for var Ext in ['.shp', '.shx', '.dbf'] do
    if FileExists(TempBase + Ext) then DeleteFile(TempBase + Ext);
end;

procedure TESRIWriterTests.WritePolygon_RoundTrip;
var
  Read: TGISShape;
  Props: TGISShapeProperties;
  Ring: TMultiPoint;
begin
  DeleteTempFiles;
  SetLength(Ring, 5);
  Ring[0] := TCoordinate.Create(0, 0);
  Ring[1] := TCoordinate.Create(10, 0);
  Ring[2] := TCoordinate.Create(10, 10);
  Ring[3] := TCoordinate.Create(0, 10);
  Ring[4] := TCoordinate.Create(0, 0);  // closed

  var W := TESRIPolygonShapeFileWriter.Create(TempBase + '.shp', []);
  try
    W.Write(Ring, []);
  finally
    W.Free;
  end;

  var R := TESRIShapeFileReader.Create(TempBase + '.shp');
  try
    Assert.IsTrue(R.ReadShape(Read, Props));
    Assert.AreEqual(Ord(stPolygon), Ord(Read.ShapeType), 'Shape type');
    Assert.AreEqual(10.0, Read[0,1].X, 1e-10, 'Second point X');
    Assert.IsFalse(R.ReadShape(Read, Props), 'Only one shape expected');
  finally
    R.Free;
  end;
  DeleteTempFiles;
end;

procedure TESRIWriterTests.WriteMultiplePolygons_CountMatches;
const
  N = 4;
var
  Read: TGISShape;
  Props: TGISShapeProperties;
  Ring: TMultiPoint;
  Count: Integer;
begin
  DeleteTempFiles;
  SetLength(Ring, 5);

  var W := TESRIPolygonShapeFileWriter.Create(TempBase + '.shp', []);
  try
    for var I := 1 to N do
    begin
      Ring[0] := TCoordinate.Create(I,   I);
      Ring[1] := TCoordinate.Create(I+1, I);
      Ring[2] := TCoordinate.Create(I+1, I+1);
      Ring[3] := TCoordinate.Create(I,   I+1);
      Ring[4] := TCoordinate.Create(I,   I);  // closed
      W.Write(Ring, []);
    end;
  finally
    W.Free;
  end;

  Count := 0;
  var R := TESRIShapeFileReader.Create(TempBase + '.shp');
  try
    while R.ReadShape(Read, Props) do Inc(Count);
  finally
    R.Free;
  end;
  Assert.AreEqual(N, Count, 'Written and read polygon counts must match');
  DeleteTempFiles;
end;

procedure TESRIWriterTests.WriteLineString_RoundTrip;
var
  Read: TGISShape;
  Props: TGISShapeProperties;
  Line: TMultiPoint;
begin
  DeleteTempFiles;
  SetLength(Line, 3);
  Line[0] := TCoordinate.Create(0, 0);
  Line[1] := TCoordinate.Create(5, 5);
  Line[2] := TCoordinate.Create(10, 0);

  var W := TESRIPolyLineShapeFileWriter.Create(TempBase + '.shp', []);
  try
    W.Write(Line, []);
  finally
    W.Free;
  end;

  var R := TESRIShapeFileReader.Create(TempBase + '.shp');
  try
    Assert.IsTrue(R.ReadShape(Read, Props));
    Assert.AreEqual(Ord(stLine), Ord(Read.ShapeType), 'Shape type');
    Assert.AreEqual(3, Read.Parts[0].Count, 'Point count');
  finally
    R.Free;
  end;
  DeleteTempFiles;
end;

initialization
  TDUnitX.RegisterTestFixture(TGeoJSONWriterTests);
  TDUnitX.RegisterTestFixture(TESRIWriterTests);

end.

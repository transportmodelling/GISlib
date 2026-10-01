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
  System.JSON, System.Generics.Collections, DUnitX.TestFramework, DBF,
  GIS, GIS.Shapes, GIS.Shapes.Polygon, GIS.Shapes.ESRI, GIS.Shapes.GeoJSON;

type
  [TestFixture]
  TGeoJSONWriterTests = class
  private
    Function TempFile: String;
    Procedure DeleteTempFile;
    // The document WriteShape writes for a shape; the caller frees it
    Function WrittenDocument(const Shape: TGISShape): TJSONValue;
  public
    [Test] Procedure WritePoint_RoundTrip;
    [Test] Procedure WritePolygon_RoundTrip;
    [Test] Procedure WritePolygon_RingClosedAutomatically;
    [Test] Procedure WriteLineString_RoundTrip;
    [Test] Procedure WriteMultipleShapes_AllRead;
    [Test] Procedure WriteShape_TwoOuterRings_WritesMultiPolygon;
    [Test] Procedure WriteShape_HoleListedFirst_WritesOuterRingFirst;
    [Test] Procedure WriteShape_WithProperties_ReadsThemBack;
  end;

  [TestFixture]
  TESRIWriterTests = class
  private
    Function TempBase: String;
    Procedure DeleteTempFiles;
    Function BigEndianHeaderField(const FileName: String): Integer;
    Function SignedArea(const Ring: TShapePart): Double;
  public
    [Test] Procedure WritePolygon_RoundTrip;
    [Test] Procedure WriteMultiplePolygons_CountMatches;
    [Test] Procedure WriteLineString_RoundTrip;
    [Test] Procedure FileHeader_SizeFields_MatchFileSizes;
    [Test] Procedure WritePoint_RoundTrip;
    [Test] Procedure WriteMultiPoint_RoundTrip;
    [Test] Procedure WriteMultiPartPolyLine_RoundTrip;
    [Test] Procedure WritePolygonWithHole_RoundTrip;
    [Test] Procedure WritePolygon_UnclosedRing_IsClosed;
    [Test] Procedure WritePolygon_SinglePoint_Raises;
    [Test] Procedure WriteWithFields_ReadsTheValuesBack;
    [Test] Procedure WriteValuesWithoutFields_Raises;
    [Test] Procedure WritePolygon_OuterRingIsWrittenClockwise;
    [Test] Procedure WritePolygonWithHole_HoleIsWrittenCounterClockwise;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

uses
  System.SysUtils, System.Variants, System.IOUtils;

////////////////////////////////////////////////////////////////////////////////

Function TGeoJSONWriterTests.TempFile: String;
begin
  Result := TPath.GetTempPath + 'TestWriter_tmp.geojson';
end;

Procedure TGeoJSONWriterTests.DeleteTempFile;
begin
  if FileExists(TempFile) then DeleteFile(TempFile);
end;

Function TGeoJSONWriterTests.WrittenDocument(const Shape: TGISShape): TJSONValue;
begin
  DeleteTempFile;
  var W := TGeoJSONWriter.Create(TempFile);
  try
    W.WriteShape(Shape);
  finally
    W.Free;
  end;
  Result := TJSONObject.ParseJSONValue(TFile.ReadAllText(TempFile));
  DeleteTempFile;
end;

Procedure TGeoJSONWriterTests.WritePoint_RoundTrip;
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

Procedure TGeoJSONWriterTests.WritePolygon_RoundTrip;
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
    Assert.AreEqual(1, Read.Count, 'One ring');
    Assert.AreEqual(5, Read.Parts[0].Count, 'Points of the ring');
    Assert.AreEqual(1.0, Read[0,1].X, 1e-10, 'Second point X');
  finally
    R.Free;
  end;
  DeleteTempFile;
end;

Procedure TGeoJSONWriterTests.WritePolygon_RingClosedAutomatically;
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

Procedure TGeoJSONWriterTests.WriteLineString_RoundTrip;
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

Procedure TGeoJSONWriterTests.WriteMultipleShapes_AllRead;
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

Procedure TGeoJSONWriterTests.WriteShape_TwoOuterRings_WritesMultiPolygon;
// Two outer rings in one Polygon would read as an outer ring with a hole
var
  Parts: TMultiPoints;
  Shape: TGISShape;
begin
  SetLength(Parts, 2);
  Parts[0] := [TCoordinate.Create(0, 0), TCoordinate.Create(1, 0), TCoordinate.Create(1, 1), TCoordinate.Create(0, 1)];
  Parts[1] := [TCoordinate.Create(3, 0), TCoordinate.Create(4, 0), TCoordinate.Create(4, 1), TCoordinate.Create(3, 1)];
  Shape.AssignPolyPolygon(Parts);
  var Document := WrittenDocument(Shape);
  try
    Assert.AreEqual('MultiPolygon', Document.GetValue<String>('features[0].geometry.type'));
    Assert.AreEqual(2, Document.GetValue<TJSONArray>('features[0].geometry.coordinates').Count, 'Polygons');
  finally
    Document.Free;
  end;
end;

Procedure TGeoJSONWriterTests.WriteShape_HoleListedFirst_WritesOuterRingFirst;
// GeoJSON takes the first ring of a polygon as its outer ring, whatever order the shape holds them in
var
  Parts: TMultiPoints;
  Shape: TGISShape;
begin
  SetLength(Parts, 2);
  Parts[0] := [TCoordinate.Create(-1, -1), TCoordinate.Create(1, -1), TCoordinate.Create(1, 1), TCoordinate.Create(-1, 1)];
  Parts[1] := [TCoordinate.Create(-5, -5), TCoordinate.Create(5, -5), TCoordinate.Create(5, 5), TCoordinate.Create(-5, 5)];
  Shape.AssignPolyPolygon(Parts);
  var Document := WrittenDocument(Shape);
  try
    Assert.AreEqual('Polygon', Document.GetValue<String>('features[0].geometry.type'));
    Assert.AreEqual(2, Document.GetValue<TJSONArray>('features[0].geometry.coordinates').Count, 'Rings');
    Assert.AreEqual(-5.0, Document.GetValue<Double>('features[0].geometry.coordinates[0][0][0]'), 1e-12, 'First ring starts at the outer ring');
  finally
    Document.Free;
  end;
end;

Procedure TGeoJSONWriterTests.WriteShape_WithProperties_ReadsThemBack;
var
  Written, Read: TGISShape;
  Props: TGISShapeProperties;
begin
  DeleteTempFile;
  Written.AssignPoint(5.4, 52.2);
  var W := TGeoJSONWriter.Create(TempFile);
  try
    W.WriteShape(Written, [TPair<String,Variant>.Create('name', 'Amersfoort'),
                           TPair<String,Variant>.Create('order', 3)]);
  finally
    W.Free;
  end;
  var R := TGeoJSONReader.Create(TempFile);
  try
    Assert.IsTrue(R.ReadShape(Read, Props));
    Assert.AreEqual('Amersfoort', String(Props.ValueFromName['name']));
    Assert.AreEqual(3, Integer(Props.ValueFromName['order']));
  finally
    R.Free;
  end;
  DeleteTempFile;
end;

////////////////////////////////////////////////////////////////////////////////

Function TESRIWriterTests.TempBase: String;
begin
  Result := TPath.GetTempPath + 'TestESRIWriter_tmp';
end;

Procedure TESRIWriterTests.DeleteTempFiles;
begin
  for var Ext in ['.shp', '.shx', '.dbf'] do
    if FileExists(TempBase + Ext) then DeleteFile(TempBase + Ext);
end;

Function TESRIWriterTests.BigEndianHeaderField(const FileName: String): Integer;
// Returns the big-endian file size field (in 16-bit words) at offset 24 of
// a shape or index file header
begin
  var Bytes := TFile.ReadAllBytes(FileName);
  Result := (Integer(Bytes[24]) shl 24) + (Integer(Bytes[25]) shl 16) +
            (Integer(Bytes[26]) shl 8) + Integer(Bytes[27]);
end;

Procedure TESRIWriterTests.WritePolygon_RoundTrip;
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
    // The ring was given counter-clockwise and is written clockwise, from the same first point
    Assert.AreEqual(10.0, Read[0,1].Y, 1e-10, 'Second point Y');
    Assert.IsFalse(R.ReadShape(Read, Props), 'Only one shape expected');
  finally
    R.Free;
  end;
  DeleteTempFiles;
end;

Procedure TESRIWriterTests.WriteMultiplePolygons_CountMatches;
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

Procedure TESRIWriterTests.WriteLineString_RoundTrip;
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

Procedure TESRIWriterTests.FileHeader_SizeFields_MatchFileSizes;
// Two three-point polylines give a 308 byte shape file, so the big-endian
// size field holds 154: a value with its low byte above 127, which the
// byte swapping must handle without signed overflow
var
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
    W.Write(Line, []);
  finally
    W.Free;
  end;

  Assert.AreEqual(308, Integer(TFile.GetSize(TempBase + '.shp')), 'Shape file size');
  Assert.AreEqual(154, BigEndianHeaderField(TempBase + '.shp'), 'Shape file size field');
  Assert.AreEqual(Integer(TFile.GetSize(TempBase + '.shx')) div 2,
                  BigEndianHeaderField(TempBase + '.shx'), 'Index file size field');
  DeleteTempFiles;
end;

Procedure TESRIWriterTests.WritePoint_RoundTrip;
var
  Read: TGISShape;
  Props: TGISShapeProperties;
begin
  DeleteTempFiles;
  var W := TESRIPointShapeFileWriter.Create(TempBase + '.shp', []);
  try
    W.Write(3, 4, []);
  finally
    W.Free;
  end;
  var R := TESRIShapeFileReader.Create(TempBase + '.shp');
  try
    Assert.IsTrue(R.ReadShape(Read, Props));
    Assert.AreEqual(Ord(stPoint), Ord(Read.ShapeType), 'Shape type');
    Assert.AreEqual(1, Read.Parts[0].Count, 'Point count');
    Assert.AreEqual(3.0, Read[0,0].X, 1e-10, 'X');
    Assert.AreEqual(4.0, Read[0,0].Y, 1e-10, 'Y');
    Assert.IsFalse(R.ReadShape(Read, Props), 'Only one shape expected');
  finally
    R.Free;
  end;
  DeleteTempFiles;
end;

Procedure TESRIWriterTests.WriteMultiPoint_RoundTrip;
var
  Read: TGISShape;
  Props: TGISShapeProperties;
begin
  DeleteTempFiles;
  var W := TESRIMultiPointShapeFileWriter.Create(TempBase + '.shp', []);
  try
    W.Write([TCoordinate.Create(0, 0), TCoordinate.Create(5, 5), TCoordinate.Create(10, 0)], []);
  finally
    W.Free;
  end;
  var R := TESRIShapeFileReader.Create(TempBase + '.shp');
  try
    Assert.IsTrue(R.ReadShape(Read, Props));
    Assert.AreEqual(Ord(stPoint), Ord(Read.ShapeType), 'Shape type');
    Assert.AreEqual(3, Read.Parts[0].Count, 'Point count');
    Assert.AreEqual(5.0, Read[0,1].Y, 1e-10, 'Second point Y');
  finally
    R.Free;
  end;
  DeleteTempFiles;
end;

Procedure TESRIWriterTests.WriteMultiPartPolyLine_RoundTrip;
var
  Read: TGISShape;
  Props: TGISShapeProperties;
  Parts: TMultiPoints;
begin
  DeleteTempFiles;
  SetLength(Parts, 2);
  Parts[0] := [TCoordinate.Create(0, 0), TCoordinate.Create(5, 5)];
  Parts[1] := [TCoordinate.Create(10, 0), TCoordinate.Create(15, 5), TCoordinate.Create(20, 0)];
  var W := TESRIPolyLineShapeFileWriter.Create(TempBase + '.shp', []);
  try
    W.Write(Parts, []);
  finally
    W.Free;
  end;
  var R := TESRIShapeFileReader.Create(TempBase + '.shp');
  try
    Assert.IsTrue(R.ReadShape(Read, Props));
    Assert.AreEqual(Ord(stLine), Ord(Read.ShapeType), 'Shape type');
    Assert.AreEqual(2, Read.Count, 'Part count');
    Assert.AreEqual(2, Read.Parts[0].Count, 'Points of the first part');
    Assert.AreEqual(3, Read.Parts[1].Count, 'Points of the second part');
    Assert.AreEqual(15.0, Read[1,1].X, 1e-10, 'Second point of the second part');
  finally
    R.Free;
  end;
  DeleteTempFiles;
end;

Procedure TESRIWriterTests.WritePolygonWithHole_RoundTrip;
var
  Read: TGISShape;
  Props: TGISShapeProperties;
  Rings: TMultiPoints;
begin
  DeleteTempFiles;
  SetLength(Rings, 2);
  Rings[0] := [TCoordinate.Create(-5, -5), TCoordinate.Create(5, -5), TCoordinate.Create(5, 5), TCoordinate.Create(-5, 5)];
  Rings[1] := [TCoordinate.Create(-1, -1), TCoordinate.Create(1, -1), TCoordinate.Create(1, 1), TCoordinate.Create(-1, 1)];
  var W := TESRIPolygonShapeFileWriter.Create(TempBase + '.shp', []);
  try
    W.Write(Rings, []);
  finally
    W.Free;
  end;
  var R := TESRIShapeFileReader.Create(TempBase + '.shp');
  try
    Assert.IsTrue(R.ReadShape(Read, Props));
    Assert.AreEqual(2, Read.Count, 'Ring count');
    var Polygons := TPolyPolygons.Create(Read);
    Assert.AreEqual(1, Polygons.Count, 'One outer ring');
    Assert.AreEqual(1, Polygons[0].HolesCount, 'with one hole');
  finally
    R.Free;
  end;
  DeleteTempFiles;
end;

Procedure TESRIWriterTests.WritePolygon_UnclosedRing_IsClosed;
var
  Read: TGISShape;
  Props: TGISShapeProperties;
begin
  DeleteTempFiles;
  var W := TESRIPolygonShapeFileWriter.Create(TempBase + '.shp', []);
  try
    W.Write([TCoordinate.Create(0, 0), TCoordinate.Create(10, 0), TCoordinate.Create(10, 10), TCoordinate.Create(0, 10)], []);
  finally
    W.Free;
  end;
  var R := TESRIShapeFileReader.Create(TempBase + '.shp');
  try
    Assert.IsTrue(R.ReadShape(Read, Props));
    Assert.AreEqual(5, Read.Parts[0].Count, 'The closing point is added');
    Assert.AreEqual(Read[0,0].X, Read[0,4].X, 1e-10, 'First and last X');
    Assert.AreEqual(Read[0,0].Y, Read[0,4].Y, 1e-10, 'First and last Y');
  finally
    R.Free;
  end;
  DeleteTempFiles;
end;

Procedure TESRIWriterTests.WritePolygon_SinglePoint_Raises;
begin
  DeleteTempFiles;
  var W := TESRIPolygonShapeFileWriter.Create(TempBase + '.shp', []);
  try
    Assert.WillRaise(Procedure begin W.Write([TCoordinate.Create(0, 0)], []) end, Exception);
  finally
    W.Free;
  end;
  DeleteTempFiles;
end;

Procedure TESRIWriterTests.WriteWithFields_ReadsTheValuesBack;
// One record of every field type, and one of nulls
var
  Read: TGISShape;
  Props: TGISShapeProperties;
begin
  DeleteTempFiles;
  var W := TESRIPointShapeFileWriter.Create(TempBase + '.shp',
    [TDBFField.Create('NAME', 'C', 10, 0, true),
     TDBFField.Create('ORDER', 'N', 5, 0),
     TDBFField.Create('VALUE', 'N', 12, 6, true),
     TDBFField.Create('FLAG', 'L', 1, 0),
     TDBFField.Create('WHEN', 'D', 8, 0)]);
  try
    W.Write(1, 2, ['Amersfoort', 3, 52.2, True, EncodeDate(2026, 10, 1)]);
    W.Write(3, 4, [Null, Null, Null, Null, Null]);
  finally
    W.Free;
  end;
  var R := TESRIShapeFileReader.Create(TempBase + '.shp');
  try
    Assert.AreEqual(2, R.IndexOf('VALUE'), 'Field index');
    Assert.IsTrue(R.ReadShape(Read, Props));
    Assert.AreEqual(5, Integer(Length(Props)), 'Field count');
    Assert.AreEqual('Amersfoort', String(Props.ValueFromName['NAME']));
    Assert.AreEqual(3, Integer(Props.ValueFromName['ORDER']));
    Assert.AreEqual(52.2, Double(Props.ValueFromName['VALUE']), 1e-9);
    Assert.IsTrue(Boolean(Props.ValueFromName['FLAG']), 'Flag');
    Assert.AreEqual(EncodeDate(2026, 10, 1), TDateTime(Props.ValueFromName['WHEN']), 1e-9);
    Assert.IsTrue(R.ReadShape(Read, Props));
    for var Prop in Props do Assert.IsTrue(VarIsNull(Prop.Value), Prop.Key + ' is null');
  finally
    R.Free;
  end;
  DeleteTempFiles;
end;

Procedure TESRIWriterTests.WriteValuesWithoutFields_Raises;
begin
  DeleteTempFiles;
  var W := TESRIPointShapeFileWriter.Create(TempBase + '.shp', []);
  try
    Assert.WillRaise(Procedure begin W.Write(1, 2, [3]) end, Exception);
  finally
    W.Free;
  end;
  DeleteTempFiles;
end;

Function TESRIWriterTests.SignedArea(const Ring: TShapePart): Double;
// Positive for a ring running counter-clockwise, negative for one running clockwise
begin
  Result := 0;
  for var Point := 1 to Ring.Count - 1 do
    Result := Result + Ring[Point-1].X*Ring[Point].Y - Ring[Point].X*Ring[Point-1].Y;
  Result := Result/2;
end;

Procedure TESRIWriterTests.WritePolygon_OuterRingIsWrittenClockwise;
// The format tells outer rings from holes by their direction; this ring is given counter-clockwise
var
  Read: TGISShape;
  Props: TGISShapeProperties;
begin
  DeleteTempFiles;
  var W := TESRIPolygonShapeFileWriter.Create(TempBase + '.shp', []);
  try
    W.Write([TCoordinate.Create(0, 0), TCoordinate.Create(10, 0), TCoordinate.Create(10, 10), TCoordinate.Create(0, 10)], []);
  finally
    W.Free;
  end;
  var R := TESRIShapeFileReader.Create(TempBase + '.shp');
  try
    Assert.IsTrue(R.ReadShape(Read, Props));
    Assert.AreEqual(-100.0, SignedArea(Read.Parts[0]), 1e-9, 'Clockwise, and the same square');
  finally
    R.Free;
  end;
  DeleteTempFiles;
end;

Procedure TESRIWriterTests.WritePolygonWithHole_HoleIsWrittenCounterClockwise;
// The hole is given first, and clockwise; the outer ring second, and counter-clockwise
var
  Read: TGISShape;
  Props: TGISShapeProperties;
  Rings: TMultiPoints;
begin
  DeleteTempFiles;
  SetLength(Rings, 2);
  Rings[0] := [TCoordinate.Create(-1, -1), TCoordinate.Create(-1, 1), TCoordinate.Create(1, 1), TCoordinate.Create(1, -1)];
  Rings[1] := [TCoordinate.Create(-5, -5), TCoordinate.Create(5, -5), TCoordinate.Create(5, 5), TCoordinate.Create(-5, 5)];
  var W := TESRIPolygonShapeFileWriter.Create(TempBase + '.shp', []);
  try
    W.Write(Rings, []);
  finally
    W.Free;
  end;
  var R := TESRIShapeFileReader.Create(TempBase + '.shp');
  try
    Assert.IsTrue(R.ReadShape(Read, Props));
    Assert.AreEqual(2, Read.Count, 'Ring count');
    Assert.AreEqual(-100.0, SignedArea(Read.Parts[0]), 1e-9, 'The outer ring first, clockwise');
    Assert.AreEqual(4.0, SignedArea(Read.Parts[1]), 1e-9, 'The hole after it, counter-clockwise');
  finally
    R.Free;
  end;
  DeleteTempFiles;
end;

initialization
  TDUnitX.RegisterTestFixture(TGeoJSONWriterTests);
  TDUnitX.RegisterTestFixture(TESRIWriterTests);

end.

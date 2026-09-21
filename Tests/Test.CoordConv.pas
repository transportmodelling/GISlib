unit Test.CoordConv;

////////////////////////////////////////////////////////////////////////////////
//
// Author: Jaap Baak
// https://github.com/transportmodelling/GISlib
//
// Test suite generated with assistance from Claude Sonnet 4.6
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
interface
////////////////////////////////////////////////////////////////////////////////

uses
  DUnitX.TestFramework, GIS, GIS.CoordConv, GIS.CoordConv.WGS84, GIS.CoordConv.DutchGrid,
  GIS.CoordConv.WebMercator, GIS.Mercator, GIS.CoordConv.UTM;

type
  [TestFixture]
  TWgs84ConverterTests = class
  private
    FConv: TWgs84CoordinateConverter;
  public
    [Setup]    procedure Setup;
    [TearDown] procedure TearDown;

    [Test] procedure CoordToGeodeticCoord_IsIdentity;
    [Test] procedure GeodeticCoordToCoord_IsIdentity;
    [Test] procedure RoundTrip_Coord;
    [Test] procedure MetersPerUnit_IsApproximately111320;
    [Test] procedure SRID_Is4326;
    [Test] procedure SRSName_IsWGS84;
    [Test] procedure SRSDefinition_ContainsGeogCS;
  end;

  [TestFixture]
  TDutchGridConverterTests = class
  private
    FConv: TDutchGridCoordinateConverter;
  public
    [Setup]    procedure Setup;
    [TearDown] procedure TearDown;

    [Test] procedure MetersPerUnit_IsOne;
    // Amersfoort (RD datum point): Dutch Grid (155000, 463000) ~ WGS84 (5.3872 deg, 52.1552 deg)
    [Test] procedure AmersfoortDutchGrid_ConvertsToCorrectGeodetic;
    // Converting DG -> geodetic -> DG should recover the original within 2 cm
    [Test] procedure RoundTrip_WithinCentimeterAccuracy;
    [Test] procedure SRID_Is28992;
    [Test] procedure SRSName_IsAmersfoort;
    [Test] procedure SRSDefinition_ContainsOblique;
  end;

  [TestFixture]
  TWebMercatorConverterTests = class
  private
    FConv: TWebMercatorCoordinateConverter;
  public
    [Setup]    procedure Setup;
    [TearDown] procedure TearDown;

    [Test] procedure MetersPerUnit_IsOne;
    [Test] procedure GeodeticCoordToCoord_OriginIsZero;
    [Test] procedure GeodeticCoordToCoord_Longitude180_XIsHalfCircumference;
    // At the projection's own MaxLatitude (Y-fraction 0), Y must equal +half the
    // earth circumference - an exact identity independent of any trig hand-math.
    [Test] procedure GeodeticCoordToCoord_AtMaxLatitude_YIsHalfCircumference;
    [Test] procedure RoundTrip_Coord;
    [Test] procedure LatitudeBeyondMaxLatitude_RaisesException;
    [Test] procedure SRID_Is3857;
    [Test] procedure SRSName_IsPseudoMercator;
    [Test] procedure SRSDefinition_ContainsMercator1SP;
    [Test] procedure SRSDefinition_StatesSphericalModel;
  end;

  [TestFixture]
  TUtmConverterTests = class
  private
    FConv: TUtmCoordinateConverter; // Zone 31, North (the Netherlands)
  public
    [Setup]    procedure Setup;
    [TearDown] procedure TearDown;

    [Test] procedure MetersPerUnit_IsOne;
    // At the zone's own central meridian and the equator, X/Y must equal the
    // false easting/northing exactly - an algebraic identity, not approximation.
    [Test] procedure GeodeticCoordToCoord_AtCentralMeridianEquator_IsFalseOrigin;
    [Test] procedure GeodeticCoordToCoord_Amsterdam_MatchesProj;
    [Test] procedure RoundTrip_Coord;
    [Test] procedure RoundTrip_SouthernHemisphere;
    [Test] procedure InvalidZoneTooLow_RaisesException;
    [Test] procedure InvalidZoneTooHigh_RaisesException;
    [Test] procedure SRID_Zone31North_Is32631;
    [Test] procedure SRID_Zone31South_Is32731;
    [Test] procedure SRID_Zone1North_Is32601;
    [Test] procedure SRID_Zone60South_Is32760;
    [Test] procedure SRSName_ContainsZoneAndHemisphere;
    [Test] procedure SRSDefinition_ContainsTransverseMercator;
  end;

  [TestFixture]
  TCoordinateConverterBaseTests = class
  // Verify that the base-class defaults are safe when a subclass does not
  // override the SRS methods.  Uses a minimal concrete subclass that only
  // implements the three abstract methods.
  public
    [Test] procedure DefaultSRID_BaseReturnsZero;
    [Test] procedure DefaultSRSName_BaseReturnsUndefined;
    [Test] procedure DefaultSRSDefinition_BaseReturnsUndefined;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

uses System.SysUtils, System.Math;

type
  // Minimal converter that implements only the abstract methods.
  // SRID/SRSName/SRSDefinition intentionally not overridden -> test base defaults.
  TMinimalConverter = class(TCoordinateConverter)
  public
    function MetersPerUnit: Float64; override;
    function CoordToGeodeticCoord(Coord: TCoordinate): TGeodeticCoordinate; override;
    function GeodeticCoordToCoord(GeodeticCoord: TGeodeticCoordinate): TCoordinate; override;
  end;

function TMinimalConverter.MetersPerUnit: Float64;
begin Result := 1; end;

function TMinimalConverter.CoordToGeodeticCoord(Coord: TCoordinate): TGeodeticCoordinate;
begin Result.Longitude := Coord.X; Result.Latitude := Coord.Y; end;

function TMinimalConverter.GeodeticCoordToCoord(GeodeticCoord: TGeodeticCoordinate): TCoordinate;
begin Result.X := GeodeticCoord.Longitude; Result.Y := GeodeticCoord.Latitude; end;

{ TWgs84ConverterTests }

procedure TWgs84ConverterTests.Setup;
begin
  FConv := TWgs84CoordinateConverter.Create;
end;

procedure TWgs84ConverterTests.TearDown;
begin
  FConv.Free;
end;

procedure TWgs84ConverterTests.CoordToGeodeticCoord_IsIdentity;
var
  G: TGeodeticCoordinate;
begin
  G := FConv.CoordToGeodeticCoord(TCoordinate.Create(5.0, 52.0));
  Assert.AreEqual(5.0,  G.Longitude, 1e-12);
  Assert.AreEqual(52.0, G.Latitude,  1e-12);
end;

procedure TWgs84ConverterTests.GeodeticCoordToCoord_IsIdentity;
var
  G: TGeodeticCoordinate;
  C: TCoordinate;
begin
  G.Longitude := 4.9; G.Latitude := 52.37;
  C := FConv.GeodeticCoordToCoord(G);
  Assert.AreEqual(4.9,   C.X, 1e-12);
  Assert.AreEqual(52.37, C.Y, 1e-12);
end;

procedure TWgs84ConverterTests.RoundTrip_Coord;
var
  Original, Recovered: TCoordinate;
begin
  Original := TCoordinate.Create(4.9, 52.4);
  Recovered := FConv.GeodeticCoordToCoord(FConv.CoordToGeodeticCoord(Original));
  Assert.AreEqual(Original.X, Recovered.X, 1e-12);
  Assert.AreEqual(Original.Y, Recovered.Y, 1e-12);
end;

procedure TWgs84ConverterTests.MetersPerUnit_IsApproximately111320;
begin
  Assert.AreEqual(111320.0, FConv.MetersPerUnit, 1.0);
end;

{ TDutchGridConverterTests }

procedure TDutchGridConverterTests.Setup;
begin
  FConv := TDutchGridCoordinateConverter.Create;
end;

procedure TDutchGridConverterTests.TearDown;
begin
  FConv.Free;
end;

procedure TDutchGridConverterTests.MetersPerUnit_IsOne;
begin
  Assert.AreEqual(1.0, FConv.MetersPerUnit, 1e-12);
end;

procedure TDutchGridConverterTests.AmersfoortDutchGrid_ConvertsToCorrectGeodetic;
var
  G: TGeodeticCoordinate;
begin
  // Amersfoort: Dutch Grid origin at (155000, 463000)
  // Expected WGS84: lon ~ 5.387206 deg, lat ~ 52.155174 deg
  G := FConv.CoordToGeodeticCoord(TCoordinate.Create(155000.0, 463000.0));
  Assert.AreEqual(5.38720, G.Longitude, 0.0001, 'Amersfoort longitude');
  Assert.AreEqual(52.15511, G.Latitude, 0.0001, 'Amersfoort latitude');
end;

procedure TDutchGridConverterTests.RoundTrip_WithinCentimeterAccuracy;
const
  // A few representative points across the Netherlands
  TestPoints: array[0..3] of array[0..1] of Double = (
    (122202, 487250),   // Amsterdam
    (92112,  436456),   // Rotterdam
    (253400, 593800),   // Groningen
    (200000, 350000)    // Zeeland area
  );
var
  I: Integer;
  Original, Recovered: TCoordinate;
begin
  for I := 0 to High(TestPoints) do
  begin
    Original  := TCoordinate.Create(TestPoints[I][0], TestPoints[I][1]);
    Recovered := FConv.GeodeticCoordToCoord(FConv.CoordToGeodeticCoord(Original));
    Assert.AreEqual(Original.X, Recovered.X, 0.02,
      Format('Round-trip X failed at point %d', [I]));
    Assert.AreEqual(Original.Y, Recovered.Y, 0.02,
      Format('Round-trip Y failed at point %d', [I]));
  end;
end;

{ TWgs84ConverterTests - SRS }

procedure TWgs84ConverterTests.SRID_Is4326;
begin
  Assert.AreEqual(4326, FConv.SRID);
end;

procedure TWgs84ConverterTests.SRSName_IsWGS84;
begin
  Assert.IsTrue(Pos('WGS', FConv.SRSName) > 0, 'SRSName should contain "WGS"');
end;

procedure TWgs84ConverterTests.SRSDefinition_ContainsGeogCS;
begin
  Assert.IsTrue(Pos('GEOGCS', FConv.SRSDefinition) > 0,
    'WGS84 SRSDefinition should contain "GEOGCS"');
end;

{ TDutchGridConverterTests - SRS }

procedure TDutchGridConverterTests.SRID_Is28992;
begin
  Assert.AreEqual(28992, FConv.SRID);
end;

procedure TDutchGridConverterTests.SRSName_IsAmersfoort;
begin
  Assert.IsTrue(Pos('Amersfoort', FConv.SRSName) > 0,
    'SRSName should contain "Amersfoort"');
end;

procedure TDutchGridConverterTests.SRSDefinition_ContainsOblique;
begin
  Assert.IsTrue(Pos('Oblique_Stereographic', FConv.SRSDefinition) > 0,
    'Dutch Grid SRSDefinition should contain "Oblique_Stereographic"');
end;

{ TWebMercatorConverterTests }

procedure TWebMercatorConverterTests.Setup;
begin
  FConv := TWebMercatorCoordinateConverter.Create;
end;

procedure TWebMercatorConverterTests.TearDown;
begin
  FConv.Free;
end;

procedure TWebMercatorConverterTests.MetersPerUnit_IsOne;
begin
  Assert.AreEqual(1.0, FConv.MetersPerUnit, 1e-12);
end;

procedure TWebMercatorConverterTests.GeodeticCoordToCoord_OriginIsZero;
var
  G: TGeodeticCoordinate;
  C: TCoordinate;
begin
  G.Longitude := 0; G.Latitude := 0;
  C := FConv.GeodeticCoordToCoord(G);
  Assert.AreEqual(0.0, C.X, 1e-6);
  Assert.AreEqual(0.0, C.Y, 1e-6);
end;

procedure TWebMercatorConverterTests.GeodeticCoordToCoord_Longitude180_XIsHalfCircumference;
const
  EarthCircumference = 2*Pi*6378137.0;
var
  G: TGeodeticCoordinate;
  C: TCoordinate;
begin
  G.Longitude := 180; G.Latitude := 0;
  C := FConv.GeodeticCoordToCoord(G);
  Assert.AreEqual(EarthCircumference/2, C.X, 1e-3);
end;

procedure TWebMercatorConverterTests.GeodeticCoordToCoord_AtMaxLatitude_YIsHalfCircumference;
const
  EarthCircumference = 2*Pi*6378137.0;
var
  Proj: TWebMercatorProjection;
  G: TGeodeticCoordinate;
  C: TCoordinate;
begin
  Proj := TWebMercatorProjection.Create;
  try
    G.Longitude := 0; G.Latitude := Proj.MaxLatitude;
  finally
    Proj.Free;
  end;
  C := FConv.GeodeticCoordToCoord(G);
  Assert.AreEqual(EarthCircumference/2, C.Y, 1e-3);
end;

procedure TWebMercatorConverterTests.RoundTrip_Coord;
var
  Original, Recovered: TCoordinate;
begin
  Original := TCoordinate.Create(544615.0, 6867807.0); // near Amsterdam
  Recovered := FConv.GeodeticCoordToCoord(FConv.CoordToGeodeticCoord(Original));
  Assert.AreEqual(Original.X, Recovered.X, 1e-6);
  Assert.AreEqual(Original.Y, Recovered.Y, 1e-6);
end;

procedure TWebMercatorConverterTests.LatitudeBeyondMaxLatitude_RaisesException;
var
  Proj: TWebMercatorProjection;
  G: TGeodeticCoordinate;
begin
  Proj := TWebMercatorProjection.Create;
  try
    G.Longitude := 0; G.Latitude := Proj.MaxLatitude + 1;
  finally
    Proj.Free;
  end;
  Assert.WillRaise(
    procedure begin FConv.GeodeticCoordToCoord(G) end,
    Exception);
end;

procedure TWebMercatorConverterTests.SRID_Is3857;
begin
  Assert.AreEqual(3857, FConv.SRID);
end;

procedure TWebMercatorConverterTests.SRSName_IsPseudoMercator;
begin
  Assert.IsTrue(Pos('Mercator', FConv.SRSName) > 0, 'SRSName should contain "Mercator"');
end;

procedure TWebMercatorConverterTests.SRSDefinition_ContainsMercator1SP;
begin
  Assert.IsTrue(Pos('Mercator_1SP', FConv.SRSDefinition) > 0,
    'SRSDefinition should contain "Mercator_1SP"');
end;

procedure TWebMercatorConverterTests.SRSDefinition_StatesSphericalModel;
// Without the PROJ4 extension the WKT reads as an ellipsoidal Mercator, which
// puts coordinates tens of kilometres out away from the equator.
begin
  Assert.IsTrue(Pos('+b=6378137', FConv.SRSDefinition) > 0,
    'SRSDefinition should state the spherical radius via the PROJ4 extension');
  Assert.IsTrue(Pos('+nadgrids=@null', FConv.SRSDefinition) > 0,
    'SRSDefinition should contain "+nadgrids=@null"');
end;
{ TUtmConverterTests }

procedure TUtmConverterTests.Setup;
begin
  FConv := TUtmCoordinateConverter.Create(31, hpNorth);
end;

procedure TUtmConverterTests.TearDown;
begin
  FConv.Free;
end;

procedure TUtmConverterTests.MetersPerUnit_IsOne;
begin
  Assert.AreEqual(1.0, FConv.MetersPerUnit, 1e-12);
end;

procedure TUtmConverterTests.GeodeticCoordToCoord_AtCentralMeridianEquator_IsFalseOrigin;
var
  G: TGeodeticCoordinate;
  C: TCoordinate;
begin
  G.Longitude := 3.0; // central meridian of zone 31
  G.Latitude := 0.0;
  C := FConv.GeodeticCoordToCoord(G);
  Assert.AreEqual(500000.0, C.X, 1e-3);
  Assert.AreEqual(0.0, C.Y, 1e-3);
end;

procedure TUtmConverterTests.RoundTrip_Coord;
var
  Original, Recovered: TCoordinate;
begin
  // Tolerance reflects the truncated meridian-arc series of the forward formulas
  Original := TCoordinate.Create(629000.0, 5803000.0); // near Amsterdam, zone 31N
  Recovered := FConv.GeodeticCoordToCoord(FConv.CoordToGeodeticCoord(Original));
  Assert.AreEqual(Original.X, Recovered.X, 1e-3);
  Assert.AreEqual(Original.Y, Recovered.Y, 1e-3);
end;

procedure TUtmConverterTests.GeodeticCoordToCoord_Amsterdam_MatchesProj;
// Reference values from PROJ (EPSG:4326 -> EPSG:32631)
var
  G: TGeodeticCoordinate;
  C: TCoordinate;
begin
  G.Latitude := 52.3731;
  G.Longitude := 4.8936;
  C := FConv.GeodeticCoordToCoord(G);
  Assert.AreEqual(628907.211, C.X, 5e-3);
  Assert.AreEqual(5804224.142, C.Y, 5e-3);
end;

procedure TUtmConverterTests.RoundTrip_SouthernHemisphere;
var
  Conv: TUtmCoordinateConverter;
  Original, Recovered: TCoordinate;
begin
  Conv := TUtmCoordinateConverter.Create(31, hpSouth);
  try
    Original := TCoordinate.Create(629000.0, 4197000.0); // latitude about 52 degrees south
    Recovered := Conv.GeodeticCoordToCoord(Conv.CoordToGeodeticCoord(Original));
    Assert.AreEqual(Original.X, Recovered.X, 1e-3);
    Assert.AreEqual(Original.Y, Recovered.Y, 1e-3);
  finally
    Conv.Free;
  end;
end;
procedure TUtmConverterTests.InvalidZoneTooLow_RaisesException;
begin
  Assert.WillRaise(
    procedure begin TUtmCoordinateConverter.Create(0, hpNorth).Free end,
    Exception);
end;

procedure TUtmConverterTests.InvalidZoneTooHigh_RaisesException;
begin
  Assert.WillRaise(
    procedure begin TUtmCoordinateConverter.Create(61, hpNorth).Free end,
    Exception);
end;

procedure TUtmConverterTests.SRID_Zone31North_Is32631;
begin
  Assert.AreEqual(32631, FConv.SRID);
end;

procedure TUtmConverterTests.SRID_Zone31South_Is32731;
var C: TUtmCoordinateConverter;
begin
  C := TUtmCoordinateConverter.Create(31, hpSouth);
  try
    Assert.AreEqual(32731, C.SRID);
  finally C.Free; end;
end;

procedure TUtmConverterTests.SRID_Zone1North_Is32601;
var C: TUtmCoordinateConverter;
begin
  C := TUtmCoordinateConverter.Create(1, hpNorth);
  try
    Assert.AreEqual(32601, C.SRID);
  finally C.Free; end;
end;

procedure TUtmConverterTests.SRID_Zone60South_Is32760;
var C: TUtmCoordinateConverter;
begin
  C := TUtmCoordinateConverter.Create(60, hpSouth);
  try
    Assert.AreEqual(32760, C.SRID);
  finally C.Free; end;
end;

procedure TUtmConverterTests.SRSName_ContainsZoneAndHemisphere;
begin
  Assert.IsTrue(Pos('31', FConv.SRSName) > 0, 'SRSName should contain zone number');
  Assert.IsTrue(Pos('N', FConv.SRSName) > 0, 'SRSName should contain hemisphere letter');
end;

procedure TUtmConverterTests.SRSDefinition_ContainsTransverseMercator;
begin
  Assert.IsTrue(Pos('Transverse_Mercator', FConv.SRSDefinition) > 0,
    'SRSDefinition should contain "Transverse_Mercator"');
end;

{ TCoordinateConverterBaseTests }

procedure TCoordinateConverterBaseTests.DefaultSRID_BaseReturnsZero;
var C: TMinimalConverter;
begin
  C := TMinimalConverter.Create;
  try
    Assert.AreEqual(0, C.SRID);
  finally C.Free; end;
end;

procedure TCoordinateConverterBaseTests.DefaultSRSName_BaseReturnsUndefined;
var C: TMinimalConverter;
begin
  C := TMinimalConverter.Create;
  try
    Assert.AreEqual('undefined', C.SRSName);
  finally C.Free; end;
end;

procedure TCoordinateConverterBaseTests.DefaultSRSDefinition_BaseReturnsUndefined;
var C: TMinimalConverter;
begin
  C := TMinimalConverter.Create;
  try
    Assert.AreEqual('undefined', C.SRSDefinition);
  finally C.Free; end;
end;

initialization
  TDUnitX.RegisterTestFixture(TWgs84ConverterTests);
  TDUnitX.RegisterTestFixture(TDutchGridConverterTests);
  TDUnitX.RegisterTestFixture(TWebMercatorConverterTests);
  TDUnitX.RegisterTestFixture(TUtmConverterTests);
  TDUnitX.RegisterTestFixture(TCoordinateConverterBaseTests);

end.

unit Test.Mercator;

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
  DUnitX.TestFramework, GIS.Mercator;

type
  [TestFixture]
  TWebMercatorProjectionTests = class
  private
    FProj: TWebMercatorProjection;
  public
    [Setup]    procedure Setup;
    [TearDown] procedure TearDown;

    // Longitude -> X
    [Test] procedure LongitudeToXCoord_WestEdgeIsZero;
    [Test] procedure LongitudeToXCoord_CentreIsHalf;
    [Test] procedure LongitudeToXCoord_EastEdgeIsOne;
    [Test] procedure LongitudeToXCoord_RoundTrip;

    // Latitude -> Y
    [Test] procedure LatitudeToYCoord_EquatorIsHalf;
    [Test] procedure YCoordToLatitude_HalfIsZero;
    [Test] procedure LatitudeToYCoord_RoundTrip;

    // Bounds
    [Test] procedure MinLatitude_LessThanMaxLatitude;
    [Test] procedure MinLatitude_IsNegativeMaxLatitude;

    // Out-of-range exceptions
    [Test] procedure LongitudeOutOfRange_RaisesException;
    [Test] procedure LatitudeOutOfRange_RaisesException;
    [Test] procedure XCoordOutOfRange_RaisesException;
    [Test] procedure YCoordOutOfRange_RaisesException;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

uses System.SysUtils, System.Math;

procedure TWebMercatorProjectionTests.Setup;
begin
  FProj := TWebMercatorProjection.Create;
end;

procedure TWebMercatorProjectionTests.TearDown;
begin
  FProj.Free;
end;

procedure TWebMercatorProjectionTests.LongitudeToXCoord_WestEdgeIsZero;
begin
  Assert.AreEqual(0.0, FProj.LongitudeToXCoord(-180.0), 1e-10);
end;

procedure TWebMercatorProjectionTests.LongitudeToXCoord_CentreIsHalf;
begin
  Assert.AreEqual(0.5, FProj.LongitudeToXCoord(0.0), 1e-10);
end;

procedure TWebMercatorProjectionTests.LongitudeToXCoord_EastEdgeIsOne;
begin
  Assert.AreEqual(1.0, FProj.LongitudeToXCoord(180.0), 1e-10);
end;

procedure TWebMercatorProjectionTests.LongitudeToXCoord_RoundTrip;
const
  Lons: array[0..4] of Double = (-180, -90, 0, 90, 180);
var
  Lon: Double;
begin
  for Lon in Lons do
    Assert.AreEqual(Lon, FProj.XCoordToLongitude(FProj.LongitudeToXCoord(Lon)), 1e-10);
end;

procedure TWebMercatorProjectionTests.LatitudeToYCoord_EquatorIsHalf;
begin
  Assert.AreEqual(0.5, FProj.LatitudeToYCoord(0.0), 1e-10);
end;

procedure TWebMercatorProjectionTests.YCoordToLatitude_HalfIsZero;
begin
  Assert.AreEqual(0.0, FProj.YCoordToLatitude(0.5), 1e-10);
end;

procedure TWebMercatorProjectionTests.LatitudeToYCoord_RoundTrip;
const
  Lats: array[0..4] of Double = (-60, -30, 0, 30, 60);
var
  Lat: Double;
begin
  for Lat in Lats do
    Assert.AreEqual(Lat, FProj.YCoordToLatitude(FProj.LatitudeToYCoord(Lat)), 1e-8);
end;

procedure TWebMercatorProjectionTests.MinLatitude_LessThanMaxLatitude;
begin
  Assert.IsTrue(FProj.MinLatitude < FProj.MaxLatitude);
end;

procedure TWebMercatorProjectionTests.MinLatitude_IsNegativeMaxLatitude;
begin
  Assert.AreEqual(FProj.MinLatitude, -FProj.MaxLatitude, 1e-10);
end;

procedure TWebMercatorProjectionTests.LongitudeOutOfRange_RaisesException;
begin
  Assert.WillRaise(
    procedure begin FProj.LongitudeToXCoord(181.0) end,
    Exception);
end;

procedure TWebMercatorProjectionTests.LatitudeOutOfRange_RaisesException;
begin
  Assert.WillRaise(
    procedure begin FProj.LatitudeToYCoord(FProj.MaxLatitude + 1) end,
    Exception);
end;

procedure TWebMercatorProjectionTests.XCoordOutOfRange_RaisesException;
begin
  Assert.WillRaise(
    procedure begin FProj.XCoordToLongitude(1.1) end,
    Exception);
end;

procedure TWebMercatorProjectionTests.YCoordOutOfRange_RaisesException;
begin
  Assert.WillRaise(
    procedure begin FProj.YCoordToLatitude(1.1) end,
    Exception);
end;

initialization
  TDUnitX.RegisterTestFixture(TWebMercatorProjectionTests);

end.

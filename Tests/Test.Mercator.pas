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
    [Setup]    Procedure Setup;
    [TearDown] Procedure TearDown;

    // Longitude -> X
    [Test] Procedure LongitudeToXCoord_WestEdgeIsZero;
    [Test] Procedure LongitudeToXCoord_CentreIsHalf;
    [Test] Procedure LongitudeToXCoord_EastEdgeIsOne;
    [Test] Procedure LongitudeToXCoord_RoundTrip;

    // Latitude -> Y
    [Test] Procedure LatitudeToYCoord_EquatorIsHalf;
    [Test] Procedure YCoordToLatitude_HalfIsZero;
    [Test] Procedure LatitudeToYCoord_RoundTrip;

    // Bounds
    [Test] Procedure MinLatitude_LessThanMaxLatitude;
    [Test] Procedure MinLatitude_IsNegativeMaxLatitude;

    // Out-of-range exceptions
    [Test] Procedure LongitudeOutOfRange_RaisesException;
    [Test] Procedure LatitudeOutOfRange_RaisesException;
    [Test] Procedure XCoordOutOfRange_RaisesException;
    [Test] Procedure YCoordOutOfRange_RaisesException;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

uses System.SysUtils, System.Math;

Procedure TWebMercatorProjectionTests.Setup;
begin
  FProj := TWebMercatorProjection.Create;
end;

Procedure TWebMercatorProjectionTests.TearDown;
begin
  FProj.Free;
end;

Procedure TWebMercatorProjectionTests.LongitudeToXCoord_WestEdgeIsZero;
begin
  Assert.AreEqual(0.0, FProj.LongitudeToXCoord(-180.0), 1e-10);
end;

Procedure TWebMercatorProjectionTests.LongitudeToXCoord_CentreIsHalf;
begin
  Assert.AreEqual(0.5, FProj.LongitudeToXCoord(0.0), 1e-10);
end;

Procedure TWebMercatorProjectionTests.LongitudeToXCoord_EastEdgeIsOne;
begin
  Assert.AreEqual(1.0, FProj.LongitudeToXCoord(180.0), 1e-10);
end;

Procedure TWebMercatorProjectionTests.LongitudeToXCoord_RoundTrip;
const
  Lons: array[0..4] of Double = (-180, -90, 0, 90, 180);
var
  Lon: Double;
begin
  for Lon in Lons do
    Assert.AreEqual(Lon, FProj.XCoordToLongitude(FProj.LongitudeToXCoord(Lon)), 1e-10);
end;

Procedure TWebMercatorProjectionTests.LatitudeToYCoord_EquatorIsHalf;
begin
  Assert.AreEqual(0.5, FProj.LatitudeToYCoord(0.0), 1e-10);
end;

Procedure TWebMercatorProjectionTests.YCoordToLatitude_HalfIsZero;
begin
  Assert.AreEqual(0.0, FProj.YCoordToLatitude(0.5), 1e-10);
end;

Procedure TWebMercatorProjectionTests.LatitudeToYCoord_RoundTrip;
const
  Lats: array[0..4] of Double = (-60, -30, 0, 30, 60);
var
  Lat: Double;
begin
  for Lat in Lats do
    Assert.AreEqual(Lat, FProj.YCoordToLatitude(FProj.LatitudeToYCoord(Lat)), 1e-8);
end;

Procedure TWebMercatorProjectionTests.MinLatitude_LessThanMaxLatitude;
begin
  Assert.IsTrue(FProj.MinLatitude < FProj.MaxLatitude);
end;

Procedure TWebMercatorProjectionTests.MinLatitude_IsNegativeMaxLatitude;
begin
  Assert.AreEqual(FProj.MinLatitude, -FProj.MaxLatitude, 1e-10);
end;

Procedure TWebMercatorProjectionTests.LongitudeOutOfRange_RaisesException;
begin
  Assert.WillRaise(
    Procedure begin FProj.LongitudeToXCoord(181.0) end,
    Exception);
end;

Procedure TWebMercatorProjectionTests.LatitudeOutOfRange_RaisesException;
begin
  Assert.WillRaise(
    Procedure begin FProj.LatitudeToYCoord(FProj.MaxLatitude + 1) end,
    Exception);
end;

Procedure TWebMercatorProjectionTests.XCoordOutOfRange_RaisesException;
begin
  Assert.WillRaise(
    Procedure begin FProj.XCoordToLongitude(1.1) end,
    Exception);
end;

Procedure TWebMercatorProjectionTests.YCoordOutOfRange_RaisesException;
begin
  Assert.WillRaise(
    Procedure begin FProj.YCoordToLatitude(1.1) end,
    Exception);
end;

initialization
  TDUnitX.RegisterTestFixture(TWebMercatorProjectionTests);

end.

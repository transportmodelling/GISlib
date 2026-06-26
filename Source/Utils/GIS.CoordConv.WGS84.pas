unit GIS.CoordConv.WGS84;

////////////////////////////////////////////////////////////////////////////////
//
// Author: Jaap Baak
// https://github.com/transportmodelling/GISlib
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
interface
////////////////////////////////////////////////////////////////////////////////

Uses
  GIS, GIS.CoordConv;

Type
  TWgs84CoordinateConverter = Class(TCoordinateConverter)
  // Identity converter for data already in WGS84 geographic coordinates
  // (X = longitude, Y = latitude).
  public
    Function MetersPerUnit: Float64; override;
    Function CoordToGeodeticCoord(Coord: TCoordinate): TGeodeticCoordinate; override;
    Function GeodeticCoordToCoord(GeodeticCoord: TGeodeticCoordinate): TCoordinate; override;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Function TWgs84CoordinateConverter.MetersPerUnit: Float64;
begin
  // Approximate metres per degree at the equator
  Result := 111320.0;
end;

Function TWgs84CoordinateConverter.CoordToGeodeticCoord(Coord: TCoordinate): TGeodeticCoordinate;
begin
  Result.Longitude := Coord.X;
  Result.Latitude  := Coord.Y;
end;

Function TWgs84CoordinateConverter.GeodeticCoordToCoord(GeodeticCoord: TGeodeticCoordinate): TCoordinate;
begin
  Result.X := GeodeticCoord.Longitude;
  Result.Y := GeodeticCoord.Latitude;
end;

end.


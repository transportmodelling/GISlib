unit GIS.CoordConv.WebMercator;

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
  GIS, GIS.CoordConv, GIS.Mercator;

Type
  TWebMercatorCoordinateConverter = Class(TCoordinateConverter)
  // Converts between geodetic coordinates and Web Mercator (EPSG:3857) coordinates,
  // expressed in metres on the spherical earth model used by web map providers
  // (Google Maps, Bing, OpenStreetMap). Reuses the unit-interval projection from
  // GIS.Mercator.TWebMercatorProjection, scaled to real-world metres.
  private
    FProjection: TWebMercatorProjection;
  public
    Constructor Create;
    Destructor Destroy; override;
    Function MetersPerUnit: Float64; override;
    Function CoordToGeodeticCoord(Coord: TCoordinate): TGeodeticCoordinate; override;
    Function GeodeticCoordToCoord(GeodeticCoord: TGeodeticCoordinate): TCoordinate; override;
    Function SRID: Integer; override;
    Function SRSName: String; override;
    Function SRSDefinition: String; override;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Const
  // Circumference of the spherical earth model used by EPSG:3857 (radius 6378137 m)
  EarthCircumference = 2*Pi*6378137.0;

Constructor TWebMercatorCoordinateConverter.Create;
begin
  inherited Create;
  FProjection := TWebMercatorProjection.Create;
end;

Destructor TWebMercatorCoordinateConverter.Destroy;
begin
  FProjection.Free;
  inherited Destroy;
end;

Function TWebMercatorCoordinateConverter.MetersPerUnit: Float64;
begin
  Result := 1.0;
end;

Function TWebMercatorCoordinateConverter.CoordToGeodeticCoord(Coord: TCoordinate): TGeodeticCoordinate;
begin
  var XFraction := 0.5 + Coord.X/EarthCircumference;
  var YFraction := 0.5 - Coord.Y/EarthCircumference;
  Result.Longitude := FProjection.XCoordToLongitude(XFraction);
  Result.Latitude  := FProjection.YCoordToLatitude(YFraction);
end;

Function TWebMercatorCoordinateConverter.GeodeticCoordToCoord(GeodeticCoord: TGeodeticCoordinate): TCoordinate;
begin
  var XFraction := FProjection.LongitudeToXCoord(GeodeticCoord.Longitude);
  var YFraction := FProjection.LatitudeToYCoord(GeodeticCoord.Latitude);
  Result.X := (XFraction-0.5)*EarthCircumference;
  Result.Y := (0.5-YFraction)*EarthCircumference;
end;

Function TWebMercatorCoordinateConverter.SRID: Integer;
begin
  Result := 3857;
end;

Function TWebMercatorCoordinateConverter.SRSName: String;
begin
  Result := 'WGS 84 / Pseudo-Mercator';
end;

Function TWebMercatorCoordinateConverter.SRSDefinition: String;
// Mercator_1SP on the WGS84 spheroid reads as an ellipsoidal Mercator, which
// differs from Web Mercator by tens of kilometres away from the equator. The
// PROJ4 extension states the spherical model explicitly, so readers do not have
// to infer it from the "Pseudo-Mercator" name. This matches the WKT1 GDAL emits.
begin
  Result :=
    'PROJCS["WGS 84 / Pseudo-Mercator",' +
    'GEOGCS["WGS 84",DATUM["WGS_1984",' +
    'SPHEROID["WGS 84",6378137,298.257223563]],' +
    'PRIMEM["Greenwich",0],UNIT["degree",0.0174532925199433]],' +
    'PROJECTION["Mercator_1SP"],' +
    'PARAMETER["central_meridian",0],' +
    'PARAMETER["scale_factor",1],' +
    'PARAMETER["false_easting",0],' +
    'PARAMETER["false_northing",0],' +
    'UNIT["metre",1],' +
    'AXIS["Easting",EAST],AXIS["Northing",NORTH],' +
    'EXTENSION["PROJ4","+proj=merc +a=6378137 +b=6378137 +lat_ts=0 +lon_0=0 ' +
    '+x_0=0 +y_0=0 +k=1 +units=m +nadgrids=@null +wktext +no_defs"]]';
end;

end.

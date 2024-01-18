unit GIS.Mercator;

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
  SysUtils, Math, Types;

Type
  TWebMercatorProjection = Class
  // Longitudes are in the range [-180..180]
  // Latitudes are in the range [MinLatitude..MaxLatitude]
  // X and Y coordinates are in the range [0..1]
  private
    FMinLatitude,FMaxLatitude: Float64;
  public
    Constructor Create;
    Function LongitudeToXCoord(const Longitude: Float64): Float64;
    Function LatitudeToYCoord(const Latitude: Float64): Float64;
    Function XCoordToLongitude(const XCoord: Float64): Float64;
    Function YCoordToLatitude(const YCoord: Float64): Float64;
  public
    Property MinLatitude: Float64 read FMinLatitude;
    Property MaxLatitude: Float64 read FMaxLatitude;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Constructor TWebMercatorProjection.Create;
begin
  inherited Create;
  FMaxLatitude := YCoordToLatitude(0);
  FMinLatitude := YCoordToLatitude(1);
end;

Function TWebMercatorProjection.LongitudeToXCoord(const Longitude: Float64): Float64;
begin
  if (Longitude >= -180) and (Longitude <= 180) then
    Result := (Longitude+180)/360
  else
    raise Exception.Create('Longitude out of range');
end;

Function TWebMercatorProjection.LatitudeToYCoord(const Latitude: Float64): Float64;
begin
  if (Latitude >= -FMaxLatitude) and (Latitude <= FMaxLatitude) then
    Result := 0.5 - ln(tan((pi/4)+(pi*Latitude/360)))/(2*pi)
  else
    raise Exception.Create('Latitude out of range');
end;

Function TWebMercatorProjection.XCoordToLongitude(const XCoord: Float64): Float64;
begin
  if (XCoord >= 0) and (XCoord <= 1) then
    Result := 360*XCoord-180
  else
    raise Exception.Create('XCoord out of range');
end;

Function TWebMercatorProjection.YCoordToLatitude(const YCoord: Float64): Float64;
begin
  if (YCoord >= 0) and (YCoord <= 1) then
    Result := (360/pi)*arctan(exp(2*(0.5-YCoord)*pi))-90
  else
    raise Exception.Create('YCoord out of range');
end;

end.

unit GIS.CoordConv.UTM;

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
  SysUtils, Math, GIS, GIS.CoordConv;

Type
  TUtmHemisphere = (hpNorth,hpSouth);

  TUtmCoordinateConverter = Class(TCoordinateConverter)
  // Converts between UTM (Universal Transverse Mercator, WGS84 ellipsoid) and
  // geodetic coordinates, for a fixed zone/hemisphere given at construction.
  // Formulas follow Snyder, "Map Projections - A Working Manual" (USGS, 1987).
  private
    Const
      EarthRadius = 6378137.0;             // WGS84 semi-major axis
      Flattening = 1/298.257223563;        // WGS84 flattening
      EccentricitySqr = Flattening*(2-Flattening);
      EccentricitySqrPrime = EccentricitySqr/(1-EccentricitySqr);
      ScaleFactor = 0.9996;                // UTM scale factor at central meridian
      FalseEasting = 500000.0;
      FalseNorthing = 10000000.0;          // applied for the southern hemisphere
    Var
      FZone: Integer;
      FHemisphere: TUtmHemisphere;
      FCentralMeridian: Float64;           // radians
  public
    Constructor Create(const Zone: Integer; const Hemisphere: TUtmHemisphere);
    Function MetersPerUnit: Float64; override;
    Function CoordToGeodeticCoord(Coord: TCoordinate): TGeodeticCoordinate; override;
    Function GeodeticCoordToCoord(GeodeticCoord: TGeodeticCoordinate): TCoordinate; override;
    Function SRID: Integer; override;
    Function SRSName: String; override;
    Function SRSDefinition: String; override;
  public
    Property Zone: Integer read FZone;
    Property Hemisphere: TUtmHemisphere read FHemisphere;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Constructor TUtmCoordinateConverter.Create(const Zone: Integer; const Hemisphere: TUtmHemisphere);
begin
  inherited Create;
  if (Zone < 1) or (Zone > 60) then raise Exception.Create('Invalid UTM zone');
  FZone := Zone;
  FHemisphere := Hemisphere;
  FCentralMeridian := (Zone*6-183)*pi/180;
end;

Function TUtmCoordinateConverter.MetersPerUnit: Float64;
begin
  Result := 1.0;
end;

Function TUtmCoordinateConverter.GeodeticCoordToCoord(GeodeticCoord: TGeodeticCoordinate): TCoordinate;
var
  Phi,Lambda,SinPhi,CosPhi,TanPhi,N,T,C,A,M: Float64;
begin
  Phi := GeodeticCoord.Latitude*pi/180;
  Lambda := GeodeticCoord.Longitude*pi/180;
  SinPhi := sin(Phi);
  CosPhi := cos(Phi);
  TanPhi := tan(Phi);

  N := EarthRadius/sqrt(1-EccentricitySqr*sqr(SinPhi));
  T := sqr(TanPhi);
  C := EccentricitySqrPrime*sqr(CosPhi);
  A := (Lambda-FCentralMeridian)*CosPhi;

  M := EarthRadius*(
         (1 - EccentricitySqr/4 - 3*sqr(EccentricitySqr)/64 - 5*EccentricitySqr*sqr(EccentricitySqr)/256)*Phi
       - (3*EccentricitySqr/8 + 3*sqr(EccentricitySqr)/32 + 45*EccentricitySqr*sqr(EccentricitySqr)/1024)*sin(2*Phi)
       + (15*sqr(EccentricitySqr)/256 + 45*EccentricitySqr*sqr(EccentricitySqr)/1024)*sin(4*Phi)
       - (35*EccentricitySqr*sqr(EccentricitySqr)/3072)*sin(6*Phi) );

  Result.X := FalseEasting + ScaleFactor*N*( A + (1-T+C)*A*A*A/6
              + (5-18*T+T*T+72*C-58*EccentricitySqrPrime)*A*A*A*A*A/120 );

  Result.Y := ScaleFactor*( M + N*TanPhi*( A*A/2 + (5-T+9*C+4*C*C)*A*A*A*A/24
              + (61-58*T+T*T+600*C-330*EccentricitySqrPrime)*A*A*A*A*A*A/720 ) );

  if FHemisphere = hpSouth then Result.Y := Result.Y + FalseNorthing;
end;

Function TUtmCoordinateConverter.CoordToGeodeticCoord(Coord: TCoordinate): TGeodeticCoordinate;
var
  X,Y,M,Mu,E1,Phi1,SinPhi1,CosPhi1,TanPhi1,C1,T1,N1,R1,D,Phi,Lambda: Float64;
begin
  X := Coord.X-FalseEasting;
  if FHemisphere = hpSouth then Y := Coord.Y-FalseNorthing else Y := Coord.Y;

  M := Y/ScaleFactor;
  Mu := M/(EarthRadius*(1 - EccentricitySqr/4 - 3*sqr(EccentricitySqr)/64 - 5*EccentricitySqr*sqr(EccentricitySqr)/256));

  E1 := (1-sqrt(1-EccentricitySqr))/(1+sqrt(1-EccentricitySqr));

  Phi1 := Mu + (3*E1/2 - 27*E1*E1*E1/32)*sin(2*Mu)
             + (21*E1*E1/16 - 55*E1*E1*E1*E1/32)*sin(4*Mu)
             + (151*E1*E1*E1/96)*sin(6*Mu)
             + (1097*E1*E1*E1*E1/512)*sin(8*Mu);

  SinPhi1 := sin(Phi1);
  CosPhi1 := cos(Phi1);
  TanPhi1 := tan(Phi1);

  C1 := EccentricitySqrPrime*sqr(CosPhi1);
  T1 := sqr(TanPhi1);
  N1 := EarthRadius/sqrt(1-EccentricitySqr*sqr(SinPhi1));
  R1 := EarthRadius*(1-EccentricitySqr)/Power(1-EccentricitySqr*sqr(SinPhi1),1.5);
  D := X/(N1*ScaleFactor);

  Phi := Phi1 - (N1*TanPhi1/R1)*( D*D/2
         - (5+3*T1+10*C1-4*C1*C1-9*EccentricitySqrPrime)*D*D*D*D/24
         + (61+90*T1+298*C1+45*T1*T1-252*EccentricitySqrPrime-3*C1*C1)*D*D*D*D*D*D/720 );

  Lambda := FCentralMeridian + ( D - (1+2*T1+C1)*D*D*D/6
            + (5-2*C1+28*T1-3*C1*C1+8*EccentricitySqrPrime+24*T1*T1)*D*D*D*D*D/120 ) / CosPhi1;

  Result.Latitude := Phi*180/pi;
  Result.Longitude := Lambda*180/pi;
end;

Function TUtmCoordinateConverter.SRID: Integer;
begin
  if FHemisphere = hpNorth then
    Result := 32600+FZone
  else
    Result := 32700+FZone;
end;

Function TUtmCoordinateConverter.SRSName: String;
begin
  if FHemisphere = hpNorth then
    Result := 'WGS 84 / UTM zone ' + IntToStr(FZone) + 'N'
  else
    Result := 'WGS 84 / UTM zone ' + IntToStr(FZone) + 'S';
end;

Function TUtmCoordinateConverter.SRSDefinition: String;
var
  HemisphereLetter: String;
  FalseNorthingValue: Integer;
begin
  if FHemisphere = hpNorth then
  begin
    HemisphereLetter := 'N';
    FalseNorthingValue := 0;
  end else
  begin
    HemisphereLetter := 'S';
    FalseNorthingValue := 10000000;
  end;
  Result := Format(
    'PROJCS["WGS 84 / UTM zone %d%s",' +
    'GEOGCS["WGS 84",DATUM["WGS_1984",' +
    'SPHEROID["WGS 84",6378137,298.257223563]],' +
    'PRIMEM["Greenwich",0],UNIT["degree",0.0174532925199433]],' +
    'PROJECTION["Transverse_Mercator"],' +
    'PARAMETER["latitude_of_origin",0],' +
    'PARAMETER["central_meridian",%d],' +
    'PARAMETER["scale_factor",0.9996],' +
    'PARAMETER["false_easting",500000],' +
    'PARAMETER["false_northing",%d],' +
    'UNIT["metre",1]]',
    [FZone, HemisphereLetter, FZone*6-183, FalseNorthingValue]);
end;

end.

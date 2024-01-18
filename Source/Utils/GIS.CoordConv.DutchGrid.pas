unit GIS.CoordConv.DutchGrid;

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
  Math, GIS, GIS.CoordConv;

Type
  TDutchGridCoordinateConverter = Class(TCoordinateConverter)
  // Converts between Dutch Grid (Rijksdriehoekmeting) and geodetic coordinates (WGS84).
  // Transformation functions based on work by Ejo Schrama (T.U. Delft).
  private
    Const
      x0 = 155000;
      y0 = 463000;
      k = 0.9999079;
      bigr = 6382644.571;
      m = 0.003773954;
      n = 1.000475857;
      lambda0 = 0.094032038;
      phi0 = 0.910296727;
      l0 = 0.094032038;
      b0 = 0.909684757;
      e = 0.081696831;
      a = 6377397.155;
  public
    Function MetersPerUnit: Float64; override;
    Function CoordToGeodeticCoord(Coord: TCoordinate): TGeodeticCoordinate; override;
    Function GeodeticCoordToCoord(GeodeticCoord: TGeodeticCoordinate): TCoordinate; override;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Function TDutchGridCoordinateConverter.MetersPerUnit: Float64;
begin
  Result := 1.0;
end;

Function TDutchGridCoordinateConverter.CoordToGeodeticCoord(Coord: TCoordinate): TGeodeticCoordinate;
var
  dx,dy,lambda,lamcor,phi,phicor,phiwgs,lamwgs,dphi,dlam,q,dq,w,dl,sdl,sa,spsi,cb,b,sb,ca,psi,cpsi,r: Float64;
begin
  dx := Coord.X-x0;
  dy := Coord.Y-y0;
  r := sqrt(sqr(dx)+sqr(dy));
  if r = 0 then sa := 0 else sa := dx/r;
  if r = 0 then ca := 0 else ca := dy/r;
  psi := 2*arctan(r/(k*2*bigr));
  cpsi:= cos(psi);
  spsi:= sin(psi);
  sb := ca*cos(b0)*spsi+sin(b0)*cpsi;
  cb := sqrt(1-sqr(sb));
  b := arccos(cb);
  sdl := sa*spsi/cb;
  dl := arcsin(sdl);
  lambda := dl/n+lambda0;
  w := ln(tan(b/2+pi/4));
  q := (w-m)/n;
  dq := 0;
  for var Iter := 1 to 4 do
  begin
    phi := 2*arctan(exp(q+dq))-pi/2;
    dq := e/2*ln((e*sin(phi)+1)/(1-e*sin(phi)));
  end;
  lambda := 180*lambda/pi;
  phi := 180*phi/pi;
  dphi := phi-52;
  dlam := lambda-5;
  phicor := (-96.862-dphi*11.714-dlam*0.125)*0.00001;
  lamcor := (dphi*0.329-37.902-dlam*14.667)*0.00001;
  Result.Latitude := phi+phicor;
  Result.Longitude := lambda+lamcor;
end;

Function TDutchGridCoordinateConverter.GeodeticCoordToCoord(GeodeticCoord: TGeodeticCoordinate): TCoordinate;
Var
  dphi,dlam,phicor,lamcor,phibes,lambes,phi,lambda,qprime,dq,q,w,b,dl,d_1,d_2,
  s2psihalf,cpsihalf,spsihalf,tpsihalf,spsi,cpsi,sa,ca,r: Float64;
begin
  dphi := GeodeticCoord.Latitude-52;
  dlam := GeodeticCoord.Longitude-5;
  phicor := (-96.862-dphi*11.714-dlam*0.125)*0.00001;
  lamcor := (dphi*0.329-37.902-dlam*14.667)*0.00001;
  phibes := GeodeticCoord.Latitude-phicor;
  lambes := GeodeticCoord.Longitude-lamcor;
  phi := pi*phibes/180;
  lambda := pi*lambes/180;
  qprime := ln(tan(phi/2+pi/4));
  dq := e*ln((e*sin(phi)+1)/(1-e*sin(phi)))/2;
  q := qprime-dq;
  w := n*q+m;
  b := 2*arctan(exp(w))-pi/2;
  dl := n*(lambda-lambda0);
  d_1 := sin((b-b0)/2);
  d_2 := sin(dl/2);
  s2psihalf := sqr(d_1)+sqr(d_2)*cos(b)*cos(b0);
  cpsihalf := sqrt(1-s2psihalf);
  spsihalf := sqrt(s2psihalf);
  tpsihalf := spsihalf/cpsihalf;
  spsi := 2*cpsihalf*spsihalf;
  cpsi := 1-2*s2psihalf;
  sa := sin(dl)*cos(b)/spsi;
  ca := (sin(b)-cpsi*sin(b0))/(spsi*cos(b0));
  r := 2*k*bigr*tpsihalf;
  Result.X := x0 + r*sa;
  Result.Y := y0 + r*ca;
end;

end.

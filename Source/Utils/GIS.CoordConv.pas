unit GIS.CoordConv;

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
  GIS;

Type
  TCoordinateConverter = Class
  public
    Function MetersPerUnit: Float64; virtual; abstract;
    Function CoordToGeodeticCoord(Coord: TCoordinate): TGeodeticCoordinate; virtual; abstract;
    Function GeodeticCoordToCoord(GeodeticCoord: TGeodeticCoordinate): TCoordinate; virtual; abstract;
    // Spatial reference system identity — override in concrete subclasses.
    // Used e.g. by TGeopackageWriter to register the CRS in gpkg_spatial_ref_sys.
    Function SRID: Integer; virtual;
    Function SRSName: String; virtual;
    Function SRSDefinition: String; virtual;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Function TCoordinateConverter.SRID: Integer;
begin
  Result := 0;
end;

Function TCoordinateConverter.SRSName: String;
begin
  Result := 'undefined';
end;

Function TCoordinateConverter.SRSDefinition: String;
begin
  Result := 'undefined';
end;

end.

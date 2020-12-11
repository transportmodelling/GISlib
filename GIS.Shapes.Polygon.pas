unit GIS.Shapes.Polygon;

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
  SysUtils,Types,Math,Generics.Defaults,Generics.Collections,GIS,GIS.Shapes;

Type
  TPolyPolygon = record
  private
    FOuterRing: TShapePart;
    FHoles: array of TShapePart;
    Function GetHoles(Hole: Integer): TShapePart; inline;
  public
    Function HolesCount: Integer;
  public
    Property OuterRing: TShapePart read FOuterRing;
    Property Holes[Hole: Integer]: TShapePart read GetHoles;
  end;

  TPolyPolygons = record
  private
    FPolyPolygons: array of TPolyPolygon;
    Function GetPolyPolygons(Polypolygon: Integer): TPolyPolygon;
  public
    Constructor Create(const [ref] PolyPolygons: TGISShape);
    Function Count: Integer;
  public
    Property PolyPolygons[PolyPolygon: Integer]: TPolyPolygon read GetPolyPolygons; default;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Function TPolyPolygon.GetHoles(Hole: Integer): TShapePart;
begin
  Result := FHoles[Hole];
end;

Function TPolyPolygon.HolesCount: Integer;
begin
  Result := Length(FHoles);
end;

////////////////////////////////////////////////////////////////////////////////

Constructor TPolyPolygons.Create(const [ref] PolyPolygons: TGISShape);
Var
  PolygonAreas: array of Float64;
  PolygonIndices: array of Integer;
  PotentialHoles: array of Boolean;
begin
  if PolyPolygons.ShapeType = stPolygon then
  begin
    // Initialization
    var OuterCount := 0;
    SetLength(PolygonAreas,PolyPolygons.Count);
    SetLength(PolygonIndices,PolyPolygons.Count);
    SetLength(PotentialHoles,PolyPolygons.Count);
    for var Polygon := 0 to PolyPolygons.Count-1 do PolygonIndices[Polygon] := Polygon;
    // Calculate (2x) polygon areas
    for var Part := 0 to PolyPolygons.Count-1 do
    begin
      var Polygon := PolyPolygons.Parts[Part];
      for var Point := 0 to Polygon.Count-2 do
      PolygonAreas[Part] := PolygonAreas[Part] +
                            Polygon[Point].X*Polygon[Point+1].Y -
                            Polygon[Point+1].X*Polygon[Point].Y;
    end;
    // Sort polygons (Outer before inner, so large area before small area)
    TArray.Sort<Integer>(PolygonIndices,TComparer<Integer>.Construct(
       Function(const Left,Right: Integer): Integer
       begin
         var LeftArea := Abs(PolygonAreas[Left]);
         var RightArea := Abs(PolygonAreas[Right]);
         if LeftArea > RightArea then Result := -1 else
         if LeftArea < RightArea then Result := +1 else
         Result := 0;
       end ),0,PolyPolygons.Count);
    // Select outer ring
    SetLength(FPolyPolygons,PolyPolygons.Count);
    for var Polygon := 0 to PolyPolygons.Count-1 do
    begin
      var PolygonIndex := PolygonIndices[Polygon];
      if PolygonAreas[PolygonIndex] < 0 then
      begin
        var OuterRing := PolyPolygons.Parts[PolygonIndex];
        FPolyPolygons[OuterCount].FOuterRing := OuterRing;
        for var PotentialHole := Polygon+1 to PolyPolygons.Count-1 do PotentialHoles[PotentialHole] := true;
        // Select holes of outer ring
        for var PotentialHole := Polygon+1 to PolyPolygons.Count-1 do
        if  PotentialHoles[PotentialHole] then
        begin
          var PotentialHoleIndex := PolygonIndices[PotentialHole];
          if PolygonAreas[PotentialHoleIndex] > 0 then
          begin
            var Hole := PolyPolygons.Parts[PotentialHoleIndex];
            if OuterRing.BoundingBox.Contains(Hole.BoundingBox) then
            begin
              // Add hole
              FPolyPolygons[OuterCount].FHoles := FPolyPolygons[OuterCount].FHoles + [Hole];
              // Exclude anything inside hole as potential hole
              for var HoleInterior := PotentialHole+1 to PolyPolygons.Count-1 do
              if  PotentialHoles[HoleInterior] then
              begin
                var HoleInteriorIndex := PolygonIndices[HoleInterior];
                var Interior := PolyPolygons.Parts[HoleInteriorIndex];
                if Hole.BoundingBox.Contains(Interior.BoundingBox) then
                PotentialHoles[HoleInterior] := false;
              end;
            end;
          end;
        end;
        Inc(OuterCount);
      end;
    end;
    SetLength(FPolyPolygons,OuterCount);
  end else
    raise Exception.Create('Invalid shape type');
end;

Function TPolyPolygons.GetPolyPolygons(Polypolygon: Integer): TPolyPolygon;
begin
  Result := FPolyPolygons[PolyPolygon];
end;

Function TPolyPolygons.Count: Integer;
begin
  Result := Length(FPolyPolygons);
end;

end.

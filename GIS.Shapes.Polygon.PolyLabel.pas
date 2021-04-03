unit GIS.Shapes.Polygon.PolyLabel;

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
  GIS,GIS.Shapes.Polygon;

Type
  TPolyLabel = record
  public
    // Find the visual center of a poly polygon, using a (slightly modified) PolyLabel algorithm
    // https://github.com/mapbox/polylabel
    Class Function PolyLabel(const [ref] PolyPolygon: TPolyPolygon; const MaxIter: Integer): TCoordinate; static;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Type
  TPolyLabelCell = Class
  private
    Const
      Factor = 0.7071067811865475244; // sqrt(2)/2;
    Var
      Size,Dist,Potential: Float64;
      Center: TCoordinate;
      Location: TPointLocation;
      Next: TPolyLabelCell;
    Procedure SetDistance(const [ref] PolyPolygon: TPolyPolygon);
    Function SetPotential: Float64;
    Function NorthEast: TPolyLabelCell;
    Function NorthWest: TPolyLabelCell;
    Function SouthEast: TPolyLabelCell;
    Function SouthWest: TPolyLabelCell;
  end;

Procedure TPolyLabelCell.SetDistance(const [ref] PolyPolygon: TPolyPolygon);
begin
  Dist := PolyPolygon.Distance(Center,Location);
end;

Function TPolyLabelCell.SetPotential: Float64;
begin
  if Location = plInterior then
    Potential := Factor*Size+Dist
  else
    Potential := Factor*Size-Dist;
  Result := Potential;
end;

Function TPolyLabelCell.NorthEast: TPolyLabelCell;
begin
  var Delta := Size/4;
  Result := TPolyLabelCell.Create;
  Result.Size := Size/2;
  Result.Center.X := Center.X + Delta;
  Result.Center.Y := Center.Y + Delta;
end;

Function TPolyLabelCell.NorthWest: TPolyLabelCell;
begin
  var Delta := Size/4;
  Result := TPolyLabelCell.Create;
  Result.Size := Size/2;
  Result.Center.X := Center.X - Delta;
  Result.Center.Y := Center.Y + Delta;
end;

Function TPolyLabelCell.SouthEast: TPolyLabelCell;
begin
  var Delta := Size/4;
  Result := TPolyLabelCell.Create;
  Result.Size := Size/2;
  Result.Center.X := Center.X + Delta;
  Result.Center.Y := Center.Y - Delta;
end;

Function TPolyLabelCell.SouthWest: TPolyLabelCell;
begin
  var Delta := Size/4;
  Result := TPolyLabelCell.Create;
  Result.Size := Size/2;
  Result.Center.X := Center.X - Delta;
  Result.Center.Y := Center.Y - Delta;
end;

////////////////////////////////////////////////////////////////////////////////

Class Function TPolyLabel.PolyLabel(const [ref] PolyPolygon: TPolyPolygon; const MaxIter: Integer): TCoordinate;
Var
  First,Last: TPolyLabelCell;
begin
  // Initialize list with bounding box cell
  var Cell := TPolyLabelCell.Create;
  var BoundingBox := PolyPolygon.OuterRing.BoundingBox;
  Cell.Center := BoundingBox.CenterPoint;
  if BoundingBox.Width > BoundingBox.Height then
    Cell.Size := BoundingBox.Width
  else
    Cell.Size := BoundingBox.Height;
  // Initialize best
  var Best := 0.0;
  Result := Cell.Center;
  // Iteratively improve solution
  First := Cell;
  Last := Cell;
  var Iter := 0;
  repeat
    Inc(Iter);
    Cell := First;
    First := Cell.Next;
    // Subdivide first cell into four smaller cells ...
    // NorthEast subcell
    var SubCell := Cell.NorthEast;
    SubCell.SetDistance(PolyPolygon);
    if SubCell.SetPotential > Best then
    begin
      // Update best
      if (SubCell.Dist > Best) and (SubCell.Location = plInterior) then
      begin
        Best := SubCell.Dist;
        Result := SubCell.Center;
      end;
      // Add subcell to list
      if First = nil then
      begin
        First := Subcell;
        Last := SubCell
      end else
      if SubCell.Potential > First.Potential then
      begin
        SubCell.Next := First;
        First := SubCell;
      end else
      begin
        Last.Next := SubCell;
        Last := SubCell;
      end;
    end;
    // NorthWest subcell
    SubCell := Cell.NorthWest;
    SubCell.SetDistance(PolyPolygon);
    if SubCell.SetPotential > Best then
    begin
      // Update best
      if (SubCell.Dist > Best) and (SubCell.Location = plInterior) then
      begin
        Best := SubCell.Dist;
        Result := SubCell.Center;
      end;
      // Add subcell to list
      if First = nil then
      begin
        First := Subcell;
        Last := SubCell
      end else
      if SubCell.Potential > First.Potential then
      begin
        SubCell.Next := First;
        First := SubCell;
      end else
      begin
        Last.Next := SubCell;
        Last := SubCell;
      end;
    end;
    // SouthEast subcell
    SubCell := Cell.SouthEast;
    SubCell.SetDistance(PolyPolygon);
    if SubCell.SetPotential > Best then
    begin
      // Update best
      if (SubCell.Dist > Best) and (SubCell.Location = plInterior) then
      begin
        Best := SubCell.Dist;
        Result := SubCell.Center;
      end;
      // Add subcell to list
      if First = nil then
      begin
        First := Subcell;
        Last := SubCell
      end else
      if SubCell.Potential > First.Potential then
      begin
        SubCell.Next := First;
        First := SubCell;
      end else
      begin
        Last.Next := SubCell;
        Last := SubCell;
      end;
    end;
    // SouthWest subcell
    SubCell := Cell.SouthWest;
    SubCell.SetDistance(PolyPolygon);
    if SubCell.SetPotential > Best then
    begin
      // Update best
      if (SubCell.Dist > Best) and (SubCell.Location = plInterior) then
      begin
        Best := SubCell.Dist;
        Result := SubCell.Center;
      end;
      // Add subcell to list
      if First = nil then
      begin
        First := Subcell;
        Last := SubCell
      end else
      if SubCell.Potential > First.Potential then
      begin
        SubCell.Next := First;
        First := SubCell;
      end else
      begin
        Last.Next := SubCell;
        Last := SubCell;
      end;
    end;
    // Remove cell
    Cell.Free;
  until (First=nil) or (First.Next = nil) or (Iter>=MaxIter);
  // Clear list
  while First <> nil do
  begin
    Cell := First;
    First := Cell.Next;
    Cell.Free;
  end;
end;

end.

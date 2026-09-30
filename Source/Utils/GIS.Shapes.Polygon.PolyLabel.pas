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
  Types,GIS,GIS.Shapes.Polygon;

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
    Constructor Create(const Center: TCoordinate; const Size: Float64);
    Procedure SetDistance(const [ref] PolyPolygon: TPolyPolygon);
    Function SetPotential: Float64;
    // One of the four cells of half the size this cell divides into, the
    // signs telling which quadrant
    Function SubCell(const SignX,SignY: Integer): TPolyLabelCell;
  end;

  TPolyLabelSearch = Class
  // The cells still to be subdivided, and the best label position found so far
  private
    First,Last: TPolyLabelCell;
    Best: Float64;
    BestCenter: TCoordinate;
    // A cell goes to the front of the list when it promises more than the
    // cell there, and to the back otherwise
    Procedure Push(const Cell: TPolyLabelCell);
    Function Pop: TPolyLabelCell;
    // Keeps a subcell that could still improve on the best position; frees
    // one that cannot
    Procedure Consider(const SubCell: TPolyLabelCell; const [ref] PolyPolygon: TPolyPolygon);
    Destructor Destroy; override;
  end;

////////////////////////////////////////////////////////////////////////////////

Constructor TPolyLabelCell.Create(const Center: TCoordinate; const Size: Float64);
begin
  inherited Create;
  Self.Center := Center;
  Self.Size := Size;
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

Function TPolyLabelCell.SubCell(const SignX,SignY: Integer): TPolyLabelCell;
begin
  var Delta := Size/4;
  Result := TPolyLabelCell.Create(TCoordinate.Create(Center.X+SignX*Delta,Center.Y+SignY*Delta),Size/2);
end;

////////////////////////////////////////////////////////////////////////////////

Procedure TPolyLabelSearch.Push(const Cell: TPolyLabelCell);
begin
  if First = nil then
  begin
    First := Cell;
    Last := Cell;
  end else
  if Cell.Potential > First.Potential then
  begin
    Cell.Next := First;
    First := Cell;
  end else
  begin
    Last.Next := Cell;
    Last := Cell;
  end;
end;

Function TPolyLabelSearch.Pop: TPolyLabelCell;
begin
  Result := First;
  First := Result.Next;
  if First = nil then Last := nil;
  Result.Next := nil;
end;

Procedure TPolyLabelSearch.Consider(const SubCell: TPolyLabelCell; const [ref] PolyPolygon: TPolyPolygon);
begin
  SubCell.SetDistance(PolyPolygon);
  if SubCell.SetPotential > Best then
  begin
    // Update best
    if (SubCell.Dist > Best) and (SubCell.Location = plInterior) then
    begin
      Best := SubCell.Dist;
      BestCenter := SubCell.Center;
    end;
    Push(SubCell);
  end else
    SubCell.Free;
end;

Destructor TPolyLabelSearch.Destroy;
begin
  while First <> nil do Pop.Free;
  inherited Destroy;
end;

////////////////////////////////////////////////////////////////////////////////

Class Function TPolyLabel.PolyLabel(const [ref] PolyPolygon: TPolyPolygon; const MaxIter: Integer): TCoordinate;
Const
  Quadrants: array[0..3] of TPoint = ((X:+1;Y:+1),(X:-1;Y:+1),(X:+1;Y:-1),(X:-1;Y:-1));
begin
  var Search := TPolyLabelSearch.Create;
  try
    // Start with the bounding box cell
    var BoundingBox := PolyPolygon.OuterRing.BoundingBox;
    var Size := BoundingBox.Width;
    if BoundingBox.Height > Size then Size := BoundingBox.Height;
    Search.BestCenter := BoundingBox.CenterPoint;
    Search.Push(TPolyLabelCell.Create(BoundingBox.CenterPoint,Size));
    // Iteratively improve solution
    var Iter := 0;
    repeat
      Inc(Iter);
      // Subdivide first cell into four smaller cells
      var Cell := Search.Pop;
      try
        for var Quadrant := low(Quadrants) to high(Quadrants) do
        Search.Consider(Cell.SubCell(Quadrants[Quadrant].X,Quadrants[Quadrant].Y),PolyPolygon);
      finally
        Cell.Free;
      end;
    until (Search.First = nil) or (Search.First.Next = nil) or (Iter >= MaxIter);
    Result := Search.BestCenter;
  finally
    Search.Free;
  end;
end;

end.

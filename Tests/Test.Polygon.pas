unit Test.Polygon;

////////////////////////////////////////////////////////////////////////////////
//
// Author: Jaap Baak
// https://github.com/transportmodelling/GISlib
//
// Test suite generated with assistance from Claude Sonnet 4.6
//
// Tests for TPolyPolygons.Contains and TPolyPolygons.Distance from
// GIS.Shapes.Polygon - no external data files required.
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
interface
////////////////////////////////////////////////////////////////////////////////

uses
  DUnitX.TestFramework, GIS, GIS.Shapes, GIS.Shapes.Polygon;

type
  [TestFixture]
  TPolyPolygonsTests = class
  private
    // Unit square: (0,0)-(1,0)-(1,1)-(0,1)
    function UnitSquare: TPolyPolygons;
    // Outer 10x10 square centred at origin with a 2x2 square hole at origin
    function DonutPolygon: TPolyPolygons;
    // Two disjoint unit squares: A at x=0..1, B at x=3..4
    function TwoDisjointSquares: TPolyPolygons;
  public
    // ----- Construction -------------------------------------------------------
    [Test] procedure Create_SinglePolygon_CountIsOne;
    [Test] procedure Create_DonutPolygon_HasOnePartWithOneHole;
    [Test] procedure Create_TwoDisjointSquares_CountIsTwo;

    // ----- Contains -----------------------------------------------------------
    [Test] procedure Contains_PointInside_ReturnsTrue;
    [Test] procedure Contains_PointOutside_ReturnsFalse;
    [Test] procedure Contains_PointInHole_ReturnsFalse;
    [Test] procedure Contains_PointInsideOuterRingButOutsideHole_ReturnsTrue;
    [Test] procedure Contains_MultiPart_PointInFirstPart_ReturnsTrue;
    [Test] procedure Contains_MultiPart_PointInSecondPart_ReturnsTrue;
    [Test] procedure Contains_MultiPart_PointBetweenParts_ReturnsFalse;

    // ----- TPolyPolygons.Distance (returns 0 for interior) --------------------
    [Test] procedure Distance_PointInside_ReturnsZero;
    [Test] procedure Distance_PointOutside_PerpendicularToEdge;
    [Test] procedure Distance_PointOutside_NearCorner;
    [Test] procedure Distance_PointInHole_ReturnsDistanceToHoleEdge;

    // ----- TPolyPolygon.Distance overload (returns edge distance everywhere) --
    [Test] procedure PolyPolygonDistance_Interior_LocationIsInterior;
    [Test] procedure PolyPolygonDistance_Interior_ReturnsDistanceToNearestEdge;
    [Test] procedure PolyPolygonDistance_Exterior_LocationIsExterior;
    [Test] procedure PolyPolygonDistance_Exterior_ReturnsDistanceToEdge;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

{ TPolyPolygonsTests helpers }

function TPolyPolygonsTests.UnitSquare: TPolyPolygons;
var
  Pts: array[0..3] of TCoordinate;
  Shape: TGISShape;
begin
  Pts[0] := TCoordinate.Create(0, 0);
  Pts[1] := TCoordinate.Create(1, 0);
  Pts[2] := TCoordinate.Create(1, 1);
  Pts[3] := TCoordinate.Create(0, 1);
  Shape.AssignPolygon(Pts);
  Result := TPolyPolygons.Create(Shape);
end;

function TPolyPolygonsTests.DonutPolygon: TPolyPolygons;
// Outer ring: 10x10 square (-5,-5)-(5,5); hole: 2x2 square (-1,-1)-(1,1)
var
  Parts: TMultiPoints;
  Shape: TGISShape;
begin
  SetLength(Parts, 2);
  SetLength(Parts[0], 4);
  Parts[0][0] := TCoordinate.Create(-5, -5);
  Parts[0][1] := TCoordinate.Create( 5, -5);
  Parts[0][2] := TCoordinate.Create( 5,  5);
  Parts[0][3] := TCoordinate.Create(-5,  5);
  SetLength(Parts[1], 4);
  Parts[1][0] := TCoordinate.Create(-1, -1);
  Parts[1][1] := TCoordinate.Create( 1, -1);
  Parts[1][2] := TCoordinate.Create( 1,  1);
  Parts[1][3] := TCoordinate.Create(-1,  1);
  Shape.AssignPolyPolygon(Parts);
  Result := TPolyPolygons.Create(Shape);
end;

function TPolyPolygonsTests.TwoDisjointSquares: TPolyPolygons;
// Square A: (0,0)-(1,1)  Square B: (3,0)-(4,1)
var
  Parts: TMultiPoints;
  Shape: TGISShape;
begin
  SetLength(Parts, 2);
  SetLength(Parts[0], 4);
  Parts[0][0] := TCoordinate.Create(0, 0);
  Parts[0][1] := TCoordinate.Create(1, 0);
  Parts[0][2] := TCoordinate.Create(1, 1);
  Parts[0][3] := TCoordinate.Create(0, 1);
  SetLength(Parts[1], 4);
  Parts[1][0] := TCoordinate.Create(3, 0);
  Parts[1][1] := TCoordinate.Create(4, 0);
  Parts[1][2] := TCoordinate.Create(4, 1);
  Parts[1][3] := TCoordinate.Create(3, 1);
  Shape.AssignPolyPolygon(Parts);
  Result := TPolyPolygons.Create(Shape);
end;

{ Construction }

procedure TPolyPolygonsTests.Create_SinglePolygon_CountIsOne;
begin
  Assert.AreEqual(1, UnitSquare.Count);
end;

procedure TPolyPolygonsTests.Create_DonutPolygon_HasOnePartWithOneHole;
var PP: TPolyPolygons;
begin
  PP := DonutPolygon;
  Assert.AreEqual(1, PP.Count, 'Expected one outer ring');
  Assert.AreEqual(1, PP[0].HolesCount, 'Expected one hole');
end;

procedure TPolyPolygonsTests.Create_TwoDisjointSquares_CountIsTwo;
begin
  Assert.AreEqual(2, TwoDisjointSquares.Count);
end;

{ Contains }

procedure TPolyPolygonsTests.Contains_PointInside_ReturnsTrue;
begin
  Assert.IsTrue(UnitSquare.Contains(TCoordinate.Create(0.5, 0.5)));
end;

procedure TPolyPolygonsTests.Contains_PointOutside_ReturnsFalse;
begin
  Assert.IsFalse(UnitSquare.Contains(TCoordinate.Create(2.0, 0.5)));
end;

procedure TPolyPolygonsTests.Contains_PointInHole_ReturnsFalse;
begin
  // (0,0) is inside the outer ring but also inside the 2x2 hole
  Assert.IsFalse(DonutPolygon.Contains(TCoordinate.Create(0.0, 0.0)));
end;

procedure TPolyPolygonsTests.Contains_PointInsideOuterRingButOutsideHole_ReturnsTrue;
begin
  // (3,3) is inside the 10x10 outer ring and outside the 2x2 hole
  Assert.IsTrue(DonutPolygon.Contains(TCoordinate.Create(3.0, 3.0)));
end;

procedure TPolyPolygonsTests.Contains_MultiPart_PointInFirstPart_ReturnsTrue;
begin
  Assert.IsTrue(TwoDisjointSquares.Contains(TCoordinate.Create(0.5, 0.5)));
end;

procedure TPolyPolygonsTests.Contains_MultiPart_PointInSecondPart_ReturnsTrue;
begin
  Assert.IsTrue(TwoDisjointSquares.Contains(TCoordinate.Create(3.5, 0.5)));
end;

procedure TPolyPolygonsTests.Contains_MultiPart_PointBetweenParts_ReturnsFalse;
begin
  Assert.IsFalse(TwoDisjointSquares.Contains(TCoordinate.Create(2.0, 0.5)));
end;

{ TPolyPolygons.Distance }

procedure TPolyPolygonsTests.Distance_PointInside_ReturnsZero;
begin
  Assert.AreEqual(0.0, UnitSquare.Distance(TCoordinate.Create(0.5, 0.5)), 1e-12);
end;

procedure TPolyPolygonsTests.Distance_PointOutside_PerpendicularToEdge;
// (1.5, 0.5) is 0.5 units to the right of the right edge of the unit square
begin
  Assert.AreEqual(0.5, UnitSquare.Distance(TCoordinate.Create(1.5, 0.5)), 1e-12);
end;

procedure TPolyPolygonsTests.Distance_PointOutside_NearCorner;
// (2, 0) - nearest point on the unit square is corner (1,0), distance = 1
begin
  Assert.AreEqual(1.0, UnitSquare.Distance(TCoordinate.Create(2.0, 0.0)), 1e-12);
end;

procedure TPolyPolygonsTests.Distance_PointInHole_ReturnsDistanceToHoleEdge;
// (0,0) is in the hole; all four hole edges are exactly 1 unit away
begin
  Assert.AreEqual(1.0, DonutPolygon.Distance(TCoordinate.Create(0.0, 0.0)), 1e-12);
end;

{ TPolyPolygon.Distance overload (out Location) }

procedure TPolyPolygonsTests.PolyPolygonDistance_Interior_LocationIsInterior;
var Loc: TPointLocation;
begin
  UnitSquare[0].Distance(TCoordinate.Create(0.5, 0.5), Loc);
  Assert.AreEqual(Ord(plInterior), Ord(Loc));
end;

procedure TPolyPolygonsTests.PolyPolygonDistance_Interior_ReturnsDistanceToNearestEdge;
// Centre of unit square is 0.5 from every edge
var Loc: TPointLocation;
begin
  Assert.AreEqual(0.5, UnitSquare[0].Distance(TCoordinate.Create(0.5, 0.5), Loc), 1e-12);
end;

procedure TPolyPolygonsTests.PolyPolygonDistance_Exterior_LocationIsExterior;
var Loc: TPointLocation;
begin
  UnitSquare[0].Distance(TCoordinate.Create(1.5, 0.5), Loc);
  Assert.AreEqual(Ord(plExterior), Ord(Loc));
end;

procedure TPolyPolygonsTests.PolyPolygonDistance_Exterior_ReturnsDistanceToEdge;
var Loc: TPointLocation;
begin
  Assert.AreEqual(0.5, UnitSquare[0].Distance(TCoordinate.Create(1.5, 0.5), Loc), 1e-12);
end;

initialization
  TDUnitX.RegisterTestFixture(TPolyPolygonsTests);

end.

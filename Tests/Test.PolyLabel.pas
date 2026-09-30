unit Test.PolyLabel;

////////////////////////////////////////////////////////////////////////////////
//
// Author: Jaap Baak
// https://github.com/transportmodelling/GISlib
//
// Tests for TPolyLabel.PolyLabel from GIS.Shapes.Polygon.PolyLabel - no
// external data files required.
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
interface
////////////////////////////////////////////////////////////////////////////////

uses
  DUnitX.TestFramework, GIS, GIS.Shapes, GIS.Shapes.Polygon,
  GIS.Shapes.Polygon.PolyLabel;

type
  [TestFixture]
  TPolyLabelTests = class
  private
    Const
      MaxIter = 100;
    // Unit square: (0,0)-(1,0)-(1,1)-(0,1)
    Function UnitSquare: TPolyPolygon;
    // Outer 10x10 square centred at origin with a 2x2 square hole at origin
    Function Donut: TPolyPolygon;
    // The number of heap blocks allocated at this moment
    Function AllocatedBlocks: Int64;
  public
    [Test] Procedure PolyLabel_UnitSquare_ReturnsCentre;
    [Test] Procedure PolyLabel_Donut_LiesInsideRingOutsideHole;
    [Test] Procedure PolyLabel_FreesEveryCell;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Function TPolyLabelTests.UnitSquare: TPolyPolygon;
var
  Pts: array[0..3] of TCoordinate;
  Shape: TGISShape;
begin
  Pts[0] := TCoordinate.Create(0, 0);
  Pts[1] := TCoordinate.Create(1, 0);
  Pts[2] := TCoordinate.Create(1, 1);
  Pts[3] := TCoordinate.Create(0, 1);
  Shape.AssignPolygon(Pts);
  Result := TPolyPolygons.Create(Shape)[0];
end;

Function TPolyLabelTests.Donut: TPolyPolygon;
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
  Result := TPolyPolygons.Create(Shape)[0];
end;

{$WARN SYMBOL_PLATFORM OFF}
Function TPolyLabelTests.AllocatedBlocks: Int64;
// Delphi's own memory manager keeps these counts on every platform it runs on
var
  State: TMemoryManagerState;
begin
  GetMemoryManagerState(State);
  Result := State.AllocatedMediumBlockCount + State.AllocatedLargeBlockCount;
  for var BlockType := low(State.SmallBlockTypeStates) to high(State.SmallBlockTypeStates) do
  Inc(Result, State.SmallBlockTypeStates[BlockType].AllocatedBlockCount);
end;
{$WARN SYMBOL_PLATFORM ON}

Procedure TPolyLabelTests.PolyLabel_UnitSquare_ReturnsCentre;
begin
  var Position := TPolyLabel.PolyLabel(UnitSquare, MaxIter);
  Assert.AreEqual(0.5, Position.X, 0.05, 'X');
  Assert.AreEqual(0.5, Position.Y, 0.05, 'Y');
end;

Procedure TPolyLabelTests.PolyLabel_Donut_LiesInsideRingOutsideHole;
// The widest part of the ring is 2 units from both the hole and the outer edge
var
  Location: TPointLocation;
begin
  var Polygon := Donut;
  var Position := TPolyLabel.PolyLabel(Polygon, MaxIter);
  var Distance := Polygon.Distance(Position, Location);
  Assert.IsTrue(Location = plInterior, 'Label position is not inside the ring');
  Assert.IsTrue(Distance >= 1.5, 'Label position is too close to an edge');
end;

Procedure TPolyLabelTests.PolyLabel_FreesEveryCell;
// The search subdivides every cell it takes up, and discards most of the
// subcells; the discarded ones must be freed like the kept ones
begin
  var Polygon := Donut;
  // Warm up, so the memory manager has its pools in place
  TPolyLabel.PolyLabel(Polygon, MaxIter);
  var Before := AllocatedBlocks;
  TPolyLabel.PolyLabel(Polygon, MaxIter);
  Assert.AreEqual(Before, AllocatedBlocks, 'Heap blocks left allocated');
end;

initialization
  TDUnitX.RegisterTestFixture(TPolyLabelTests);

end.

unit Test.Geometry;

////////////////////////////////////////////////////////////////////////////////
//
// Author: Jaap Baak
// https://github.com/transportmodelling/GISlib
//
// Test suite generated with assistance from Claude Sonnet 4.6
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
interface
////////////////////////////////////////////////////////////////////////////////

uses
  DUnitX.TestFramework, GIS, GIS.Shapes;

type
  [TestFixture]
  TCoordinateRectTests = class
  private
    function MakeRect: TCoordinateRect;
  public
    // Width / Height
    [Test] procedure Width_ReturnsRightMinusLeft;
    [Test] procedure Height_ReturnsTopMinusBottom;

    // CenterPoint
    [Test] procedure CenterPoint_ReturnsCorrectValue;

    // Empty / Clear
    [Test] procedure Empty_WhenLeftGreaterThanRight;
    [Test] procedure Empty_WhenBottomGreaterThanTop;
    [Test] procedure NotEmpty_WhenValid;
    [Test] procedure Clear_MakesRectEmpty;

    // Enclose
    [Test] procedure Enclose_PointInsideDoesNotExpand;
    [Test] procedure Enclose_PointOutsideExpandsLeft;
    [Test] procedure Enclose_PointOutsideExpandsRight;
    [Test] procedure Enclose_PointOutsideExpandsTop;
    [Test] procedure Enclose_PointOutsideExpandsBottom;
    [Test] procedure Enclose_FirstPointOnEmptyRect;

    // Contains
    [Test] procedure Contains_PointInsideReturnsTrue;
    [Test] procedure Contains_PointOutsideReturnsFalse;
    [Test] procedure Contains_PointOnBoundaryReturnsTrue;

    // IntersectsWith
    [Test] procedure IntersectsWith_OverlappingRectsReturnsTrue;
    [Test] procedure IntersectsWith_NonOverlappingReturnsFalse;
    [Test] procedure IntersectsWith_TouchingReturnsFalse;
  end;

  [TestFixture]
  TCoordinateTests = class
  public
    [Test] Procedure Distance_IsEuclidean;
    [Test] Procedure SqrDistance_IsSquareOfDistance;
  end;

  [TestFixture]
  TShapePartTests = class
  private
    // An L-shaped ring over the unit squares with lower left corners (0,0),
    // (0,1) and (1,1): the square at (1,0) is missing
    Function LShape: TShapePart;
  public
    [Test] Procedure Contains_PointInsideSquare;
    [Test] Procedure Contains_PointOutsideSquare;
    [Test] Procedure Contains_PointInsideLShape;
    [Test] Procedure Contains_PointInLShapeNotch;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

function TCoordinateRectTests.MakeRect: TCoordinateRect;
begin
  Result.Left   := 1.0;
  Result.Right  := 5.0;
  Result.Bottom := 2.0;
  Result.Top    := 6.0;
end;

procedure TCoordinateRectTests.Width_ReturnsRightMinusLeft;
begin
  Assert.AreEqual(4.0, MakeRect.Width, 1e-12);
end;

procedure TCoordinateRectTests.Height_ReturnsTopMinusBottom;
begin
  Assert.AreEqual(4.0, MakeRect.Height, 1e-12);
end;

procedure TCoordinateRectTests.CenterPoint_ReturnsCorrectValue;
var
  C: TCoordinate;
begin
  C := MakeRect.CenterPoint;
  Assert.AreEqual(3.0, C.X, 1e-12);
  Assert.AreEqual(4.0, C.Y, 1e-12);
end;

procedure TCoordinateRectTests.Empty_WhenLeftGreaterThanRight;
var
  R: TCoordinateRect;
begin
  R.Left := 5; R.Right := 1; R.Bottom := 0; R.Top := 10;
  Assert.IsTrue(R.Empty);
end;

procedure TCoordinateRectTests.Empty_WhenBottomGreaterThanTop;
var
  R: TCoordinateRect;
begin
  R.Left := 0; R.Right := 10; R.Bottom := 6; R.Top := 2;
  Assert.IsTrue(R.Empty);
end;

procedure TCoordinateRectTests.NotEmpty_WhenValid;
begin
  Assert.IsFalse(MakeRect.Empty);
end;

procedure TCoordinateRectTests.Clear_MakesRectEmpty;
var
  R: TCoordinateRect;
begin
  R := MakeRect;
  R.Clear;
  Assert.IsTrue(R.Empty);
end;

procedure TCoordinateRectTests.Enclose_PointInsideDoesNotExpand;
var
  R: TCoordinateRect;
begin
  R := MakeRect;
  R.Enclose(TCoordinate.Create(3.0, 4.0));
  Assert.AreEqual(1.0, R.Left,   1e-12);
  Assert.AreEqual(5.0, R.Right,  1e-12);
  Assert.AreEqual(2.0, R.Bottom, 1e-12);
  Assert.AreEqual(6.0, R.Top,    1e-12);
end;

procedure TCoordinateRectTests.Enclose_PointOutsideExpandsLeft;
var
  R: TCoordinateRect;
begin
  R := MakeRect;
  R.Enclose(TCoordinate.Create(-2.0, 4.0));
  Assert.AreEqual(-2.0, R.Left, 1e-12);
end;

procedure TCoordinateRectTests.Enclose_PointOutsideExpandsRight;
var
  R: TCoordinateRect;
begin
  R := MakeRect;
  R.Enclose(TCoordinate.Create(9.0, 4.0));
  Assert.AreEqual(9.0, R.Right, 1e-12);
end;

procedure TCoordinateRectTests.Enclose_PointOutsideExpandsTop;
var
  R: TCoordinateRect;
begin
  R := MakeRect;
  R.Enclose(TCoordinate.Create(3.0, 10.0));
  Assert.AreEqual(10.0, R.Top, 1e-12);
end;

procedure TCoordinateRectTests.Enclose_PointOutsideExpandsBottom;
var
  R: TCoordinateRect;
begin
  R := MakeRect;
  R.Enclose(TCoordinate.Create(3.0, -1.0));
  Assert.AreEqual(-1.0, R.Bottom, 1e-12);
end;

procedure TCoordinateRectTests.Enclose_FirstPointOnEmptyRect;
var
  R: TCoordinateRect;
begin
  R.Clear;
  R.Enclose(TCoordinate.Create(3.0, 7.0));
  Assert.IsFalse(R.Empty);
  Assert.AreEqual(3.0, R.Left,   1e-12);
  Assert.AreEqual(3.0, R.Right,  1e-12);
  Assert.AreEqual(7.0, R.Bottom, 1e-12);
  Assert.AreEqual(7.0, R.Top,    1e-12);
end;

procedure TCoordinateRectTests.Contains_PointInsideReturnsTrue;
begin
  Assert.IsTrue(MakeRect.Contains(TCoordinate.Create(3.0, 4.0)));
end;

procedure TCoordinateRectTests.Contains_PointOutsideReturnsFalse;
begin
  Assert.IsFalse(MakeRect.Contains(TCoordinate.Create(0.0, 4.0)));
end;

procedure TCoordinateRectTests.Contains_PointOnBoundaryReturnsTrue;
begin
  Assert.IsTrue(MakeRect.Contains(TCoordinate.Create(1.0, 2.0)));
end;

procedure TCoordinateRectTests.IntersectsWith_OverlappingRectsReturnsTrue;
var
  A, B: TCoordinateRect;
begin
  A := MakeRect;
  B.Left := 3; B.Right := 8; B.Bottom := 4; B.Top := 9;
  Assert.IsTrue(A.IntersectsWith(B));
end;

procedure TCoordinateRectTests.IntersectsWith_NonOverlappingReturnsFalse;
var
  A, B: TCoordinateRect;
begin
  A := MakeRect;
  B.Left := 10; B.Right := 20; B.Bottom := 10; B.Top := 20;
  Assert.IsFalse(A.IntersectsWith(B));
end;

procedure TCoordinateRectTests.IntersectsWith_TouchingReturnsFalse;
var
  A, B: TCoordinateRect;
begin
  A := MakeRect;                           // Right = 5
  B.Left := 5; B.Right := 9; B.Bottom := 2; B.Top := 6;
  Assert.IsFalse(A.IntersectsWith(B));
end;

////////////////////////////////////////////////////////////////////////////////

Procedure TCoordinateTests.Distance_IsEuclidean;
begin
  var A := TCoordinate.Create(1, 2);
  var B := TCoordinate.Create(4, 6);
  Assert.AreEqual(5.0, A.Distance(B), 1e-12);
  Assert.AreEqual(5.0, B.Distance(A), 1e-12, 'Distance should be symmetric');
end;

Procedure TCoordinateTests.SqrDistance_IsSquareOfDistance;
begin
  var A := TCoordinate.Create(1, 2);
  var B := TCoordinate.Create(4, 6);
  Assert.AreEqual(25.0, A.SqrDistance(B), 1e-12);
end;

////////////////////////////////////////////////////////////////////////////////

Function TShapePartTests.LShape: TShapePart;
begin
  Result := TShapePart.Create([TCoordinate.Create(0, 0), TCoordinate.Create(1, 0),
                               TCoordinate.Create(1, 1), TCoordinate.Create(2, 1),
                               TCoordinate.Create(2, 2), TCoordinate.Create(0, 2)], true);
end;

Procedure TShapePartTests.Contains_PointInsideSquare;
begin
  var Square := TShapePart.Create([TCoordinate.Create(0, 0), TCoordinate.Create(1, 0),
                                   TCoordinate.Create(1, 1), TCoordinate.Create(0, 1)], true);
  Assert.IsTrue(Square.Contains(TCoordinate.Create(0.5, 0.5)));
end;

Procedure TShapePartTests.Contains_PointOutsideSquare;
begin
  var Square := TShapePart.Create([TCoordinate.Create(0, 0), TCoordinate.Create(1, 0),
                                   TCoordinate.Create(1, 1), TCoordinate.Create(0, 1)], true);
  Assert.IsFalse(Square.Contains(TCoordinate.Create(1.5, 0.5)), 'Right of the square');
  Assert.IsFalse(Square.Contains(TCoordinate.Create(0.5, 1.5)), 'Above the square');
end;

Procedure TShapePartTests.Contains_PointInsideLShape;
begin
  Assert.IsTrue(LShape.Contains(TCoordinate.Create(0.5, 0.5)), 'Lower square');
  Assert.IsTrue(LShape.Contains(TCoordinate.Create(1.5, 1.5)), 'Upper right square');
end;

Procedure TShapePartTests.Contains_PointInLShapeNotch;
begin
  // Inside the ring's bounding box, but in the missing square
  Assert.IsFalse(LShape.Contains(TCoordinate.Create(1.5, 0.5)));
end;

initialization
  TDUnitX.RegisterTestFixture(TCoordinateRectTests);
  TDUnitX.RegisterTestFixture(TCoordinateTests);
  TDUnitX.RegisterTestFixture(TShapePartTests);

end.

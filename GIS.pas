unit GIS;

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
  Math;

Type
  TCoordinate = record
    X,Y: Float64;
    Constructor Create(Xcoord,Ycoord: Float64);
  end;

  TCoordinateRect = record
    // For a non empty coordinate rect Left <= Right and Bottom <= Top (unlike TRectF)
    Left,Right,Bottom,Top: Float64;
    Function Empty: Boolean;
    Procedure Clear;
    Procedure Enclose(Point: TCoordinate); overload;
    Procedure Enclose(Rect: TCoordinateRect); overload;
    Function Width: Float64;
    Function Height: Float64;
    Function CenterPoint: TCoordinate;
    Function Scale(Factor: Float64): TCoordinateRect;
    Function Contains(const Point: TCoordinate): Boolean; overload;
    Function Contains(const [ref] Rect: TCoordinateRect): Boolean; overload;
    Function IntersectsWith(const [ref] Rect: TCoordinateRect): Boolean;
  end;

  TGeodeticCoordinate = record
    Latitude,Longitude: Float64;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Constructor TCoordinate.Create(Xcoord,Ycoord: Float64);
begin
  X := Xcoord;
  Y := YCoord;
end;

////////////////////////////////////////////////////////////////////////////////

Function TCoordinateRect.Empty: Boolean;
begin
  Result := (Left > Right) or (Bottom > Top);
end;

Procedure TCoordinateRect.Clear;
begin
  Left := Infinity;
  Right := -Infinity;
  Bottom := Infinity;
  Top := -Infinity;
end;

Procedure TCoordinateRect.Enclose(Point: TCoordinate);
begin
  if Point.X < Left then Left := Point.X;
  if Point.X > Right then Right := Point.X;
  if Point.Y < Bottom then Bottom := Point.Y;
  if Point.Y > Top then Top := Point.Y;
end;

Procedure TCoordinateRect.Enclose(Rect: TCoordinateRect);
begin
  if Rect.Left < Left then Left := Rect.Left;
  if Rect.Right > Right then Right := Rect.Right;
  if Rect.Bottom < Bottom then Bottom := Rect.Bottom;
  if Rect.Top > Top then Top := Rect.Top;
end;

Function TCoordinateRect.Width: Float64;
begin
  Result := Right-Left;
end;

Function TCoordinateRect.Height: Float64;
begin
  Result := Top-Bottom;
end;

Function TCoordinateRect.CenterPoint: TCoordinate;
begin
  Result.X := (Left+Right)/2;
  Result.Y := (Top+Bottom)/2;
end;

Function TCoordinateRect.Scale(Factor: Float64): TCoordinateRect;
begin
  var CenterX := (Left+Right)/2;
  var CenterY := (Top+Bottom)/2;
  Result.Left := CenterX - Factor*(CenterX-Left);
  Result.Right := CenterX + Factor*(Right-CenterX);
  Result.Bottom := CenterY - Factor*(CenterY-Bottom);
  Result.Top := CenterY + Factor*(Top-CenterY);
end;

Function TCoordinateRect.Contains(const Point: TCoordinate): Boolean;
begin
  Result := (Left <= Point.X) and (Right >= Point.X) and
            (Bottom <= Point.Y) and (Top >= Point.Y)
end;

Function TCoordinateRect.Contains(const [ref] Rect: TCoordinateRect): Boolean;
begin
  if not Rect.Empty then
    Result := (Left <= Rect.Left) and (Right >= Rect.Right) and
              (Bottom <= Rect.Bottom) and (Top >= Rect.Top)
  else
    Result := false;
end;

Function TCoordinateRect.IntersectsWith(const [ref] Rect: TCoordinateRect): Boolean;
begin
  if not Rect.Empty then
    Result := (Left < Rect.Right) and (Right > Rect.Left) and
              (Bottom < Rect.Top) and (Top > Rect.Bottom)
  else
    Result := false;
end;

end.

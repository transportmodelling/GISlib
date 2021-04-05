unit GIS.Render.Shapes.PixelConv;

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
  Types,GIS;

Type
  TCustomPixelConverter = Class
  private
    FMargin: Integer; // Pixels
    FTop,FLeft,FCoordUnitsPerPixel: Float64;
  public
    // Convert between pixels and world coordinates
    Function CoordToPixel(const Coord: TCoordinate): TPoint; overload;
    Function PixelToCoord(const Pixel: TPoint): TCoordinate; overload;
    Function PixelToCoord(const Width,Height: Integer): TCoordinateRect; overload;
    // Get and set center coordinates
    Function GetCenter(PixelWidth,PixelHeight: Integer): TCoordinate; overload;
    Procedure SetCenter(Coord: TCoordinate; PixelWidth,PixelHeight: Integer; ZoomFactor: Float64 = 1.0); overload;
    Procedure Shift(XPixelShift,YPixelShift: Integer);
  public
    Property Top: Float64 read FTop;
    Property Left: Float64 read FLeft;
    Property Margin: Integer read FMargin;
  end;

  TPixelConverter = Class(TCustomPixelConverter)
  public
    Procedure Initialize(const Viewport: TCoordinateRect; PixelWidth,PixelHeight,Margin: Integer);
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Function TCustomPixelConverter.CoordToPixel(const Coord: TCoordinate): TPoint;
begin
  Result.X := Round((Coord.X-FLeft)/FCoordUnitsPerPixel);
  Result.Y := Round((FTop-Coord.Y)/FCoordUnitsPerPixel);
end;

Function TCustomPixelConverter.PixelToCoord(const Pixel: TPoint): TCoordinate;
begin
  Result.X := FLeft + Pixel.X*FCoordUnitsPerPixel;
  Result.Y := FTop - Pixel.Y*FCoordUnitsPerPixel;
end;

Function TCustomPixelConverter.PixelToCoord(const Width,Height: Integer): TCoordinateRect;
begin
  Result.Left := FLeft;
  Result.Right := FLeft + Width*FCoordUnitsPerPixel;
  Result.Bottom := FTop - Height*FCoordUnitsPerPixel;
  Result.Top := FTop;
end;

Function TCustomPixelConverter.GetCenter(PixelWidth,PixelHeight: Integer): TCoordinate;
begin
  Result.X := FLeft + PixelWidth*FCoordUnitsPerPixel/2;
  Result.Y := FTop - PixelHeight*FCoordUnitsPerPixel/2;
end;

Procedure TCustomPixelConverter.SetCenter(Coord: TCoordinate;
                                          PixelWidth,PixelHeight: Integer;
                                          ZoomFactor: Float64 = 1.0);
begin
  FCoordUnitsPerPixel := FCoordUnitsPerPixel/ZoomFactor;
  FLeft := Coord.X - PixelWidth*FCoordUnitsPerPixel/2 + FMargin;
  FTop := Coord.Y + PixelHeight*FCoordUnitsPerPixel/2 + FMargin;
end;

Procedure TCustomPixelConverter.Shift(XPixelShift,YPixelShift: Integer);
begin
  FLeft := FLeft + XPixelShift*FCoordUnitsPerPixel;
  FTop := FTop - YPixelShift*FCoordUnitsPerPixel;
end;

////////////////////////////////////////////////////////////////////////////////

Procedure TPixelConverter.Initialize(const Viewport: TCoordinateRect; PixelWidth,PixelHeight,Margin: Integer);
begin
  var XCoordUnitsPerPixel := Viewport.Width/(PixelWidth-2*Margin);
  var YCoordUnitsPerPixel := Viewport.Height/(PixelHeight-2*Margin);
  if XCoordUnitsPerPixel > YCoordUnitsPerPixel then
  begin
    FCoordUnitsPerPixel := XCoordUnitsPerPixel;
    SetCenter(Viewport.CenterPoint,PixelWidth,PixelHeight);
  end else
  begin
    FCoordUnitsPerPixel := YCoordUnitsPerPixel;
    SetCenter(Viewport.CenterPoint,PixelWidth,PixelHeight);
  end;
  FMargin := Margin;
end;

end.

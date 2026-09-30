unit GIS.Render.PixelConv.Cartesian;

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
  SysUtils, Classes, Types, GIS, GIS.Render.PixelConv;

Type
  TCartesianPixelConverter = Class(TCustomPixelConverter)
  private
    Const
      ZoomFactor = 1.5;
    Var
      FCoordUnitsPerPixel: Float64;
      FViewport: TCoordinateRect;
    Procedure SetViewport(const Center: TCoordinate);
  strict protected
    Procedure WriteState(const Writer: TBinaryWriter); override;
    Procedure ReadState(const Reader: TBinaryReader); override;
  public
    // Convert between pixels and world coordinates
    Function CoordToPixel(const Coord: TCoordinate): TPointF; override;
    Function PixelToCoord(const Pixel: TPointF): TCoordinate; overload; override;
    // Calculate coordinate bounding box from pixel bounding box.
    // For a pixel bounding box Bottom >= Top.
    Function PixelToCoord(const Pixels: TRectF): TCoordinateRect; overload;
    Function PixelToCoord(const Pixels: TRect): TCoordinateRect; overload;
    Function PixelToCoord(const Left,Top,Right,Bottom: Float64): TCoordinateRect; overload;
    // Control convertion between pixels and coordinates
    Procedure Initialize(const BoundingBox: TCoordinateRect; const PixelWidth,PixelHeight: Float32); override;
    Procedure ZoomIn(const Pixel: TPointF); overload; override;
    Procedure ZoomIn(const Pixels: TRectF); overload; override;
    Procedure ZoomOut(const Pixel: TPointF); overload; override;
    Procedure PanMap(const DeltaXPixel,DeltaYPixel: Float32); override;
    // Update pixel dimensions, keeping the scale and the centre of the view.
    // The view itself is unchanged, so it is not added to the history and
    // OnChange does not fire.
    Procedure Resize(const PixelWidth,PixelHeight: Float32);
    // Get viewport
    Function GetViewport: TCoordinateRect; override;
  public
    Property CoordUnitsPerPixel: Float64 read FCoordUnitsPerPixel;
    Property Viewport: TCoordinateRect read FViewport;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Procedure TCartesianPixelConverter.SetViewport(const Center: TCoordinate);
begin
  FViewport.Left := Center.X - 0.5*FPixelWidth*FCoordUnitsPerPixel;
  FViewport.Right := Center.X + 0.5*FPixelWidth*FCoordUnitsPerPixel;
  FViewport.Top := Center.Y + 0.5*FPixelHeight*FCoordUnitsPerPixel;
  FViewport.Bottom := Center.Y - 0.5*FPixelHeight*FCoordUnitsPerPixel;
end;

Procedure TCartesianPixelConverter.WriteState(const Writer: TBinaryWriter);
// A state holds the centre of the view rather than its top left corner, so
// that it restores the same view after the pixel dimensions have changed
begin
  var Center := FViewport.CenterPoint;
  Writer.Write(Center.X);
  Writer.Write(Center.Y);
  Writer.Write(FCoordUnitsPerPixel);
end;

Procedure TCartesianPixelConverter.ReadState(const Reader: TBinaryReader);
Var
  Center: TCoordinate;
begin
  Center.X := Reader.ReadDouble;
  Center.Y := Reader.ReadDouble;
  FCoordUnitsPerPixel := Reader.ReadDouble;
  SetViewport(Center);
end;

Function TCartesianPixelConverter.CoordToPixel(const Coord: TCoordinate): TPointF;
begin
  if FInitialized then
  begin
    Result.X := (Coord.X-FViewport.Left)/FCoordUnitsPerPixel;
    Result.Y := (FViewport.Top-Coord.Y)/FCoordUnitsPerPixel;
  end else
    raise Exception.Create('Pixel converter not initialized');
end;

Function TCartesianPixelConverter.PixelToCoord(const Pixel: TPointF): TCoordinate;
begin
  if FInitialized then
  begin
    Result.X := FViewport.Left + Pixel.X*FCoordUnitsPerPixel;
    Result.Y := FViewport.Top - Pixel.Y*FCoordUnitsPerPixel;
  end else
    raise Exception.Create('Pixel converter not initialized');
end;

Function TCartesianPixelConverter.PixelToCoord(const Pixels: TRectF): TCoordinateRect;
begin
  if FInitialized then
  begin
    Result.Clear;
    Result.Enclose(PixelToCoord(Pixels.TopLeft));
    Result.Enclose(PixelToCoord(Pixels.BottomRight));
  end else
    raise Exception.Create('Pixel converter not initialized');
end;

Function TCartesianPixelConverter.PixelToCoord(const Pixels: TRect): TCoordinateRect;
begin
  Result := PixelToCoord(TRectF.Create(Pixels));
end;

Function TCartesianPixelConverter.PixelToCoord(const Left,Top,Right,Bottom: Float64): TCoordinateRect;
begin
  Result := PixelToCoord(TRectF.Create(Left,Top,Right,Bottom));
end;

Procedure TCartesianPixelConverter.Initialize(const BoundingBox: TCoordinateRect; const PixelWidth,PixelHeight: Float32);
Var
  RoomWidth,RoomHeight: Float32;
begin
  if BoundingBox.Empty then raise Exception.Create('Cannot initialize on an empty bounding box');
  RoomWithinMargin(PixelWidth,PixelHeight,RoomWidth,RoomHeight);
  FInitialized := true;
  FPixelWidth := PixelWidth;
  FPixelHeight := PixelHeight;
  // A single point or a straight line has no width or no height. It is given a square of the size
  // it does have, or of one unit, so that the view has a scale
  var Box := BoundingBox;
  if (Box.Width = 0) or (Box.Height = 0) then
  begin
    var Size := Box.Width;
    if Box.Height > Size then Size := Box.Height;
    if Size = 0 then Size := 1;
    var Center := Box.CenterPoint;
    Box.Left := Center.X - Size/2;
    Box.Right := Center.X + Size/2;
    Box.Bottom := Center.Y - Size/2;
    Box.Top := Center.Y + Size/2;
  end;
  // The scale at which the box fits within the margin, centred
  FCoordUnitsPerPixel := Box.Width/RoomWidth;
  if Box.Height/RoomHeight > FCoordUnitsPerPixel then FCoordUnitsPerPixel := Box.Height/RoomHeight;
  SetViewport(Box.CenterPoint);
  Changed;
end;

Procedure TCartesianPixelConverter.ZoomIn(const Pixel: TPointF);
begin
  if FInitialized then
  begin
    var Center := PixelToCoord(Pixel);
    var Width := FViewport.Width/ZoomFactor;
    var Height := FViewport.Height/ZoomFactor;
    FViewport.Left := Center.X - Width/2;
    FViewport.Right := Center.X + Width/2;
    FViewport.Top := Center.Y + Height/2;
    FViewport.Bottom := Center.Y - Height/2;
    FCoordUnitsPerPixel := FCoordUnitsPerPixel/ZoomFactor;
    Changed;
  end else
    raise Exception.Create('Pixel converter not initialized');
end;

Procedure TCartesianPixelConverter.ZoomIn(const Pixels: TRectF);
begin
  if FInitialized then
    Initialize(PixelToCoord(Pixels),FPixelWidth,FPixelHeight)
  else
    raise Exception.Create('Pixel converter not initialized');
end;

Procedure TCartesianPixelConverter.ZoomOut(const Pixel: TPointF);
begin
  if FInitialized then
  begin
    var Center := PixelToCoord(Pixel);
    var Width := ZoomFactor*FViewport.Width;
    var Height := ZoomFactor*FViewport.Height;
    FViewport.Left := Center.X - Width/2;
    FViewport.Right := Center.X + Width/2;
    FViewport.Top := Center.Y + Height/2;
    FViewport.Bottom := Center.Y - Height/2;
    FCoordUnitsPerPixel := ZoomFactor*FCoordUnitsPerPixel;
    Changed;
  end else
    raise Exception.Create('Pixel converter not initialized');
end;

Procedure TCartesianPixelConverter.PanMap(const DeltaXPixel,DeltaYPixel: Float32);
begin
  if FInitialized then
  begin
    FViewport.Left := FViewport.Left - DeltaXPixel*FCoordUnitsPerPixel;
    FViewport.Right := FViewport.Right - DeltaXPixel*FCoordUnitsPerPixel;
    FViewport.Top := FViewport.Top + DeltaYPixel*FCoordUnitsPerPixel;
    FViewport.Bottom := FViewport.Bottom + DeltaYPixel*FCoordUnitsPerPixel;
    Changed;
  end else
    raise Exception.Create('Pixel converter not initialized');
end;

Procedure TCartesianPixelConverter.Resize(const PixelWidth,PixelHeight: Float32);
begin
  if FInitialized then
  begin
    var Center := FViewport.CenterPoint;
    FPixelWidth := PixelWidth;
    FPixelHeight := PixelHeight;
    SetViewport(Center);
  end;
end;

Function TCartesianPixelConverter.GetViewport: TCoordinateRect;
begin
  if FInitialized then
    Result := PixelToCoord(0,0,FPixelWidth,FPixelHeight)
  else
    raise Exception.Create('Pixel converter not initialized');
end;

end.

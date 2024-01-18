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
      FMargin: Float32; // Pixels
      FCoordUnitsPerPixel: Float64;
      FViewport: TCoordinateRect;
    Procedure SetMargin(Margin: Float32);
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
    // Get viewport
    Function GetViewport: TCoordinateRect; override;
  public
    Property Margin: Float32 read FMargin write SetMargin;
    Property CoordUnitsPerPixel: Float64 read FCoordUnitsPerPixel;
    Property Viewport: TCoordinateRect read FViewport;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Procedure TCartesianPixelConverter.SetMargin(Margin: Float32);
begin
  if Margin <> FMargin then
  begin
    FMargin := Margin;
    if FInitialized then Initialize(FViewport,FPixelWidth,FPixelHeight);
  end;
end;

Procedure TCartesianPixelConverter.WriteState(const Writer: TBinaryWriter);
begin
  Writer.Write(FViewport.Left);
  Writer.Write(FViewport.Top);
  Writer.Write(FCoordUnitsPerPixel);
end;

Procedure TCartesianPixelConverter.ReadState(const Reader: TBinaryReader);
begin
  FViewport.Left := Reader.ReadDouble;
  FViewport.Top := Reader.ReadDouble;
  FCoordUnitsPerPixel := Reader.ReadDouble;
  FViewport.Right := FViewport.Left + PixelWidth*FCoordUnitsPerPixel;
  FViewport.Bottom := FViewport.Top - PixelHeight*FCoordUnitsPerPixel;
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
begin
  FInitialized := true;
  FPixelWidth := PixelWidth;
  FPixelHeight := PixelHeight;
  // Set viewport
  if PixelWidth/PixelHeight > BoundingBox.Width/BoundingBox.Height then
  begin
    var ScaleFactor := (PixelWidth*BoundingBox.Height)/(PixelHeight*BoundingBox.Width);
    var DeltaWidth:= (ScaleFactor-1)*BoundingBox.Width;
    FViewport.Left := BoundingBox.Left - DeltaWidth/2;
    FViewport.Right := BoundingBox.Right + DeltaWidth/2;
    FViewport.Top := BoundingBox.Top;
    FViewport.Bottom := BoundingBox.Bottom;
  end else
  begin
    var ScaleFactor := (PixelHeight*BoundingBox.Width)/(PixelWidth*BoundingBox.Height);
    var DeltaHeight:= (ScaleFactor-1)*BoundingBox.Height;
    FViewport.Left := BoundingBox.Left;
    FViewport.Right := BoundingBox.Right;
    FViewport.Top := BoundingBox.Top+DeltaHeight/2;
    FViewport.Bottom := BoundingBox.Bottom-DeltaHeight/2;
  end;
  FCoordUnitsPerPixel := FViewport.Width/PixelWidth;
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

Function TCartesianPixelConverter.GetViewport: TCoordinateRect;
begin
  if FInitialized then
    Result := PixelToCoord(0,0,FPixelWidth,FPixelHeight)
  else
    raise Exception.Create('Pixel converter not initialized');
end;

end.

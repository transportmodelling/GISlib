unit GIS.Render.PixelConv;

////////////////////////////////////////////////////////////////////////////////
interface
////////////////////////////////////////////////////////////////////////////////

Uses
  SysUtils, Types, GIS;

Type
  TCustomPixelConverter = Class
  strict protected
    FInitialized: Boolean;
    FPixelWidth,FPixelHeight: Float32;
  public
    // Convert between pixels and world coordinates
    Function CoordToPixel(const Coord: TCoordinate): TPointF; overload; virtual; abstract;
    Function CoordToPixel(const Xcoord,Ycoord: Float64): TPointF; overload;
    Function PixelToCoord(const Pixel: TPointF): TCoordinate; overload; virtual; abstract;
    Function PixelToCoord(const Pixel: TPoint): TCoordinate; overload;
    Function PixelToCoord(const Xpixel,Ypixel: Float64): TCoordinate; overload;
    // Control convertion between pixels and coordinates
    Procedure Initialize(const BoundingBox: TCoordinateRect; const PixelWidth,PixelHeight: Float32); virtual; abstract;
    Procedure ZoomIn(const Pixel: TPointF); overload; virtual; abstract;
    Procedure ZoomIn(const Pixels: TRectF); overload; virtual; abstract;
    Procedure ZoomOut(const Pixel: TPointF); overload; virtual; abstract;
    Procedure PanMap(const DeltaXPixel,DeltaYPixel: Float32); virtual; abstract;
    // Get viewport
    Function GetViewport: TCoordinateRect; virtual; abstract;
  public
    Property Initialized: Boolean read FInitialized;
    Property PixelWidth: Float32 read FPixelWidth;
    Property PixelHeight: Float32 read FPixelHeight;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Function TCustomPixelConverter.CoordToPixel(const Xcoord,Ycoord: Float64): TPointF;
begin
  Result := CoordToPixel(TCoordinate.Create(Xcoord,Ycoord));
end;

Function TCustomPixelConverter.PixelToCoord(const Pixel: TPoint): TCoordinate;
begin
  Result := PixelToCoord(TPointF.Create(Pixel));
end;

Function TCustomPixelConverter.PixelToCoord(const Xpixel,Ypixel: Float64): TCoordinate;
begin
  Result := PixelToCoord(TPointF.Create(Xpixel,Ypixel));
end;

end.

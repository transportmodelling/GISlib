unit RndrCtrl;

////////////////////////////////////////////////////////////////////////////////
//
// Author: Jaap Baak
// https://github.com/transportmodelling/GISlib
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
interface
////////////////////////////////////////////////////////////////////////////////

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
  GISCoordSystem, GIS.CoordConv, GIS.Render.PixelConv.Mercator, GIS.Render.Shapes;

type
  TLayerRenderingControl = Class; // Forward reference

  TLayer = class
  public
    Shapes:           TShapesLayer;
    Converter:        TWebMercatorPixelConverter;
    Name:             String;
    Visible:          Boolean;
    Opacity:          Byte;
    CoordSystem:      TGISCoordinateSystem;  // not owned - belongs to the app's CoordinateSystems array
    PenColor:         TColor;
    PenWidth:         Integer;
    PenStyle:         TPenStyle;
    BrushColor:       TColor;
    BrushStyle:       TBrushStyle;
    RenderingControl: TLayerRenderingControl;
    constructor Create(const AShapes: TShapesLayer; const AName: String;
                       const ACoordSystem: TGISCoordinateSystem; const AOpacity: Byte;
                       const APrimary: TWebMercatorPixelConverter);
    destructor Destroy; override;
  end;

  TLayerRenderingControl = class(TFrame)
  protected
    FOnChange: TNotifyEvent;
    Layer: TLayer;
    Procedure Changed;
  public
    // Bind to layer first so event handlers can safely reference Layer
    // while the controls below are being populated.
    Procedure LoadFrom(ALayer: TLayer); virtual;
  public
    Property OnChange: TNotifyEvent read FOnChange write FOnChange;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

{$R *.dfm}

constructor TLayer.Create(const AShapes: TShapesLayer; const AName: String;
                           const ACoordSystem: TGISCoordinateSystem; const AOpacity: Byte;
                           const APrimary: TWebMercatorPixelConverter);
begin
  Shapes      := AShapes;
  Name        := AName;
  CoordSystem := ACoordSystem;
  Opacity     := AOpacity;
  Visible     := true;
  PenColor    := clBlue;
  PenWidth    := 1;
  PenStyle    := psSolid;
  BrushColor  := clSkyBlue;
  BrushStyle  := bsSolid;
  Converter := TWebMercatorPixelConverter.Create(ACoordSystem.CreateConverter);
  if (APrimary <> nil) and APrimary.Initialized then
    Converter.SyncFrom(APrimary);
end;

destructor TLayer.Destroy;
begin
  Shapes.Free;
  Converter.Free;
  RenderingControl.Free;
  inherited;
end;

Procedure TLayerRenderingControl.Changed;
begin
  if Assigned(FOnChange) then FOnChange(Self);
end;

Procedure TLayerRenderingControl.LoadFrom(ALayer: TLayer);
begin
  Layer := ALayer;
end;

end.

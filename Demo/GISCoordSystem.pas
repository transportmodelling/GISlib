unit GISCoordSystem;

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
  SysUtils, Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Samples.Spin,
  GIS.CoordConv, GIS.CoordConv.WGS84, GIS.CoordConv.DutchGrid, GIS.CoordConv.WebMercator,
  GIS.CoordConv.UTM;

type
  TGISCoordinateSystem = class
  public
    function Name: String; virtual; abstract;
    function SRID: Integer; virtual; abstract;
    // Caller owns the returned converter
    function CreateConverter: TCoordinateConverter; virtual; abstract;
    // Called once when the user explicitly selects this system, so systems with
    // extra parameters (e.g. UTM zone/hemisphere) can prompt for them. No-op by
    // default; CreateConverter must not prompt, since it is also called from
    // non-interactive contexts (e.g. saving a layer).
    procedure Configure; virtual;
    // Optional hint when the file being opened carries its own CRS metadata
    // (e.g. a GeoPackage layer's stored SRID). Systems with extra parameters
    // can use this as a starting point for Configure. No-op by default.
    procedure HintSRID(const SRID: Integer); virtual;
  end;

  TWgs84CoordinateSystem = class(TGISCoordinateSystem)
  public
    function Name: String; override;
    function SRID: Integer; override;
    function CreateConverter: TCoordinateConverter; override;
  end;

  TDutchGridCoordinateSystem = class(TGISCoordinateSystem)
  public
    function Name: String; override;
    function SRID: Integer; override;
    function CreateConverter: TCoordinateConverter; override;
  end;

  TWebMercatorCoordinateSystem = class(TGISCoordinateSystem)
  public
    function Name: String; override;
    function SRID: Integer; override;
    function CreateConverter: TCoordinateConverter; override;
  end;

  TUtmCoordinateSystem = class(TGISCoordinateSystem)
  private
    FZone: Integer;
    FHemisphere: TUtmHemisphere;
    FConfigured: Boolean;
  public
    constructor Create;
    function Name: String; override;
    function SRID: Integer; override;
    function CreateConverter: TCoordinateConverter; override;
    procedure Configure; override;
    procedure HintSRID(const SRID: Integer); override;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

procedure TGISCoordinateSystem.Configure;
begin
  // No parameters to configure by default
end;

procedure TGISCoordinateSystem.HintSRID(const SRID: Integer);
begin
  // No CRS metadata to use by default
end;

function TWgs84CoordinateSystem.Name: String;
begin
  Result := 'WGS84';
end;

function TWgs84CoordinateSystem.SRID: Integer;
begin
  Result := 4326;
end;

function TWgs84CoordinateSystem.CreateConverter: TCoordinateConverter;
begin
  Result := TWgs84CoordinateConverter.Create;
end;

function TDutchGridCoordinateSystem.Name: String;
begin
  Result := 'Dutch Grid (RD New)';
end;

function TDutchGridCoordinateSystem.SRID: Integer;
begin
  Result := 28992;
end;

function TDutchGridCoordinateSystem.CreateConverter: TCoordinateConverter;
begin
  Result := TDutchGridCoordinateConverter.Create;
end;

function TWebMercatorCoordinateSystem.Name: String;
begin
  Result := 'Web Mercator (EPSG:3857)';
end;

function TWebMercatorCoordinateSystem.SRID: Integer;
begin
  Result := 3857;
end;

function TWebMercatorCoordinateSystem.CreateConverter: TCoordinateConverter;
begin
  Result := TWebMercatorCoordinateConverter.Create;
end;

constructor TUtmCoordinateSystem.Create;
begin
  inherited Create;
  FZone := 31;            // fallback if CreateConverter is called before Configure
  FHemisphere := hpNorth;
  FConfigured := False;
end;

function TUtmCoordinateSystem.Name: String;
begin
  if not FConfigured then
    Result := 'UTM'
  else if FHemisphere = hpNorth then
    Result := 'UTM zone ' + IntToStr(FZone) + 'N'
  else
    Result := 'UTM zone ' + IntToStr(FZone) + 'S';
end;

function TUtmCoordinateSystem.SRID: Integer;
begin
  if FHemisphere = hpNorth then
    Result := 32600+FZone
  else
    Result := 32700+FZone;
end;

function TUtmCoordinateSystem.CreateConverter: TCoordinateConverter;
begin
  Result := TUtmCoordinateConverter.Create(FZone, FHemisphere);
end;

procedure TUtmCoordinateSystem.Configure;
var
  Dialog: TForm;
  ZoneLbl: TLabel;
  ZoneSpin: TSpinEdit;
  HemisphereGroup: TRadioGroup;
  OKBtn, CancelBtn: TButton;
begin
  Dialog := TForm.CreateNew(Application);
  try
    Dialog.Caption      := 'Select UTM Zone';
    Dialog.ClientWidth  := 220;
    Dialog.ClientHeight := 160;
    Dialog.Position     := poOwnerFormCenter;
    Dialog.BorderStyle  := bsDialog;

    ZoneLbl := TLabel.Create(Dialog);
    ZoneLbl.Parent := Dialog;
    ZoneLbl.SetBounds(8, 8, 200, 16);
    ZoneLbl.Caption := 'UTM zone (1-60):';

    ZoneSpin := TSpinEdit.Create(Dialog);
    ZoneSpin.Parent := Dialog;
    ZoneSpin.SetBounds(8, 26, 80, 24);
    ZoneSpin.MinValue := 1;
    ZoneSpin.MaxValue := 60;
    ZoneSpin.Value    := FZone;

    HemisphereGroup := TRadioGroup.Create(Dialog);
    HemisphereGroup.Parent := Dialog;
    HemisphereGroup.SetBounds(8, 56, 200, 64);
    HemisphereGroup.Caption := 'Hemisphere';
    HemisphereGroup.Items.Add('North');
    HemisphereGroup.Items.Add('South');
    if FHemisphere = hpNorth then HemisphereGroup.ItemIndex := 0 else HemisphereGroup.ItemIndex := 1;

    OKBtn := TButton.Create(Dialog);
    OKBtn.Parent      := Dialog;
    OKBtn.SetBounds(54, 128, 75, 26);
    OKBtn.Caption     := 'OK';
    OKBtn.ModalResult := mrOk;
    OKBtn.Default     := True;

    CancelBtn := TButton.Create(Dialog);
    CancelBtn.Parent      := Dialog;
    CancelBtn.SetBounds(136, 128, 75, 26);
    CancelBtn.Caption     := 'Cancel';
    CancelBtn.ModalResult := mrCancel;

    if Dialog.ShowModal = mrOk then
    begin
      FZone := ZoneSpin.Value;
      if HemisphereGroup.ItemIndex = 0 then FHemisphere := hpNorth else FHemisphere := hpSouth;
      FConfigured := True;
    end;
    // On Cancel, the previously configured zone/hemisphere (or unconfigured state) is kept
  finally
    Dialog.Free;
  end;
end;

procedure TUtmCoordinateSystem.HintSRID(const SRID: Integer);
begin
  if (SRID >= 32601) and (SRID <= 32660) then
  begin
    FZone := SRID-32600;
    FHemisphere := hpNorth;
  end else
  if (SRID >= 32701) and (SRID <= 32760) then
  begin
    FZone := SRID-32700;
    FHemisphere := hpSouth;
  end;
  // Any other SRID is not a recognized UTM zone code; leave Zone/Hemisphere unchanged
end;

end.

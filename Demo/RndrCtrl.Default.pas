unit RndrCtrl.Default;

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
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls,
  Vcl.Samples.Spin, Vcl.ComCtrls, Vcl.ExtCtrls, RndrCtrl, GIS.Render.Shapes;

type
  TTDefaultLayerRenderingControl = class(TLayerRenderingControl)
    BrushColorPanel: TPanel;
    BrushLabel: TLabel;
    BrushStyleCombo: TComboBox;
    CoordinateSystemLabel: TLabel;
    EditCoordinateSystem: TEdit;
    OpacityLabel: TLabel;
    OpacityTrackbar: TTrackBar;
    PenColorPanel: TPanel;
    PenLabel: TLabel;
    PenStyleCombo: TComboBox;
    PenWidthSpinEdit: TSpinEdit;
    VisibleCheckBox: TCheckBox;
    PointLabel: TLabel;
    PointComboBox: TComboBox;
    PointSizeSpinEdit: TSpinEdit;
    procedure VisibleCheckBoxClick(Sender: TObject);
    procedure OpacityTrackBarChange(Sender: TObject);
    procedure PenColorPanelClick(Sender: TObject);
    procedure PenStyleComboChange(Sender: TObject);
    procedure PenWidthSpinEditChange(Sender: TObject);
    procedure BrushColorPanelClick(Sender: TObject);
    procedure BrushStyleComboChange(Sender: TObject);
    procedure PointComboBoxChange(Sender: TObject);
    procedure PointSizeSpinEditChange(Sender: TObject);
  public
    Procedure LoadFrom(ALayer: TLayer); override;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

{$R *.dfm}

Procedure TTDefaultLayerRenderingControl.LoadFrom(ALayer: TLayer);
begin
  // Bind to layer first so event handlers can safely reference Layer
  // while the controls below are being populated.
  inherited LoadFrom(ALayer);
  VisibleCheckBox.Checked   := ALayer.Visible;
  OpacityTrackbar.Position  := ALayer.Opacity;
  PenColorPanel.Color       := ALayer.PenColor;
  PenStyleCombo.ItemIndex   := Ord(ALayer.PenStyle);
  PenWidthSpinEdit.Value    := ALayer.PenWidth;
  BrushColorPanel.Color     := ALayer.BrushColor;
  BrushStyleCombo.ItemIndex := Ord(ALayer.BrushStyle);
  EditCoordinateSystem.Text := ALayer.CoordSystem.Name;
  PointComboBox.ItemIndex  := Ord(ALayer.Shapes.PointRenderStyle);
  PointSizeSpinEdit.Value  := ALayer.Shapes.PointRenderSize;
end;

procedure TTDefaultLayerRenderingControl.VisibleCheckBoxClick(Sender: TObject);
begin
  if Layer <> nil then
  begin
    Layer.Visible := VisibleCheckBox.Checked;
    Changed;
  end;
end;

procedure TTDefaultLayerRenderingControl.OpacityTrackBarChange(Sender: TObject);
begin
  if (Layer <> nil) and (OpacityTrackbar.Position <> Layer.Opacity) then
  begin
    Layer.Opacity := OpacityTrackbar.Position;
    Changed;
  end;
end;

procedure TTDefaultLayerRenderingControl.PenColorPanelClick(Sender: TObject);
var
  Dlg: TColorDialog;
begin
  if Layer = nil then Exit;
  Dlg := TColorDialog.Create(nil);
  try
    Dlg.Color := Layer.PenColor;
    if Dlg.Execute then
    begin
      Layer.PenColor    := Dlg.Color;
      PenColorPanel.Color := Dlg.Color;
      Changed;
    end;
  finally
    Dlg.Free;
  end;
end;

procedure TTDefaultLayerRenderingControl.PenStyleComboChange(Sender: TObject);
begin
  if Layer <> nil then
  begin
    Layer.PenStyle := TPenStyle(PenStyleCombo.ItemIndex);
    Changed;
  end;
end;

procedure TTDefaultLayerRenderingControl.PenWidthSpinEditChange(Sender: TObject);
begin
  if Layer <> nil then
  begin
    Layer.PenWidth := PenWidthSpinEdit.Value;
    Changed;
  end;
end;

procedure TTDefaultLayerRenderingControl.PointComboBoxChange(Sender: TObject);
begin
  if Layer <> nil then
  begin
    Layer.Shapes.PointRenderStyle := TPointRenderStyle(PointComboBox.ItemIndex);
    Changed;
  end;
end;

procedure TTDefaultLayerRenderingControl.PointSizeSpinEditChange(Sender: TObject);
begin
  if Layer <> nil then
  begin
    Layer.Shapes.PointRenderSize := PointSizeSpinEdit.Value;
    Changed;
  end;
end;

procedure TTDefaultLayerRenderingControl.BrushColorPanelClick(Sender: TObject);
var
  Dlg: TColorDialog;
begin
  if Layer = nil then Exit;
  Dlg := TColorDialog.Create(nil);
  try
    Dlg.Color := Layer.BrushColor;
    if Dlg.Execute then
    begin
      Layer.BrushColor      := Dlg.Color;
      BrushColorPanel.Color := Dlg.Color;
      Changed;
    end;
  finally
    Dlg.Free;
  end;
end;

procedure TTDefaultLayerRenderingControl.BrushStyleComboChange(Sender: TObject);
begin
  if Layer <> nil then
  begin
    Layer.BrushStyle := TBrushStyle(BrushStyleCombo.ItemIndex);
    Changed;
  end;
end;

end.

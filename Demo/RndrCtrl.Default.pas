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
  Vcl.Samples.Spin, Vcl.ComCtrls, Vcl.ExtCtrls, RndrCtrl, GIS.Shapes, GIS.Render.Shapes;

type
  TDefaultLayerRenderingControl = class(TLayerRenderingControl)
    GeneralSection: TPanel;
    PenSection: TPanel;
    BrushSection: TPanel;
    PointsSection: TPanel;
    LabelsSection: TPanel;
    CoordSystemSection: TPanel;
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
    LabelsLabel: TLabel;
    LabelSourceCombo: TComboBox;
    TextColorPanel: TPanel;
    TextSizeSpinEdit: TSpinEdit;
    Procedure VisibleCheckBoxClick(Sender: TObject);
    Procedure OpacityTrackBarChange(Sender: TObject);
    Procedure PenColorPanelClick(Sender: TObject);
    Procedure PenStyleComboChange(Sender: TObject);
    Procedure PenWidthSpinEditChange(Sender: TObject);
    Procedure BrushColorPanelClick(Sender: TObject);
    Procedure BrushStyleComboChange(Sender: TObject);
    Procedure PointComboBoxChange(Sender: TObject);
    Procedure PointSizeSpinEditChange(Sender: TObject);
    Procedure LabelSourceComboChange(Sender: TObject);
    Procedure TextColorPanelClick(Sender: TObject);
    Procedure TextSizeSpinEditChange(Sender: TObject);
  private
    Const
      // The styles offered, in the order of PointComboBox's items. rsBitmap is
      // left out: it needs an image, and the demo has no way to pick one.
      PointStyles: array[0..11] of TPointRenderStyle = (
        rsCircle,rsSquare,rsTriangleUp,rsTriangleDown,
        rsStation_18dp,rsStation_24dp,rsStation_36dp,rsStation_48dp,
        rsAirport_18dp,rsAirport_24dp,rsAirport_36dp,rsAirport_48dp);
    Function SelectColor(const ColorPanel: TPanel; var Color: TColor): Boolean;
  public
    Procedure LoadFrom(ALayer: TLayer); override;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

{$R *.dfm}

Procedure TDefaultLayerRenderingControl.LoadFrom(ALayer: TLayer);
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
  PointComboBox.ItemIndex   := -1;
  for var Style := Low(PointStyles) to High(PointStyles) do
    if PointStyles[Style] = ALayer.Shapes.PointRenderStyle then
      PointComboBox.ItemIndex := Style;
  // A symbol is drawn at the size of its image
  PointSizeSpinEdit.Enabled := ALayer.Shapes.PointRenderStyle < rsBitmap;
  PointSizeSpinEdit.Value   := ALayer.Shapes.PointRenderSize;
  // The label source items map onto TLabeledShapesLayer.LabelSource + 2
  LabelSourceCombo.Items.BeginUpdate;
  try
    LabelSourceCombo.Items.Clear;
    LabelSourceCombo.Items.Add('None');
    LabelSourceCombo.Items.Add('Feature number');
    for var Field in ALayer.Shapes.FieldNames do
      LabelSourceCombo.Items.Add(Field);
  finally
    LabelSourceCombo.Items.EndUpdate;
  end;
  LabelSourceCombo.ItemIndex := ALayer.Shapes.LabelSource + 2;
  TextColorPanel.Color       := ALayer.TextColor;
  TextSizeSpinEdit.Value     := ALayer.TextSize;
  // Show only the sections that apply to the shapes in the layer: points are
  // outlined with the pen and filled with the brush, and only polygons are
  // labelled
  var Points   := ALayer.Shapes.ShapeCount(stPoint) > 0;
  var Lines    := ALayer.Shapes.ShapeCount(stLine) > 0;
  var Polygons := ALayer.Shapes.ShapeCount(stPolygon) > 0;
  PenSection.Visible    := Points or Lines or Polygons;
  BrushSection.Visible  := Points or Polygons;
  PointsSection.Visible := Points;
  LabelsSection.Visible := Polygons;
  // Stack the visible sections without gaps
  var Y := 0;
  for var Section in [GeneralSection,PenSection,BrushSection,PointsSection,
                      LabelsSection,CoordSystemSection] do
    if Section.Visible then
    begin
      Section.Top := Y;
      Inc(Y,Section.Height);
    end;
end;

Function TDefaultLayerRenderingControl.SelectColor(const ColorPanel: TPanel;
                                                   var Color: TColor): Boolean;
var
  Dlg: TColorDialog;
begin
  Dlg := TColorDialog.Create(nil);
  try
    Dlg.Color := Color;
    Result := Dlg.Execute;
    if Result then
    begin
      Color            := Dlg.Color;
      ColorPanel.Color := Dlg.Color;
    end;
  finally
    Dlg.Free;
  end;
end;

Procedure TDefaultLayerRenderingControl.VisibleCheckBoxClick(Sender: TObject);
begin
  if Layer <> nil then
  begin
    Layer.Visible := VisibleCheckBox.Checked;
    Changed;
  end;
end;

Procedure TDefaultLayerRenderingControl.OpacityTrackBarChange(Sender: TObject);
begin
  if (Layer <> nil) and (OpacityTrackbar.Position <> Layer.Opacity) then
  begin
    Layer.Opacity := OpacityTrackbar.Position;
    Changed;
  end;
end;

Procedure TDefaultLayerRenderingControl.PenColorPanelClick(Sender: TObject);
begin
  if (Layer <> nil) and SelectColor(PenColorPanel,Layer.PenColor) then Changed;
end;

Procedure TDefaultLayerRenderingControl.PenStyleComboChange(Sender: TObject);
begin
  if Layer <> nil then
  begin
    Layer.PenStyle := TPenStyle(PenStyleCombo.ItemIndex);
    Changed;
  end;
end;

Procedure TDefaultLayerRenderingControl.PenWidthSpinEditChange(Sender: TObject);
begin
  if Layer <> nil then
  begin
    Layer.PenWidth := PenWidthSpinEdit.Value;
    Changed;
  end;
end;

Procedure TDefaultLayerRenderingControl.PointComboBoxChange(Sender: TObject);
begin
  if (Layer <> nil) and (PointComboBox.ItemIndex >= 0) then
  begin
    Layer.Shapes.PointRenderStyle := PointStyles[PointComboBox.ItemIndex];
    // A symbol sets the point size to that of its image
    PointSizeSpinEdit.Enabled := Layer.Shapes.PointRenderStyle < rsBitmap;
    PointSizeSpinEdit.Value   := Layer.Shapes.PointRenderSize;
    Changed;
  end;
end;

Procedure TDefaultLayerRenderingControl.PointSizeSpinEditChange(Sender: TObject);
begin
  if Layer <> nil then
  begin
    Layer.Shapes.PointRenderSize := PointSizeSpinEdit.Value;
    Changed;
  end;
end;

Procedure TDefaultLayerRenderingControl.BrushColorPanelClick(Sender: TObject);
begin
  if (Layer <> nil) and SelectColor(BrushColorPanel,Layer.BrushColor) then Changed;
end;

Procedure TDefaultLayerRenderingControl.BrushStyleComboChange(Sender: TObject);
begin
  if Layer <> nil then
  begin
    Layer.BrushStyle := TBrushStyle(BrushStyleCombo.ItemIndex);
    Changed;
  end;
end;

Procedure TDefaultLayerRenderingControl.LabelSourceComboChange(Sender: TObject);
begin
  if (Layer <> nil) and (LabelSourceCombo.ItemIndex >= 0) then
  begin
    Layer.Shapes.LabelSource := LabelSourceCombo.ItemIndex - 2;
    Changed;
  end;
end;

Procedure TDefaultLayerRenderingControl.TextColorPanelClick(Sender: TObject);
begin
  if (Layer <> nil) and SelectColor(TextColorPanel,Layer.TextColor) then Changed;
end;

Procedure TDefaultLayerRenderingControl.TextSizeSpinEditChange(Sender: TObject);
begin
  if Layer <> nil then
  begin
    Layer.TextSize := TextSizeSpinEdit.Value;
    Changed;
  end;
end;

end.

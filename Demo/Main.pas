unit Main;

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
  Classes, SysUtils, Math, Types, Variants, Actions, Winapi.Windows,
  Winapi.Messages, Winapi.ShellAPI, Vcl.Graphics, Vcl.Controls, Vcl.Forms,
  Vcl.Dialogs, Vcl.ActnList, Vcl.StdActns, Vcl.ComCtrls, Vcl.StdCtrls, PngImage,
  Vcl.Samples.Spin,
  System.ImageList, Vcl.ImgList, Vcl.ExtCtrls, Vcl.ToolWin,
  System.Generics.Collections, FloatHlp,
  GISCoordSystem, GISFileFormat, RndrCtrl, RndrCtrl.Default,
  FireDAC.Comp.UI, FireDAC.VCLUI.Wait,
  GIS, GIS.Shapes, GIS.Render.Shapes, GIS.Render.Canvas, GIS.Render.Canvas.VCL,
  GIS.Render.PixelConv, GIS.Render.PixelConv.Mercator, GIS.Render.Tiles.OSM,
  GIS.CoordConv, GIS.CoordConv.WGS84;

type
  TZoomStyle = (zsNone,zsMove,zsZoomIn,zsZoomOut);

  TMainForm = class(TForm)
    ActionList: TActionList;
    ImageList: TImageList;
    AddLayer: TFileOpen;
    PaintBox: TPaintBox;
    CoordPanel: TPanel;
    YCoordPanel: TPanel;
    XCoordPanel: TPanel;
    OSMAttribLabel: TLabel;
    ZoomIn: TAction;
    ZoomOut: TAction;
    ZoomAll: TAction;
    Pan: TAction;
    ShowOSM: TAction;
    GISToolBar: TToolBar;
    ToolButton9: TToolButton;
    ToolButton10: TToolButton;
    ToolButton11: TToolButton;
    ToolButton12: TToolButton;
    ToolButton13: TToolButton;
    ToolButton14: TToolButton;
    LayerPanel: TPanel;
    LayerListBox: TListBox;
    CollapseBtn: TButton;
    CollapsiblePanel: TPanel;
    SelectedLayerPanel: TPanel;
    CoordSystemComboBox: TComboBox;
    GISPanel: TPanel;
    LayersToolBar: TToolBar;
    RemoveLayer: TAction;
    LayerUp: TAction;
    LayerDown: TAction;
    ToolButton2: TToolButton;
    ToolButton3: TToolButton;
    ToolButton4: TToolButton;
    SaveImage: TAction;
    ToolButton5: TToolButton;
    ToolButton6: TToolButton;
    ToolButton8: TToolButton;
    SaveLayer: TAction;
    SaveLayers: TAction;
    ToolButton1: TToolButton;
    ToolButton7: TToolButton;
    procedure AddLayerAccept(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure ZoomInExecute(Sender: TObject);
    procedure ZoomOutExecute(Sender: TObject);
    procedure PanExecute(Sender: TObject);
    procedure ZoomAllExecute(Sender: TObject);
    procedure ShowOSMExecute(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure PaintBoxMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure PaintBoxMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure PaintBoxMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure PaintBoxPaint(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure LayerListBoxClick(Sender: TObject);
    procedure RemoveLayerBtnClick(Sender: TObject);
    procedure CollapseBtnClick(Sender: TObject);
    procedure CoordSystemComboBoxChange(Sender: TObject);
    procedure RemoveLayerExecute(Sender: TObject);
    procedure LayerUpExecute(Sender: TObject);
    procedure LayerDownExecute(Sender: TObject);
    procedure SaveImageExecute(Sender: TObject);
    procedure SaveLayerExecute(Sender: TObject);
    procedure SaveLayersExecute(Sender: TObject);
  private
    Const
      crZoomIn  = 1;
      crZoomOut = 2;
    Var
      ZoomStyle: TZoomStyle;
      ShapesImage: TBitmap;
      LayerImage: TBitmap;
      MousePosition,StartPosition: TPoint;
      MouseCoordinate: TCoordinate;
      MouseDown: Boolean;
      MercatorConverter: TWebMercatorPixelConverter;
      OSMLayer: TOpenStreetMapLayer;
      Layers: TObjectList<TLayer>;
      ViewportChanged: Boolean;
      LayoutChanged: Boolean;
      Repainting: Boolean;
      DisplayCoordConverter: TCoordinateConverter;
      FileFormats:       TArray<TGISFileFormat>;
      CoordinateSystems: TArray<TGISCoordinateSystem>;
    Function  ActiveConverter: TCustomPixelConverter;
    Function  WorldBBox: TCoordinateRect;
    Function  AllLayersBBox: TCoordinateRect;
    Procedure UpdateSelectedLayerPanel;
    Procedure LayerPropertyChanged(Sender: TObject);
    Procedure MercatorConverterChanged(Sender: TObject);
    Procedure OpenShapeFile(const FileName: String);
  public
    Procedure AddGISLayer(const ALayer: TLayer);
    procedure WMDropFiles(var msg: TWMDropFiles); message WM_DROPFILES;
    procedure WMSize(var Message: TWMSize); message WM_SIZE;
    procedure WMExitSizeMove(var Message: TMessage); message WM_EXITSIZEMOVE;
  end;

var
  MainForm: TMainForm;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

{$R *.dfm}
{$R GIS.Cursor.RES}

////////////////////////////////////////////////////////////////////////////////
// TMainForm helpers
////////////////////////////////////////////////////////////////////////////////

Function TMainForm.ActiveConverter: TCustomPixelConverter;
begin
  Result := MercatorConverter;
end;

Function TMainForm.WorldBBox: TCoordinateRect;
begin
  Result.Left := -180; Result.Right := 180; Result.Top := 85; Result.Bottom := -85;
end;

Function TMainForm.AllLayersBBox: TCoordinateRect;
begin
  Result.Clear;
  for var Layer in Layers do
    if Layer.Visible then
    begin
      var BB := Layer.Shapes.BoundingBox;
      for var Corner in [TCoordinate.Create(BB.Left,BB.Top),
                         TCoordinate.Create(BB.Right,BB.Top),
                         TCoordinate.Create(BB.Right,BB.Bottom),
                         TCoordinate.Create(BB.Left,BB.Bottom)] do
      begin
        var G := Layer.Converter.CoordinateConverter.CoordToGeodeticCoord(Corner);
        Result.Enclose(TCoordinate.Create(G.Longitude,G.Latitude));
      end;
    end;
  if Result.Empty then Result := WorldBBox;
end;

procedure TMainForm.CoordSystemComboBoxChange(Sender: TObject);
var
  Idx: Integer;
begin
  FreeAndNil(DisplayCoordConverter);
  Idx := CoordSystemComboBox.ItemIndex;
  if (Idx >= 0) and (Idx < Length(CoordinateSystems)) then
  begin
    CoordinateSystems[Idx].Configure;
    CoordSystemComboBox.Items[Idx] := CoordinateSystems[Idx].Name;
    CoordSystemComboBox.ItemIndex := Idx;  // re-select: Items[Idx] assignment does not refresh the displayed text
    DisplayCoordConverter := CoordinateSystems[Idx].CreateConverter;
  end else
    DisplayCoordConverter := CoordinateSystems[0].CreateConverter;
  XCoordPanel.Caption := '';
  YCoordPanel.Caption := '';
end;

Procedure TMainForm.UpdateSelectedLayerPanel;
var
  Idx: Integer;
  Ctrl: TLayerRenderingControl;
begin
  // Remove the currently displayed rendering control
  if SelectedLayerPanel.ControlCount > 0 then
    SelectedLayerPanel.Controls[0].Parent := nil;
  Idx := LayerListBox.ItemIndex;
  if (Idx >= 0) and (Idx < Layers.Count) then
  begin
    Ctrl := Layers[Idx].RenderingControl;
    if Ctrl <> nil then
    begin
      Ctrl.LoadFrom(Layers[Idx]);
      Ctrl.OnChange              := LayerPropertyChanged;
      Ctrl.Parent                := SelectedLayerPanel;
      SelectedLayerPanel.Height  := Ctrl.Height;   // resize before alClient stretches
      Ctrl.Align                 := alClient;
    end;
    SelectedLayerPanel.Enabled := true;
  end else
    SelectedLayerPanel.Enabled := false;
end;

Procedure TMainForm.LayerPropertyChanged(Sender: TObject);
begin
  ViewportChanged := true;
  PaintBox.Invalidate;
end;

Procedure TMainForm.AddGISLayer(const ALayer: TLayer);
begin
  Layers.Add(ALayer);
  LayerListBox.Items.Add(ALayer.Name);
  LayerListBox.ItemIndex := LayerListBox.Count-1;
  UpdateSelectedLayerPanel;
  if LayerPanel.Width <= CollapseBtn.Width then
    CollapseBtnClick(nil);
  ZoomAllExecute(nil);
end;

Procedure TMainForm.MercatorConverterChanged(Sender: TObject);
begin
  for var Layer in Layers do
    Layer.Converter.SyncFrom(MercatorConverter);
end;

////////////////////////////////////////////////////////////////////////////////
// Windows messages
////////////////////////////////////////////////////////////////////////////////

procedure TMainForm.WMDropFiles(var msg: TWMDropFiles);
const
  MaxFileName = 255;
var
  FileName: array[0..MaxFileName] of char;
begin
  DragQueryFile(msg.Drop,0,FileName,MaxFileName);
  OpenShapeFile(FileName);
  DragFinish(msg.Drop);
end;

procedure TMainForm.WMSize(var Message: TWMSize);
begin
  inherited;
  if Message.SizeType = SIZE_MAXIMIZED then FormResize(nil);
end;

procedure TMainForm.WMExitSizeMove(var Message: TMessage);
begin
  FormResize(nil);
end;

////////////////////////////////////////////////////////////////////////////////
// Form lifecycle
////////////////////////////////////////////////////////////////////////////////

procedure TMainForm.FormCreate(Sender: TObject);
begin
  TFDGUIxWaitCursor.Create(Self);  // required by FireDAC; owned by form
  DragAcceptFiles(Handle,true);
  Screen.Cursors[crZoomIn]  := LoadCursor(HInstance,'ZOOM_IN');
  Screen.Cursors[crZoomOut] := LoadCursor(HInstance,'ZOOM_OUT');
  ShapesImage := TBitmap.Create;
  LayerImage  := TBitmap.Create;
  OSMLayer    := TOpenStreetMapLayer.Create;
  Layers      := TObjectList<TLayer>.Create(true);
  ViewportChanged := true;
  // Registered coordinate systems - extend here to add more
  CoordinateSystems := [
    TWgs84CoordinateSystem.Create,
    TDutchGridCoordinateSystem.Create,
    TWebMercatorCoordinateSystem.Create,
    TUtmCoordinateSystem.Create
  ];
  // Registered file formats - extend here to add more
  FileFormats := [
    TESRIFileFormat.Create,
    TGeoJSONFileFormat.Create,
    TGeoPackageFileFormat.Create
  ];
  // Build the open-dialog filter from the registered formats
  var AllExts := '';
  for var FF in FileFormats do
    for var Ext in FF.Extensions do
    begin
      if AllExts <> '' then AllExts := AllExts + ';';
      AllExts := AllExts + '*' + Ext;
    end;
  var Filter := 'All GIS files|' + AllExts;
  for var FF in FileFormats do
    Filter := Filter + '|' + FF.DialogFilter;
  Filter := Filter + '|All files|*.*';
  AddLayer.Dialog.Filter := Filter;
  // Only set InitialDir when the Data directory exists relative to the exe
  // (development layout). For downloaded releases the OS default is used.
  var DataDir := ExpandFileName(ExtractFilePath(Application.ExeName) + '..\Data');
  if DirectoryExists(DataDir) then
    AddLayer.Dialog.InitialDir := DataDir;
  // Populate coordinate-system combo box
  for var CS in CoordinateSystems do
    CoordSystemComboBox.Items.Add(CS.Name);
  CoordSystemComboBox.ItemIndex := 0;
  // Primary converter (always WGS84 for the Mercator view)
  MercatorConverter := TWebMercatorPixelConverter.Create(TWgs84CoordinateConverter.Create);
  MercatorConverter.OnChange := MercatorConverterChanged;
  DisplayCoordConverter := CoordinateSystems[0].CreateConverter;
  ShowOSMExecute(nil);
  CollapseBtnClick(nil);
end;

procedure TMainForm.FormShow(Sender: TObject);
begin
  ZoomAllExecute(nil);
end;

procedure TMainForm.FormResize(Sender: TObject);
begin
  if (Layers.Count > 0) or ShowOSM.Checked then
    PaintBox.Invalidate;
end;

procedure TMainForm.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  ShapesImage.Free;
  LayerImage.Free;
  MercatorConverter.Free;
  OSMLayer.Free;
  Layers.Free;  // free layers before coord systems (layers hold CoordSystem refs)
  DisplayCoordConverter.Free;
  for var CS in CoordinateSystems do CS.Free;
  for var FF in FileFormats do FF.Free;
end;


////////////////////////////////////////////////////////////////////////////////
// Layer management
////////////////////////////////////////////////////////////////////////////////

Procedure TMainForm.LayerListBoxClick(Sender: TObject);
begin
  UpdateSelectedLayerPanel;
end;


procedure TMainForm.RemoveLayerExecute(Sender: TObject);
begin
  var Idx := LayerListBox.ItemIndex;
  if (Idx >= 0) and (Idx < Layers.Count) then
  begin
    Layers.Delete(Idx);
    LayerListBox.Items.Delete(Idx);
    if LayerListBox.Count > 0 then
      LayerListBox.ItemIndex := Min(Idx,LayerListBox.Count-1);
      UpdateSelectedLayerPanel;
    LayoutChanged := true;
    PaintBox.Refresh;
  end;
end;

procedure TMainForm.SaveImageExecute(Sender: TObject);
var
  Dlg: TSaveDialog;
begin
  Dlg := TSaveDialog.Create(nil);
  try
    Dlg.Title       := 'Save map image';
    Dlg.Filter      := 'PNG image|*.png|Bitmap|*.bmp';
    Dlg.FilterIndex := 1;
    Dlg.DefaultExt  := 'png';
    Dlg.Options     := [ofOverwritePrompt];
    if Dlg.Execute then
      if SameText(ExtractFileExt(Dlg.FileName), '.bmp') then
        ShapesImage.SaveToFile(Dlg.FileName)
      else
      begin
        var PNG := TPngImage.Create;
        try
          PNG.Assign(ShapesImage);
          PNG.SaveToFile(Dlg.FileName);
        finally
          PNG.Free;
        end;
      end;
  finally
    Dlg.Free;
  end;
end;

procedure TMainForm.SaveLayerExecute(Sender: TObject);
var
  Idx: Integer;
  Writable: TArray<TGISFileFormat>;
  Filter: String;
  Dlg: TSaveDialog;
begin
  Idx := LayerListBox.ItemIndex;
  if (Idx < 0) or (Idx >= Layers.Count) then Exit;
  Writable := [];
  for var FF in FileFormats do
    if FF.CanWrite then Writable := Writable + [FF];
  if Length(Writable) = 0 then Exit;
  Filter := '';
  for var FF in Writable do
  begin
    if Filter <> '' then Filter := Filter + '|';
    Filter := Filter + FF.DialogFilter;
  end;
  Dlg := TSaveDialog.Create(nil);
  try
    Dlg.Filter      := Filter;
    Dlg.FilterIndex := 1;
    Dlg.Options     := [ofOverwritePrompt];
    if Dlg.Execute then
      Writable[Dlg.FilterIndex - 1].SaveLayer(Dlg.FileName, Layers[Idx]);
  finally
    Dlg.Free;
  end;
end;

procedure TMainForm.SaveLayersExecute(Sender: TObject);
var
  MultiLayer: TArray<TGISFileFormat>;
  Filter: String;
  Dlg: TSaveDialog;
begin
  if Layers.Count = 0 then Exit;
  MultiLayer := [];
  for var FF in FileFormats do
    if FF.CanWrite and FF.MultiLayerSupport then MultiLayer := MultiLayer + [FF];
  if Length(MultiLayer) = 0 then Exit;
  Filter := '';
  for var FF in MultiLayer do
  begin
    if Filter <> '' then Filter := Filter + '|';
    Filter := Filter + FF.DialogFilter;
  end;
  var All: TArray<TLayer>;
  SetLength(All, Layers.Count);
  for var I := 0 to Layers.Count - 1 do All[I] := Layers[I];
  Dlg := TSaveDialog.Create(nil);
  try
    Dlg.Filter      := Filter;
    Dlg.FilterIndex := 1;
    Dlg.Options     := [ofOverwritePrompt];
    if Dlg.Execute then
      MultiLayer[Dlg.FilterIndex - 1].SaveLayers(Dlg.FileName, All);
  finally
    Dlg.Free;
  end;
end;

procedure TMainForm.LayerUpExecute(Sender: TObject);
var
  Idx: Integer;
  Tmp: String;
begin
  Idx := LayerListBox.ItemIndex;
  if Idx > 0 then
  begin
    Layers.Exchange(Idx, Idx-1);
    Tmp := LayerListBox.Items[Idx];
    LayerListBox.Items[Idx] := LayerListBox.Items[Idx-1];
    LayerListBox.Items[Idx-1] := Tmp;
    LayerListBox.ItemIndex := Idx-1;
    LayoutChanged := true;
    PaintBox.Refresh;
  end;
end;

procedure TMainForm.LayerDownExecute(Sender: TObject);
var
  Idx: Integer;
  Tmp: String;
begin
  Idx := LayerListBox.ItemIndex;
  if (Idx >= 0) and (Idx < Layers.Count-1) then
  begin
    Layers.Exchange(Idx, Idx+1);
    Tmp := LayerListBox.Items[Idx];
    LayerListBox.Items[Idx] := LayerListBox.Items[Idx+1];
    LayerListBox.Items[Idx+1] := Tmp;
    LayerListBox.ItemIndex := Idx+1;
    LayoutChanged := true;
    PaintBox.Refresh;
  end;
end;

procedure TMainForm.CollapseBtnClick(Sender: TObject);
begin
  if LayerPanel.Width > CollapseBtn.Width then
  begin
    LayerPanel.Width      := CollapseBtn.Width;
    LayerListBox.Visible  := false;
    CollapseBtn.Caption   := '>>';
  end else
  begin
    LayerPanel.Width      := 200;
    LayerListBox.Visible  := true;
    CollapseBtn.Caption   := '<<';
  end;
end;

procedure TMainForm.RemoveLayerBtnClick(Sender: TObject);
begin
end;

////////////////////////////////////////////////////////////////////////////////
// View actions
////////////////////////////////////////////////////////////////////////////////

procedure TMainForm.ZoomInExecute(Sender: TObject);
begin
  MouseDown := false;
  ZoomIn.Checked := not ZoomIn.Checked;
  if ZoomIn.Checked then
  begin
    ZoomStyle := zsZoomIn;
    PaintBox.Cursor := crZoomIn;
  end else
  begin
    ZoomStyle := zsNone;
    PaintBox.Cursor := crArrow;
  end;
end;

procedure TMainForm.ZoomOutExecute(Sender: TObject);
begin
  MouseDown := false;
  ZoomOut.Checked := not ZoomOut.Checked;
  if ZoomOut.Checked then
  begin
    ZoomStyle := zsZoomOut;
    PaintBox.Cursor := crZoomOut;
  end else
  begin
    ZoomStyle := zsNone;
    PaintBox.Cursor := crArrow;
  end;
end;

procedure TMainForm.PanExecute(Sender: TObject);
begin
  MouseDown := false;
  Pan.Checked := not Pan.Checked;
  if Pan.Checked then
  begin
    ZoomStyle := zsMove;
    PaintBox.Cursor := crDrag;
  end else
  begin
    ZoomStyle := zsNone;
    PaintBox.Cursor := crArrow;
  end;
end;

procedure TMainForm.ZoomAllExecute(Sender: TObject);
var
  BBox: TCoordinateRect;
begin
  if Layers.Count > 0 then
    BBox := AllLayersBBox
  else
    BBox := WorldBBox;
  if MercatorConverter <> nil then
  begin
    MercatorConverter.Initialize(BBox,PaintBox.ClientWidth,PaintBox.ClientHeight);
    LayoutChanged := true;
    if Layers.Count > 0 then ViewportChanged := true;
  end;
  PaintBox.Invalidate;
end;

procedure TMainForm.ShowOSMExecute(Sender: TObject);
begin
  MouseDown := false;
  ShowOSM.Checked := not ShowOSM.Checked;
  OSMAttribLabel.Visible := ShowOSM.Checked;
  LayoutChanged := true;
  PaintBox.Invalidate;
end;

////////////////////////////////////////////////////////////////////////////////
// Mouse handlers
////////////////////////////////////////////////////////////////////////////////

procedure TMainForm.PaintBoxMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  MouseDown := true;
  StartPosition := MousePosition;
end;

procedure TMainForm.PaintBoxMouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
begin
  // Erase rubber band
  if MouseDown and (ZoomStyle = zsZoomIn) then
  begin
    PaintBox.Canvas.Pen.Width := 1;
    PaintBox.Canvas.Pen.Color := clBlack;
    PaintBox.Canvas.Pen.Mode  := pmNotXor;
    PaintBox.Canvas.Pen.Style := psDot;
    PaintBox.Canvas.Rectangle(StartPosition.X,StartPosition.Y,MousePosition.X,MousePosition.Y);
  end;
  // Update coordinate panels
  MousePosition := Point(X,Y);
  if MercatorConverter.Initialized and
     (X >= 0) and (X < PaintBox.ClientWidth) and
     (Y >= 0) and (Y < PaintBox.ClientHeight) then
  begin
    var Geodetic := MercatorConverter.PixelToGeodeticCoord(TPointF.Create(MousePosition.X,MousePosition.Y));
    MouseCoordinate := DisplayCoordConverter.GeodeticCoordToCoord(Geodetic);
    XCoordPanel.Caption := MouseCoordinate.X.ToString(4,false,false);
    YCoordPanel.Caption := MouseCoordinate.Y.ToString(4,false,false);
  end else
  begin
    XCoordPanel.Caption := '';
    YCoordPanel.Caption := '';
  end;
  // Update paint box
  if MouseDown then
  case ZoomStyle of
    zsZoomIn: PaintBox.Canvas.Rectangle(StartPosition.X,StartPosition.Y,MousePosition.X,MousePosition.Y);
    zsMove:   PaintBox.Invalidate;
  end;
end;

procedure TMainForm.PaintBoxMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  if MouseDown and (ZoomStyle <> zsNone) then
  begin
    MouseDown := false;
    case ZoomStyle of
      zsMove:
        MercatorConverter.PanMap(MousePosition.X-StartPosition.X,MousePosition.Y-StartPosition.Y);
      zsZoomIn:
        if (MousePosition.X=StartPosition.X) and (MousePosition.Y=StartPosition.Y) then
          MercatorConverter.ZoomIn(MousePosition)
        else
          begin
            var Left   := Min(StartPosition.X,MousePosition.X);
            var Top    := Min(StartPosition.Y,MousePosition.Y);
            var Right  := Max(StartPosition.X,MousePosition.X);
            var Bottom := Max(StartPosition.Y,MousePosition.Y);
            MercatorConverter.ZoomIn(TRectF.Create(Left,Top,Right,Bottom));
          end;
      zsZoomOut:
        begin
          var CenterX := Round((StartPosition.X+MousePosition.X)/2);
          var CenterY := Round((StartPosition.Y+MousePosition.Y)/2);
          MercatorConverter.ZoomOut(TPointF.Create(CenterX,CenterY));
        end;
    end;
    if Layers.Count > 0 then ViewportChanged := true;
    LayoutChanged := ShowOSM.Checked;
    PaintBox.Invalidate;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
// Paint
////////////////////////////////////////////////////////////////////////////////

procedure TMainForm.PaintBoxPaint(Sender: TObject);
var
  X,Y: Integer;
  OSMActive: Boolean;
begin
  if Repainting then Exit;
  Repainting := true;
  try
    OSMActive := ShowOSM.Checked and MercatorConverter.Initialized;
    if OSMActive or (Layers.Count > 0) then
    begin
      // Handle size change
      // Handle any size change (resize, panel collapse/expand, maximise ...)
      // Checked unconditionally so it fires even before FormResize sets isResized.
      var NewW := PaintBox.ClientWidth;
      var NewH := PaintBox.ClientHeight;
      if (NewW <> ShapesImage.Width) or (NewH <> ShapesImage.Height) then
      begin
        if MercatorConverter.Initialized then
        begin
          var OldW := MercatorConverter.PixelWidth;
          var OldH := MercatorConverter.PixelHeight;
          MercatorConverter.Resize(NewW, NewH);
          if (OldW > 0) and (OldH > 0) then
            MercatorConverter.PanMap((NewW - OldW) / 2, (NewH - OldH) / 2);
        end;
        ViewportChanged := true;
        LayoutChanged     := true;
      end;
      // Repaint image
      if LayoutChanged or ((Layers.Count > 0) and ViewportChanged) then
      begin
        Screen.Cursor := crHourGlass;
        try
          ShapesImage.Width  := PaintBox.ClientWidth;
          ShapesImage.Height := PaintBox.ClientHeight;
          ShapesImage.Canvas.Brush.Color := clWhite;
          ShapesImage.Canvas.FillRect(Rect(0,0,ShapesImage.Width,ShapesImage.Height));
          if OSMActive then
            OSMLayer.DrawLayer(GISCanvas(ShapesImage),MercatorConverter);
          for var Layer in Layers do
            if Layer.Visible then
            begin
              LayerImage.Width  := ShapesImage.Width;
              LayerImage.Height := ShapesImage.Height;
              LayerImage.Canvas.Draw(0,0,ShapesImage);
              var LayerStyle := Layer.Shapes.Style;
              LayerStyle.Stroke := TGISStroke.Create(AlphaColor(Layer.PenColor),
                                                     Layer.PenWidth,GISPenStyle(Layer.PenStyle));
              LayerStyle.Fill   := TGISFill.Create(AlphaColor(Layer.BrushColor),
                                                   GISBrushStyle(Layer.BrushStyle));
              Layer.Shapes.Style := LayerStyle;
              Layer.Shapes.DrawLayer(GISCanvas(LayerImage),Layer.Converter);
              ShapesImage.Canvas.Draw(0,0,LayerImage,Layer.Opacity);
            end;
        finally
          Screen.Cursor := crDefault;
        end;
      end;
      LayoutChanged := false;
      if Layers.Count > 0 then ViewportChanged := false;
      // Draw to canvas
      if MouseDown and (ZoomStyle = zsMove) then
      begin
        X := MousePosition.X-StartPosition.X;
        Y := MousePosition.Y-StartPosition.Y;
      end else
      begin
        X := 0;
        Y := 0;
      end;
      PaintBox.Canvas.Draw(X,Y,ShapesImage);
    end;
  finally
    Repainting := false;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
// Trackbar
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// File loading
////////////////////////////////////////////////////////////////////////////////

Procedure TMainForm.OpenShapeFile(const FileName: String);
var
  Ext: String;
begin
  Screen.Cursor := crHourGlass;
  try
    Ext := ExtractFileExt(FileName);
    for var FF in FileFormats do
      if FF.Handles(Ext) then
      begin
        var NewLayers := FF.OpenFile(FileName, CoordinateSystems, MercatorConverter);
        for var L in NewLayers do
          AddGISLayer(L);
        Break;
      end;
    ZoomStyle := zsNone;
    PaintBox.Cursor := crArrow;
    ZoomIn.Checked  := false;
    ZoomOut.Checked := false;
    Pan.Checked     := false;
  finally
    Screen.Cursor := crDefault;
  end;
end;

procedure TMainForm.AddLayerAccept(Sender: TObject);
begin
  OpenShapeFile(AddLayer.Dialog.FileName);
end;

end.

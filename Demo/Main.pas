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
  Classes, SysUtils, Math, Types, UITypes, Variants, Actions, Winapi.Windows,
  Winapi.Messages, Winapi.ShellAPI, Vcl.Graphics, Vcl.Controls, Vcl.Forms,
  Vcl.Dialogs, Vcl.ActnList, Vcl.StdActns, Vcl.ComCtrls, Vcl.StdCtrls, Vcl.Clipbrd, PngImage,
  Vcl.Samples.Spin,
  System.ImageList, Vcl.ImgList, Vcl.BaseImageCollection, Vcl.ImageCollection,
  Vcl.VirtualImageList, Vcl.ExtCtrls, Vcl.ToolWin,
  System.Generics.Collections, FloatHlp,
  GISCoordSystem, GISFileFormat, RndrCtrl, RndrCtrl.Default,
  FireDAC.Comp.UI, FireDAC.VCLUI.Wait,
  GIS, GIS.Shapes, GIS.Render.Shapes, GIS.Render.Canvas, GIS.Render.Canvas.VCL,
  GIS.Render.Canvas.SVG, GIS.Render.PixelConv, GIS.Render.PixelConv.Cartesian, GIS.Render.PixelConv.Mercator,
  GIS.Render.Tiles.OSM, GIS.CoordConv, GIS.CoordConv.WGS84, Vcl.TitleBarCtrls;

type
  TZoomStyle = (zsNone,zsMove,zsZoomIn,zsZoomOut);

  // mpCartesian draws the coordinates of the layers as they are, which fits a
  // view to the paint area exactly. It takes visible layers that share a
  // coordinate system and shows no tiles. A layer of an unknown coordinate
  // system is taken to be in that of the others, and is hidden in any other
  // projection.
  TMapProjection = (mpWebMercator,mpCartesian);

  TMainForm = class(TForm)
    ActionList: TActionList;
    ImageCollection: TImageCollection;
    ImageList: TVirtualImageList;
    DisabledImageList: TVirtualImageList;
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
    ZoomInToolButton: TToolButton;
    ZoomOutToolButton: TToolButton;
    PanToolButton: TToolButton;
    ZoomAllToolButton: TToolButton;
    OSMSeparator: TToolButton;
    ShowOSMToolButton: TToolButton;
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
    RemoveLayerToolButton: TToolButton;
    LayerUpToolButton: TToolButton;
    LayerDownToolButton: TToolButton;
    SaveImage: TAction;
    SaveImageSeparator: TToolButton;
    SaveImageToolButton: TToolButton;
    AddLayerToolButton: TToolButton;
    SaveLayer: TAction;
    SaveLayers: TAction;
    SaveLayerToolButton: TToolButton;
    SaveLayersToolButton: TToolButton;
    SaveLayersSeparator: TToolButton;
    MapPanel: TPanel;
    ProjectionLabel: TLabel;
    ProjectionComboBox: TComboBox;
    BackgroundLabel: TLabel;
    BackgroundColorPanel: TPanel;
    PreviousView: TAction;
    NextView: TAction;
    PreviousViewToolButton: TToolButton;
    NextViewToolButton: TToolButton;
    CopyImage: TAction;
    CopyImageToolButton: TToolButton;
    TitleBarPanel: TTitleBarPanel;
    Procedure AddLayerAccept(Sender: TObject);
    Procedure FormCreate(Sender: TObject);
    Procedure ZoomInExecute(Sender: TObject);
    Procedure ZoomOutExecute(Sender: TObject);
    Procedure PanExecute(Sender: TObject);
    Procedure ZoomAllExecute(Sender: TObject);
    Procedure ShowOSMExecute(Sender: TObject);
    Procedure FormShow(Sender: TObject);
    Procedure FormResize(Sender: TObject);
    Procedure PaintBoxMouseDown(Sender: TObject; Button: TMouseButton;
                                Shift: TShiftState; X, Y: Integer);
    Procedure PaintBoxMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    Procedure PaintBoxMouseUp(Sender: TObject; Button: TMouseButton;
                              Shift: TShiftState; X, Y: Integer);
    Procedure PaintBoxPaint(Sender: TObject);
    Procedure FormClose(Sender: TObject; var Action: TCloseAction);
    Procedure LayerListBoxClick(Sender: TObject);
    Procedure CollapseBtnClick(Sender: TObject);
    Procedure CoordSystemComboBoxChange(Sender: TObject);
    Procedure RemoveLayerExecute(Sender: TObject);
    Procedure LayerUpExecute(Sender: TObject);
    Procedure LayerDownExecute(Sender: TObject);
    Procedure SaveImageExecute(Sender: TObject);
    Procedure SaveLayerExecute(Sender: TObject);
    Procedure SaveLayersExecute(Sender: TObject);
    Procedure BackgroundColorPanelClick(Sender: TObject);
    Procedure PreviousViewExecute(Sender: TObject);
    Procedure NextViewExecute(Sender: TObject);
    Procedure ProjectionComboBoxChange(Sender: TObject);
    Procedure ActionListUpdate(Action: TBasicAction; var Handled: Boolean);
    Procedure CopyImageExecute(Sender: TObject);
  private
    Const
      crZoomIn  = 1;
      crZoomOut = 2;
      ProjectionNames: array[TMapProjection] of String = ('Web Mercator','Cartesian');
    Var
      ZoomStyle: TZoomStyle;
      ShapesImage: TBitmap;
      LayerImage: TBitmap;
      MousePosition,StartPosition: TPoint;
      MouseCoordinate: TCoordinate;
      MouseDown: Boolean;
      MercatorConverter: TWebMercatorPixelConverter;
      CartesianConverter: TCartesianPixelConverter;
      // The coordinate system of the Cartesian view (owned by
      // CoordinateSystems) and its converter
      CartesianCoordSystem: TGISCoordinateSystem;
      CartesianCoordConverter: TCoordinateConverter;
      Projection: TMapProjection;
      OSMLayer: TOpenStreetMapLayer;
      Layers: TObjectList<TLayer>;
      ViewportChanged: Boolean;
      LayoutChanged: Boolean;
      Repainting: Boolean;
      BackgroundColor: TColor;
      DisplayCoordConverter: TCoordinateConverter;
      FileFormats:       TArray<TGISFileFormat>;
      CoordinateSystems: TArray<TGISCoordinateSystem>;
      // Offered when opening a file, ahead of CoordinateSystems
      UnknownCoordSystem: TGISCoordinateSystem;
    Function  ActiveConverter: TCustomPixelConverter;
    Function  MapShown: Boolean;
    Function  Georeferenced: Boolean;
    Function  PixelToGeodeticCoord(const Pixel: TPointF): TGeodeticCoordinate;
    Function  CommonCoordSystem(out CoordSystem: TGISCoordinateSystem): Boolean;
    Function  UnknownLayerShown: Boolean;
    Function  WorldBBox: TCoordinateRect;
    Function  AllLayersBBox: TCoordinateRect;
    Function  CartesianLayersBBox: TCoordinateRect;
    // The pixels a shape may stick out of its layer's bounding box, so that a view fitted to
    // the layers keeps the outermost symbols on the map
    Function  LayersMargin: Single;
    Procedure HideUnknownLayers;
    Procedure SetProjection(NewProjection: TMapProjection; const KeepView: Boolean = true);
    Procedure UpdateSelectedLayerPanel;
    Procedure UpdateMinHeight;
    Procedure LayerPropertyChanged(Sender: TObject);
    Procedure ConverterChanged(Sender: TObject);
    Procedure OpenShapeFile(const FileName: String);
    Procedure ApplyLayerStyle(const Layer: TLayer);
    Procedure SaveSvgImage(const FileName: String);
  public
    Procedure AddGISLayer(const ALayer: TLayer);
    Procedure WMDropFiles(var msg: TWMDropFiles); message WM_DROPFILES;
    Procedure WMSize(var Message: TWMSize); message WM_SIZE;
    Procedure WMExitSizeMove(var Message: TMessage); message WM_EXITSIZEMOVE;
  end;

var
  MainForm: TMainForm;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

{$R *.dfm}
{$R GIS.Cursor.RES}

Const
  // Wide enough for the layers toolbar to keep its buttons on one row. The
  // toolbar wraps silently when this is too small, hiding the last buttons.
  ExpandedLayerPanelWidth = 216;

////////////////////////////////////////////////////////////////////////////////
// TMainForm helpers
////////////////////////////////////////////////////////////////////////////////

Function TMainForm.ActiveConverter: TCustomPixelConverter;
begin
  if Projection = mpCartesian then
    Result := CartesianConverter
  else
    Result := MercatorConverter;
end;

Function TMainForm.MapShown: Boolean;
// Returns whether there is anything to look at: the tiles or a visible layer.
// Without it there is no view to zoom, pan or save.
begin
  if ShowOSM.Checked then
    Result := true
  else
    begin
      Result := false;
      for var Layer in Layers do
      if Layer.Visible then Exit(true);
    end;
end;

Function TMainForm.Georeferenced: Boolean;
// Whether the coordinates of the view are of a known coordinate system, so
// that they can be converted to another one
begin
  Result := (Projection = mpWebMercator) or CartesianCoordSystem.Known;
end;

Function TMainForm.PixelToGeodeticCoord(const Pixel: TPointF): TGeodeticCoordinate;
begin
  if Projection = mpCartesian then
    Result := CartesianCoordConverter.CoordToGeodeticCoord(CartesianConverter.PixelToCoord(Pixel))
  else
    Result := MercatorConverter.PixelToGeodeticCoord(Pixel);
end;

Function TMainForm.CommonCoordSystem(out CoordSystem: TGISCoordinateSystem): Boolean;
// Whether the visible layers share a coordinate system, and that coordinate
// system. It is nil where no layer is visible. A layer of an unknown
// coordinate system is taken to share that of the others, so the unknown one
// is returned only where no other is visible.
begin
  Result := true;
  CoordSystem := nil;
  for var Layer in Layers do
    if Layer.Visible then
      if (CoordSystem = nil) or not CoordSystem.Known then CoordSystem := Layer.CoordSystem else
      if Layer.CoordSystem.Known and (Layer.CoordSystem <> CoordSystem) then Exit(false);
end;

Function TMainForm.UnknownLayerShown: Boolean;
begin
  Result := false;
  for var Layer in Layers do
    if Layer.Visible and not Layer.CoordSystem.Known then Exit(true);
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

Function TMainForm.CartesianLayersBBox: TCoordinateRect;
begin
  Result.Clear;
  for var Layer in Layers do
    if Layer.Visible then Result.Enclose(Layer.Shapes.BoundingBox);
  if Result.Empty then
  begin
    Result.Left := 0; Result.Right := 1; Result.Bottom := 0; Result.Top := 1;
  end;
  // A single point or a horizontal or vertical line has no area to fit the
  // paint area to
  var Padding := 0.5*Max(Result.Width,Result.Height);
  if Padding = 0 then Padding := 0.5;
  if Result.Width = 0 then
  begin
    Result.Left  := Result.Left - Padding;
    Result.Right := Result.Right + Padding;
  end;
  if Result.Height = 0 then
  begin
    Result.Bottom := Result.Bottom - Padding;
    Result.Top    := Result.Top + Padding;
  end;
end;

Function TMainForm.LayersMargin: Single;
// Half a point symbol, plus the pen it is drawn with
begin
  Result := 0;
  for var Layer in Layers do
    if Layer.Visible then
    begin
      var Margin: Single := Layer.PenWidth;
      if Layer.Shapes.ShapeCount(stPoint) > 0 then Margin := Margin + 0.5*Layer.Shapes.PointRenderSize;
      if Margin > Result then Result := Margin;
    end;
end;

Procedure TMainForm.HideUnknownLayers;
begin
  for var Layer in Layers do
    if not Layer.CoordSystem.Known then Layer.Visible := false;
  // Show it in the panel of the selected layer, without the control reporting
  // the change back
  var Selected := LayerListBox.ItemIndex;
  if (Selected >= 0) and (Selected < Layers.Count) then
  begin
    var Ctrl := Layers[Selected].RenderingControl;
    if Ctrl <> nil then
    begin
      Ctrl.OnChange := nil;
      Ctrl.LoadFrom(Layers[Selected]);
      Ctrl.OnChange := LayerPropertyChanged;
    end;
  end;
  LayoutChanged := true;
  PaintBox.Invalidate;
end;

Procedure TMainForm.SetProjection(NewProjection: TMapProjection; const KeepView: Boolean = true);
// Puts the projection into effect and carries the view over to it. Without
// KeepView the view is zoomed to all layers instead. Passing the projection in
// effect checks it against the visible layers.
var
  CoordSystem: TGISCoordinateSystem;
  Corners: TArray<TGeodeticCoordinate>;
  Viewport,Pixels: TCoordinateRect;
begin
  // Cartesian draws the coordinates of the visible layers as they are, so
  // these must share a coordinate system. Web Mercator converts them, so it
  // must know the coordinate system of each: asking for it hides the layers
  // of an unknown one.
  var Refused := '';
  if (NewProjection = mpWebMercator) and (Projection = mpCartesian) then HideUnknownLayers;
  var Common := CommonCoordSystem(CoordSystem);
  // A layer of an unknown coordinate system was added or shown
  if UnknownLayerShown then
    if Common then
    begin
      if NewProjection = mpWebMercator then
        Refused := 'The Web Mercator projection needs the coordinate system of '+
                   'every visible layer. The map is drawn in Cartesian.';
      NewProjection := mpCartesian;
    end else
    begin
      // Neither projection takes these layers together
      HideUnknownLayers;
      NewProjection := mpWebMercator;
      Refused := 'A layer of an unknown coordinate system cannot be drawn '+
                 'together with layers that differ in coordinate system. '+
                 'It is hidden.';
    end
  else
    if (NewProjection = mpCartesian) and not Common then
    begin
      NewProjection := mpWebMercator;
      Refused := 'The Cartesian projection takes layers that share a coordinate '+
                 'system. The map is drawn in Web Mercator.';
    end;
  // The coordinate system stays the one last drawn in for as long as no layer
  // is visible
  if NewProjection = mpCartesian then
  begin
    if CoordSystem = nil then CoordSystem := CartesianCoordSystem;
    if CoordSystem = nil then CoordSystem := CoordinateSystems[0];
  end;
  ProjectionComboBox.ItemIndex := Ord(NewProjection);
  // Tiles are laid out in Web Mercator
  if (NewProjection = mpCartesian) and ShowOSM.Checked then
  begin
    ShowOSM.Checked := false;
    OSMAttribLabel.Visible := false;
    LayoutChanged := true;
    PaintBox.Invalidate;
  end;
  if (NewProjection <> Projection) or
     ((NewProjection = mpCartesian) and (CoordSystem <> CartesianCoordSystem)) then
  begin
    // A Cartesian view that gains or loses its coordinate system keeps its
    // coordinates: layers of an unknown one are taken to be in that of the view
    var SameCoords := (Projection = mpCartesian) and (NewProjection = mpCartesian) and
                      not (CartesianCoordSystem.Known and CoordSystem.Known);
    var CarryView := KeepView and ActiveConverter.Initialized and not SameCoords;
    // The corners of the view, taken before the projection changes. There are
    // none to carry over from or to an unknown coordinate system.
    var ViewWidth  := ActiveConverter.PixelWidth;
    var ViewHeight := ActiveConverter.PixelHeight;
    if CarryView and Georeferenced and
       ((NewProjection = mpWebMercator) or CoordSystem.Known) then
      Corners := [PixelToGeodeticCoord(TPointF.Create(0,0)),
                  PixelToGeodeticCoord(TPointF.Create(ViewWidth,0)),
                  PixelToGeodeticCoord(TPointF.Create(ViewWidth,ViewHeight)),
                  PixelToGeodeticCoord(TPointF.Create(0,ViewHeight))];
    Projection := NewProjection;
    // The view history holds views of a single projection
    if not SameCoords then ActiveConverter.Clear;
    if Projection = mpCartesian then
    begin
      CartesianCoordSystem := CoordSystem;
      FreeAndNil(CartesianCoordConverter);
      CartesianCoordConverter := CoordSystem.CreateConverter;
    end;
    if Length(Corners) > 0 then
    begin
      Viewport.Clear;
      if Projection = mpCartesian then
      begin
        for var Corner in Corners do
          Viewport.Enclose(CartesianCoordConverter.GeodeticCoordToCoord(Corner));
        // The view is carried over as it is
        CartesianConverter.Margin := 0;
        CartesianConverter.Initialize(Viewport,ViewWidth,ViewHeight);
      end else
      begin
        // Web Mercator reaches neither pole
        for var Corner in Corners do
          Viewport.Enclose(TCoordinate.Create(EnsureRange(Corner.Longitude,-180,180),
                                              EnsureRange(Corner.Latitude,-85,85)));
        MercatorConverter.Margin := 0;
        MercatorConverter.Initialize(Viewport,ViewWidth,ViewHeight);
        // Web Mercator zooms in whole levels, and Initialize takes a level
        // that holds the viewport. Zoom in to the level nearest to the scale
        // of the view, so that switching back and forth does not zoom out.
        Pixels.Clear;
        for var Corner in [TCoordinate.Create(Viewport.Left,Viewport.Top),
                           TCoordinate.Create(Viewport.Right,Viewport.Bottom)] do
        begin
          var Pixel := MercatorConverter.CoordToPixel(Corner);
          Pixels.Enclose(TCoordinate.Create(Pixel.X,Pixel.Y));
        end;
        var Fill := Max(Pixels.Width/ViewWidth,Pixels.Height/ViewHeight);
        while (Fill < Sqrt(0.5)) and
              (MercatorConverter.ZoomLevel < MercatorConverter.MaxZoomLevel) do
        begin
          MercatorConverter.ZoomIn(TPointF.Create(ViewWidth/2,ViewHeight/2));
          Fill := 2*Fill;
        end;
        // Start the view history at the view arrived at
        MercatorConverter.Clear;
        var State := MercatorConverter.GetState;
        try
          MercatorConverter.SetState(State);
        finally
          State.Free;
        end;
      end;
    end else
      if CarryView then ZoomAllExecute(nil);
    ConverterChanged(nil);
    LayoutChanged   := true;
    ViewportChanged := true;
    PaintBox.Invalidate;
  end;
  // The mouse coordinates are converted to the coordinate system selected
  CoordSystemComboBox.Enabled := Georeferenced;
  // Before the message: the map is painted while it shows
  if not KeepView then ZoomAllExecute(nil);
  if Refused <> '' then MessageDlg(Refused,mtInformation,[mbOK],0);
end;

Procedure TMainForm.CoordSystemComboBoxChange(Sender: TObject);
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
      Ctrl.Align                 := alClient;
      // Give the control the height it needs; the list box above gets what is
      // left, and scrolls. Keep the bottom edge above MapPanel:
      // bottom-aligned panels are stacked by their bottom edge.
      var PanelHeight := Ctrl.RequiredHeight +
                         SelectedLayerPanel.Height - SelectedLayerPanel.ClientHeight;
      SelectedLayerPanel.SetBounds(0,MapPanel.Top-PanelHeight,
                                   SelectedLayerPanel.Width,PanelHeight);
      UpdateMinHeight;
    end;
    SelectedLayerPanel.Enabled := true;
  end else
    SelectedLayerPanel.Enabled := false;
end;

Procedure TMainForm.UpdateMinHeight;
// The layer list box gives up its height to the selected layer's panel and
// scrolls instead, but it cannot scroll once it has no height left. So keep
// the form tall enough for a few rows, plus a row's worth for the border.
Const
  MinLayerRows = 3;
begin
  Constraints.MinHeight := (Height - ClientHeight) + CoordPanel.Height +
                           LayersToolBar.Height + SelectedLayerPanel.Height +
                           MapPanel.Height +
                           (MinLayerRows+1)*LayerListBox.ItemHeight;
end;

Procedure TMainForm.LayerPropertyChanged(Sender: TObject);
begin
  SetProjection(Projection);  // the layer may have been shown or hidden
  ViewportChanged := true;
  PaintBox.Invalidate;
end;

Procedure TMainForm.AddGISLayer(const ALayer: TLayer);
begin
  if ALayer.RenderingControl = nil then
    ALayer.RenderingControl := TDefaultLayerRenderingControl.Create(nil);  // owned by the layer
  Layers.Add(ALayer);
  LayerListBox.Items.Add(ALayer.Name);
  LayerListBox.ItemIndex := LayerListBox.Count-1;
  UpdateSelectedLayerPanel;
  if LayerPanel.Width <= CollapseBtn.Width then
    CollapseBtnClick(nil);
  SetProjection(Projection,false);
end;

Procedure TMainForm.ConverterChanged(Sender: TObject);
begin
  for var Layer in Layers do
    Layer.Converter.SyncFrom(MercatorConverter);
end;

////////////////////////////////////////////////////////////////////////////////
// Windows messages
////////////////////////////////////////////////////////////////////////////////

Procedure TMainForm.WMDropFiles(var msg: TWMDropFiles);
const
  MaxFileName = 255;
var
  FileName: array[0..MaxFileName] of char;
begin
  DragQueryFile(msg.Drop,0,FileName,MaxFileName);
  OpenShapeFile(FileName);
  DragFinish(msg.Drop);
end;

Procedure TMainForm.WMSize(var Message: TWMSize);
begin
  inherited;
  if Message.SizeType = SIZE_MAXIMIZED then FormResize(nil);
end;

Procedure TMainForm.WMExitSizeMove(var Message: TMessage);
begin
  FormResize(nil);
end;

////////////////////////////////////////////////////////////////////////////////
// Form lifecycle
////////////////////////////////////////////////////////////////////////////////

Procedure TMainForm.FormCreate(Sender: TObject);
begin
  TFDGUIxWaitCursor.Create(Self);  // required by FireDAC; owned by form
  DragAcceptFiles(Handle,true);
  Screen.Cursors[crZoomIn]  := LoadCursor(HInstance,'ZOOM_IN');
  Screen.Cursors[crZoomOut] := LoadCursor(HInstance,'ZOOM_OUT');
  ShapesImage := TBitmap.Create;
  LayerImage  := TBitmap.Create;
  OSMLayer    := TOpenStreetMapLayer.Create;
  Layers      := TObjectList<TLayer>.Create(true);
  BackgroundColor := BackgroundColorPanel.Color;
  ViewportChanged := true;
  // Registered coordinate systems - extend here to add more
  CoordinateSystems := [
    TWgs84CoordinateSystem.Create,
    TDutchGridCoordinateSystem.Create,
    TWebMercatorCoordinateSystem.Create,
    TUtmCoordinateSystem.Create
  ];
  UnknownCoordSystem := TUnknownCoordinateSystem.Create;
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
  // Populate projection combo box
  for var MapProjection := Low(TMapProjection) to High(TMapProjection) do
    ProjectionComboBox.Items.Add(ProjectionNames[MapProjection]);
  ProjectionComboBox.ItemIndex := Ord(Projection);
  // Primary converter (always WGS84 for the Mercator view)
  MercatorConverter := TWebMercatorPixelConverter.Create(TWgs84CoordinateConverter.Create);
  CartesianConverter := TCartesianPixelConverter.Create;
  MercatorConverter.OnChange := ConverterChanged;
  CartesianConverter.OnChange := ConverterChanged;
  DisplayCoordConverter := CoordinateSystems[0].CreateConverter;
  ShowOSMExecute(nil);
end;

Procedure TMainForm.FormShow(Sender: TObject);
begin
  UpdateMinHeight;
  ZoomAllExecute(nil);
end;

Procedure TMainForm.FormResize(Sender: TObject);
begin
  if (Layers.Count > 0) or ShowOSM.Checked then
    PaintBox.Invalidate;
end;

Procedure TMainForm.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  ActionList.OnUpdate := nil;  // it looks at what is freed here
  ShapesImage.Free;
  LayerImage.Free;
  MercatorConverter.Free;
  CartesianConverter.Free;
  CartesianCoordConverter.Free;
  OSMLayer.Free;
  Layers.Free;  // free layers before coord systems (layers hold CoordSystem refs)
  DisplayCoordConverter.Free;
  for var CS in CoordinateSystems do CS.Free;
  UnknownCoordSystem.Free;
  for var FF in FileFormats do FF.Free;
end;


////////////////////////////////////////////////////////////////////////////////
// Layer management
////////////////////////////////////////////////////////////////////////////////

Procedure TMainForm.LayerListBoxClick(Sender: TObject);
begin
  UpdateSelectedLayerPanel;
end;


Procedure TMainForm.RemoveLayerExecute(Sender: TObject);
begin
  var Idx := LayerListBox.ItemIndex;
  if (Idx >= 0) and (Idx < Layers.Count) then
  begin
    Layers.Delete(Idx);
    LayerListBox.Items.Delete(Idx);
    if LayerListBox.Count > 0 then
      LayerListBox.ItemIndex := Min(Idx,LayerListBox.Count-1);
      UpdateSelectedLayerPanel;
    SetProjection(Projection);
    LayoutChanged := true;
    PaintBox.Refresh;
  end;
end;

Procedure TMainForm.SaveImageExecute(Sender: TObject);
var
  Dlg: TSaveDialog;
begin
  Dlg := TSaveDialog.Create(nil);
  try
    Dlg.Title       := 'Save map image';
    Dlg.Filter      := 'PNG image|*.png|Bitmap|*.bmp|SVG image|*.svg';
    Dlg.FilterIndex := 1;
    Dlg.DefaultExt  := 'png';
    Dlg.Options     := [ofOverwritePrompt];
    if Dlg.Execute then
      if SameText(ExtractFileExt(Dlg.FileName), '.svg') then
        SaveSvgImage(Dlg.FileName)
      else
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

Procedure TMainForm.ApplyLayerStyle(const Layer: TLayer);
begin
  var LayerStyle := Layer.Shapes.Style;
  LayerStyle.Stroke := TGISStroke.Create(AlphaColor(Layer.PenColor),
                                         Layer.PenWidth,GISPenStyle(Layer.PenStyle));
  LayerStyle.Fill   := TGISFill.Create(AlphaColor(Layer.BrushColor),
                                       GISBrushStyle(Layer.BrushStyle));
  // The canvas takes a font size in pixels, the layer a point size
  LayerStyle.Text.Size  := Layer.TextSize*CurrentPPI/72;
  LayerStyle.Text.Color := AlphaColor(Layer.TextColor);
  Layer.Shapes.Style := LayerStyle;
end;

Procedure TMainForm.SaveSvgImage(const FileName: String);
// Draws the map again, on an SVG canvas of the size of the view, rather than
// saving the pixels of ShapesImage: the shapes stay shapes in the file.
begin
  var Svg := TSvgCanvas.Create(ShapesImage.Width,ShapesImage.Height);
  var Canvas: IGISCanvas := Svg;   // keeps Svg alive, and releases it
  Screen.Cursor := crHourGlass;
  try
    Canvas.FillRect(TRectF.Create(0,0,ShapesImage.Width,ShapesImage.Height),
                    TGISFill.Create(AlphaColor(BackgroundColor)),
                    TGISStroke.Create(TAlphaColorRec.Null,0,gpsClear));
    if ShowOSM.Checked and MercatorConverter.Initialized then
      OSMLayer.DrawLayer(Canvas,MercatorConverter);
    for var Layer in Layers do
      if Layer.Visible then
      begin
        ApplyLayerStyle(Layer);
        // A group takes the place of the bitmap a layer is blended with on screen
        Svg.BeginGroup(Layer.Opacity/255);
        try
          if Projection = mpCartesian then
            Layer.Shapes.DrawLayer(Canvas,CartesianConverter)
          else
            Layer.Shapes.DrawLayer(Canvas,Layer.Converter);
        finally
          Svg.EndGroup;
        end;
      end;
    Svg.SaveToFile(FileName);
  finally
    Screen.Cursor := crDefault;
  end;
end;

Procedure TMainForm.CopyImageExecute(Sender: TObject);
// Puts the map on the clipboard as a bitmap, as it is drawn on screen
begin
  Clipboard.Assign(ShapesImage);
end;

Procedure TMainForm.SaveLayerExecute(Sender: TObject);
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

Procedure TMainForm.SaveLayersExecute(Sender: TObject);
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

Procedure TMainForm.LayerUpExecute(Sender: TObject);
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

Procedure TMainForm.LayerDownExecute(Sender: TObject);
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

Procedure TMainForm.CollapseBtnClick(Sender: TObject);
begin
  if LayerPanel.Width > CollapseBtn.Width then
  begin
    LayerPanel.Width      := CollapseBtn.Width;
    LayerListBox.Visible  := false;
    CollapseBtn.Caption   := '>';
  end else
  begin
    LayerPanel.Width      := ExpandedLayerPanelWidth;
    LayerListBox.Visible  := true;
    CollapseBtn.Caption   := '<';
  end;
end;

Procedure TMainForm.BackgroundColorPanelClick(Sender: TObject);
var
  Dlg: TColorDialog;
begin
  Dlg := TColorDialog.Create(nil);
  try
    Dlg.Color := BackgroundColor;
    if Dlg.Execute then
    begin
      BackgroundColor            := Dlg.Color;
      BackgroundColorPanel.Color := Dlg.Color;
      LayoutChanged := true;
      PaintBox.Invalidate;
    end;
  finally
    Dlg.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
// View actions
////////////////////////////////////////////////////////////////////////////////

Procedure TMainForm.ZoomInExecute(Sender: TObject);
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

Procedure TMainForm.ZoomOutExecute(Sender: TObject);
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

Procedure TMainForm.PanExecute(Sender: TObject);
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

Procedure TMainForm.ZoomAllExecute(Sender: TObject);
begin
  if MercatorConverter <> nil then
  begin
    // AllLayersBBox converts coordinates, which takes known coordinate systems
    var Margin := LayersMargin;
    CartesianConverter.Margin := Margin;
    MercatorConverter.Margin := Margin;
    if Projection = mpCartesian then
      CartesianConverter.Initialize(CartesianLayersBBox,PaintBox.ClientWidth,PaintBox.ClientHeight)
    else
      MercatorConverter.Initialize(AllLayersBBox,PaintBox.ClientWidth,PaintBox.ClientHeight);
    LayoutChanged := true;
    if Layers.Count > 0 then ViewportChanged := true;
  end;
  PaintBox.Invalidate;
end;

Procedure TMainForm.PreviousViewExecute(Sender: TObject);
begin
  MouseDown := false;
  if ActiveConverter.Previous then  // OnChange syncs the layers
  begin
    LayoutChanged   := true;
    ViewportChanged := true;
    PaintBox.Invalidate;
  end;
end;

Procedure TMainForm.NextViewExecute(Sender: TObject);
begin
  MouseDown := false;
  if ActiveConverter.Next then  // OnChange syncs the layers
  begin
    LayoutChanged   := true;
    ViewportChanged := true;
    PaintBox.Invalidate;
  end;
end;

Procedure TMainForm.ShowOSMExecute(Sender: TObject);
begin
  MouseDown := false;
  ShowOSM.Checked := not ShowOSM.Checked;
  OSMAttribLabel.Visible := ShowOSM.Checked;
  if ShowOSM.Checked then SetProjection(mpWebMercator);  // tiles are laid out in Web Mercator
  LayoutChanged := true;
  PaintBox.Invalidate;
end;

Procedure TMainForm.ProjectionComboBoxChange(Sender: TObject);
begin
  MouseDown := false;
  SetProjection(TMapProjection(ProjectionComboBox.ItemIndex));
end;

Procedure TMainForm.ActionListUpdate(Action: TBasicAction; var Handled: Boolean);
// The layer actions need a layer to act on, and the view actions a map. A tool
// stays checked while it is disabled, so it is back in effect once there is a
// map again.
begin
  var Selected := LayerListBox.ItemIndex;
  var HasSelection := (Selected >= 0) and (Selected < Layers.Count);
  var Shown := MapShown;
  RemoveLayer.Enabled  := HasSelection;
  LayerUp.Enabled      := HasSelection and (Selected > 0);
  LayerDown.Enabled    := HasSelection and (Selected < Layers.Count-1);
  SaveLayer.Enabled    := HasSelection;
  SaveLayers.Enabled   := Layers.Count > 0;
  ZoomIn.Enabled       := Shown;
  ZoomOut.Enabled      := Shown;
  Pan.Enabled          := Shown;
  ZoomAll.Enabled      := Shown;
  PreviousView.Enabled := Shown and ActiveConverter.PreviousAvail;
  NextView.Enabled     := Shown and ActiveConverter.NextAvail;
  SaveImage.Enabled    := Shown;
  CopyImage.Enabled    := Shown;
end;

////////////////////////////////////////////////////////////////////////////////
// Mouse handlers
////////////////////////////////////////////////////////////////////////////////

Procedure TMainForm.PaintBoxMouseDown(Sender: TObject; Button: TMouseButton;
                                      Shift: TShiftState; X, Y: Integer);
begin
  MouseDown := MapShown;  // a tool left checked has nothing to act on otherwise
  StartPosition := MousePosition;
end;

Procedure TMainForm.PaintBoxMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
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
  if ActiveConverter.Initialized and
     (X >= 0) and (X < PaintBox.ClientWidth) and
     (Y >= 0) and (Y < PaintBox.ClientHeight) then
  begin
    var Pixel := TPointF.Create(MousePosition.X,MousePosition.Y);
    if Georeferenced then
      MouseCoordinate := DisplayCoordConverter.GeodeticCoordToCoord(PixelToGeodeticCoord(Pixel))
    else
      MouseCoordinate := CartesianConverter.PixelToCoord(Pixel);  // as they are
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

Procedure TMainForm.PaintBoxMouseUp(Sender: TObject; Button: TMouseButton;
                                    Shift: TShiftState; X, Y: Integer);
begin
  if MouseDown and (ZoomStyle <> zsNone) then
  begin
    MouseDown := false;
    case ZoomStyle of
      zsMove:
        ActiveConverter.PanMap(MousePosition.X-StartPosition.X,MousePosition.Y-StartPosition.Y);
      zsZoomIn:
        if (MousePosition.X=StartPosition.X) and (MousePosition.Y=StartPosition.Y) then
          ActiveConverter.ZoomIn(MousePosition)
        else
          begin
            var Left   := Min(StartPosition.X,MousePosition.X);
            var Top    := Min(StartPosition.Y,MousePosition.Y);
            var Right  := Max(StartPosition.X,MousePosition.X);
            var Bottom := Max(StartPosition.Y,MousePosition.Y);
            ActiveConverter.ZoomIn(TRectF.Create(Left,Top,Right,Bottom));
          end;
      zsZoomOut:
        begin
          var CenterX := Round((StartPosition.X+MousePosition.X)/2);
          var CenterY := Round((StartPosition.Y+MousePosition.Y)/2);
          ActiveConverter.ZoomOut(TPointF.Create(CenterX,CenterY));
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

Procedure TMainForm.PaintBoxPaint(Sender: TObject);
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
        if ActiveConverter.Initialized then
        begin
          // Keeps the centre of the view and, not being a change of view,
          // leaves the view history and OnChange alone
          if Projection = mpCartesian then
            CartesianConverter.Resize(NewW, NewH)
          else
            MercatorConverter.Resize(NewW, NewH);
          ConverterChanged(nil);
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
          ShapesImage.Canvas.Brush.Color := BackgroundColor;
          ShapesImage.Canvas.FillRect(Rect(0,0,ShapesImage.Width,ShapesImage.Height));
          if OSMActive then
            OSMLayer.DrawLayer(GISCanvas(ShapesImage),MercatorConverter);
          for var Layer in Layers do
            if Layer.Visible then
            begin
              LayerImage.Width  := ShapesImage.Width;
              LayerImage.Height := ShapesImage.Height;
              LayerImage.Canvas.Draw(0,0,ShapesImage);
              ApplyLayerStyle(Layer);
              if Projection = mpCartesian then
                Layer.Shapes.DrawLayer(GISCanvas(LayerImage),CartesianConverter)
              else
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
        var NewLayers := FF.OpenFile(FileName, [UnknownCoordSystem] + CoordinateSystems,
                                     MercatorConverter);
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

Procedure TMainForm.AddLayerAccept(Sender: TObject);
begin
  OpenShapeFile(AddLayer.Dialog.FileName);
end;

end.

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
  System.Classes, System.SysUtils, System.Variants, System.Actions, Winapi.Windows,
  Winapi.Messages, Winapi.ShellAPI, Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ActnList,Vcl.StdActns,
  System.ImageList, Vcl.ImgList, Vcl.PlatformDefaultStyleActnCtrls, Vcl.ActnMan, Vcl.ToolWin, Vcl.ActnCtrls,
  Vcl.ExtCtrls, GIS, GIS.Shapes, GIS.Shapes.ESRI, GIS.Render.Shapes, GIS.Render.Shapes.PixelConv;

type
  TZoomStyle = (zsNone,zsMove,zsZoomIn,zsZoomOut);
  TShapeImageStatus = (isNoShapes,isViewportUninitialized,isViewportChanged,isResized,isUpToDate);

  TMainForm = class(TForm)
    ActionToolBar1: TActionToolBar;
    ActionList: TActionList;
    ActionManager: TActionManager;
    ImageList: TImageList;
    FileOpen: TFileOpen;
    PaintBox: TPaintBox;
    CoordPanel: TPanel;
    YCoordPanel: TPanel;
    XCoordPanel: TPanel;
    ViewZoomIn: TAction;
    ViewZoomOut: TAction;
    ViewZoomAll: TAction;
    ViewMove: TAction;
    procedure FileOpenAccept(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure ViewZoomInExecute(Sender: TObject);
    procedure ViewZoomOutExecute(Sender: TObject);
    procedure ViewMoveExecute(Sender: TObject);
    procedure ViewZoomAllExecute(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure PaintBoxMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure PaintBoxMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure PaintBoxMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure PaintBoxPaint(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
  private
    Const
      // Cursors
      crZoomIn = 1;
      crZoomOut = 2;
    Var
      ZoomStyle: TZoomStyle;
      ShapesImage: TBitmap;
      Margin: Integer;
      MousePosition,StartPosition: TPoint;
      MouseCoordinate: TCoordinate;
      MouseDown: Boolean;
      PixelConverter: TPixelConverter;
      ShapesLayer: TCustomShapesLayer;
      ShapesImageStatus: TShapeImageStatus;
    Procedure OpenShapeFile(const FileName: String);
    procedure WMDropFiles(var msg : TWMDropFiles); message WM_DROPFILES;
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

procedure TMainForm.WMDropFiles(var msg : TWMDropFiles);
const
  MaxFileName = 255;
var
  FileName: array [0..MaxFileName] of char;
begin
  DragQueryFile(msg.Drop,0,FileName,MaxFileName) ;
  OpenShapeFile(FileName);
  DragFinish(msg.Drop) ;
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

procedure TMainForm.FormCreate(Sender: TObject);
begin
  DragAcceptFiles(Handle,true);
  Screen.Cursors[crZoomIn] := LoadCursor(HInstance,'ZOOM_IN');
  Screen.Cursors[crZoomOut] := LoadCursor(HInstance,'ZOOM_OUT');
  ShapesImage := TBitmap.Create;
  PixelConverter := TPixelConverter.Create;
  ShapesImageStatus := isNoShapes;
end;

procedure TMainForm.FormResize(Sender: TObject);
begin
  if ShapesImageStatus <> isNoShapes then
  begin
    ShapesImageStatus := isResized;
    PaintBox.Invalidate;
  end;
end;

procedure TMainForm.ViewZoomInExecute(Sender: TObject);
begin
  MouseDown := false;
  ViewZoomIn.Checked := not ViewZoomIn.Checked;
  if ViewZoomIn.Checked then
  begin
    ZoomStyle := zsZoomIn;
    PaintBox.Cursor := crZoomIn;
  end else
  begin
    ZoomStyle := zsNone;
    PaintBox.Cursor := crArrow;
  end;
end;

procedure TMainForm.ViewZoomOutExecute(Sender: TObject);
begin
  MouseDown := false;
  ViewZoomOut.Checked := not ViewZoomOut.Checked;
  if ViewZoomOut.Checked then
  begin
    ZoomStyle := zsZoomOut;
    PaintBox.Cursor := crZoomOut;
  end else
  begin
    ZoomStyle := zsNone;
    PaintBox.Cursor := crArrow;
  end;
end;

procedure TMainForm.ViewMoveExecute(Sender: TObject);
begin
  MouseDown := false;
  ViewMove.Checked := not ViewMove.Checked;
  if ViewMove.Checked then
  begin
    ZoomStyle := zsMove;
    PaintBox.Cursor := crDrag;
  end else
  begin
    ZoomStyle := zsNone;
    PaintBox.Cursor := crArrow;
  end;
end;

procedure TMainForm.ViewZoomAllExecute(Sender: TObject);
begin
  ShapesImageStatus := isViewportUninitialized;
  PaintBox.Invalidate;
end;

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
    PaintBox.Canvas.Pen.Mode := pmNotXor;
    PaintBox.Canvas.Pen.Style := psDot;
    PaintBox.Canvas.Rectangle(StartPosition.X,StartPosition.Y,MousePosition.X,MousePosition.Y);
  end;
  // Update coordinate panels
  MousePosition := Point(X,Y);
  MouseCoordinate := PixelConverter.PixelToCoord(MousePosition);
  XCoordPanel.Caption := Round(MouseCoordinate.X).ToString;
  YCoordPanel.Caption := Round(MouseCoordinate.Y).ToString;
  // Update paint box
  if MouseDown then
  case ZoomStyle of
    zsZoomIn: PaintBox.Canvas.Rectangle(StartPosition.X,StartPosition.Y,MousePosition.X,MousePosition.Y);
    zsMove: PaintBox.Invalidate;
  end;
end;

procedure TMainForm.PaintBoxMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
Var
  Viewport: TCoordinateRect;
begin
  if MouseDown and (ZoomStyle <> zsNone) then
  begin
    MouseDown := false;
    case ZoomStyle of
      zsMove:
        begin
          PixelConverter.Shift(StartPosition.X-MousePosition.X,StartPosition.Y-MousePosition.Y);
          ShapesImageStatus := isViewportChanged;
          PaintBox.Invalidate;
        end;
      zsZoomIn:
        begin
          if (MousePosition.X=StartPosition.X) and (MousePosition.Y=StartPosition.Y) then
            PixelConverter.SetCenter(MouseCoordinate,ShapesImage.Width,ShapesImage.Height,1.5)
          else
            begin
              Viewport.Clear;
              Viewport.Enclose(PixelConverter.PixelToCoord(StartPosition));
              Viewport.Enclose(PixelConverter.PixelToCoord(MousePosition));
              PixelConverter.Initialize(Viewport,ShapesImage.Width,ShapesImage.Height,Margin);
            end;
          ShapesImageStatus := isViewportChanged;
          PaintBox.Invalidate;
        end;
      zsZoomOut:
        begin
          var CenterX := Round((StartPosition.X + MousePosition.X)/2);
          var CenterY := Round((StartPosition.Y + MousePosition.Y)/2);
          var CenterCoord := PixelConverter.PixelToCoord(Point(CenterX,CenterY));
          PixelConverter.SetCenter(CenterCoord,ShapesImage.Width,ShapesImage.Height,0.667);
          ShapesImageStatus := isViewportChanged;
          PaintBox.Invalidate;
        end;
    end;
  end;
end;

procedure TMainForm.PaintBoxPaint(Sender: TObject);
Var
  X,Y: Integer;
begin
  if ShapesImageStatus <> isNoShapes then
  begin
    // Handle size change
    if ShapesImageStatus = isResized then
    if (ShapesImage.Width < PaintBox.ClientWidth) or (ShapesImage.Height < PaintBox.ClientHeight) then
    ShapesImageStatus := isViewportChanged;
    // Initialize viewport
    if ShapesImageStatus = isViewportUnInitialized then
    begin
      PixelConverter.Initialize(ShapesLayer.BoundingBox,PaintBox.ClientWidth,PaintBox.ClientHeight,Margin);
      ShapesImageStatus := isViewportChanged;
    end;
    // Repaint image
    if ShapesImageStatus = isViewportChanged then
    begin
      Screen.Cursor := crHourGlass;
      try
        ShapesImage.Width := PaintBox.ClientWidth;
        ShapesImage.Height := PaintBox.ClientHeight;
        ShapesImage.Canvas.Brush.Color := clWhite;
        ShapesImage.Canvas.FillRect(Rect(0,0,ShapesImage.Width,ShapesImage.Height));
        ShapesImage.Canvas.Pen.Color := clBlue;
        ShapesImage.Canvas.Brush.Color := clSkyBlue;
        ShapesLayer.DrawLayer(ShapesImage,PixelConverter);
        PaintBox.Invalidate;
      finally
        Screen.Cursor := crDefault;
      end;
    end;
    ShapesImageStatus := isUpToDate;
    // Draw image on pant box canvas
    if MouseDown and (ZoomStyle = zsMove)then
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
end;

procedure TMainForm.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  ShapesImage.Free;
  ShapesLayer.Free;
  PixelConverter.Free;
end;

Procedure TMainForm.OpenShapeFile(const FileName: String);
begin
  Screen.Cursor := crHourGlass;
  try
    // Read shapes file
    var ESRIShapesFile := TShapesLayer.Create(clMaroon);
    ESRIShapesFile.Read(FileName,TESRIShapeFileReader);
    if ESRIShapesFile.ShapeCount(stPoint) = 0 then Margin := 0 else Margin := ESRIShapesFile.PointRenderSize;
    // Show layer
    ShapesLayer.Free;
    ShapesLayer := ESRIShapesFile;
    ViewZoomAllExecute(nil);
    // Set zoom style
    ZoomStyle := zsNone;
    PaintBox.Cursor := crArrow;
    ViewZoomIn.Checked := false;
    ViewZoomOut.Checked := false;
    ViewMove.Checked := false;
  finally
    Screen.Cursor := crDefault;
  end;
end;

procedure TMainForm.FileOpenAccept(Sender: TObject);
begin
  OpenShapeFile(FileOpen.Dialog.FileName);
end;

end.

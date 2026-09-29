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
  System.Math, Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
  GISCoordSystem, GIS.Shapes, GIS.CoordConv, GIS.Render.PixelConv.Mercator, GIS.Render.Shapes;

type
  TLayerRenderingControl = Class; // Forward reference

  TLabeledShapesLayer = class(TShapesLayer)
  // Keeps the attributes read with each shape, so the polygons can be labelled
  // with their feature number or with the value of one of the attribute fields.
  public
    Const
      lsNone          = -2;
      lsFeatureNumber = -1;
  private
    FProperties:  TArray<TGISShapeProperties>;
    FFieldNames:  TArray<String>;
    FLabelSource: Integer;
    FLabels:      TArray<String>;  // label per shape when labelling by field
    Function  FieldIndex(const Properties: TGISShapeProperties; const Field: Integer): Integer;
    Procedure SetLabelSource(LabelSource: Integer);
  strict protected
    Function ShapeLabel(const Shape: Integer): String; override;
  public
    Constructor Create;
    Procedure Add(const Shape: TGISShape; const Properties: TGISShapeProperties); overload;
    Procedure Read(const FileName: String; const FileFormat: TGISShapesFormat);
  public
    // The attribute fields found in the shapes, in the order first seen
    Property FieldNames: TArray<String> read FFieldNames;
    // lsNone, lsFeatureNumber or an index into FieldNames
    Property LabelSource: Integer read FLabelSource write SetLabelSource;
  end;

  TLayer = class
  public
    Shapes:           TLabeledShapesLayer;
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
    TextColor:        TColor;
    TextSize:         Integer;  // points
    RenderingControl: TLayerRenderingControl;
    constructor Create(const AShapes: TLabeledShapesLayer; const AName: String;
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
    // The height that shows all controls, whatever height the frame has been
    // stretched to. Taken from the controls, so it follows DPI scaling.
    Function RequiredHeight: Integer; virtual;
  public
    Property OnChange: TNotifyEvent read FOnChange write FOnChange;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

{$R *.dfm}

Constructor TLabeledShapesLayer.Create;
begin
  inherited Create;
  FLabelSource := lsNone;
end;

Function TLabeledShapesLayer.FieldIndex(const Properties: TGISShapeProperties;
                                        const Field: Integer): Integer;
begin
  // Shapes from one file nearly always list their fields in the same order
  if (Field < Length(Properties)) and (Properties[Field].Key = FFieldNames[Field]) then
    Exit(Field);
  for var Prop := 0 to High(Properties) do
    if SameText(Properties[Prop].Key,FFieldNames[Field]) then Exit(Prop);
  Result := -1;
end;

Procedure TLabeledShapesLayer.Add(const Shape: TGISShape; const Properties: TGISShapeProperties);
begin
  inherited Add(Shape);
  if Length(FProperties) < Count then SetLength(FProperties,2*Count+256);
  FProperties[Count-1] := Properties;
  // GeoJSON features need not share their properties, so collect them all
  for var Prop := 0 to High(Properties) do
    if (Prop >= Length(FFieldNames)) or (Properties[Prop].Key <> FFieldNames[Prop]) then
    begin
      var Known := false;
      for var Field in FFieldNames do
        if SameText(Field,Properties[Prop].Key) then
        begin
          Known := true;
          Break;
        end;
      if not Known then FFieldNames := FFieldNames + [Properties[Prop].Key];
    end;
  FLabels := nil;  // rebuilt on the next draw
end;

Procedure TLabeledShapesLayer.Read(const FileName: String; const FileFormat: TGISShapesFormat);
var
  Shape: TGISShape;
  Properties: TGISShapeProperties;
begin
  var Reader := FileFormat.Create(FileName);
  try
    while Reader.ReadShape(Shape,Properties) do Add(Shape,Properties);
  finally
    Reader.Free;
  end;
end;

Procedure TLabeledShapesLayer.SetLabelSource(LabelSource: Integer);
begin
  if (LabelSource < lsNone) or (LabelSource >= Length(FFieldNames)) then
    LabelSource := lsNone;
  if LabelSource <> FLabelSource then
  begin
    FLabelSource := LabelSource;
    FLabels := nil;
  end;
end;

Function TLabeledShapesLayer.ShapeLabel(const Shape: Integer): String;
begin
  case FLabelSource of
    lsNone:          Result := '';
    lsFeatureNumber: Result := (Shape+1).ToString;
    else
      begin
        if FLabels = nil then
        begin
          SetLength(FLabels,Count);
          // Shapes added without properties (inherited Add) get no label
          for var Shp := 0 to Count-1 do
          if Shp < Length(FProperties) then
          begin
            var Prop := FieldIndex(FProperties[Shp],FLabelSource);
            if Prop >= 0 then
              FLabels[Shp] := VarToStr(FProperties[Shp][Prop].Value).Trim;
          end;
        end;
        Result := FLabels[Shape];
      end;
  end;
end;

////////////////////////////////////////////////////////////////////////////////

constructor TLayer.Create(const AShapes: TLabeledShapesLayer; const AName: String;
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
  TextColor   := clBlack;
  TextSize    := 9;
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

Function TLayerRenderingControl.RequiredHeight: Integer;
begin
  // Leave the same margin below the lowest visible control as above the
  // highest one
  var Upper := MaxInt;
  var Lower := 0;
  for var Ctrl := 0 to ControlCount-1 do
    if Controls[Ctrl].Visible then
    begin
      Upper := Min(Upper,Controls[Ctrl].Top);
      Lower := Max(Lower,Controls[Ctrl].BoundsRect.Bottom);
    end;
  if Upper = MaxInt then Result := Height else Result := Lower + Upper;
end;

end.

unit GISFileFormat;

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
  SysUtils,
  Vcl.Graphics, Vcl.Forms, Vcl.StdCtrls, Vcl.Controls,
  GISCoordSystem, RndrCtrl,
  GIS.Shapes, GIS.Shapes.ESRI, GIS.Shapes.GeoJSON, GIS.Shapes.Geopackage,
  GIS.Render.Shapes, GIS.Render.PixelConv.Mercator;

type
  TGISFileFormat = class
  protected
    // Presents a CRS selection dialog using the supplied systems. These may
    // include an unknown one, for a file to be drawn without its CRS.
    // Returns nil if the user cancels.
    Function SelectCoordSystem(const ACoordSystems: TArray<TGISCoordinateSystem>): TGISCoordinateSystem;
  public
    Function Name: String; virtual; abstract;
    Function Extensions: TArray<String>; virtual; abstract;
    // One filter entry suitable for TOpenDialog.Filter, e.g. 'ESRI Shapefile|*.shp'
    Function DialogFilter: String; virtual;
    // Returns true if this format handles the given file extension.
    Function Handles(const AExtension: String): Boolean; virtual;
    // Opens the file, showing any necessary dialogs.
    // Returns an empty array when the user cancels.
    Function OpenFile(const AFileName: String;
                      const ACoordSystems: TArray<TGISCoordinateSystem>;
                      const APrimary: TWebMercatorPixelConverter): TArray<TLayer>; virtual; abstract;
    // Write support
    Function CanWrite: Boolean; virtual;
    Function MultiLayerSupport: Boolean; virtual;
    Procedure SaveLayer(const AFileName: String; const ALayer: TLayer); virtual;
    Procedure SaveLayers(const AFileName: String; const ALayers: TArray<TLayer>); virtual;
  end;

  TESRIFileFormat = class(TGISFileFormat)
  public
    Function Name: String; override;
    Function Extensions: TArray<String>; override;
    Function OpenFile(const AFileName: String;
                      const ACoordSystems: TArray<TGISCoordinateSystem>;
                      const APrimary: TWebMercatorPixelConverter): TArray<TLayer>; override;
    Function CanWrite: Boolean; override;
    Procedure SaveLayer(const AFileName: String; const ALayer: TLayer); override;
  end;

  TGeoJSONFileFormat = class(TGISFileFormat)
  public
    Function Name: String; override;
    Function Extensions: TArray<String>; override;
    Function OpenFile(const AFileName: String;
                      const ACoordSystems: TArray<TGISCoordinateSystem>;
                      const APrimary: TWebMercatorPixelConverter): TArray<TLayer>; override;
    Function CanWrite: Boolean; override;
    Procedure SaveLayer(const AFileName: String; const ALayer: TLayer); override;
  end;

  TGeoPackageFileFormat = class(TGISFileFormat)
  private
    Function SelectLayer(const AFileName: String;
                         const ACoordSystems: TArray<TGISCoordinateSystem>;
                         out ALayerName: String;
                         out ACoordSystem: TGISCoordinateSystem): Boolean;
    // Writes the layer's shapes as a layer of the package, named after the layer without its
    // file prefix, or after the file when the layer has no name
    Procedure WriteLayer(const AWriter: TGeopackageWriter;
                         const ALayer: TLayer;
                         const AFileName: String);
  public
    Function Name: String; override;
    Function Extensions: TArray<String>; override;
    Function OpenFile(const AFileName: String;
                      const ACoordSystems: TArray<TGISCoordinateSystem>;
                      const APrimary: TWebMercatorPixelConverter): TArray<TLayer>; override;
    Function CanWrite: Boolean; override;
    Function MultiLayerSupport: Boolean; override;
    Procedure SaveLayer(const AFileName: String; const ALayer: TLayer); override;
    Procedure SaveLayers(const AFileName: String; const ALayers: TArray<TLayer>); override;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Function TGISFileFormat.DialogFilter: String;
var
  ExtStr: String;
begin
  ExtStr := '';
  for var Ext in Extensions do
  begin
    if ExtStr <> '' then ExtStr := ExtStr + ';';
    ExtStr := ExtStr + '*' + Ext;
  end;
  Result := Name + '|' + ExtStr;
end;

Function TGISFileFormat.Handles(const AExtension: String): Boolean;
begin
  for var Ext in Extensions do
    if SameText(Ext, AExtension) then
      Exit(True);
  Result := False;
end;

Function TGISFileFormat.SelectCoordSystem(const ACoordSystems: TArray<TGISCoordinateSystem>): TGISCoordinateSystem;
var
  Dialog: TForm;
  Prompt: TLabel;
  Combo: TComboBox;
  OKBtn, CancelBtn: TButton;
begin
  Result := nil;
  Dialog := TForm.CreateNew(Application);
  try
    Dialog.Caption     := 'Coordinate System';
    Dialog.ClientWidth := 296;
    Dialog.ClientHeight := 104;
    Dialog.Position    := poOwnerFormCenter;
    Dialog.BorderStyle := bsDialog;
    Prompt := TLabel.Create(Dialog);
    Prompt.Parent := Dialog;
    Prompt.SetBounds(8, 8, 280, 20);
    Prompt.Caption := 'Select the coordinate system of this file:';
    Combo := TComboBox.Create(Dialog);
    Combo.Parent := Dialog;
    Combo.SetBounds(8, 30, 280, 22);
    Combo.Style := csDropDownList;
    for var CS in ACoordSystems do
      Combo.Items.Add(CS.Description);
    Combo.ItemIndex := 0;
    OKBtn := TButton.Create(Dialog);
    OKBtn.Parent      := Dialog;
    OKBtn.SetBounds(130, 70, 75, 26);
    OKBtn.Caption     := 'OK';
    OKBtn.ModalResult := mrOk;
    OKBtn.Default     := True;
    CancelBtn := TButton.Create(Dialog);
    CancelBtn.Parent      := Dialog;
    CancelBtn.SetBounds(212, 70, 75, 26);
    CancelBtn.Caption     := 'Cancel';
    CancelBtn.ModalResult := mrCancel;
    if Dialog.ShowModal = mrOk then
    begin
      Result := ACoordSystems[Combo.ItemIndex];
      Result.Configure;
    end;
  finally
    Dialog.Free;
  end;
end;

Function TGISFileFormat.CanWrite: Boolean;
begin
  Result := False;
end;

Function TGISFileFormat.MultiLayerSupport: Boolean;
begin
  Result := False;
end;

Procedure TGISFileFormat.SaveLayer(const AFileName: String; const ALayer: TLayer);
begin
  raise Exception.CreateFmt('%s does not support writing', [Name]);
end;

Procedure TGISFileFormat.SaveLayers(const AFileName: String; const ALayers: TArray<TLayer>);
begin
  raise Exception.CreateFmt('%s does not support multi-layer writing', [Name]);
end;

////////////////////////////////////////////////////////////////////////////////

Function TESRIFileFormat.Name: String;
begin
  Result := 'ESRI Shapefile';
end;

Function TESRIFileFormat.Extensions: TArray<String>;
begin
  Result := ['.shp'];
end;

Function TESRIFileFormat.OpenFile(const AFileName: String;
                                  const ACoordSystems: TArray<TGISCoordinateSystem>;
                                  const APrimary: TWebMercatorPixelConverter): TArray<TLayer>;
var
  CS: TGISCoordinateSystem;
  Shapes: TLabeledShapesLayer;
begin
  SetLength(Result, 0);
  CS := SelectCoordSystem(ACoordSystems);
  if CS = nil then Exit;
  Shapes := TLabeledShapesLayer.Create;
  Shapes.Read(AFileName, TESRIShapeFileReader);
  SetLength(Result, 1);
  Result[0] := TLayer.Create(Shapes, ExtractFileName(AFileName), CS, 160, APrimary);
end;

Function TESRIFileFormat.CanWrite: Boolean;
begin
  Result := True;
end;

Procedure TESRIFileFormat.SaveLayer(const AFileName: String; const ALayer: TLayer);
var
  I: Integer;
  Shape: TGISShape;
  Parts: TMultiPoints;
begin
  // Determine dominant shape type
  var Shapes := ALayer.Shapes;
  var ST := stEmpty;
  if Shapes.ShapeCount(stPolygon) > 0 then ST := stPolygon
  else if Shapes.ShapeCount(stLine) > 0 then ST := stLine
  else if Shapes.ShapeCount(stPoint) > 0 then ST := stPoint;
  case ST of
    stPoint:
      begin
        var W := TESRIPointShapeFileWriter.Create(AFileName, []);
        try
          for I := 0 to Shapes.Count - 1 do
          begin
            Shape := Shapes[I];
            if Shape.ShapeType = stPoint then
              W.Write(Shape[0, 0], []);
          end;
        finally
          W.Free;
        end;
      end;
    stLine:
      begin
        var W := TESRIPolyLineShapeFileWriter.Create(AFileName, []);
        try
          for I := 0 to Shapes.Count - 1 do
          begin
            Shape := Shapes[I];
            if Shape.ShapeType = stLine then
            begin
              SetLength(Parts, Shape.Count);
              for var J := 0 to Shape.Count - 1 do
                Parts[J] := Shape.Parts[J].AsMultiPoint;
              W.Write(Parts, []);
            end;
          end;
        finally
          W.Free;
        end;
      end;
    stPolygon:
      begin
        var W := TESRIPolygonShapeFileWriter.Create(AFileName, []);
        try
          for I := 0 to Shapes.Count - 1 do
          begin
            Shape := Shapes[I];
            if Shape.ShapeType = stPolygon then
            begin
              SetLength(Parts, Shape.Count);
              for var J := 0 to Shape.Count - 1 do
                Parts[J] := Shape.Parts[J].AsMultiPoint;
              W.Write(Parts, []);
            end;
          end;
        finally
          W.Free;
        end;
      end;
  end;
end;

////////////////////////////////////////////////////////////////////////////////

Function TGeoJSONFileFormat.Name: String;
begin
  Result := 'GeoJSON';
end;

Function TGeoJSONFileFormat.Extensions: TArray<String>;
begin
  Result := ['.geojson'];
end;

Function TGeoJSONFileFormat.OpenFile(const AFileName: String;
                                     const ACoordSystems: TArray<TGISCoordinateSystem>;
                                     const APrimary: TWebMercatorPixelConverter): TArray<TLayer>;
var
  CS: TGISCoordinateSystem;
  Shapes: TLabeledShapesLayer;
begin
  SetLength(Result, 0);
  CS := SelectCoordSystem(ACoordSystems);
  if CS = nil then Exit;
  Shapes := TLabeledShapesLayer.Create;
  Shapes.Read(AFileName, TGeoJSONReader);
  SetLength(Result, 1);
  Result[0] := TLayer.Create(Shapes, ExtractFileName(AFileName), CS, 160, APrimary);
end;

Function TGeoJSONFileFormat.CanWrite: Boolean;
begin
  Result := True;
end;

Procedure TGeoJSONFileFormat.SaveLayer(const AFileName: String; const ALayer: TLayer);
var
  I: Integer;
begin
  var Writer := TGeoJSONWriter.Create(AFileName);
  try
    for I := 0 to ALayer.Shapes.Count - 1 do
      Writer.WriteShape(ALayer.Shapes[I]);
  finally
    Writer.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////

Function TGeoPackageFileFormat.SelectLayer(const AFileName: String;
                                           const ACoordSystems: TArray<TGISCoordinateSystem>;
                                           out ALayerName: String;
                                           out ACoordSystem: TGISCoordinateSystem): Boolean;
var
  Pkg: TGeopackage;
  Dialog: TForm;
  LayerLbl, CRSLbl: TLabel;
  LayerCombo, CRSCombo: TComboBox;
  OKBtn, CancelBtn: TButton;
begin
  Result := False;
  Pkg := TGeopackage.Create(AFileName);
  try
    var Names := Pkg.LayerNames;
    if Length(Names) = 0 then
      raise Exception.Create('GeoPackage contains no feature layers.');
    Dialog := TForm.CreateNew(Application);
    try
      Dialog.Caption      := 'Open GeoPackage Layer';
      Dialog.ClientWidth  := 296;
      Dialog.ClientHeight := 130;
      Dialog.Position     := poOwnerFormCenter;
      Dialog.BorderStyle  := bsDialog;
      LayerLbl := TLabel.Create(Dialog);
      LayerLbl.Parent := Dialog;
      LayerLbl.SetBounds(8, 8, 280, 16);
      LayerLbl.Caption := 'Layer:';
      LayerCombo := TComboBox.Create(Dialog);
      LayerCombo.Parent := Dialog;
      LayerCombo.SetBounds(8, 26, 280, 22);
      LayerCombo.Style := csDropDownList;
      for var N in Names do
        LayerCombo.Items.Add(N);
      LayerCombo.ItemIndex := 0;
      CRSLbl := TLabel.Create(Dialog);
      CRSLbl.Parent := Dialog;
      CRSLbl.SetBounds(8, 56, 280, 16);
      CRSLbl.Caption := 'Coordinate system:';
      CRSCombo := TComboBox.Create(Dialog);
      CRSCombo.Parent := Dialog;
      CRSCombo.SetBounds(8, 74, 280, 22);
      CRSCombo.Style := csDropDownList;
      for var CS in ACoordSystems do
        CRSCombo.Items.Add(CS.Description);
      CRSCombo.ItemIndex := 0;
      OKBtn := TButton.Create(Dialog);
      OKBtn.Parent      := Dialog;
      OKBtn.SetBounds(130, 100, 75, 26);
      OKBtn.Caption     := 'OK';
      OKBtn.ModalResult := mrOk;
      OKBtn.Default     := True;
      CancelBtn := TButton.Create(Dialog);
      CancelBtn.Parent      := Dialog;
      CancelBtn.SetBounds(212, 100, 75, 26);
      CancelBtn.Caption     := 'Cancel';
      CancelBtn.ModalResult := mrCancel;
      if Dialog.ShowModal = mrOk then
      begin
        ALayerName   := LayerCombo.Text;
        ACoordSystem := ACoordSystems[CRSCombo.ItemIndex];
        var Reader := Pkg.CreateReader(ALayerName);
        try
          ACoordSystem.HintSRID(Reader.SRID);
        finally
          Reader.Free;
        end;
        ACoordSystem.Configure;
        Result := True;
      end;
    finally
      Dialog.Free;
    end;
  finally
    Pkg.Free;
  end;
end;

Function TGeoPackageFileFormat.Name: String;
begin
  Result := 'GeoPackage';
end;

Function TGeoPackageFileFormat.Extensions: TArray<String>;
begin
  Result := ['.gpkg'];
end;

Function TGeoPackageFileFormat.OpenFile(const AFileName: String;
                                        const ACoordSystems: TArray<TGISCoordinateSystem>;
                                        const APrimary: TWebMercatorPixelConverter): TArray<TLayer>;
var
  LayerName: String;
  CS: TGISCoordinateSystem;
  Pkg: TGeopackage;
  Reader: TGeopackageReader;
  Shapes: TLabeledShapesLayer;
  Shape: TGISShape;
  Props: TGISShapeProperties;
begin
  SetLength(Result, 0);
  if not SelectLayer(AFileName, ACoordSystems, LayerName, CS) then Exit;
  Pkg := TGeopackage.Create(AFileName);
  try
    Reader := Pkg.CreateReader(LayerName);
    try
      Shapes := TLabeledShapesLayer.Create;
      while Reader.ReadShape(Shape, Props) do
        Shapes.Add(Shape, Props);
      SetLength(Result, 1);
      Result[0] := TLayer.Create(
        Shapes,
        ExtractFileName(AFileName) + ' / ' + LayerName,
        CS, 160, APrimary);
    finally
      Reader.Free;
    end;
  finally
    Pkg.Free;
  end;
end;

Function TGeoPackageFileFormat.CanWrite: Boolean;
begin
  Result := True;
end;

Function TGeoPackageFileFormat.MultiLayerSupport: Boolean;
begin
  Result := True;
end;

Procedure TGeoPackageFileFormat.WriteLayer(const AWriter: TGeopackageWriter;
                                           const ALayer: TLayer;
                                           const AFileName: String);
var
  LayerName: String;
begin
  // Strip any "file / layername" prefix carried in the layer name
  var P := Pos(' / ', ALayer.Name);
  if P > 0 then
    LayerName := Copy(ALayer.Name, P + 3, MaxInt)
  else
    LayerName := ALayer.Name;
  if LayerName = '' then
    LayerName := ChangeFileExt(ExtractFileName(AFileName), '');
  // The layer writer reads the coordinate system off the converter without taking it over
  var Converter := ALayer.CoordSystem.CreateConverter;
  try
    var LW := AWriter.CreateLayerWriter(LayerName, Converter);
    try
      for var I := 0 to ALayer.Shapes.Count - 1 do
        LW.WriteShape(ALayer.Shapes[I], nil);
    finally
      LW.Free;
    end;
  finally
    Converter.Free;
  end;
end;

Procedure TGeoPackageFileFormat.SaveLayer(const AFileName: String;
                                          const ALayer: TLayer);
begin
  var Pkg := TGeopackage.Create(AFileName, gpReadWrite);
  try
    var Writer := Pkg.CreateWriter;
    try
      WriteLayer(Writer, ALayer, AFileName);
    finally
      Writer.Free;
    end;
  finally
    Pkg.Free;
  end;
end;

Procedure TGeoPackageFileFormat.SaveLayers(const AFileName: String;
                                           const ALayers: TArray<TLayer>);
begin
  var Pkg := TGeopackage.Create(AFileName, gpReadWrite);
  try
    var Writer := Pkg.CreateWriter;
    try
      for var Layer in ALayers do WriteLayer(Writer, Layer, AFileName);
    finally
      Writer.Free;
    end;
  finally
    Pkg.Free;
  end;
end;

end.

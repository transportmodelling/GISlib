unit GIS.Shapes.Geopackage;

////////////////////////////////////////////////////////////////////////////////
//
// Author: Jaap Baak
// https://github.com/transportmodelling/GISlib
//
// Requires FireDAC with the SQLite driver (FireDAC.Phys.SQLite).
// Ensure SQLite3.dll is present alongside the executable.
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
interface
////////////////////////////////////////////////////////////////////////////////

uses
  SysUtils, Classes, Variants,
  Generics.Collections,
  GIS, GIS.Shapes, GIS.CoordConv,
  FireDAC.Stan.Def,
  FireDAC.Stan.Async,
  FireDAC.DApt,
  FireDAC.Comp.Client,
  FireDAC.Phys.SQLite,
  Data.DB;

type
  // Forward declarations
  TGeopackageReader = class;
  TGeopackageWriter = class;

  TGeopackageMode = (gpRead, gpReadWrite);

  TGeopackage = class
  // Represents an open GeoPackage file.
  // Holds the shared database connection; call CreateReader / CreateWriter.
  private
    FConnection: TFDConnection;
    FFileName: TFileName;
    FMode: TGeopackageMode;
  public
    Constructor Create(const FileName: TFileName; Mode: TGeopackageMode = gpRead);
    Function LayerNames: TArray<String>;
    Function CreateReader(const LayerName: String): TGeopackageReader;
    Function CreateWriter: TGeopackageWriter;
    Destructor  Destroy; override;
  public
    Property FileName: TFileName read FFileName;
    Property Mode: TGeopackageMode read FMode;
    Property Connection: TFDConnection read FConnection;
  end;

  TGeopackageReader = class(TGISShapesReader)
  // Reads TGISShape objects one at a time from a GeoPackage feature layer.
  // Multi-geometry rows (MultiPolygon etc.) produce one shape per sub-geometry.
  // Create via TGeopackage.CreateReader rather than directly.
  private
    FConnection: TFDConnection; // not owned — belongs to TGeopackage
    FQuery: TFDQuery;
    FGeomColumnName: String;
    FBuffer: TList<TGISShape>; // sub-shapes waiting to be returned
    FBufferProps: TGISShapeProperties; // properties shared by buffered shapes
    Function  FindGeomColumn(const LayerName: String): String;
    Procedure OpenQuery(const LayerName: String);
    // GeoPackage geometry blob → list of TGISShape
    Function  ParseBlob(const Bytes: TBytes; ShapeList: TList<TGISShape>): Boolean;
    // WKB parser — appends one or more shapes to ShapeList (recursive for multi-types)
    Procedure ReadWKB(const B: TBytes; var P: Integer; ShapeList: TList<TGISShape>);
    Procedure ReadRing(const B: TBytes; var P: Integer; ByteOrder: Byte; HasZ,HasM: Boolean; out Ring: TMultiPoint);
    Procedure ReadCoord(const B: TBytes; var P: Integer; ByteOrder: Byte; HasZ,HasM: Boolean; out X, Y: Double);
    Function  ReadInt32(const B: TBytes; var P: Integer; ByteOrder: Byte): Int32;
    Function  ReadF64  (const B: TBytes; var P: Integer; ByteOrder: Byte): Double;
    Procedure DecodeGeomType(GeomType: Integer; out BaseType: Integer; out HasZ,HasM: Boolean);
  public
    Constructor Create(Connection: TFDConnection; const LayerName: String); reintroduce;
    Function ReadShape(out Shape: TGISShape; out Properties: TGISShapeProperties): Boolean; override;
    Destructor Destroy; override;
  end;

  TGeopackageLayerWriter = class
  // Writes TGISShape objects to a single feature layer in a GeoPackage file.
  // Create via TGeopackageWriter.CreateLayerWriter.
  private
    Class procedure WriteByte  (Stream: TStream; Value: Byte);   static;
    Class procedure WriteInt32LE(Stream: TStream; Value: Int32); static;
    Class procedure WriteF64LE (Stream: TStream; Value: Double); static;
    Class procedure WriteRing  (Stream: TStream; const Part: TShapePart); static;
  private
    FConnection: TFDConnection;  // not owned — belongs to TGeopackageWriter
    FLayerName: String;
    FSRID: Integer;
    FPropNames: TArray<String>;
    FQuery: TFDQuery;
    Function ShapeToBlob(const Shape: TGISShape): TBytes;
  public
    Constructor Create(const Connection: TFDConnection; const LayerName: String;
                       const SRID: Integer; const PropNames: TArray<String>);
    Procedure WriteShape(const Shape: TGISShape; const Properties: TGISShapeProperties);
    Destructor Destroy; override;
  end;

  TGeopackageWriter = class
  // Adds feature layers to a GeoPackage opened in gpReadWrite mode.
  // Create via TGeopackage.CreateWriter.
  private
    FPackage: TGeopackage;  // not owned
    FConnection: TFDConnection;
    Procedure ExecSQL(const SQL: String);
    Procedure InitSchema;
    Procedure InsertSRS(SRSID: Integer; const Name,OrgName,Definition: String);
  public
    Constructor Create(Package: TGeopackage);
    // Add a new feature layer; PropNames lists extra attribute columns (TEXT).
    Function CreateLayerWriter(const LayerName: String; const SRID: Integer;
                               const PropNames: TArray<String>): TGeopackageLayerWriter; overload;
    Function CreateLayerWriter(const LayerName: String; const SRID: Integer): TGeopackageLayerWriter; overload;
    // Overload that reads SRID and WKT definition directly from the converter.
    Function CreateLayerWriter(const LayerName: String; const Converter: TCoordinateConverter): TGeopackageLayerWriter; overload;
  public
    property Package: TGeopackage read FPackage;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

const
  // GeoPackage envelope sizes in bytes, indexed by envelope indicator (bits 1–3
  // of the flags byte): 0=none, 1=XY(32), 2=XYZ(48), 3=XYM(48), 4=XYZM(64).
  GpkgEnvSize: array[0..4] of Integer = (0, 32, 48, 48, 64);

Constructor TGeopackage.Create(const FileName: TFileName; Mode: TGeopackageMode = gpRead);
begin
  inherited Create;
  FFileName := FileName;
  FMode := Mode;
  FConnection := TFDConnection.Create(nil);
  FConnection.DriverName := 'SQLite';
  FConnection.Params.Values['Database'] := FileName;
  if Mode = gpReadWrite then
    FConnection.Params.Values['OpenMode'] := 'CreateUTF8'
  else
    FConnection.Params.Values['OpenMode'] := 'ReadOnly';
  FConnection.Connected := True;
end;

Function TGeopackage.LayerNames: TArray<String>;
// Names of all feature layers in the file (from gpkg_contents).
begin
  var Query := TFDQuery.Create(nil);
  try
    Result := nil;
    Query.Connection := FConnection;
    Query.SQL.Text   :=
      'SELECT table_name FROM gpkg_contents ' +
      'WHERE data_type = ''features'' ORDER BY table_name';
    Query.Open;
    while not Query.Eof do
    begin
      Result := result + [Query.Fields[0].AsString];
      Query.Next;
    end;
  finally
    Query.Free;
  end;
end;

Function TGeopackage.CreateReader(const LayerName: String): TGeopackageReader;
// Create a reader for the named feature layer.
begin
  Result := TGeopackageReader.Create(FConnection,LayerName);
end;

Function TGeopackage.CreateWriter: TGeopackageWriter;
// Create a writer (requires gpReadWrite mode).
begin
  if FMode = gpReadWrite then
    Result := TGeopackageWriter.Create(Self)
  else
    raise Exception.Create('TGeopackage: CreateWriter requires gpReadWrite mode')
end;

Destructor TGeopackage.Destroy;
begin
  FConnection.Free;
  inherited Destroy;
end;

////////////////////////////////////////////////////////////////////////////////

Constructor TGeopackageReader.Create(Connection: TFDConnection; const LayerName: String);
begin
  inherited Create(LayerName); // stores layer name as FileName in base class
  FConnection := Connection;
  FBuffer := TList<TGISShape>.Create;
  FGeomColumnName := FindGeomColumn(LayerName);
  OpenQuery(LayerName);
end;

Function TGeopackageReader.FindGeomColumn(const LayerName: String): String;
begin
  var Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text   :=
      'SELECT column_name FROM gpkg_geometry_columns WHERE table_name = :t';
    Query.ParamByName('t').AsString := LayerName;
    Query.Open;
    if not Query.IsEmpty then
      Result := Query.Fields[0].AsString
    else
      raise Exception.CreateFmt('GeoPackage: no geometry column found for layer ''%s''', [LayerName]);
  finally
    Query.Free;
  end;
end;

Procedure TGeopackageReader.OpenQuery(const LayerName: String);
Var
  ColList: String;
begin
  // Build a column list where the geometry column is explicitly CAST AS BLOB.
  // Without this, FireDAC maps it as varchar (max 32767 bytes) causing an
  // overflow for any geometry larger than ~32 KB.
  var PragmaQuery := TFDQuery.Create(nil);
  try
    ColList := '';
    PragmaQuery.Connection := FConnection;
    PragmaQuery.SQL.Text := 'PRAGMA table_info(' + LayerName + ')';
    PragmaQuery.Open;
    while not PragmaQuery.Eof do
    begin
      if ColList <> '' then ColList := ColList + ', ';
      var ColName := PragmaQuery.FieldByName('name').AsString;
      if SameText(ColName,FGeomColumnName) then
        ColList := ColList + 'CAST(' + ColName + ' AS BLOB) AS ' + ColName
      else
        ColList := ColList + ColName;
      PragmaQuery.Next;
    end;
  finally
    PragmaQuery.Free;
  end;
  // Open the Query
  FQuery := TFDQuery.Create(nil);
  FQuery.Connection := FConnection;
  FQuery.SQL.Text := 'SELECT ' + ColList + ' FROM ' + LayerName;
  FQuery.Open;
end;

Function TGeopackageReader.ReadInt32(const B: TBytes; var P: Integer; ByteOrder: Byte): Int32;
begin
  if ByteOrder = 1 then
    // little-endian
    Result := Int32(B[P]) or (Int32(B[P+1]) shl 8) or (Int32(B[P+2]) shl 16) or (Int32(B[P+3]) shl 24)
  else
    // big-endian
    Result := (Int32(B[P]) shl 24) or (Int32(B[P+1]) shl 16) or (Int32(B[P+2]) shl 8) or Int32(B[P+3]);
  Inc(P, 4);
end;

Function TGeopackageReader.ReadF64(const B: TBytes; var P: Integer; ByteOrder: Byte): Double;
Var
  V: UInt64;
begin
  if ByteOrder = 1 then
    // little-endian
    V := UInt64(B[P]) or (UInt64(B[P+1]) shl 8)  or (UInt64(B[P+2]) shl 16) or (UInt64(B[P+3]) shl 24) or
         (UInt64(B[P+4]) shl 32) or (UInt64(B[P+5]) shl 40) or (UInt64(B[P+6]) shl 48) or (UInt64(B[P+7]) shl 56)
  else
    // big-endian
    V := (UInt64(B[P])   shl 56) or (UInt64(B[P+1]) shl 48) or (UInt64(B[P+2]) shl 40) or (UInt64(B[P+3]) shl 32) or
         (UInt64(B[P+4]) shl 24) or (UInt64(B[P+5]) shl 16) or (UInt64(B[P+6]) shl 8)  or  UInt64(B[P+7]);
  Move(V, Result,8);
  Inc(P,8);
end;

Procedure TGeopackageReader.ReadCoord(const B: TBytes; var P: Integer; ByteOrder: Byte; HasZ,HasM: Boolean; out X,Y: Double);
begin
  X := ReadF64(B,P,ByteOrder);
  Y := ReadF64(B,P,ByteOrder);
  if HasZ then ReadF64(B,P,ByteOrder);  // discard Z
  if HasM then ReadF64(B,P,ByteOrder);  // discard M
end;

Procedure TGeopackageReader.ReadRing(const B: TBytes; var P: Integer; ByteOrder: Byte; HasZ,HasM: Boolean; out Ring: TMultiPoint);
Var
  X, Y: Double;
begin
  SetLength(Ring,ReadInt32(B,P,ByteOrder));
  for var Point := low(Ring) to high(Ring) do
  begin
    ReadCoord(B,P,ByteOrder,HasZ,HasM,X,Y);
    Ring[Point] := TCoordinate.Create(X, Y);
  end;
end;

Procedure TGeopackageReader.DecodeGeomType(GeomType: Integer; out BaseType: Integer; out HasZ,HasM: Boolean);
begin
  HasZ := false;
  HasM := false;
  if (GeomType >= 3001) and (GeomType <= 3007) then
  begin
    HasZ := true;
    HasM := true;
    BaseType := GeomType-3000;
  end else
  if (GeomType >= 2001) and (GeomType <= 2007) then
  begin
    HasM := true;
    BaseType := GeomType-2000;
  end else
  if (GeomType >= 1001) and (GeomType <= 1007) then
  begin
    HasZ := true;
    BaseType := GeomType-1000;
  end else
    BaseType := GeomType;
end;

Procedure TGeopackageReader.ReadWKB(const B: TBytes; var P: Integer; ShapeList: TList<TGISShape>);
Var
  BaseType,SubGeomType,SubBaseType: Integer;
  HasZ,HasM,SubHasZ,SubHasM: Boolean;
  Ring: TMultiPoint;
  Lines: TMultiPoints;
  Parts: array of TShapePart;
  Shape: TGISShape;
  X,Y: Double;
begin
  if P < Length(B) then
  begin
    var ByteOrder := B[P]; Inc(P);
    var GeomType  := ReadInt32(B,P,ByteOrder);
    DecodeGeomType(GeomType,BaseType,HasZ,HasM);
    case BaseType of
      1: begin
           // Point
           ReadCoord(B,P,ByteOrder,HasZ,HasM,X,Y);
           Shape.AssignPoint(X,Y);
           ShapeList.Add(Shape);
         end;

      2: begin
           // LineString
           ReadRing(B,P,ByteOrder,HasZ,HasM,Ring);
           Shape.AssignLine(Ring);
           ShapeList.Add(Shape);
         end;
      3: begin
           // Polygon — exterior ring + optional holes
           var NRings := ReadInt32(B,P,ByteOrder);
           if NRings > 0 then
           begin
             SetLength(Parts,NRings);
             for var Part := 0 to NRings-1 do
             begin
               ReadRing(B,P,ByteOrder,HasZ,HasM,Ring);
               Parts[Part] := TShapePart.Create(Ring,true);
             end;
             if NRings = 1 then
               Shape.AssignPolygon(Parts[0].AsMultiPoint)
             else
               Shape.AssignPolyPolygon(Parts);
             ShapeList.Add(Shape);
           end;
         end;
      4: begin
           // MultiPoint — one shape per point
           var NParts := ReadInt32(B,P,ByteOrder);
           for var Part := 0 to NParts-1 do ReadWKB(B,P,ShapeList);
         end;
      5: begin
           // MultiLineString — all segments combined into one polyline
           var NParts := ReadInt32(B,P,ByteOrder);
           SetLength(Lines,NParts);
           for var Part := 0 to NParts - 1 do
           begin
             var SubByteOrder := B[P];
             Inc(P);
             SubGeomType := ReadInt32(B,P,SubByteOrder);
             DecodeGeomType(SubGeomType,SubBaseType,SubHasZ,SubHasM);
             ReadRing(B,P,SubByteOrder,SubHasZ,SubHasM,Ring);
             Lines[Part] := Ring;  // TArray<TCoordinate> → TMultiPoint (assignment-compatible)
           end;
           Shape.AssignPolyLine(Lines);
           ShapeList.Add(Shape);
         end;
      6: begin
           // MultiPolygon — all rings combined into one shape
           var NParts  := ReadInt32(B,P,ByteOrder);
           var TotalRings := 0;
           SetLength(Parts,0);
           for var Part := 0 to NParts - 1 do
           begin
             var SubByteOrder := B[P];
             Inc(P);
             SubGeomType := ReadInt32(B,P,SubByteOrder);
             DecodeGeomType(SubGeomType,SubBaseType,SubHasZ,SubHasM);
             if SubBaseType = 3 then
             begin
               var NumSubRings := ReadInt32(B,P,SubByteOrder);
               SetLength(Parts,TotalRings+NumSubRings);
               for var SubRing := 0 to NumSubRings - 1 do
               begin
                 ReadRing(B, P, SubByteOrder, SubHasZ, SubHasM, Ring);
                 Parts[TotalRings+SubRing] := TShapePart.Create(Ring, True);
               end;
               Inc(TotalRings,NumSubRings);
             end;
           end;
           if TotalRings = 1 then
             Shape.AssignPolygon(Parts[0].AsMultiPoint)
           else
             if TotalRings > 1 then Shape.AssignPolyPolygon(Parts);
           if TotalRings > 0 then ShapeList.Add(Shape);
         end;
      7: begin
           // GeometryCollection — each sub-geometry as its own shape
           var NParts := ReadInt32(B,P,ByteOrder);
           for var Part := 0 to NParts - 1 do ReadWKB(B,P,ShapeList);
         end;
    end;
  end;
end;

Function TGeopackageReader.ParseBlob(const Bytes: TBytes; ShapeList: TList<TGISShape>): Boolean;
var
  WkbOffset: Integer;
begin
  Result := false;
  if Length(Bytes) >= 8 then
  if (Bytes[0] = $47) and (Bytes[1] = $50) then // magic 'GP'
  begin
    var Flags := Bytes[3];
    if Flags and $10 = 0 then
    begin
      var EnvType := (Flags shr 1) and $07;
      if EnvType > 4 then EnvType := 0;
      // Header layout: 2 magic + 1 version + 1 flags + 4 SRID = 8 bytes, then envelope
      WkbOffset := 8 + GpkgEnvSize[EnvType];
      ReadWKB(Bytes,WkbOffset,ShapeList);
      Result := ShapeList.Count > 0;
    end;
  end;
end;

Function TGeopackageReader.ReadShape(out Shape: TGISShape; out Properties: TGISShapeProperties): Boolean;
begin
  Result := False;
  if FBuffer.Count > 0 then
  begin
    // Return any buffered sub-shapes from a multi-geometry row first
    Result := True;
    Shape := FBuffer[0];
    Properties := FBufferProps;
    FBuffer.Delete(0);
  end else
  begin
    // Advance through rows; skip null/unreadable geometries
    while not FQuery.Eof do
    begin
      var GeomField := FQuery.FieldByName(FGeomColumnName);
      if not GeomField.IsNull then
      begin
        var GeomBytes := GeomField.AsBytes;
        FBuffer.Clear;
        if ParseBlob(GeomBytes,FBuffer) then
        begin
          // Collect non-geometry fields as properties
          var PropCount := 0;
          SetLength(Properties,FQuery.FieldCount-1);
          for var Field := 0 to FQuery.FieldCount- 1 do
          if not SameText(FQuery.Fields[Field].FieldName, FGeomColumnName) then
          begin
            Properties[PropCount] := TPair<String,Variant>.Create(FQuery.Fields[Field].FieldName,FQuery.Fields[Field].Value);
            Inc(PropCount);
          end;
          // Set properties
          SetLength(Properties,PropCount);
          Shape := FBuffer[0];
          FBuffer.Delete(0);
          FBufferProps := Properties;  // shared by any remaining buffered sub-shapes
          FQuery.Next;
          Result := True;
          Exit;
        end;
      end;
      FQuery.Next;
    end;
  end;
end;

Destructor TGeopackageReader.Destroy;
begin
  FQuery.Free;
  FBuffer.Free;
  inherited Destroy;
end;

////////////////////////////////////////////////////////////////////////////////

Class procedure TGeopackageLayerWriter.WriteByte(Stream: TStream; Value: Byte);
begin
  Stream.WriteBuffer(Value,1);
end;

Class procedure TGeopackageLayerWriter.WriteInt32LE(Stream: TStream; Value: Int32);
var
  B: array[0..3] of Byte;
begin
  B[0] :=  Value         and $FF;
  B[1] := (Value shr  8) and $FF;
  B[2] := (Value shr 16) and $FF;
  B[3] := (Value shr 24) and $FF;
  Stream.WriteBuffer(B,4);
end;

Class procedure TGeopackageLayerWriter.WriteF64LE(Stream: TStream; Value: Double);
var
  V: UInt64;
  B: array[0..7] of Byte;
begin
  Move(Value,V,8);
  B[0] :=  V         and $FF;
  B[1] := (V shr  8) and $FF;
  B[2] := (V shr 16) and $FF;
  B[3] := (V shr 24) and $FF;
  B[4] := (V shr 32) and $FF;
  B[5] := (V shr 40) and $FF;
  B[6] := (V shr 48) and $FF;
  B[7] := (V shr 56) and $FF;
  Stream.WriteBuffer(B,8);
end;

Class procedure TGeopackageLayerWriter.WriteRing(Stream: TStream; const Part: TShapePart);
begin
  WriteInt32LE(Stream,Part.Count);
  for var Point := 0 to Part.Count-1 do
  begin
    WriteF64LE(Stream,Part[Point].X);
    WriteF64LE(Stream,Part[Point].Y);
  end;
end;

Constructor TGeopackageLayerWriter.Create(const Connection: TFDConnection;
                                          const LayerName: String;
                                          const SRID: Integer;
                                          const PropNames: TArray<String>);
begin
  inherited Create;
  FConnection := Connection;
  FLayerName := LayerName;
  FSRID := SRID;
  FPropNames := PropNames;
  // Prepare reusable INSERT statement
  var SQL := 'INSERT INTO ' + LayerName + ' (geom';
  for var PropName := low(PropNames) to high(PropNames) do SQL := SQL + ', ' + PropNames[PropName];
  SQL := SQL + ') VALUES (:geom';
  for var PropName := low(PropNames) to high(PropNames) do SQL := SQL + ', :' + PropNames[PropName];
  SQL := SQL + ')';
  // Create query
  FQuery := TFDQuery.Create(nil);
  FQuery.Connection := FConnection;
  FQuery.SQL.Text := SQL;
end;

Function TGeopackageLayerWriter.ShapeToBlob(const Shape: TGISShape): TBytes;
begin
  Result := nil;
  if Shape.ShapeType <> stEmpty then
  begin
    var Stream := TMemoryStream.Create;
    try
      // GeoPackage header: magic + version + flags (LE, no envelope) + SRID
      WriteByte(Stream,$47);  // 'G'
      WriteByte(Stream,$50);  // 'P'
      WriteByte(Stream,$00);  // version
      WriteByte(Stream,$01);  // flags: little-endian, no envelope, not empty
      WriteInt32LE(Stream,FSRID);
      // WKB byte order (always little-endian)
      WriteByte(Stream,1);
      case Shape.ShapeType of
        stPoint:
          begin
            WriteInt32LE(Stream,1);  // WKBPoint
            WriteF64LE(Stream,Shape[0, 0].X);
            WriteF64LE(Stream,Shape[0, 0].Y);
          end;
        stLine:
          if Shape.Count = 1 then
          begin
            WriteInt32LE(Stream,2);  // WKBLineString
            WriteRing(Stream,Shape.Parts[0]);
          end else
          begin
            WriteInt32LE(Stream,5);  // WKBMultiLineString
            WriteInt32LE(Stream,Shape.Count);
            for var Part := 0 to Shape.Count - 1 do
            begin
              WriteByte(Stream,1);          // sub-geometry byte order
              WriteInt32LE(Stream,2);       // WKBLineString
              WriteRing(Stream,Shape.Parts[Part]);
            end;
          end;
        stPolygon:
          begin
            WriteInt32LE(Stream,3);  // WKBPolygon — all parts are rings
            WriteInt32LE(Stream,Shape.Count);
            for var Part := 0 to Shape.Count-1 do WriteRing(Stream,Shape.Parts[Part]);
          end;
      end;
      // Set result
      SetLength(Result,Stream.Size);
      if Stream.Size > 0 then
      begin
        Stream.Position := 0;
        Stream.ReadBuffer(Result[0],Stream.Size);
      end;
    finally
      Stream.Free;
    end;
  end;
end;

Procedure TGeopackageLayerWriter.WriteShape(const Shape: TGISShape; const Properties: TGISShapeProperties);
begin
  var Blob := ShapeToBlob(Shape);
  if Length(Blob) > 0 then
  begin
    var BlobStream := TBytesStream.Create(Blob);
    try
      FQuery.ParamByName('geom').LoadFromStream(BlobStream, ftBlob);
    finally
      BlobStream.Free;
    end;

    for var PropName := 0 to High(FPropNames) do
    begin
      var PropVal := '';
      for var Prop := low(Properties) to high(Properties) do
      if SameText(Properties[Prop].Key,FPropNames[PropName]) then
      begin
        PropVal := VarToStr(Properties[Prop].Value);
        Break;
      end;
      FQuery.ParamByName(FPropNames[PropName]).AsString := PropVal;
    end;

    FQuery.ExecSQL;
  end;
end;

Destructor TGeopackageLayerWriter.Destroy;
begin
  FQuery.Free;
  inherited Destroy;
end;

////////////////////////////////////////////////////////////////////////////////

Constructor TGeopackageWriter.Create(Package: TGeopackage);
begin
  inherited Create;
  FPackage  := Package;
  FConnection := Package.Connection;  // shared, not owned
  InitSchema;
end;

Procedure TGeopackageWriter.ExecSQL(const SQL: String);
begin
  var Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := SQL;
    Query.ExecSQL;
  finally
    Query.Free;
  end;
end;

Procedure TGeopackageWriter.InsertSRS(SRSID: Integer; const Name,OrgName,Definition: String);
begin
  var Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text   :=
      'INSERT OR IGNORE INTO gpkg_spatial_ref_sys ' +
      '(srs_id, srs_name, organization, organization_coordsys_id, definition) ' +
      'VALUES (:id, :name, :org, :orgid, :def)';
    Query.ParamByName('id').AsInteger := SRSID;
    Query.ParamByName('name').AsString := Name;
    Query.ParamByName('org').AsString := OrgName;
    Query.ParamByName('orgid').AsInteger := SRSID;
    Query.ParamByName('def').AsString := Definition;
    Query.ExecSQL;
  finally
    Query.Free;
  end;
end;

procedure TGeopackageWriter.InitSchema;
begin
  ExecSQL(
    'CREATE TABLE IF NOT EXISTS gpkg_spatial_ref_sys (' +
    '  srs_name TEXT NOT NULL, srs_id INTEGER NOT NULL PRIMARY KEY,' +
    '  organization TEXT NOT NULL, organization_coordsys_id INTEGER NOT NULL,' +
    '  definition TEXT NOT NULL, description TEXT)');

  ExecSQL(
    'CREATE TABLE IF NOT EXISTS gpkg_contents (' +
    '  table_name TEXT NOT NULL PRIMARY KEY, data_type TEXT NOT NULL,' +
    '  identifier TEXT, description TEXT DEFAULT '''',' +
    '  last_change DATETIME NOT NULL DEFAULT' +
    '    (strftime(''%Y-%m-%dT%H:%M:%fZ'',''now'')),' +
    '  min_x REAL, min_y REAL, max_x REAL, max_y REAL, srs_id INTEGER)');

  ExecSQL(
    'CREATE TABLE IF NOT EXISTS gpkg_geometry_columns (' +
    '  table_name TEXT NOT NULL, column_name TEXT NOT NULL,' +
    '  geometry_type_name TEXT NOT NULL, srs_id INTEGER NOT NULL,' +
    '  z TINYINT NOT NULL, m TINYINT NOT NULL,' +
    '  CONSTRAINT pk_geom_cols PRIMARY KEY (table_name, column_name))');

  // Pre-populate the mandatory WGS 84 baseline record
  InsertSRS(4326, 'WGS 84', 'EPSG',
    'GEOGCS["WGS 84",DATUM["WGS_1984",' +
    'SPHEROID["WGS 84",6378137,298.257223563]],' +
    'PRIMEM["Greenwich",0],UNIT["degree",0.0174532925199433]]');
end;

Function TGeopackageWriter.CreateLayerWriter(const LayerName: String;
                                             const SRID: Integer;
                                             const PropNames: TArray<String>): TGeopackageLayerWriter;
var
  SQL: String;
begin
  // Feature table
  SQL := 'CREATE TABLE IF NOT EXISTS ' + LayerName +
         ' (fid INTEGER PRIMARY KEY AUTOINCREMENT, geom BLOB';
  for var Idx := 0 to High(PropNames) do SQL := SQL + ', ' + PropNames[Idx] + ' TEXT';
  SQL := SQL + ')';
  ExecSQL(SQL);

  // Ensure a minimal SRS record exists; callers with full WKT should use the
  // CreateLayerWriter(LayerName, Converter) overload or call InsertSRS first.
  InsertSRS(SRID, 'EPSG:' + IntToStr(SRID), 'EPSG', 'undefined');

  // Register metadata
  ExecSQL(
    'INSERT OR IGNORE INTO gpkg_contents (table_name, data_type, identifier, srs_id)' +
    ' VALUES (''' + LayerName + ''', ''features'', ''' + LayerName + ''', ' +
    IntToStr(SRID) + ')');

  ExecSQL(
    'INSERT OR IGNORE INTO gpkg_geometry_columns ' +
    '(table_name, column_name, geometry_type_name, srs_id, z, m)' +
    ' VALUES (''' + LayerName + ''', ''geom'', ''GEOMETRY'', ' +
    IntToStr(SRID) + ', 0, 0)');

  Result := TGeopackageLayerWriter.Create(FConnection,LayerName,SRID,PropNames);
end;

Function TGeopackageWriter.CreateLayerWriter(const LayerName: String; const SRID: Integer): TGeopackageLayerWriter;
begin
  Result := CreateLayerWriter(LayerName,SRID,[]);
end;

Function TGeopackageWriter.CreateLayerWriter(const LayerName: String;
  const Converter: TCoordinateConverter): TGeopackageLayerWriter;
begin
  InsertSRS(Converter.SRID, Converter.SRSName, 'EPSG', Converter.SRSDefinition);
  Result := CreateLayerWriter(LayerName, Converter.SRID, []);
end;

end.

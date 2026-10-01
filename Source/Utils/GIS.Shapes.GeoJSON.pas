unit GIS.Shapes.GeoJSON;

////////////////////////////////////////////////////////////////////////////////
//
// Author: Jaap Baak
// https://github.com/transportmodelling/GISlib
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
interface
////////////////////////////////////////////////////////////////////////////////

Uses
  SysUtils, Classes, Rtti, Generics.Collections, JSON, JSON.Types, JSON.Writers, JSON.ObjArr,
  Json.Eval, GIS, GIS.Shapes, GIS.Shapes.Polygon;

Type
  TGeoJSONReader = Class(TGISShapesReader)
  // Reads a GeoJSON feature collection
  private
    Type
      TGeoJSONStreamReader = Class(TStreamReader)
      private
        Procedure SkipToFeatures;
      public
        Constructor Create(const FileName: TFileName);
      end;
    Var
      StreamReader: TGeoJSONStreamReader;
      FeaturesParser: TJsonObjectArrayParser;
    Function PropertyValue(const Value: TJsonValue): Variant;
    Function  ReadPoint(const Point: TJsonValue): TCoordinate;
    Function  ReadMultiPoint(const MultiPoint: TJsonValue): TMultiPoint;
    Function  ReadMultiPoints(const MultiPoints: TJsonValue): TMultiPoints;
    Function  ReadMultiPolygon(const MultiPolygon: TJsonValue): TMultiPoints;
    Procedure ReadGeometry(const GeoJsonObject: TJsonObject; out Shape: TGISShape);
    Function  ReadProperties(const GeoJsonObject: TJsonObject): TGISShapeProperties;
  public
    Constructor Create(const FileName: TFileName); override;
    Function ReadShape(out Shape: TGISShape; out Properties: TGISShapeProperties): Boolean; override;
    Function EndOfFile: Boolean;
    Destructor Destroy; override;
  end;

  TGeoJSONWriter = Class
  // Writes shapes to a GeoJSON feature collection
  private
    AsciiWriter: TAsciiStreamWriter;
    JSONWriter: TJSONTextWriter;
    Procedure WriteStartFeature(const ShapeType: String);
    Procedure WriteCoordinateValue(const Point: TCoordinate);
    Procedure WriteCoordinateValues(const MultiPoint: TMultiPoint); overload;
    Procedure WriteCoordinateValues(const MultiPoints: TMultiPoints); overload;
    Procedure WriteCoordinateValues(const Polygons: TArray<TMultiPoints>); overload;
    // The rings with each of them closed, as GeoJSON requires
    Function ClosedRings(const Rings: TMultiPoints): TMultiPoints;
    Procedure WriteEndFeature(const Properties: TGISShapeProperties);
  public
    Constructor Create(const FileName: String;
                       const Formatting: TJSONFormatting = TJSONFormatting.Indented);
    Procedure WritePoint(X,Y: Float64; const Properties: TGISShapeProperties); overload;
    Procedure WritePoint(Point: TCoordinate; const Properties: TGISShapeProperties); overload;
    Procedure WriteMultiPoint(MultiPoint: TMultiPoint; const Properties: TGISShapeProperties);
    Procedure WriteLineString(LineString: TMultiPoint; const Properties: TGISShapeProperties);
    Procedure WriteMultiLineString(MultiLineString: TMultiPoints; const Properties: TGISShapeProperties);
    // Writes a polygon, its outer ring first and then its holes; rings are closed automatically
    Procedure WritePolygon(const Parts: TMultiPoints; const Properties: TGISShapeProperties);
    // Writes a multi polygon, the rings of each polygon as for WritePolygon
    Procedure WriteMultiPolygon(const Polygons: TArray<TMultiPoints>; const Properties: TGISShapeProperties);
    // Writes any TGISShape; a polygon shape with more than one outer ring becomes a multi polygon
    Procedure WriteShape(const Shape: TGISShape); overload;
    Procedure WriteShape(const Shape: TGISShape; const Properties: TGISShapeProperties); overload;
    Destructor Destroy; override;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Constructor TGeoJSONReader.TGeoJSONStreamReader.Create(const FileName: TFileName);
begin
  // GeoJSON is UTF-8 by definition (RFC 7946), with or without a byte order mark
  inherited Create(FileName,TEncoding.UTF8,true);
  SkipToFeatures;
end;

Procedure TGeoJSONReader.TGeoJSONStreamReader.SkipToFeatures;
// Reads up to the value of the features property
begin
  while (not EndOfStream) and (Char(Peek) in [#10,#13,#32]) do Read;
  if (not EndOfStream) and (Char(Peek) = '{') then
  begin
    var Name := '';
    var SetName := true;
    var BracesCount := 0;
    var BracketsCount := 0;
    Read; // Read start object
    if not EndOfStream then
    repeat
      var Ch := Char(Read);
      if not (Ch in [#10,#13,#32]) then
      begin
        if Ch = '{' then Inc(BracesCount) else if Ch = '}' then Dec(BracesCount);
        if Ch = '[' then Inc(BracketsCount) else if Ch = ']' then Dec(BracketsCount);
        if (BracesCount=0) and (BracketsCount=0) then
        begin
          if Ch = ':' then SetName := false else
          if Ch = ',' then
          begin
            Name := '';
            SetName := true;
          end else
          if SetName then Name := Name + Ch;
        end
      end;
    until EndOfStream or (Name='"features"');
  end else
    raise Exception.Create('Invalid GeoJson-object');
  while (not EndOfStream) and (Char(Peek) in [#10,#13,#32,':']) do Read;
end;

////////////////////////////////////////////////////////////////////////////////

Constructor TGeoJSONReader.Create(const FileName: TFileName);
begin
  inherited Create(FileName);
  StreamReader := TGeoJSONStreamReader.Create(FileName);
  FeaturesParser := TJsonObjectArrayParser.Create(StreamReader);
end;

Function TGeoJSONReader.PropertyValue(const Value: TJsonValue): Variant;
begin
  if Value is TJSONNumber then
  begin
    var NumberValue := TJSONNumber(Value).AsDouble;
    if Frac(NumberValue) = 0 then Result := Trunc(NumberValue) else Result := NumberValue;
  end else
  if Value is TJSONString then Result := Value.Value else
  if Value is TJSONBool then Result := TJSONBool(Value).AsBoolean else
  Result := Value.ToString;
end;

Function TGeoJSONReader.ReadPoint(const Point: TJsonValue): TCoordinate;
begin
  if Assigned(Point) and (Point is TJsonArray) then
  begin
    var Coordinates := Point as TJsonArray;
    if Coordinates.Count = 2 then
    begin
      Result.X := Coordinates.Items[0].AsType<Double>;
      Result.Y := Coordinates.Items[1].AsType<Double>;
    end else
      raise Exception.Create('Invalid GeoJson-object');
  end else
    raise Exception.Create('Invalid GeoJson-object');
end;

Function TGeoJSONReader.ReadMultiPoint(const MultiPoint: TJsonValue): TMultiPoint;
begin
  if Assigned(MultiPoint) and (MultiPoint is TJsonArray) then
  begin
    var Points := MultiPoint as TJsonArray;
    SetLength(Result,Points.Count);
    for var Point := 0 to Points.Count-1 do
    begin
      var Coordinate := Points.Items[Point];
      Result[Point] := ReadPoint(Coordinate);
    end;
  end else
    raise Exception.Create('Invalid GeoJson-object');
end;

Function TGeoJSONReader.ReadMultiPoints(const MultiPoints: TJsonValue): TMultiPoints;
begin
  if Assigned(MultiPoints) and (MultiPoints is TJsonArray) then
  begin
    var Parts := MultiPoints as TJsonArray;
    SetLength(Result,Parts.Count);
    for var Part := 0 to Parts.Count-1 do
    begin
      var MultiPoint := Parts.Items[Part];
      Result[Part] := ReadMultiPoint(MultiPoint);
    end;
  end else
    raise Exception.Create('Invalid GeoJson-object');
end;

Function TGeoJSONReader.ReadMultiPolygon(const MultiPolygon: TJsonValue): TMultiPoints;
begin
  if Assigned(MultiPolygon) and (MultiPolygon is TJsonArray) then
  begin
    var Polygons := MultiPolygon as TJsonArray;
    for var Polygon := 0 to Polygons.Count-1 do
    begin
      var MultiPoints := Polygons.Items[Polygon];
      Result := Result + ReadMultiPoints(MultiPoints);
    end;
  end else
    raise Exception.Create('Invalid GeoJson-object');
end;

Procedure TGeoJSONReader.ReadGeometry(const GeoJsonObject: TJsonObject; out Shape: TGISShape);
Var
  GeometryType: String;
  Coordinates: TJsonValue;
begin
  if TJsonEvaluator.GetStr(GeoJsonObject,['geometry','type'],GeometryType) and
     TJsonEvaluator.NavigateTo(GeoJsonObject,['geometry','coordinates'],Coordinates) then
  begin
    if GeometryType = 'Point' then Shape.AssignPoint(ReadPoint(Coordinates)) else
    if GeometryType = 'MultiPoint' then Shape.AssignPoints(ReadMultiPoint(Coordinates)) else
    if GeometryType = 'LineString' then Shape.AssignLine(ReadMultiPoint(Coordinates)) else
    if GeometryType = 'MultiLineString' then Shape.AssignPolyLine(ReadMultiPoints(Coordinates)) else
    if GeometryType = 'Polygon' then Shape.AssignPolyPolygon(ReadMultiPoints(Coordinates)) else
    if GeometryType = 'MultiPolygon' then Shape.AssignPolyPolygon(ReadMultiPolygon(Coordinates)) else
    if GeometryType = 'GeometryCollection' then raise exception.Create('Unsupported geometry type') else
    raise Exception.Create('Invalid GeoJson-object');
  end else
    raise Exception.Create('Invalid GeoJson-object');
end;

Function TGeoJSONReader.ReadProperties(const GeoJsonObject: TJsonObject): TGISShapeProperties;
Var
  Fields: TArray<TJsonField>;
begin
  if TJsonEvaluator.GetFields(GeoJsonObject,['properties'],Fields) then
  begin
    SetLength(Result,Length(Fields));
    for var Field := low(Fields) to high(Fields) do
    Result[Field] := TPair<String,Variant>.Create(Fields[Field].Key,PropertyValue(Fields[Field].Value));
  end else
    raise Exception.Create('Invalid GeoJson-object');
end;

Function TGeoJSONReader.ReadShape(out Shape: TGISShape; out Properties: TGISShapeProperties): Boolean;
begin
  if not EndOfFile then
  begin
    Result := true;
    var JsonValue := TJSONObject.ParseJSONValue(FeaturesParser.Next);
    try
      if Assigned(JsonValue) and (JsonValue is TJsonObject) then
      begin
        var GeoJsonObject := JsonValue as TJsonObject;
        ReadGeometry(GeoJsonObject,Shape);
        Properties := ReadProperties(GeoJsonObject);
      end else
        raise Exception.Create('Invalid GeoJson-object')
    finally
      JsonValue.Free;
    end;
  end else
    Result := false;
end;

Function TGeoJSONReader.EndOfFile: Boolean;
begin
  Result := FeaturesParser.EndOfArray;
end;

Destructor TGeoJSONReader.Destroy;
begin
  FeaturesParser.Free;
  StreamReader.Free;
  inherited Destroy;
end;

////////////////////////////////////////////////////////////////////////////////

Constructor TGeoJSONWriter.Create(const FileName: String;
                                  const Formatting: TJSONFormatting = TJSONFormatting.Indented);
begin
  inherited Create;
  AsciiWriter := TAsciiStreamWriter.Create(FileName);
  JSONWriter := TJSONTextWriter.Create(AsciiWriter);
  JSONWriter.Formatting := Formatting;
  JSONWriter.WriteStartObject;
  JSONWriter.WritePropertyName('type');
  JSONWriter.WriteValue('FeatureCollection');
  JSONWriter.WritePropertyName('features');
  JSONWriter.WriteStartArray;
end;

Procedure TGeoJSONWriter.WriteStartFeature(const ShapeType: String);
begin
  JSONWriter.WriteStartObject;
  JSONWriter.WritePropertyName('type');
  JSONWriter.WriteValue('Feature');
  JSONWriter.WritePropertyName('geometry');
  JSONWriter.WriteStartObject;
  JSONWriter.WritePropertyName('type');
  JSONWriter.WriteValue(ShapeType);
  JSONWriter.WritePropertyName('coordinates');
end;

Procedure TGeoJSONWriter.WriteCoordinateValue(const Point: TCoordinate);
begin
  JSONWriter.WriteStartArray;
  JSONWriter.WriteValue(Point.X);
  JSONWriter.WriteValue(Point.Y);
  JSONWriter.WriteEndArray;
end;

Procedure TGeoJSONWriter.WriteCoordinateValues(const MultiPoint: TMultiPoint);
begin
  JSONWriter.WriteStartArray;
  for var Point := low(MultiPoint) to high(MultiPoint) do
  begin
    JSONWriter.WriteStartArray;
    JSONWriter.WriteValue(MultiPoint[Point].X);
    JSONWriter.WriteValue(MultiPoint[Point].Y);
    JSONWriter.WriteEndArray;
  end;
  JSONWriter.WriteEndArray;
end;

Procedure TGeoJSONWriter.WriteCoordinateValues(const MultiPoints: TMultiPoints);
begin
  JSONWriter.WriteStartArray;
  for var Part := low(MultiPoints) to high(MultiPoints) do
  begin
    JSONWriter.WriteStartArray;
    for var Point := low(MultiPoints[Part]) to high(MultiPoints[Part]) do
    begin
      JSONWriter.WriteStartArray;
      JSONWriter.WriteValue(MultiPoints[Part,Point].X);
      JSONWriter.WriteValue(MultiPoints[Part,Point].Y);
      JSONWriter.WriteEndArray;
    end;
    JSONWriter.WriteEndArray;
  end;
  JSONWriter.WriteEndArray;
end;

Procedure TGeoJSONWriter.WriteCoordinateValues(const Polygons: TArray<TMultiPoints>);
begin
  JSONWriter.WriteStartArray;
  for var Polygon := low(Polygons) to high(Polygons) do WriteCoordinateValues(Polygons[Polygon]);
  JSONWriter.WriteEndArray;
end;

Function TGeoJSONWriter.ClosedRings(const Rings: TMultiPoints): TMultiPoints;
begin
  SetLength(Result,Length(Rings));
  for var Ring := low(Rings) to high(Rings) do
  begin
    Result[Ring] := Rings[Ring];
    var Count := Length(Result[Ring]);
    if (Count > 0) and
       ((Result[Ring][0].X <> Result[Ring][Count-1].X) or
        (Result[Ring][0].Y <> Result[Ring][Count-1].Y)) then
      Result[Ring] := Result[Ring] + [Result[Ring][0]];
  end;
end;

Procedure TGeoJSONWriter.WriteEndFeature(const Properties: TGISShapeProperties);
begin
  JSONWriter.WriteEndObject;
  JSONWriter.WritePropertyName('properties');
  JSONWriter.WriteStartObject;
  for var Prop := low(Properties) to high(Properties) do
  begin
    JSONWriter.WritePropertyName(Properties[Prop].Key);
    JSONWriter.WriteValue(TValue.FromVariant(Properties[Prop].Value));
  end;
  JSONWriter.WriteEndObject;
  JSONWriter.WriteEndObject;
end;

Procedure TGeoJSONWriter.WritePoint(X,Y: Float64; const Properties: TGISShapeProperties);
begin
  WritePoint(TCoordinate.Create(X,Y),Properties);
end;

Procedure TGeoJSONWriter.WritePoint(Point: TCoordinate; const Properties: TGISShapeProperties);
begin
  WriteStartFeature('Point');
  WriteCoordinateValue(Point);
  WriteEndFeature(Properties);
end;

Procedure TGeoJSONWriter.WriteMultiPoint(MultiPoint: TMultiPoint; const Properties: TGISShapeProperties);
begin
  WriteStartFeature('MultiPoint');
  WriteCoordinateValues(MultiPoint);
  WriteEndFeature(Properties);
end;

Procedure TGeoJSONWriter.WriteLineString(LineString: TMultiPoint; const Properties: TGISShapeProperties);
begin
  WriteStartFeature('LineString');
  WriteCoordinateValues(LineString);
  WriteEndFeature(Properties);
end;

Procedure TGeoJSONWriter.WriteMultiLineString(MultiLineString: TMultiPoints; const Properties: TGISShapeProperties);
begin
  WriteStartFeature('MultiLineString');
  WriteCoordinateValues(MultiLineString);
  WriteEndFeature(Properties);
end;

Procedure TGeoJSONWriter.WritePolygon(const Parts: TMultiPoints; const Properties: TGISShapeProperties);
begin
  WriteStartFeature('Polygon');
  WriteCoordinateValues(ClosedRings(Parts));
  WriteEndFeature(Properties);
end;

Procedure TGeoJSONWriter.WriteMultiPolygon(const Polygons: TArray<TMultiPoints>; const Properties: TGISShapeProperties);
var
  ClosedPolygons: TArray<TMultiPoints>;
begin
  SetLength(ClosedPolygons,Length(Polygons));
  for var Polygon := low(Polygons) to high(Polygons) do ClosedPolygons[Polygon] := ClosedRings(Polygons[Polygon]);
  WriteStartFeature('MultiPolygon');
  WriteCoordinateValues(ClosedPolygons);
  WriteEndFeature(Properties);
end;

Procedure TGeoJSONWriter.WriteShape(const Shape: TGISShape);
begin
  WriteShape(Shape,[]);
end;

Procedure TGeoJSONWriter.WriteShape(const Shape: TGISShape; const Properties: TGISShapeProperties);
var
  Parts: TMultiPoints;
  Polygons: TArray<TMultiPoints>;
begin
  case Shape.ShapeType of
    stPoint:
      WritePoint(Shape[0,0],Properties);
    stLine:
      begin
        SetLength(Parts,Shape.Count);
        for var Part := 0 to Shape.Count - 1 do Parts[Part] := Shape.Parts[Part].AsMultiPoint;
        if Shape.Count = 1 then
          WriteLineString(Parts[0],Properties)
        else
          WriteMultiLineString(Parts,Properties);
      end;
    stPolygon:
      begin
        // The rings are sorted into outer rings and their holes, which is how GeoJSON takes them
        var PolyPolygons := TPolyPolygons.Create(Shape);
        if PolyPolygons.Count = 1 then
          WritePolygon(PolyPolygons[0].Rings,Properties)
        else
        begin
          SetLength(Polygons,PolyPolygons.Count);
          for var Polygon := 0 to PolyPolygons.Count-1 do Polygons[Polygon] := PolyPolygons[Polygon].Rings;
          WriteMultiPolygon(Polygons,Properties);
        end;
      end;
  end;
end;

Destructor TGeoJSONWriter.Destroy;
begin
  JSONWriter.WriteEndArray;
  JSONWriter.WriteEndObject;
  JSONWriter.Free;
  AsciiWriter.Free;
  inherited Destroy;
end;

end.

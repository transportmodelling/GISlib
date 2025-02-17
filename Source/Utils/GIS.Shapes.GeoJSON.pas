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
  SysUtils, Classes, Rtti, Generics.Collections, ObjArr, JSON, JSON.Types, JSON.Writers,
  GIS, GIS.Shapes;

Type
  TGeoJSONReader = Class(TGISShapesReader)
  // Reads a GeoJSON feature collection
  private
    Type
      TGeoJSONStreamReader = Class(TStreamReader)
      public
        Constructor Create(const FileName: TFileName);
      end;
    Var
      StreamReader: TGeoJSONStreamReader;
      FeaturesParser: TJsonObjectArrayParser;
    Function  ReadPoint(const Point: TJsonValue): TCoordinate;
    Function  ReadMultiPoint(const MultiPoint: TJsonValue): TMultiPoint;
    Function  ReadMultiPoints(const MultiPoints: TJsonValue): TMultiPoints;
    Function  ReadMultiPolygon(const MultiPolygon: TJsonValue): TMultiPoints;
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
    Procedure WriteEndFeature(const Properties: array of TPair<String,TValue>);
  public
    Constructor Create(const FileName: String;
                       const Formatting: TJSONFormatting = TJSONFormatting.Indented);
    Procedure WritePoint(X,Y: Float64; const Properties: array of TPair<String,TValue>); overload;
    Procedure WritePoint(Point: TCoordinate; const Properties: array of TPair<String,TValue>); overload;
    Procedure WriteMultiPoint(MultiPoint: TMultiPoint; const Properties: array of TPair<String,TValue>);
    Procedure WriteLineString(LineString: TMultiPoint; const Properties: array of TPair<String,TValue>);
    Procedure WriteMultiLineString(MultiLineString: TMultiPoints; const Properties: array of TPair<String,TValue>);
    Destructor Destroy; override;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Constructor TGeoJSONReader.TGeoJSONStreamReader.Create(const FileName: TFileName);
begin
  inherited Create(FileName,Tencoding.ANSI);
  // Read up to the Features array
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
Var
  PropertyName: String;
begin
  inherited Create(FileName);
  StreamReader := TGeoJSONStreamReader.Create(FileName);
  FeaturesParser := TJsonObjectArrayParser.Create(StreamReader);
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

Function TGeoJSONReader.ReadShape(out Shape: TGISShape; out Properties: TArray<TPair<String,Variant>>): Boolean;
begin
  if not EndOfFile then
  begin
    Result := true;
    // Create GEOjson object
    var Json := FeaturesParser.Next;
    var JsonValue := TJSONObject.ParseJSONValue(Json);
    try
      if Assigned(JsonValue) and (JsonValue is TJsonObject) then
      begin
        var GeoJsonObject := JsonValue as TJsonObject;
        // Set shape
        var GeometryValue := GeoJsonObject.Get('geometry').JsonValue;
        if Assigned(GeometryValue) and (GeometryValue is TJsonObject) then
        begin
          var GeometryObject := GeometryValue as TJsonObject;
          var Coordinates := GeometryObject.Get('coordinates').JsonValue;
          // Get geometry type
          var GeometryType := GeometryObject.GetValue('type');
          if Assigned(GeometryType) then
          begin
            if GeometryType.Value = 'Point' then Shape.AssignPoint(ReadPoint(Coordinates)) else
            if GeometryType.Value = 'MultiPoint' then Shape.AssignPoints(ReadMultiPoint(Coordinates)) else
            if GeometryType.Value = 'LineString' then Shape.AssignLine(ReadMultiPoint(Coordinates)) else
            if GeometryType.Value = 'MultiLineString' then Shape.AssignPolyLine(ReadMultiPoints(Coordinates)) else
            if GeometryType.Value = 'Polygon' then Shape.AssignPolyPolygon(ReadMultiPoints(Coordinates)) else
            if GeometryType.Value = 'MultiPolygon' then Shape.AssignPolyPolygon(ReadMultiPolygon(Coordinates)) else
            if GeometryType.Value = 'GeometryCollection' then raise exception.Create('Unsupported geometry type') else
            raise Exception.Create('Invalid GeoJson-object');
          end else
            raise Exception.Create('Invalid GeoJson-object');
        end else
          raise Exception.Create('Invalid GeoJson-object');
        // Set properties
        var PropertiesValue := GeoJsonObject.Get('properties').JsonValue;
        if Assigned(PropertiesValue) and (PropertiesValue is TJsonObject) then
        begin
          var Index := 0;
          var PropertiesObject := PropertiesValue as TJsonObject;
          SetLength(Properties,PropertiesObject.Count);
          for var Pair in PropertiesObject do
          begin
            if Pair.JsonValue is TJSONNumber then
            begin
              var NumberValue := TJSONNumber(Pair.JsonValue).AsDouble;
              if Frac(NumberValue) = 0 then
                Properties[Index] := TPair<string,Variant>.Create(Pair.JsonString.Value,Trunc(NumberValue))
              else
                Properties[Index] := TPair<string,Variant>.Create(Pair.JsonString.Value,NumberValue)
            end else
            if Pair.JsonValue is TJSONString then
              Properties[Index] := TPair<string,Variant>.Create(Pair.JsonString.Value,Pair.JsonValue.Value)
            else if Pair.JsonValue is TJSONBool then
              Properties[Index] := TPair<string,Variant>.Create(Pair.JsonString.Value,TJSONBool(Pair.JsonValue).AsBoolean)
            else
              Properties[Index] := TPair<string,Variant>.Create(Pair.JsonString.Value,Pair.JsonValue.ToString);
            Inc(Index);
          end;
        end else
          raise Exception.Create('Invalid GeoJson-object');
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

Procedure TGeoJSONWriter.WriteEndFeature(const Properties: array of TPair<String,TValue>);
begin
  JSONWriter.WriteEndObject;
  JSONWriter.WritePropertyName('properties');
  JSONWriter.WriteStartObject;
  for var Prop := low(Properties) to high(Properties) do
  begin
    JSONWriter.WritePropertyName(Properties[Prop].Key);
    JSONWriter.WriteValue(Properties[Prop].Value);
  end;
  JSONWriter.WriteEndObject;
  JSONWriter.WriteEndObject;
end;

Procedure TGeoJSONWriter.WritePoint(X,Y: Float64; const Properties: array of TPair<String,TValue>);
begin
  WritePoint(TCoordinate.Create(X,Y),Properties);
end;

Procedure TGeoJSONWriter.WritePoint(Point: TCoordinate; const Properties: array of TPair<String,TValue>);
begin
  WriteStartFeature('Point');
  WriteCoordinateValue(Point);
  WriteEndFeature(Properties);
end;

Procedure TGeoJSONWriter.WriteMultiPoint(MultiPoint: TMultiPoint; const Properties: array of TPair<String,TValue>);
begin
  WriteStartFeature('MultiPoint');
  WriteCoordinateValues(MultiPoint);
  WriteEndFeature(Properties);
end;

Procedure TGeoJSONWriter.WriteLineString(LineString: TMultiPoint; const Properties: array of TPair<String,TValue>);
begin
  WriteStartFeature('LineString');
  WriteCoordinateValues(LineString);
  WriteEndFeature(Properties);
end;

Procedure TGeoJSONWriter.WriteMultiLineString(MultiLineString: TMultiPoints; const Properties: array of TPair<String,TValue>);
begin
  WriteStartFeature('MultiLineString');
  WriteCoordinateValues(MultiLineString);
  WriteEndFeature(Properties);
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

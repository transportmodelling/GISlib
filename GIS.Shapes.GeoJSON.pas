unit GIS.Shapes.GeoJSON;

////////////////////////////////////////////////////////////////////////////////
interface
////////////////////////////////////////////////////////////////////////////////

Uses
  System.JSON.Types,System.JSON.Writers,GIS,GIS.Shapes;

Type
  TGeoJSONWriter = Class
  // Writes shapes to a GeoJSON feature collection
  private
    AsciiWriter: TAsciiStreamWriter;
    JSONWriter: TJSONTextWriter;
    Procedure WriteStartFeature(const ShapeType: String);
    Procedure WriteCoordinateValue(const Point: TCoordinate);
    Procedure WriteCoordinateValues(const MultiPoint: TMultiPoint); overload;
    Procedure WriteCoordinateValues(const MultiPoints: TMultiPoints); overload;
    Procedure WriteEndFeature;
  public
    Constructor Create(const FileName: String;
                       const Formatting: TJSONFormatting = TJSONFormatting.Indented);
    Procedure WritePoint(X,Y: Float64); overload;
    Procedure WritePoint(Point: TCoordinate); overload;
    Procedure WriteMultiPoint(MultiPoint: TMultiPoint);
    Procedure WriteLineString(LineString: TMultiPoint);
    Procedure WriteMultiLineString(MultiLineString: TMultiPoints);
    Destructor Destroy; override;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
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

Procedure TGeoJSONWriter.WriteEndFeature;
begin
  JSONWriter.WriteEndObject;
  JSONWriter.WritePropertyName('properties');
  JSONWriter.WriteStartObject;
  JSONWriter.WriteEndObject;
  JSONWriter.WriteEndObject;
end;

Procedure TGeoJSONWriter.WritePoint(X,Y: Float64);
begin
  WritePoint(TCoordinate.Create(X,Y));
end;

Procedure TGeoJSONWriter.WritePoint(Point: TCoordinate);
begin
  WriteStartFeature('Point');
  WriteCoordinateValue(Point);
  WriteEndFeature;
end;

Procedure TGeoJSONWriter.WriteMultiPoint(MultiPoint: TMultiPoint);
begin
  WriteStartFeature('MultiPoint');
  WriteCoordinateValues(MultiPoint);
  WriteEndFeature;
end;

Procedure TGeoJSONWriter.WriteLineString(LineString: TMultiPoint);
begin
  WriteStartFeature('LineString');
  WriteCoordinateValues(LineString);
  WriteEndFeature;
end;

Procedure TGeoJSONWriter.WriteMultiLineString(MultiLineString: TMultiPoints);
begin
  WriteStartFeature('MultiLineString');
  WriteCoordinateValues(MultiLineString);
  WriteEndFeature;
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

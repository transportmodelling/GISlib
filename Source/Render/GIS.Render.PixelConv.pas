unit GIS.Render.PixelConv;

////////////////////////////////////////////////////////////////////////////////
interface
////////////////////////////////////////////////////////////////////////////////

Uses
  SysUtils, Classes, Types, GIS;

Type
  TPixelConverterState = Class
  private
    State: TMemoryStream;
    Previous,Next: TPixelConverterState;
  public
    Constructor Create;
    Destructor Destroy; override;
  end;

  TCustomPixelConverter = Class
  private
    // History
    Const
      Capacity = 32;
    Var
      Count: Integer;
      First,Last,Current: TPixelConverterState;
      FOnChange: TNotifyEvent;
    Procedure SetOnChange(OnChange: TNotifyEvent);
    Procedure ReadState(const State: TPixelConverterState); overload;
  strict protected
    FInitialized: Boolean;
    FPixelWidth,FPixelHeight: Float32;
    Procedure Changed;
    Procedure WriteState(const Writer: TBinaryWriter); virtual; abstract;
    Procedure ReadState(const Reader: TBinaryReader); overload; virtual; abstract;
  public
    // Convert between pixels and world coordinates
    Function CoordToPixel(const Coord: TCoordinate): TPointF; overload; virtual; abstract;
    Function CoordToPixel(const Xcoord,Ycoord: Float64): TPointF; overload;
    Function PixelToCoord(const Pixel: TPointF): TCoordinate; overload; virtual; abstract;
    Function PixelToCoord(const Pixel: TPoint): TCoordinate; overload;
    Function PixelToCoord(const Xpixel,Ypixel: Float64): TCoordinate; overload;
    // Control convertion between pixels and coordinates
    Procedure Initialize(const BoundingBox: TCoordinateRect; const PixelWidth,PixelHeight: Float32); virtual; abstract;
    Procedure ZoomIn(const Pixel: TPointF); overload; virtual; abstract;
    Procedure ZoomIn(const Pixels: TRectF); overload; virtual; abstract;
    Procedure ZoomOut(const Pixel: TPointF); overload; virtual; abstract;
    Procedure PanMap(const DeltaXPixel,DeltaYPixel: Float32); virtual; abstract;
    // State persistence
    Function GetState: TPixelConverterState;
    Procedure SetState(const State: TPixelConverterState);
    // State history
    Procedure Clear;
    Function PreviousAvail: Boolean;
    Function Previous: Boolean;
    Function NextAvail: Boolean;
    Function Next: Boolean;
    // Get viewport
    Function GetViewport: TCoordinateRect; virtual; abstract;
    Destructor Destroy; override;
  public
    Property Initialized: Boolean read FInitialized;
    Property PixelWidth: Float32 read FPixelWidth;
    Property PixelHeight: Float32 read FPixelHeight;
  public
    Property OnChange: TNotifyEvent read FOnChange write SetOnChange;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Constructor TPixelConverterState.Create;
begin
  inherited Create;
  State := TMemoryStream.Create;
end;

Destructor TPixelConverterState.Destroy;
begin
  State.Free;
  inherited Destroy;
end;

////////////////////////////////////////////////////////////////////////////////

Procedure TCustomPixelConverter.ReadState(const State: TPixelConverterState);
begin
  var Reader := TBinaryReader.Create(State.State);
  try
    ReadState(Reader);
    State.State.Position := 0;
  finally
    Reader.Free;
  end;
end;

Procedure TCustomPixelConverter.SetOnChange(OnChange: TNotifyEvent);
begin
  FOnChange := OnChange;
  FOnChange(Self);
end;

Procedure TCustomPixelConverter.Changed;
begin
  if Capacity > 0 then
  begin
    // Clear history following current state
    if Current <> nil then
    begin
      var State := Current.Next;
      while State <> nil do
      begin
        var ObsoleteState := State;
        State := State.Next;
        ObsoleteState.Free;
        Dec(Count);
      end;
    end;
    // Remove first state from list if needed
    if Count = Capacity then
    begin
      var ObsoleteState := First;
      First := First.Next;
      First.Previous := nil;
      ObsoleteState.Free;
      Dec(Count);
    end;
    // Add current state at end of state list
    var State := GetState;
    State.Previous := Current;
    if Current = nil then First := State else Current.Next := State;
    Current := State;
    Last := State;
    Inc(Count);
    // Fire OnChange-event
    if Assigned(FOnChange) then FOnChange(Self);
  end;
end;

Function TCustomPixelConverter.CoordToPixel(const Xcoord,Ycoord: Float64): TPointF;
begin
  Result := CoordToPixel(TCoordinate.Create(Xcoord,Ycoord));
end;

Function TCustomPixelConverter.PixelToCoord(const Pixel: TPoint): TCoordinate;
begin
  Result := PixelToCoord(TPointF.Create(Pixel));
end;

Function TCustomPixelConverter.PixelToCoord(const Xpixel,Ypixel: Float64): TCoordinate;
begin
  Result := PixelToCoord(TPointF.Create(Xpixel,Ypixel));
end;

Function TCustomPixelConverter.GetState: TPixelConverterState;
begin
  Result := TPixelConverterState.Create;
  // Write state
  var Writer := TBinaryWriter.Create(Result.State);
  try
    WriteState(Writer);
    Result.State.Position := 0;
  finally
    Writer.Free;
  end;
end;

Procedure TCustomPixelConverter.SetState(const State: TPixelConverterState);
begin
  ReadState(State);
  Changed;
end;

Procedure TCustomPixelConverter.Clear;
begin
  var State := First;
  while State <> nil do
  begin
    var ObsoleteState := State;
    State := State.Next;
    ObsoleteState.Free;
  end;
  First := nil;
  Current := nil;
  Last := nil;
  Count := 0;
end;

Function TCustomPixelConverter.PreviousAvail: Boolean;
begin
  if Current = nil then Result := false else Result := (Current.Previous <> nil);
end;

Function TCustomPixelConverter.Previous: Boolean;
begin
  if Current <> nil then
    if Current.Previous <> nil then
    begin
      Result := true;
      Current := Current.Previous;
      ReadState(Current);
      if Assigned(FOnChange) then FOnChange(Self);
    end else
      Result := false
  else
    Result := false;
end;

Function TCustomPixelConverter.NextAvail: Boolean;
begin
  if Current = nil then Result := false else Result := (Current.Next <> nil);
end;

Function TCustomPixelConverter.Next: Boolean;
begin
  if Current <> nil then
    if Current.Next <> nil then
    begin
      Result := true;
      Current := Current.Next;
      ReadState(Current);
      if Assigned(FOnChange) then FOnChange(Self);
    end else
      Result := false
  else
    Result := false;
end;

Destructor TCustomPixelConverter.Destroy;
begin
  Clear;
  inherited Destroy;
end;

end.

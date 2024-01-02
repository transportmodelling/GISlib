unit GIS.Render.Shapes.Network;

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
  Graphics, GIS, GIS.Shapes, GIS.Render.Shapes, GIS.Render.PixelConv;

Type
  TNetworkLink = record
  private
    FFromNode,FToNode: Integer;
  public
    Constructor Create(FromNode,ToNode: Integer);
  public
    Property FromNode: Integer read FFromNode;
    Property ToNode: Integer read FToNode;
  end;

  TNetworkLayer = Class(TCustomShapesLayer)
  private
    FNodesCount: Integer;
    FNodes: array of TCoordinate;
    FLinks: array of TNetworkLink;
    LinkRenderer: TCustomShapesLayer.TLinesRenderer;
    Procedure EnsureNodesCapacity;
    Procedure EnsureLinksCapacity;
    Function GetNodes(Node: Integer): TCoordinate; inline;
    Function GetLinks(Link: Integer): TNetworkLink; inline;
  strict protected
    Function ShapeRenderer(const Shape: Integer): TCustomShapesLayer.TShapeRenderer; override;
  strict protected
    Procedure SetNodesCapacity(Capacity: Integer); virtual;
    Procedure SetLinksCapacity(Capacity: Integer); virtual;
    Function LinkLabel(const Link: Integer): String; virtual;
  public
    Constructor Create(const TransparentColor: TColor;
                       const InitialNodesCapacity: Integer = 16384;
                       const InitialLinksCapacity: Integer = 16384);
    Procedure Clear;
    Function AddNode(X,Y: Float64): Integer; overload;
    Function AddNode(Node: TCoordinate): Integer; overload;
    Procedure AddLink(FromNode,ToNode: Integer); overload;
    Procedure AddLink(Link: TNetworkLink); overload;
    Destructor Destroy; override;
  public
    Property NodesCount: Integer read FNodesCount;
    Property LinksCount: Integer read FCount;
    Property Nodes[Node: Integer]: TCoordinate read GetNodes;
    Property Links[Link: Integer]: TNetworkLink read GetLinks; default;
  end;


////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Constructor TNetworkLink.Create(FromNode,ToNode: Integer);
begin
  FFromNode := FromNode;
  FToNode := ToNode;
end;

////////////////////////////////////////////////////////////////////////////////

Constructor TNetworkLayer.Create(const TransparentColor: TColor;
                                 const InitialNodesCapacity: Integer = 16384;
                                 const InitialLinksCapacity: Integer = 16384);
begin
  inherited Create(TransparentColor);
  SetNodesCapacity(InitialNodesCapacity);
  SetLinksCapacity(InitialLinksCapacity);
  LinkRenderer := TCustomShapesLayer.TLinesRenderer.Create;
end;

Procedure TNetworkLayer.EnsureNodesCapacity;
begin
  if FNodesCount = Length(FNodes) then
  begin
    var Delta := Round(0.25*FNodesCount);
    if Delta < 1024 then Delta := 1024;
    SetNodesCapacity(FNodesCount+Delta);
  end;
end;

Procedure TNetworkLayer.EnsureLinksCapacity;
begin
  if FCount = Length(FLinks) then
  begin
    var Delta := Round(0.25*FCount);
    if Delta < 1024 then Delta := 1024;
    SetLinksCapacity(FCount+Delta);
  end;
end;

Function TNetworkLayer.GetNodes(Node: Integer): TCoordinate;
begin
  Result := FNodes[Node];
end;

Function TNetworkLayer.GetLinks(Link: Integer): TNetworkLink;
begin
  Result := FLinks[Link];
end;

Function TNetworkLayer.ShapeRenderer(const Shape: Integer): TCustomShapesLayer.TShapeRenderer;
begin
  LinkRenderer.Lines.AssignLine([FNodes[FLinks[Shape].FFromNode],FNodes[FLinks[Shape].FToNode]]);
  Result := LinkRenderer;
end;

Procedure TNetworkLayer.SetNodesCapacity(Capacity: Integer);
begin
  SetLength(FNodes,Capacity);
end;

Procedure TNetworkLayer.SetLinksCapacity(Capacity: Integer);
begin
  SetLength(FLinks,Capacity);
end;

Function TNetworkLayer.LinkLabel(const Link: Integer): String;
begin
  Result := '';
end;

Procedure TNetworkLayer.Clear;
begin
  FCount := 0;
  FNodesCount := 0;
end;

Function TNetworkLayer.AddNode(X,Y: Float64): Integer;
begin
  AddNode(TCoordinate.Create(X,Y));
end;

Function TNetworkLayer.AddNode(Node: TCoordinate): Integer;
begin
  EnsureNodesCapacity;
  FNodes[FNodesCount] := Node;
  Inc(FNodesCount);
  FBoundingBox.Enclose(Node);
end;

Procedure TNetworkLayer.AddLink(FromNode,ToNode: Integer);
begin
  AddLink(TNetworkLink.Create(FromNode,ToNode));
end;

Procedure TNetworkLayer.AddLink(Link: TNetworkLink);
begin
  EnsureLinksCapacity;
  FLinks[FCount] := Link;
  Inc(FCount);
end;

Destructor TNetworkLayer.Destroy;
begin
  LinkRenderer.Free;
  inherited Destroy;
end;

end.

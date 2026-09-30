unit Test.Render.Tiles;

////////////////////////////////////////////////////////////////////////////////
//
// Author: Jaap Baak
// https://github.com/transportmodelling/GISlib
//
// Tests for TCustomTilesLayer from GIS.Render.Tiles, with a layer that serves
// blank tiles instead of downloading them, drawing on the SVG canvas.
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
interface
////////////////////////////////////////////////////////////////////////////////

uses
  System.SysUtils,
  DUnitX.TestFramework,
  GIS, GIS.CoordConv.WGS84,
  GIS.Render.Canvas, GIS.Render.Canvas.SVG,
  GIS.Render.Tiles, GIS.Render.PixelConv.Mercator,
  Test.Render.Shapes;

type
  TBlankTilesLayer = class(TCustomTilesLayer)
  // Serves a blank 256 by 256 tile for any index, counting the requests
  public
    Fetches: Integer;
  strict protected
    Function GetTile(Level,Xindex,Yindex: Integer): TBytes; override;
  end;

  [TestFixture]
  TTilesLayerTests = class
  private
    FLayer: TBlankTilesLayer;
    FConverter: TWebMercatorPixelConverter;
    Function Occurrences(const SubText,Text: String): Integer;
  public
    [Setup]    Procedure Setup;
    [TearDown] Procedure TearDown;
    [Test] Procedure DrawLayer_DrawsEveryVisibleTileOnce;
    [Test] Procedure DrawLayer_Again_FetchesNoTileAgain;
    [Test] Procedure DrawLayer_OnAnotherCanvasOfTheSameKind_DecodesNoTileAgain;
    [Test] Procedure UserAgent_NamesGISlibByDefault;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Function TBlankTilesLayer.GetTile(Level,Xindex,Yindex: Integer): TBytes;
// The header of a PNG, which is all the SVG canvas reads of it
begin
  Inc(Fetches);
  Result := [$89,$50,$4E,$47,$0D,$0A,$1A,$0A,0,0,0,13,Ord('I'),Ord('H'),Ord('D'),Ord('R'),
             0,0,1,0, 0,0,1,0];
end;

////////////////////////////////////////////////////////////////////////////////

Procedure TTilesLayerTests.Setup;
var
  BB: TCoordinateRect;
begin
  FLayer := TBlankTilesLayer.Create;
  FConverter := TWebMercatorPixelConverter.Create(TWgs84CoordinateConverter.Create);
  BB.Left := -10; BB.Right := 10; BB.Bottom := 40; BB.Top := 60;
  FConverter.Initialize(BB,512,512);
end;

Procedure TTilesLayerTests.TearDown;
begin
  FConverter.Free;
  FLayer.Free;
end;

Function TTilesLayerTests.Occurrences(const SubText,Text: String): Integer;
begin
  Result := 0;
  var Position := Pos(SubText,Text);
  while Position > 0 do
  begin
    Inc(Result);
    Position := Pos(SubText,Text,Position+1);
  end;
end;

Procedure TTilesLayerTests.DrawLayer_DrawsEveryVisibleTileOnce;
begin
  var Svg := TSvgCanvas.Create(512,512);
  var Canvas: IGISCanvas := Svg;
  FLayer.DrawLayer(Canvas,FConverter);
  Assert.IsTrue(FLayer.Fetches > 1,'Several tiles are visible');
  Assert.AreEqual(FLayer.Fetches,Occurrences('<use ',Svg.Document),'Each tile drawn once');
end;

Procedure TTilesLayerTests.DrawLayer_Again_FetchesNoTileAgain;
begin
  var Canvas: IGISCanvas := TSvgCanvas.Create(512,512);
  FLayer.DrawLayer(Canvas,FConverter);
  var Fetches := FLayer.Fetches;
  FLayer.DrawLayer(Canvas,FConverter);
  Assert.AreEqual(Fetches,FLayer.Fetches);
end;

Procedure TTilesLayerTests.DrawLayer_OnAnotherCanvasOfTheSameKind_DecodesNoTileAgain;
// An application wraps a new canvas around its bitmap for every paint; a tile decoded
// for one canvas serves any other of the same kind
begin
  var First := TCountingSvgCanvas.Create(512,512);
  var FirstCanvas: IGISCanvas := First;
  var Second := TCountingSvgCanvas.Create(512,512);
  var SecondCanvas: IGISCanvas := Second;
  FLayer.DrawLayer(FirstCanvas,FConverter);
  FLayer.DrawLayer(SecondCanvas,FConverter);
  Assert.AreEqual(FLayer.Fetches,First.Decodes,'Decoded for the first canvas');
  Assert.AreEqual(0,Second.Decodes,'Not decoded again for the second');
end;

Procedure TTilesLayerTests.UserAgent_NamesGISlibByDefault;
begin
  Assert.Contains(FLayer.UserAgent,'GISlib');
end;

initialization
  TDUnitX.RegisterTestFixture(TTilesLayerTests);

end.

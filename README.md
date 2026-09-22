# GISlib

A Delphi library for reading, writing and rendering geospatial vector data, with
raster tile basemaps underneath.

---

## Capabilities

### File formats

GISlib can read and write vector data in three formats:

| Format | Read | Write | Notes |
|---|---|---|---|
| ESRI Shapefile (`.shp`) | ✓ | ✓ | Points, lines and polygons |
| GeoJSON (`.geojson`) | ✓ | ✓ | Points, lines and polygons |
| GeoPackage (`.gpkg`) | ✓ | ✓ | Multiple layers per file; requires FireDAC with the SQLite driver |

### Coordinate systems

`TCoordinateConverter` (`GIS.CoordConv`) converts shape *data* between a projected
coordinate system and geodetic longitude/latitude. It's a stateless transform used
by file readers/writers to interpret and store coordinates, and to report a layer's
CRS identity (`SRID`, `SRSName`, `SRSDefinition` — e.g. for GeoPackage's
`gpkg_spatial_ref_sys`). The library includes four converters out of the box:

- **WGS84 (EPSG:4326)** — latitude/longitude in decimal degrees
- **Dutch Grid (RD New / EPSG:28992)** — the Dutch national coordinate system in metres
- **Web Mercator (EPSG:3857)** — the projection used by Google Maps, Bing and OpenStreetMap, in metres
- **UTM (EPSG:32601–32660 / 32701–32760)** — `TUtmCoordinateConverter.Create(Zone, Hemisphere)`,
  covering any of the 60 worldwide UTM zones in either hemisphere, in metres
  (the Netherlands is zone 31, northern hemisphere)

Additional coordinate systems can be added by subclassing `TCoordinateConverter`.

This is a different concern from the **pixel converter** (`TCustomPixelConverter` /
`TWebMercatorPixelConverter`, see Projection below), which converts between *screen
pixels* and coordinates for a given pan/zoom state. The pixel converter holds a
`TCoordinateConverter` internally so that each rendered layer's native CRS is
reprojected to screen space on the fly — it doesn't change which CRS the underlying
data is stored in.

### Map rendering

Rendering targets `IGISCanvas` (`GIS.Render.Canvas`), a small drawing-surface
interface, so the layer code itself stays free of any UI framework. Framework
adapters implement the interface: `GIS.Render.Canvas.VCL` draws through GDI+.
Wrap a VCL surface with `GISCanvas(MyBitmap)` or `GISCanvas(MyCanvas, Width, Height)`
and hand the result to `DrawLayer`. An FMX or SVG back end can be added as another
implementation without touching the layers.

- Renders vector layers (points, lines, polygons) on any `IGISCanvas`
- Styling per layer through `Style` (`TGISStroke` and `TGISFill`), or per shape by
  overriding `ShapeStyle`
- Colours are `TAlphaColor`, so a layer carries its own alpha
- Point symbols: circle, square, triangle, or an encoded image set through
  `PointImageBytes` and decoded by the canvas
- Polygon holes are cut from a single even-odd path, so whatever lies beneath
  shows through
- Pixel coordinates are not rounded, so output is antialiased
- Layers can be composited with individual opacity

### OpenStreetMap tile overlay

- Downloads and caches OpenStreetMap tiles over HTTP/HTTPS at any zoom level
- Tiles are rendered beneath vector layers using the Web Mercator projection
- Tile cache holds up to 256 tiles in memory, as the encoded bytes they arrived
  as; the canvas decodes them, so no image codec is needed in the layer
- `DrawLayer` takes an `IGISCanvas`, like the vector layers

### Projection

- Built-in Web Mercator pixel converter for map views
- Supports pan, zoom in/out and zoom to bounding box
- Multiple vector layers with different coordinate systems can be rendered on the same Mercator map simultaneously — each layer's converter reprojects its data on the fly

---

## Demo application

The repository includes a demo application that exercises the full library:

- Open ESRI shapefiles, GeoJSON and GeoPackage files as map layers
- Toggle the OpenStreetMap background on or off
- Select a coordinate system for the status-bar coordinate display (WGS84, Dutch
  Grid, Web Mercator, or UTM with a zone picker)
- Per-layer properties panel: visibility, opacity, pen and brush settings, point size and style
- Reorder, remove and save layers
- Export the current map view as a PNG or BMP image

---

## Dependencies

**ESRI Shapefile support** requires the
[Utils](https://github.com/transportmodelling/Utils) repository.
Clone it and add it to your Delphi Library path.

**GeoPackage support** requires FireDAC with the SQLite driver
(`FireDAC.Phys.SQLite`). By default this dynamically loads SQLite3.dll, which
must be present alongside the executable. For a self-contained binary, add
`FireDAC.Phys.SQLiteWrapper.Stat` to your project's uses clause to statically
link SQLite instead (see `Tests\TestGISlib.dpr` for an example).
Both are included in standard Delphi/RAD Studio installations.

---

## Tests

A DUnitX console test project (`TestGISlib`) is included in the `Tests` directory.
It covers coordinate conversion, map projection, geometry operations, polygon
queries, file format round-trips (read-after-write), and rendering. Add
`Source\Utils` and `Source\Render` to the project search path before building.

The rendering tests draw to a bitmap and read the pixels back, which is the only
way to confirm that a polygon hole is genuinely cut out rather than painted over.
They need `Vcl.Graphics` and GDI+, unlike the rest of the suite, so they are
compiled only under `{$IFDEF MSWINDOWS}` and the suite still builds where VCL is
unavailable.

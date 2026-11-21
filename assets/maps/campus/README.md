# Campus geographic data contract (schema 1)

Production geography belongs here. `../fixtures/` is synthetic London test data;
it must never be copied into this directory as real university geography.
The loader selects fixtures only in debug builds with `CAMPUS_MAP_FIXTURES=true`.

Current revision: `2026-11-20-foundation-1`. All GeoJSON uses RFC 7946 WGS84
coordinates **[longitude, latitude]**, with no Z/M coordinate. Distances and
relative building dimensions are metres. Preserve stable IDs when revising a
feature; do not use array indices as IDs. IDs contain letters, digits, `.`, `:`,
`_` or `-`, start with a letter/digit, and are unique within their collection.
`building_id` groups multiple height sections and may be shared across sections.

## Evidence and missing data

The only production point is the University of Balamand campus reference
`[35.7836648, 34.3643747]`, from the **Al Koura Campus** map destination linked by
the [university contact page](https://www.balamand.edu.lb/ContactUs/Pages/ContactUs.aspx).
It is neither a building entrance nor a routing node. Its name and geographic
reference are sourced; the description states the current dataset limitation.

The `camera_bounds` in `campus.json` are an intentionally provisional viewing
envelope. They are not the campus property boundary. No surveyed boundary,
building footprint, height, replacement mask, individual campus destination,
entrance or pedestrian path was available in the repository. Those collections
are empty. A point on a general map is insufficient evidence for an entrance or
a safe walking connection. Routing stays unavailable until verified data arrives.

## Files and fields

Each `.geojson` is a FeatureCollection with a `features` array (empty is valid).
Each feature has `type: Feature`, non-null geometry and object properties.
`source` should identify the survey/orthomosaic/approved inventory, capture date,
and approver; `revision` identifies the data revision, not a runtime timestamp.

| File | Geometry | Required properties | Optional properties |
| --- | --- | --- | --- |
| `boundary.geojson` | Polygon/MultiPolygon | `id`, `source`, `revision` | institutional survey reference |
| `buildings.geojson` | Polygon/MultiPolygon | `id` (section), `building_id` (shared building), `name`, `code`, `category`, `height`, `base_height`, `source`, `revision` | `levels` (positive integer) |
| `replacement_areas.geojson` | Polygon/MultiPolygon | `id`, `building_id`, `approved` (boolean), `source`, `revision` | review notes |
| `destinations.geojson` | Point | `id`, `name`, `code`, `category`, `source`, `revision` | `aliases` (strings), `building_id`, `entrance_ids` (strings), `image` (approved bundled asset path), `description` |
| `entrances.geojson` | Point | `id`, `name`, `destination_id`, `node_id` | `building_id`, provenance |
| `pedestrian_nodes.geojson` | Point | `id`, `type`, `source`, `revision` | `destination_id`, `building_id` |
| `pedestrian_edges.geojson` | LineString | `id`, `from`, `to`, `distance_m`, `type`, `bidirectional` (boolean), `accessibility` | `restricted` (boolean, default false), `slope` (signed rise/run), provenance |

Entrances must be listed by their destination, and reference an existing graph
node at the same location (within 5 cm). `destination_id` on a node, if supplied,
must resolve. Destinations and entrances may reference buildings rendered only
by Mapbox: custom geometry is **not** a prerequisite for search or navigation.

Edge coordinates run from the `from` node to the `to` node; endpoint discrepancy
must be at most 5 cm. `bidirectional=false` permits travel only in that direction.
Internal coordinates preserve curves. An intersection is connected only through
shared, explicitly declared endpoint nodes. Bridges/overpasses must not acquire
connections just because their lines cross in the drawing.

Use `type: stairs` for stairs; other outdoor types can include `path`, `ramp`
and `gate`. `restricted=true` excludes an edge from every walking route. Resolve
any time-dependent or institutional access conditions before publishing a
dataset; the MVP does not evaluate schedules or user entitlements.

`accessibility` is exactly `verified`, `inaccessible` or `unknown`. Only use
`verified` after reviewing the complete edge for wheelchair use. Avoiding stairs
alone does not verify accessibility. The UI explicitly states this limitation.

`distance_m` must be positive and agree with summed WGS84 segment distances
within 3% + 0.5 m. Routing uses recomputed segment lengths as its source of
distance, so stale length attributes cannot change the heuristic's validity.

Building `height` is the top height **above local ground**, not an altitude above
sea level; `base_height` is the lower height above ground, with
`0 <= base_height < height`. A roof section could have `base_height: 16` and
`height: 20`, while the lower section has `base_height: 0`, `height: 16`.
Use separate features with the same `building_id` for sections. Polygon holes
and MultiPolygon components are retained. Never derive unmeasured heights from
appearance. Native terrain alignment is requested for both top and base.

A replacement area must reference valid custom geometry. Only `approved=true`
areas activate clipping and their custom sections. Keep mask geometry separate:
it may need to cover the complete outdated basemap building, not just the new
footprint. Inspect neighboring buildings, trees and labels before approval.
No mask or extrusion is active in the production dataset today.

`campus.json` requires `schema_version: 1`, `id`, `revision`, `name`, `center`,
`camera_bounds: [southwest, northeast]`, `provisional_bounds` and `fixture`.
Update the revision and provenance whenever geography changes. A camera envelope
does not mean off-campus tiles become invisible. A supplied boundary is drawn
as a subtle outline; no invented outside-campus mask is generated.

## Validation and release workflow

From the Flutter repository root:

```powershell
dart run tool/validate_campus.dart
dart run tool/validate_campus.dart assets/maps/fixtures
flutter test test/data/services/campus_dataset_service_test.dart test/domain/services
```

The CLI and runtime share the parser. It rejects malformed geometry types,
invalid/nonfinite coordinates, duplicate IDs, open/degenerate/self-crossing
rings, invalid heights, inconsistent lengths, broken references and orphaned
replacement masks. It reports weak graph components, excluding restricted paths.
It is not a replacement for QGIS/GEOS validity, polygon-hole topology, access
review, real-world safety inspection or directed reachability tests.

## QGIS preparation handoff

1. Obtain the approved Pix4D orthomosaic, capture date, accuracy report, native
   CRS and usage permission. Import it into QGIS without relabeling its CRS.
2. Create a metric working GeoPackage in WGS84 / UTM zone 36N (`EPSG:32636`) for
   Qalhat; reproject inputs correctly. Record any vertical datum separately.
3. Import/digitize surveyed building polygons, courtyard holes and multipart
   sections. Assign stable building/section IDs and measured ground-relative
   heights. Run **Check Validity** and inspect every correction.
4. Digitize replacement masks independently against the current Standard
   basemap. Cover the full obsolete building; avoid adjacent buildings. Leave
   `approved=false` until native device comparison is signed off.
5. Trace only field-verified pedestrian centerlines. Mark stairs, ramps, gates,
   restrictions and unknown accessibility explicitly. Keep real path curvature.
6. Enable vertex/segment snapping and topological editing. Snap and split at
   legitimate junctions. Preserve grade-separated crossings and disconnected
   access areas; do not auto-connect all geometric intersections.
7. Create nodes at edge endpoints and routing decision points, stairs/ramp
   transitions and gates. Set every edge's `from`/`to` to the correct node IDs.
8. Survey each usable entrance; create its node and verified connecting path.
   Link entrances bidirectionally to the destination catalog via IDs. Supply
   multiple doors where appropriate and confirm each door is publicly usable.
9. Calculate `distance_m` from metric geometry, set direction/access attributes,
   and export the seven collections to **EPSG:4326**, decimal longitude/latitude,
   sufficient precision for 5 cm endpoint matching. Drop Z/M values. Keep the
   GeoPackage and orthomosaic as the editable source, outside runtime assets.
10. Run the CLI and tests; inspect component reports, selected-entrance routes,
    one-way paths, stairs and restrictions. Use debug graph rendering to inspect
    IDs. Walk representative routes on campus, measure GPS behavior and verify
    doors/closures/accessibility before approving the data revision.

Reference: [QGIS digitizing and snapping](https://docs.qgis.org/3.44/en/docs/user_manual/working_with_vector/editing_geometry_attributes.html),
[QGIS geometry validation](https://docs.qgis.org/3.44/en/docs/user_manual/processing_algs/qgis/vectorgeometry.html).

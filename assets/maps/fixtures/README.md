# Synthetic development fixture

This small network, destination catalog, extrusion and replacement polygon are
**invented test geometry in London**. They describe no real campus, building,
walkway or accessible route. They are geographically separate from Qalhat.

The fixture includes bidirectional edges, a one-way connection, stairs, a
restricted edge, unknown accessibility and a disconnected destination.
The building and replacement polygon have different geometry to exercise the
selective-rendering contract. The fixture is deliberately opt-in and the screen
always labels it `DEMO · Synthetic London network`. Real GPS navigation is
disabled on this network. Simulation follows the calculated synthetic geometry.

```powershell
flutter run --dart-define-from-file=config/mapbox.local.json --dart-define=CAMPUS_MAP_FIXTURES=true --dart-define=CAMPUS_MAP_DEBUG_GRAPH=true
```

In the Map tab, choose **Browse places → Demo east destination → Directions**,
select **Demo west entrance door**, find a route, then **Simulate this route**.
Use Pause/Resume and 1×/2×/4× controls. End navigation restores explore controls.
Both fixture selection and graph debug rendering are disabled in release builds.
Neither is exposed as a preference to ordinary users.

The production schema and GIS handoff are in [the campus data contract](../campus/README.md).

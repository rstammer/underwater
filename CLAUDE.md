# underwater — 🐠 DragonRuby-Spiel

Ein 2D-Pixel-Art-Spiel mit **DragonRuby GTK**, in dem ein Taucher die
Unterwasserwelt erkundet. Erstes DragonRuby-Spiel, aus Spaß am Game-Dev-Lernen.

Repo: https://github.com/rstammer/underwater

> **Diese Datei ist die Landkarte.** Sie soll reichen, um ohne Alt-Kontext
> wieder einzusteigen. Roadmap & offene Ideen: siehe [`TODO.md`](TODO.md).

## Lokales Setup (Engine)

Die **DragonRuby-Engine ist bewusst NICHT versioniert** — alle Engine-Dateien
stehen im `.gitignore`. Versioniert sind nur `app/`, `tests/`, `bin/`,
`sprites/`, `sounds/`, `README.md`, `open-source-licenses.txt`, `font.ttf`.

DragonRuby ist lizenzpflichtig (Kauf via itch.io / dragonruby.org). Nach einem
frischen Checkout muss die Engine einmalig in diesen Ordner entpackt werden:

1. DragonRuby GTK (macOS) von itch.io herunterladen & entpacken.
2. Den **Inhalt** von `dragonruby-macos/` (Binary `dragonruby`, `docs/`,
   `samples/`, `.dragonruby/`, `font.ttf` …) in dieses `underwater/`-Verzeichnis
   kopieren — **ohne** die Sample-`mygame/`. Die Engine-Dateien liegen dann neben
   `app/` und werden alle vom `.gitignore` ignoriert.
3. Zuletzt eingerichtet mit einem Build vom **2026-07-04** (Universal-Binary,
   arm64 + x86_64).

## Starten & Testen

```sh
./dragonruby .                # Spiel starten (aus underwater/ heraus)
bin/test                      # ganze Test-Suite (tests/all_tests.rb)
bin/test tests/diver_tests.rb # einzelne Test-Datei
```

Game-Ordner-Root = Repo-Root (enthält `app/`); DragonRuby lädt `app/main.rb` als
Entry-Point. (Das `./dragonruby app` in der README.md ist veraltet — `.` ist
korrekt.)

## Architektur

Das gesamte Spiel lebt in **`class Game` mit `attr_dr`** (in `app/main.rb`).
`attr_dr` liefert `state`/`inputs`/`outputs`/`grid`/`args`, ohne `args`
durchzureichen. Top-Level nur `boot`/`tick`/`reset`, die an ein `$game`-
Singleton delegieren; `boot` initialisiert `args.state = {}` (kein nil-Auto-
Init). Aller Spiel-State liegt in `args.state` (kein bare Top-Level-`@ivar`).

- `app/main.rb` — `class Game` (Loop + Helfer) + `boot`/`tick`/`reset`
- `app/scenes/` — `title`/`area1`/`area2`/`game_over`, **reopenen `class Game`**
  und definieren `<scene>_tick`; Dispatch via `send("#{state.game_scene}_tick")`.
  `area1`/`area2` rendern dieselbe kontinuierliche, durchscrollende Welt
  (`render_underwater`) und sind nur noch Sektor-Labels; eine eigene „surface"-
  Szene gibt es **nicht mehr** — Oberfläche wie Seitwärts-Erkundung sind Teil
  der durchgehenden Kamera-Welt (s. Kamera unten).
- `app/entities/` — `diver` (Spieler), `dark_shark`, `sloppy_scalar` — eigene
  Klassen, bekommen `args` übergeben, lesen Position aus `state`
- `app/world/` — **Welt-System** (s. u.): `rng`, `noise`, `biome`, `world`,
  `world_generator`, `static_worlds`, `island_world` (die handgebaute Insel mit
  Höhle), `world_stream` (reopenet `Game`; welche Segmente es gibt, welche
  sichtbar sind, Welt→Screen-Offsets, Fauna-Spawn), `world_renderer` (reopenet
  `Game`; zeichnet Wasser, Himmel, Boden, Fels, Luftblasen, Deko, Boot),
  `fog_of_war`
- `app/ux/` — `hud` (reopenet
  `Game`: O2- und Anzug-Balken, Locator, Tiefenanzeige, Debug-Readout)
- `sprites/` — Pixel-Art (SpearFishing by Szym, PixelArt Diver by Daniel Kole)
- `sprites/decor/` — selbst generierte Pixel-Art (Blase, Seestern, Koralle,
  Seetang, Fels, Boot; für die Inseln: Palme groß/klein, Busch, Gras, Treibholz,
  Krabbe, Fahne, Möwe)
- `tools/make_decor_sprites.rb` — erzeugt diese PNGs aus ASCII-Art + Palette,
  nur mit Ruby-Stdlib (`ruby tools/make_decor_sprites.rb sprites/decor`).
  Läuft in **MRI**, nicht in DragonRuby — reines Autoren-Werkzeug.
- `sounds/` — Audio

### Spiel-Loop (`Game#tick`)

Ein Tick läuft **in dieser Reihenfolge** — sie ist bewusst so und teils bugfix-
kritisch:

1. `initialize_game` (nur beim ersten Tick, `unless state.initialized`)
2. `update_scene` — setzt `state.game_scene` (State-Machine, s. u.)
3. `update_sprint` — setzt `state.sprinting` + `state.speed` (vor jeder Bewegung)
4. `update_characters` — Hai/Skalare ticken; **Hai-Kollision (in Welt-Koordinaten,
   auf `depth_y`) → game_over (`death_cause = :eaten`)**
5. `basic_movements_per_tick` — Tastatur-Input, Auftrieb/Sinken (verändert
   `depth_y`), `angle`
6. `update_depth_and_camera` — clampt `depth_y` (Meeresgrund ↔ Atem-Höhe an der
   Wasserlinie), zieht `camera_y` weich (`CAMERA_EASE`) an sein Ziel (folgt dem
   Taucher, Dead Zone **relativ zum Boden unter ihm**) und projiziert auf die
   Screen-Position `player_y = depth_y - camera_y`
7. `update_oxygen` (außer wenn `game_paused?`) — Drain/Refill, leer → ertrinken
8. `send("#{state.game_scene}_tick")` — rendert die aktive Szene (kamera-versetzt)
9. `render_diver` (außer pausiert) — Taucher-Sprite + Fog
10. `render_panel` — **HUD ganz zuletzt**, sonst überdeckt die Szene/der Fog den
   O2-Balken (das war ein realer Bug)

Render-Layering in DragonRuby: `solids < sprites < labels`; innerhalb eines
Buckets bestimmt die Einfüge-Reihenfolge das Layering. Deshalb HUD am Ende.

### Scene-State-Machine (`state.game_scene`)

Es gibt **keinen** Szenenwechsel mehr — Auf-/Abtauchen *und* seitliches Erkunden
sind eine durchgehende Kamerafahrt (s. Kamera). `game_scene` steuert nur noch das
**Sektor-Label** (für HUD/Biom) plus die pausierten Screens:

```
   area1 ⇄ area2   (diver_global_x < 1281 → area1, sonst area2; nur ein Label —
                    beide rendern dieselbe kontinuierliche, durchscrollende Welt)

   title ──[Leertaste/z/j/A]──► area1 (Spielstart, an der Oberfläche/atmend)
   <überall> ──[Hai / O2 leer]──► game_over ──[Leertaste]──► area1 (reset_game)
   <überall> ──[ESC]──► title
```

`title` und `game_over` sind **pausiert** (`game_paused?`): kein O2-Drain, kein HUD.

### Kamera (beide Achsen, kontinuierlich)

Position ist **eine durchgehende Welt-Koordinate** pro Achse; eine Kamera folgt
dem Taucher und projiziert auf die Screen-Position (`update_depth_and_camera`):

- **Welt-Position:** `state.depth_y` (`WATERLINE_Y` = `SCREEN_HEIGHT` =
  Wasserlinie, darüber Himmel; nach unten offen — der Grund liegt je nach Ort auf
  ganz unterschiedlicher Tiefe) und `state.diver_global_x` (unbegrenzt, Single
  source of truth für horizontal).
- **Kamera:** `state.camera_y` = Welt-`y` am **unteren** Rand, Ziel ist
  `max(depth_y - CAMERA_ANCHOR, camera_floor_y - FLOOR_VIEW_MARGIN)` → **Dead Zone
  am Boden, die dem Bodenprofil folgt** (deshalb relativ statt fix bei 0).
  `camera_floor_y` liest `WorldGenerator.smooth_floor_y_at` — den Boden als
  **glatte Kurve** (alles außer Terrassen und Jitter) — aber nie mehr als
  `CAMERA_FLOOR_SLACK` über dem echten Sand: an einer Abgrundwand weichen die
  beiden um Hunderte px ab, und dann gilt der Sand. Der rohe Sand lässt das
  Bild bei jeder Kerbe ruckeln; nur die *grobe* Form (Shelf+Basin) wiederum liegt
  im Abgrund weit über dem echten Grund und klemmt den Taucher an die Unterkante. Zusätzlich **easet** sie mit `CAMERA_EASE`
  ans Ziel; `center_camera` setzt sie hart (Spawn/Reset).
  `state.camera_x` = Welt-`x` am **linken** Rand, zentriert den Taucher
  (`diver_global_x - CAMERA_ANCHOR_X`) → er steht bildschirm-mittig, die Welt
  scrollt seitlich.
- **Projektion:** `screen = welt - camera`; der Taucher landet auf
  `state.player_x/player_y` (Diver + Fog lesen daraus, unverändert).
- **Rendering:** Der Renderer zeichnet alle **sichtbaren Segmente**
  (`visible_world_indices` — meist das Chunk des Tauchers + ein Nachbar), jedes
  um `chunk_offset_x(index)` und `camera_y` verschoben, sodass der Boden über
  Grenzen **durchscrollt**. Welten sind pro Index gecacht (`world_at`/
  `world_cache`). Fauna liegt im aktuellen Chunk (`place_in_current_chunk`).
  **Kein Sprung, kein Raum-/Chunk-Flip.** (Wasser/Himmel/Fog bleiben das aktuelle
  Biom über den ganzen Screen.)

## Welten (prozedural + statisch)

Die Unterwasser-Szenen sind **prozedural generiert und in Segmente (Chunks)
geteilt**. Trennung von *Beschreibung* und *Rendering*:

- **`World`** (`app/world/world.rb`) — reine Daten: Boden (`floor` = **Welt-`y`
  pro Spalte**, `COLUMN_WIDTH = 8` px), Deko-Platzierungen (`decorations`),
  `biome`, dazu **optional** `roof` und `air_pockets` (s. u.). Rührt nie
  `outputs` an → testbar. `deepest_y` = tiefster Punkt.
- **`Rng`** — seedbarer xorshift-PRNG: gleiche Seed → gleiche Welt (deterministisch,
  stabil beim Zurückschwimmen, unit-testbar).
- **`Noise`** — deterministisches 1-D-Value-Noise über der **Welt-x-Achse**:
  `Noise.value(x, wavelength, seed)` (smoothstep-interpoliert, 0..1) und
  `Noise.jitter(cell, seed)` (roh, **nicht** interpoliert → gezackt).
- **`Biome`** — Themen (Sandbank/Kelpwald/Riff/Tiefsee): Wasserpalette, `fog`-Stärke,
  Boden-Farben, Deko-Dichte, Fauna (Fischanzahl/-farben, `shark`).
- **`WorldGenerator.floor_y_at(world_x)`** — **die eine Wahrheit über den
  Meeresgrund.** Kein Würfeln pro Segment, sondern eine Funktion der Welt-`x`,
  geschichtet aus mehreren Noise-Oktaven: `shelf` (sehr breit — ganze Regionen
  sind Bank oder fallen ab), `basin` (Becken), `crag` (ridged Noise → felsige
  Spitzen), `dune` (kleines Relief), `rough` (Jitter pro 16-px-Zelle → zerklüftete,
  pixelige Sandkante). Alles rastet auf `FLOOR_STEP = 8` px → **Pixel-Terrassen**
  statt glattem Dach. Gesampelt wird **einmal pro Terrasse** (`terrace_start`),
  und Terrassen sind **unterschiedlich breit** (8–64 px, `TERRACE_BLOCK` /
  `TERRACE_WIDTHS`) — sonst sähe der Boden aus wie ein regelmäßiger Kamm.
  `SHELF_BIAS`/`BASIN_BIAS` (>1) schieben die Verteilung Richtung flach: meist Bank, ab und zu ein echter Graben (~80 m … ~220 m).
  Weil es eine Funktion der Welt-Position ist, passen **Nachbarsegmente
  nahtlos** aneinander.
- **`WorldGenerator.generate(index)`** — sampelt diese Funktion für die Spalten
  des Segments und würfelt (per `Rng`) Deko dazu; Biom pro Index gemischt gewählt.
- **`StaticWorlds`** — Registry, um einzelne Indizes mit **handgebauten** Welten zu
  überschreiben (`world_for` = statisch ?: generiert). Der „Mix"-Hook; aktuell leer.
- **Höhlen: `roof` + `air_pockets`.** Eine Heightmap kann **keine** Höhle
  beschreiben (sie kennt nur „Sand bis hierhin"). Deshalb kann eine Welt pro
  Spalte eine **zweite Fels-Spanne** tragen: `roof[col] = { ceiling:, crown: }` —
  Fels von `ceiling` (Unterkante, wo der Taucher anstößt) bis `crown` (Oberkante);
  `nil` = offenes Wasser. Dazu `air_pockets`: Rechtecke eingeschlossener Luft,
  deren **Unterkante die Wasseroberfläche darin** ist (`air_line_at`, `air_at?`).
- **`IslandWorld`** — eine Insel: wird **auf** eine generierte Welt gestempelt
  (`IslandWorld.build(world)`), nicht statt ihrer — so bleiben die Segmentränder
  unangetastet und nahtlos. Es ist eine **Klasse pro Insel**: Spannweite (`span`)
  und Höhe (`peak`) werden aus dem Segment-Index gewürfelt, die Silhouette
  (`crown_y`) ist Noise **an der Welt-Position** mal einer Hüllkurve
  (`envelope`), die den Fels an beiden Enden ans Wasser bindet — deshalb sieht
  **keine Insel aus wie die andere**. Gelesen wird pro Terrasse
  (`WorldGenerator.terrace_start`), das gibt Plateaus und Schultern statt einer
  glatten Kuppe; nach oben deckelt `CROWN_MAX`, sonst schneidet der Bildrand den
  Gipfel ab.
- **Der Tunnel** ist pro Insel anders: der Boden (`tunnel_floor_y`) ist eine Rampe
  zwischen dem Sand beider Mündungen **plus ein Sack oder Buckel** (`@sag`, an den
  Enden null — deshalb keine Stufe beim Rein-/Rausschwimmen), die Höhe
  (`tunnel_height`) wechselt zwischen **Engstelle und Halle**
  (`TUNNEL_MIN`..`TUNNEL_MAX`, nie enger als `MIN_GAP`), und unterwegs heben
  **ein bis zwei Luftkammern** (`chambers`, Position gewürfelt) die Decke — dort
  taucht man auf und atmet. Im Korridor wächst Seetang, Koralle, Fels
  (`tunnel_decor`).
- **Bewuchs oben** steht auf den **Plateaus** (`plateaus` = Läufe gleicher
  Kronenhöhe; ein Platz je `PLANT_SPACING` px): Treibholz und Krabben am Strand,
  weiter oben, was in die Lücke passt. Geprüft wird der **Fuß** der Pflanze
  (`base_width`, ~⅓ der Sprite-Breite) — Wedel dürfen überhängen, Stämme nicht.
  (Vorher standen Palmen in festen Abständen und damit halb über der Kante.)
  Möwen kreisen **weit draußen über dem Wasser** (`gulls`/`GULL_OFFSETS`, beide
  Seiten, 320–1600 px vor der Küste): Vögel am Horizont sind der erste Hinweis,
  dass da Land ist — über dem Gipfel wären sie außerhalb des Bildes. Auf manchen
  Gipfeln steckt eine Fahne. Die Bewegung
  von Möwe und Krabbe macht `decor_drift` im Renderer.
- **Wo die Inseln liegen:** `ISLAND_COUNT` Stück pro Runde, ausgewürfelt in
  `roll_island_sectors` (verschiedene Sektoren, beide Richtungen), gemerkt in
  `state.island_sectors`. Die **erste landet immer nah** (`1..ISLAND_NEAR_SECTOR`),
  damit man beim Rausschwimmen in *irgendeine* Richtung auf eine trifft; die
  übrigen liegen weiter draußen (`ISLAND_MIN_SECTOR`..`ISLAND_MAX_SECTOR`).
- **`world_stream.rb`** (reopenet `Game`) — die Segment-Verwaltung: `current_world`
  wählt das Chunk des Tauchers (`world_index = diver_global_x / SCREEN_WIDTH`) für
  Biom/Fauna/Fog, `world_at`/`world_for` cachen bzw. bauen Segmente,
  `visible_world_indices` sagt, was im Bild ist, `chunk_offset_x`/
  `place_in_current_chunk` rechnen Welt→Screen, `spawn_fauna` besetzt ein neues
  Segment — jeder Fisch bekommt dabei den **freien Wasserstreifen** seiner Höhe
  mit (`open_water_span`, über sein ganzes Driftband geprüft), sonst schwimmen
  sie durch Inseln und Höhlenwände hindurch.
- **`world_renderer.rb`** (reopenet `Game`) — zeichnet daraus das Bild.
  `render_world` malt **kamera-versetzt** (`camera_x`/`camera_y`): Wasser
  (`world_water` — füllt den ganzen Screen, jede Bande nimmt ihre Farbe aus der
  Welt-Tiefe, die sie gerade zeigt), darüber Himmel (`sky_fill`, deckt alles über
  der Wasserlinie ab), Wasserlinie (`surface_line`), dann für **jedes sichtbare
  Segment** (`visible_world_indices`, gecacht via `world_at`/`world_cache`) Boden
  + Deko — jeweils um `chunk_offset_x(index)` verschoben, sodass die Welt über
  Grenzen durchscrollt. `world_floor` fasst gleich hohe Spalten zu **Terrassen**
  zusammen (`each_terrace`, ~3x weniger Rects) und füllt jede `FLOOR_FILL_DEPTH`
  px nach unten (der Boden kann beliebig tief liegen), plus hellere Kappe und
  Tönung **nach Höhe** (Schichten/Strata, nicht pro Spalte). Boot (`home_boat`) wenn Segment 0 sichtbar
  (`home_visible?`), dazu die Willkommens-Karte (`render_boat_hint`) — **nur**,
  wenn man wirklich daneben treibt (`at_the_boat?`). Fauna: `spawn_fauna` streut den Schwarm in die
  **Wassersäule des jeweiligen Segments** (über dessen eigenem Boden, `FAUNA_BAND`),
  `fauna_visible?`/`shark_present?` — Fisch **und** Hai an der Oberfläche
  (`breathing?`) unsichtbar.
- **Fels über dem Wasser sieht anders aus als Fels darin.** `world_roof` zeichnet
  nur den **sichtbaren** Ausschnitt eines Slabs und nimmt sein Licht aus dessen
  Oberkante (`roof_light`): in der Sonne hell, unter Wasser über `ROOF_FADE`
  abdunkelnd, im Inneren eines Berges `CAVE_DIM`. Bricht ein Slab die Oberfläche
  (Insel), bekommt er eigenes, warmes Gestein (`ISLAND_ROCK`) statt der Biom-
  Palette — sonst trägt eine Insel im Tiefsee-Sektor deren Schiefergrau — plus
  einen grünen Streifen (`GREEN`/`GREEN_CAP`) auf der Kuppe.
- **Licht & Tiefe:** `light_at(world_y)` ist die gemeinsame Tageslicht-Kurve
  (voll bis `WATER_TWILIGHT`, dann Abfall bis `WATER_ABYSS`, max. `ABYSS_DIM`
  geschluckt). Wasserfarbe (`water_color_at`), Sandfarbe **und** Fog
  (`fog_radius`/`fog_color`) lesen daraus → **je tiefer, desto dunkler und enger**.
  Zusätzlich gilt weiter: **hellere Biome sehen weiter** als die Tiefsee.
- **Home & Locator:** `at_home?` (`world_index == 0`) — Taucher im Startsegment;
  das Boot zeigt sich, sobald Segment 0 im Bild ist. Der dezente Locator (oben
  rechts) zeigt Sektor + Tiefe, hinter `locator?` (später an ein Gerät koppelbar).

Deko-Sprites für Welten liegen in `sprites/decor/` (seaweed/coral/starfish/rock).

## State-Modell (`args.state`)

Der komplette Spielzustand — Property-Namen dürfen **nicht** wie Methoden heißen
(s. Gotchas):

| Key | Bedeutung |
|-----|-----------|
| `initialized` | Flag, ob `initialize_game` schon lief |
| `game_scene` | aktiver Screen (`title`/`area1`/`area2`/`game_over`) — steuert Dispatch |
| `diver_global_x` | **horizontale Welt-Position (Single source of truth).** Unbegrenzt; `world_index = diver_global_x / SCREEN_WIDTH` |
| `depth_y` | **vertikale Welt-Position (Single source of truth).** `WATERLINE_Y` = Wasserlinie, darüber Himmel; nach unten offen (Gräben liegen weit unter `0`, `0` ist nur das historische „Grund"-Niveau). Hoch schwimmen = `depth_y` steigt = flacher |
| `camera_x` / `camera_y` | Welt-`x`/`y` am linken/unteren Screenrand; folgen dem Taucher (`camera_x` zentriert; `camera_y` easet ans Ziel, Dead Zone **relativ zum Boden**) |
| `player_x` / `player_y` | **abgeleitete** Screen-Position des Tauchers = `global_x/depth_y - camera_x/y`; jeden Tick in `update_depth_and_camera` gesetzt (Diver + Fog lesen daraus) |
| `world_cache` | Hash `{index → World}` — memoisiert Segmente fürs kontinuierliche Rendern der Nachbar-Chunks; wird bei jedem Rundenstart geleert |
| `island_sectors` | Segment-Indizes, auf denen diese Runde die Inseln liegen (pro Runde gewürfelt) |
| `direction` | `:left` / `:right` (Blickrichtung, hält beim Idle) |
| `angle` | Sprite-Neigung beim Diagonal-Schwimmen |
| `sprinting` | `true`, solange die Sprint-Taste gehalten wird *und* geschwommen wird |
| `speed` | effektive Geschwindigkeit dieses Ticks (`Diver::SPEED`, beim Sprint ×`SPRINT_MULTIPLIER`); von Movement *und* `Diver#tick` gelesen |
| `oxygen` | 0..`OXYGEN_MAX`; leer → ertrinken |
| `suit` | 0..`SUIT_MAX` — Zustand des Anzugs; nimmt unterhalb `SUIT_DEPTH_LIMIT` Schaden, bei 0 → zerdrückt |
| `death_cause` | `:eaten` (Hai) / `:drowned` (O2 leer) / `:crushed` (Anzug hin) / `nil` — steuert Game-Over-Text |
| `diver` / `shark` | Entity-Instanzen (`Diver` / `DarkShark`) |
| `fish` | Array von `SloppyScalar` — Schwarm des aktiven Bioms; Positionen als **lokale** Chunk-`x` (0..`SCREEN_WIDTH`) + Welt-`y`, gerendert via `place_in_current_chunk`. Jeder Fisch patrouilliert nur seinen freien Wasserstreifen (`from_x`/`to_x` aus `open_water_span`, dreht an den Enden) und driftet `DRIFT` px um seine Spawn-Tiefe (kein Wrap!) |
| `dark_shark` | `{x:, y:}`-Hash der Hai-Position: **lokale** Chunk-`x` (wrappt bei `SCREEN_WIDTH`) + Welt-`y` (von der `DarkShark`-Entity in `to_h` gelesen). Bei jeder neuen Runde kommt er auf **Taucher-Tiefe** ±`SHARK_PATROL_SPREAD` rein |
| `active_world` / `active_world_index` | gecachtes aktuelles Chunk (Biom/Fauna) + sein Segment-Index (Neu-Setzen nur bei Segmentwechsel) |

Koordinaten-Merksatz: **hoch schwimmen = `depth_y` steigt = flacher; seitlich =
`diver_global_x`.** Wasserlinie bei `WATERLINE_Y`, der Grund liegt je nach Ort
irgendwo zwischen `WorldGenerator::FLOOR_CEILING` und `FLOOR_BOTTOM` (nicht mehr
fix bei 0!); `player_x`/`player_y` sind nur die kamera-projizierten
Screen-Positionen und werden nicht direkt gesetzt.

## Spielmechanik

- **Rundenstart (`spawn_at_surface`):** Jede Runde (erster Start *und* Neustart
  nach game_over) beginnt an der Wasserlinie neben dem Boot (`SURFACE_BOAT_X`),
  Kopf raus/atmend (`depth_y = WATERLINE_Y - SURFACE_FLOAT_DEPTH`). Am Startsegment
  schaukelt das **Tauchboot** (`home_boat`/`BOAT_SPRITE`) an der Wasserlinie — ein
  kleines Motorboot mit Kajüte, Außenborder und **Badeleiter**, die ins Wasser
  reicht (gedacht als späteres Zuhause zum Anlegen/Einsteigen). Liegt man daneben,
  erscheint eine kleine Karte über dem Boot (`render_boat_hint`): „Dein Boot —
  hier bist du zu Hause / Anzug wird repariert, Luft füllt sich auf". Sonst
  bleibt der Bildschirm frei von Text (die alten Szenen-Titel sind weg).
- **Bewegung (kontinuierlich, beide Achsen):** Es gibt keinen Übergang mehr — der
  Taucher bewegt sich in `depth_y` (vertikal) und `diver_global_x` (horizontal),
  die Kamera scrollt die Welt weich durch. Vertikal: nahe dem Grund ruht die
  Kamera (Dead Zone, die dem Bodenprofil folgt), höher folgt sie und Wasserlinie
  + Himmel kommen ins Bild.
  Horizontal: der Taucher bleibt bildschirm-mittig, die Segmente scrollen seitlich
  durch (Nachbar-Chunks nahtlos). `update_depth_and_camera` clampt `depth_y`
  zwischen Meeresgrund (`sea_floor_y`, ruht auf dem Sand) und Atem-Höhe
  (`WATERLINE_Y - SURFACE_FLOAT_DEPTH`, nur der Kopf ragt raus). Er kann das
  Wasser nie ganz verlassen; horizontal ist die Welt (noch) unbegrenzt.
- **Nur Wasseroberfläche oben:** An der Oberfläche (`breathing?`) sind Fisch und
  Hai unsichtbar (`fauna_visible?`/`shark_present?`) — man sieht nur die
  Wasseroberfläche + Himmel.
- **Auftrieb:** Der Taucher ist negativ schwimmfähig und `depth_y` sinkt langsam
  (0.15/Tick), solange man nicht ↑ hält. **Ausnahme:** ragt sein Kopf aus dem
  Wasser (`breathing?`, `depth_y + Diver::HEIGHT >= WATERLINE_Y`), sinkt er nicht
  — Ruhe-/Atem-Modus. Sobald er wieder untertaucht, sinkt er weiter.
- **Fels ist fest.** Seitwärts kommt der Taucher nur in Wasser, in das er
  wirklich passt (`swim_sideways`/`blocked?`): zu hoher Sand, eine Höhlendecke
  vorm Gesicht oder ein zu schmaler Spalt halten ihn auf. Kanten bis
  `SOLID_STEP_UP` (48 px) gleitet er hoch — natürliches Gelände hat p99 = 32 px,
  also bremst nur echter Fels. **Eine Wand ist nie eine Falle:** hochschwimmen
  geht immer.
- **Inseln & Höhlen:** `ISLAND_COUNT` bewachsene Inseln ragen aus dem Wasser, jede
  mit eigener Form und Größe — eine davon in Sichtweite (1–3 Sektoren), der Rest
  weiter draußen. Drüber kommt man nicht — der Weg führt **unten durch den Tunnel**,
  mit einer **Luftkammer** auf halber Strecke, in der man auftaucht und den
  Sauerstoff auffüllt.
- **Anzug & Druck (die zweite Uhr):** Der Anzug ist für `SUIT_DEPTH_LIMIT` (100 m)
  ausgelegt. Tiefer nimmt er Schaden, **linear mit den Metern darunter**
  (`update_suit`) — 120 m kostet fast nichts, 190 m die Hälfte, ab ~230 m stirbt
  man auf dem Rückweg (`death_cause = :crushed`). Luft begrenzt, wie *lange* man
  unten bleibt; der Anzug, wie *tief* man geht. Repariert wird **nur am Boot**
  (`at_the_boat?`, `SUIT_REPAIR`) — das gibt dem Boot seinen Zweck. HUD: Anzug-
  Balken **unter** dem O2-Balken (`render_gauges`), er warnt mit
  „Anzug — Druck!", sobald man unter der Auslegungstiefe ist.
- **Sauerstoff:** Drain unter Wasser (`OXYGEN_DRAIN`/Tick, ~3 min). Refill **nur**
  wenn `breathing?` — Kopf über *einer* Wasseroberfläche: der des Meeres **oder**
  der in einer Luftkammer. Leer → `game_over` /
  `:drowned`. O2-Balken-HUD wird bei <30 % rot.
- **Sprint:** Sprint-Taste (Leertaste) halten *während* man schwimmt →
  Geschwindigkeit ×`SPRINT_MULTIPLIER` und O2-Verbrauch ×`SPRINT_MULTIPLIER`.
  Reine Entscheidung in `sprint_active?` (nie in pausierten Szenen), Effekt über
  `state.speed` / `oxygen_drain`. Taste im Stehen kostet nichts. Kein Konflikt
  mit `fire_input?` (das nutzt `key_down`, nur in pausierten Szenen).
- **Fog of War:** unter Wasser aktiv (`FOG_OF_WAR`), an der Oberfläche
  (`breathing?`) aus (dort ist Tageslicht).
- **Hai:** in Hai-Biomen (Tiefsee) unterwegs; **Kollision in Welt-Koordinaten**
  (Taucher auf `depth_y` vs. Hai-Welt-`y`, `intersect_rect?`) → `game_over` /
  `:eaten`. Er patrouilliert auf **Taucher-Tiefe** (`shark_patrol_y`, geclampt in
  die Wassersäule via `in_water`) — also auch im Graben gefährlich. **Fels stoppt
  ihn wie den Taucher:** vor der Insel dreht er um (`shark_blocked?`/`solid_at?`,
  `dark_shark.dir`, Sprite spiegelt sich) statt hindurchzuschwimmen.
- **Maßstab:** `PIXELS_PER_METRE = 14`. Der Anzug deckelt die *Meter*, also gibt
  ein großzügiger Meter dem Meer den Platz, sich tief anzufühlen: die Wassersäule
  ist im Median ~890 px — mehr als ein Bildschirm, man sieht von oben also nicht
  auf den Grund.
- **Tiefe & Profil:** Der normale Meeresgrund liegt bei ~20–95 m, also **innerhalb**
  dessen, was der Anzug aushält; das Relief ist zerklüftet/terrassiert. Dazwischen
  reißt der Schelf immer wieder auf: **Abgründe** (`chasm_at`) fallen auf ~150–240 m
  — sichtbar, anschwimmbar, aber mit diesem Anzug nicht auszuhalten. Sie sind
  schmal und häufig genug, dass man in beide Richtungen binnen weniger Sektoren
  auf einen trifft (ca. ein Fünftel des Meeresbodens liegt jenseits der Grenze). Je tiefer, desto dunkler das Wasser und enger der Fog (`light_at`).

### Tuning-Konstanten

`app/world/island_world.rb` (Inseln): `SPAN_MIN/MAX`, `PEAK_MIN/MAX`, `CROWN_MAX`,
`SHORE_LIP`, `SHORE_HEIGHT`, `TUNNEL_HEIGHT`, `DOME_SPAN`, `DOME_RISE`,
`AIR_DEPTH`, `CROWN_STEP`, `PLANT_SPACING`, `MARGIN`, `GULL_HEIGHT`, `SCALES`;
Tunnel: `TUNNEL_MIN/MAX`, `TUNNEL_WAVE`, `MIN_GAP`, `SAG_MAX`, `DOME_SPAN`,
`DOME_RISE`.

`app/main.rb`: `WATERLINE_Y=SCREEN_HEIGHT`, `CAMERA_ANCHOR=SCREEN_HEIGHT/2`,
`CAMERA_ANCHOR_X=SCREEN_WIDTH/2`, `FLOOR_VIEW_MARGIN=240`, `CAMERA_FLOOR_SLACK=60`,
`CAMERA_EASE=0.1`,
`SURFACE_FLOAT_DEPTH=20`, `PIXELS_PER_METRE=14`, `OXYGEN_MAX=100`, `OXYGEN_DRAIN=0.009`,
`OXYGEN_REFILL=1.0`, `SUIT_MAX=100`, `SUIT_DEPTH_LIMIT=100`, `SUIT_DRAIN=0.0025`,
`SUIT_REPAIR=0.4`, `BOAT_REACH=160`, `SPRINT_MULTIPLIER=2`, `SHARK_PATROL_SPREAD=200`,
`SOLID_STEP_UP=48`, `ISLAND_MIN_SECTOR=2`, `ISLAND_MAX_SECTOR=10`, `ISLAND_NEAR_SECTOR=3`,
`ISLAND_COUNT=3`,
`FOG_OF_WAR=true`, `DEBUG=false`.

`app/world/world_generator.rb` (Geländeform): `FLOOR_TOP_Y`, `SHELF_*`,
`BASIN_*`, `CHASM_*`, `CRAG_*`, `DUNE_*`, `ROUGH_*`, `FLOOR_STEP`, `TERRACE_BLOCK`,
`TERRACE_WIDTHS`; `DIVER_FOOTPRINT` (main.rb) = wie breit der Taucher Grund fühlt.
`app/world/world_renderer.rb` (Optik): `WATER_TWILIGHT`, `WATER_ABYSS`,
`ABYSS_DIM`, `WATER_BANDS`, `FLOOR_FILL_DEPTH`, `ISLAND_ROCK`, `GREEN`,
`GREEN_CAP`, `CAVE_DIM`, `ROOF_FADE`; `FAUNA_BAND` in `world_stream.rb`.
Per Playtest justierbar — siehe Notizen in [`TODO.md`](TODO.md).

## Tests

DragonRuby bringt ein **eigenes Unit-Test-Framework** mit (kein Minitest/RSpec —
das läuft in MRI, nicht in DRs mruby-Runtime). Tests sind Klassen mit Methoden
`def test_x(args, assert)` und `assert.equal!` / `assert.true!` / `assert.false!` /
`assert.not_equal!`. Sie laufen headless **in der echten Runtime**, d. h. `args`,
`attr_dr` und der Hash-Dot-Access funktionieren.

- Tests liegen in `tests/`; `tests/all_tests.rb` `require`t alle Dateien.
- `bin/test` parst den Output und liefert einen **echten Exit-Code** (DRs `--test`
  gibt immer 0 zurück, auch bei Fehlschlag → CI-untauglich ohne Wrapper).
- Entities/World/UX werden mit einem echten `args` bzw. Stubs unit-getestet;
  `Game` wird integrativ getestet (`Game.new` + `game.args = args`).
- Dateien mit führendem `_` ignoriert der Runner — Namensschema `*_tests.rb`.
- **TDD:** erst der fehlschlagende Test, dann Implementierung
  (RED → GREEN → REFACTOR).

## Konventionen

- Code und Commit-Nachrichten in English; Commits ohne Tool-/AI-Hinweise
- Requires in `main.rb` immer relativ zum Game-Root mit `app/`-Prefix,
  z. B. `require "app/scenes/title.rb"`
- **Kein bare Top-Level-`@ivar`** — State gehört in `args.state`
- Massen-Rechtecke als `path: :solid`-Sprites rendern, nicht `outputs.solids`

## Gotchas & Lektionen (nicht nochmal reintappen)

- **`Integer / Integer` ist in DragonRuby ein `Float`.** `(a + b) / 2` liefert
  `64.5` — als Array-Index gelesen wird daraus stillschweigend die falsche
  Spalte, und ein Vergleich wie `col >= 64.5` verschiebt einen ganzen Bereich um
  eine halbe Spalte. Für Spalten, Indizes und Segmente **immer `idiv`**. (Genau
  so ist die Luftkammer einmal neben ihrer eigenen Luftblase gelandet.)
- **`args.state`-Property ≠ Methodenname.** Eine `state.foo`-Property, die wie
  eine `Game`-Methode heißt, ruft die **Methode** auf statt Daten zu lesen →
  Crash `wrong number of arguments`. Deshalb heißen State-Caches bewusst anders
  als die Render-Helfer.
- **Welt vs. Screen trennen.** Positionen leben in **Welt-Koordinaten**
  (`diver_global_x`/`depth_y`; Fauna in lokaler Chunk-`x` + Welt-`y`); beim Rendern
  immer per `camera_x`/`camera_y` bzw. `chunk_offset_x`/`place_in_current_chunk`
  auf den Screen bringen. Hai-Kollision deshalb in **Welt-`x`/`y`** prüfen
  (Taucher `diver_global_x`/`depth_y`, Hai `world_index*SCREEN_WIDTH + dark_shark.x`),
  nie auf der projizierten `player_x`/`player_y`.
- **Kein `% SCREEN_HEIGHT` auf Welt-`y`.** Die Wassersäule ist tiefer als ein
  Screen — wer eine Welt-`y` modulo Screen-Höhe rechnet (so lagen Fisch und Hai
  ursprünglich), faltet Kreaturen aus dem Graben zurück an die Oberfläche.
  Vertikal wird geclampt (`in_water`, `DRIFT`), nicht gewrappt. Horizontal
  (lokale Chunk-`x`) ist der Wrap dagegen richtig.
- **`breathing?` ≠ „an der Oberfläche".** `breathing?` heißt nur „Kopf über
  *einer* Wasseroberfläche" (Meer **oder** Luftkammer) und steuert Sauerstoff und
  Auftrieb. Alles, was mit **Tageslicht** zu tun hat — Fog aus, Fauna unsichtbar,
  Oberflächen-Hinweis — muss `at_open_surface?` fragen, sonst wird die Höhle
  taghell und leer.
- **Kamera-Bodenbezug: geglättet, aber derselbe Boden.** Die Dead Zone darf weder
  am rohen Sand hängen (jede Kerbe wackelt: gemessen 4 px/Tick) noch nur an der
  groben Form (`ground_level_at`) — die weicht dort, wo Fels oder Abgrund im Spiel
  ist, um Hunderte px vom echten Grund ab und klemmt den Taucher an die
  Bildunterkante (gemessen: `player_y` 59 im Abgrund). Richtig ist
  `smooth_floor_y_at`: derselbe Boden, nur ohne Terrassen und Jitter. Und: ein
  Kamera-Test sollte den **Ruck** messen (2. Ableitung), nicht die Geschwindigkeit
  — gleichmäßiges Mitschwenken über einen Hang ist erwünscht.
- **Gelände-Tests brauchen `island_sectors = []`.** Die Inseln werden pro Runde auf
  zufällige Sektoren gewürfelt; landet eine auf der getesteten Stelle, ist das
  Gelände dort ein anderes — der Test wird flaky (genau so passiert). Ebenso fühlt der Taucher den Grund
  über seine ganze Breite (`DIVER_FOOTPRINT`, Maximum) statt an genau einer Spalte.
- **Boden = Funktion der Welt-`x`, nicht pro Segment gewürfelt.** Nur weil
  `WorldGenerator.floor_y_at` global ist, passen unabhängig generierte Segmente
  an der Naht zusammen. Wer für ein Segment eigene Kontrollpunkte würfelt,
  bekommt an jeder Chunk-Grenze eine Stufe.
- **HUD zuletzt rendern.** `render_panel` muss ans Ende von `tick`, sonst
  überdecken Szene/Fog den O2-Balken.
- **`--test` exit-code lügt.** Immer 0 — nur `bin/test` (mit Output-Parsing)
  gibt einen echten Exit-Code für CI.

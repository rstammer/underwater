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
  `area1`/`area2` rendern dieselbe kontinuierliche Welt (`render_underwater`);
  eine eigene „surface"-Szene gibt es **nicht mehr** — die Oberfläche ist Teil
  der durchgehenden Vertikalen (s. Kamera unten).
- `app/entities/` — `diver` (Spieler), `dark_shark`, `sloppy_scalar` — eigene
  Klassen, bekommen `args` übergeben, lesen Position aus `state`
- `app/world/` — **Welt-System** (s. u.): `rng`, `biome`, `world`, `world_generator`,
  `static_worlds`, `world_renderer` (reopenet `Game`; Kamera, Wasser, Himmel,
  Boden, Deko, Boot), `fog_of_war`
- `app/ux/` — `panel` (HUD/UI), eigenständige Klasse
- `sprites/` — Pixel-Art (SpearFishing by Szym, PixelArt Diver by Daniel Kole)
- `sprites/decor/` — selbst generierte Pixel-Art (Blase, Seestern, Koralle,
  Seetang, Boot); erzeugt per Stdlib-PNG-Skript, im Titel + an der Oberfläche
  genutzt und für später wiederverwendbar
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
   Wasserlinie), setzt `camera_y` (folgt dem Taucher, Dead Zone am Grund) und
   projiziert auf die Screen-Position `player_y = depth_y - camera_y`
7. `update_oxygen` (außer wenn `game_paused?`) — Drain/Refill, leer → ertrinken
8. `send("#{state.game_scene}_tick")` — rendert die aktive Szene (kamera-versetzt)
9. `render_diver` (außer pausiert) — Taucher-Sprite + Fog
10. `render_panel` — **HUD ganz zuletzt**, sonst überdeckt die Szene/der Fog den
   O2-Balken (das war ein realer Bug)

Render-Layering in DragonRuby: `solids < sprites < labels`; innerhalb eines
Buckets bestimmt die Einfüge-Reihenfolge das Layering. Deshalb HUD am Ende.

### Scene-State-Machine (`state.game_scene`)

Vertikal gibt es **keinen** Szenenwechsel mehr — Auf-/Abtauchen ist eine
durchgehende Kamerafahrt (s. Kamera & Vertikale). `game_scene` steuert nur noch
den **horizontalen** Sektor plus die pausierten Screens:

```
   area1 ⇄ area2   (diver_global_x < 1281 → area1, sonst area2; beide rendern
                    dieselbe kontinuierliche Welt inkl. Oberfläche/Himmel)

   title ──[Leertaste/z/j/A]──► area1 (Spielstart, an der Oberfläche/atmend)
   <überall> ──[Hai / O2 leer]──► game_over ──[Leertaste]──► area1 (reset_game)
   <überall> ──[ESC]──► title
```

`title` und `game_over` sind **pausiert** (`game_paused?`): kein O2-Drain, kein HUD.

### Kamera & Vertikale (kontinuierlich)

Die Vertikale ist **eine durchgehende Welt-Koordinate**, keine gestapelten
Szenen:

- `state.depth_y` — Welt-Position des Tauchers: `0` = Meeresgrund,
  `WATERLINE_Y` (= `SCREEN_HEIGHT`) = Wasserlinie, darüber Himmel.
- `state.camera_y` — Welt-`y`, das am **unteren** Screenrand liegt; folgt dem
  Taucher (`depth_y - CAMERA_ANCHOR`), aber nie unter den Grund (`max(…, 0)`) →
  **Dead Zone** am Meeresgrund (dort ruht die Kamera, der klassische Blick 0..720).
- **Projektion:** `screen_y = welt_y - camera_y`; der Taucher landet auf
  `state.player_y = depth_y - camera_y` (Diver + Fog lesen daraus, unverändert).
- Alles Welt-Räumliche (Wasser-Verlauf, Himmel, Boden, Deko, Fisch, Hai, Boot)
  wird beim Rendern um `camera_y` verschoben (`camera_shift`). Hochschwimmen
  scrollt so die Welt weich durch, bis Wasserlinie + Himmel ins Bild kommen —
  **kein Sprung, keine Teleportation.**

## Welten (prozedural + statisch)

Die Unterwasser-Szenen sind **prozedural generiert und in Segmente (Chunks)
geteilt**. Trennung von *Beschreibung* und *Rendering*:

- **`World`** (`app/world/world.rb`) — reine Daten: Boden-Heightmap (`floor`),
  Deko-Platzierungen (`decorations`), `biome`. Rührt nie `outputs` an → testbar.
- **`Rng`** — seedbarer xorshift-PRNG: gleiche Seed → gleiche Welt (deterministisch,
  stabil beim Zurückschwimmen, unit-testbar).
- **`Biome`** — Themen (Sandbank/Kelpwald/Riff/Tiefsee): Wasserpalette, `fog`-Stärke,
  Boden-Farben, Deko-Dichte, Fauna (Fischanzahl/-farben, `shark`).
- **`WorldGenerator.generate(index)`** — baut aus dem Index deterministisch Boden
  (interpoliertes Value-Noise) + Deko; Biom wird pro Index gemischt gewählt.
- **`StaticWorlds`** — Registry, um einzelne Indizes mit **handgebauten** Welten zu
  überschreiben (`world_for` = statisch ?: generiert). Der „Mix"-Hook; aktuell leer.
- **`world_renderer.rb`** (reopenet `Game`) — `current_world` wählt die Welt aus
  `world_index = diver_global_x / SCREEN_WIDTH` (gecacht in `state.active_world`,
  Neugenerierung nur bei Segmentwechsel). `render_world` zeichnet **kamera-versetzt**
  (`camera_y`): Himmel über der Wasserlinie (`sky_fill`), Wasser-Verlauf über die
  ganze Wassersäule (`world_water`), Wasserlinie (`surface_line`), Boden + Deko,
  und am Startsegment das Boot (`home_boat` + `surface_hint` beim Atmen). Fauna:
  `spawn_fauna` (Fisch-Schwarm pro Biom), `fauna_visible?`/`shark_present?` — Fisch
  **und** Hai sind an der Oberfläche (`breathing?`) unsichtbar, dort sieht man nur
  die Wasseroberfläche. **Fog:** `fog_radius`/`fog_color` aus dem Biom — **hellere
  Biome sehen weiter**, die Tiefsee schließt sich eng um den Taucher.
- **Home & Locator:** `at_home?` (`world_index == 0`) — nur dort schwimmt das Boot
  an der Wasserlinie. Der dezente Locator (oben rechts) zeigt Sektor + Tiefe, hinter
  `locator?` (später an ein Gerät koppelbar).

Deko-Sprites für Welten liegen in `sprites/decor/` (seaweed/coral/starfish/rock).

## State-Modell (`args.state`)

Der komplette Spielzustand — Property-Namen dürfen **nicht** wie Methoden heißen
(s. Gotchas):

| Key | Bedeutung |
|-----|-----------|
| `initialized` | Flag, ob `initialize_game` schon lief |
| `game_scene` | aktiver Screen (`title`/`area1`/`area2`/`game_over`) — steuert Dispatch |
| `player_x` | horizontale Screen-Position (wird `% 1280` gerendert) |
| `depth_y` | **vertikale Welt-Position (Single source of truth).** `0` = Meeresgrund, `WATERLINE_Y` = Wasserlinie, darüber Himmel. Hoch schwimmen = `depth_y` steigt = flacher |
| `camera_y` | Welt-`y` am unteren Screenrand; folgt dem Taucher, `≥ 0` (Dead Zone am Grund) |
| `player_y` | **abgeleitete** Screen-`y` des Tauchers = `depth_y - camera_y`; jeden Tick in `update_depth_and_camera` gesetzt (Diver + Fog lesen daraus) |
| `diver_global_x` | unbegrenztes horizontales Weltkoordinat des Tauchers → entscheidet area1/area2. Single source of truth (Diver liest daraus) |
| `direction` | `:left` / `:right` (Blickrichtung, hält beim Idle) |
| `angle` | Sprite-Neigung beim Diagonal-Schwimmen |
| `sprinting` | `true`, solange die Sprint-Taste gehalten wird *und* geschwommen wird |
| `speed` | effektive Geschwindigkeit dieses Ticks (`Diver::SPEED`, beim Sprint ×`SPRINT_MULTIPLIER`); von Movement *und* `Diver#tick` gelesen |
| `oxygen` | 0..`OXYGEN_MAX`; leer → ertrinken |
| `death_cause` | `:eaten` (Hai) / `:drowned` (O2 leer) / `nil` — steuert Game-Over-Text |
| `diver` / `shark` | Entity-Instanzen (`Diver` / `DarkShark`) |
| `fish` | Array von `SloppyScalar` — der Fisch-Schwarm des aktiven Bioms (von `spawn_fauna` neu bestückt); Positionen in Welt-`y` |
| `dark_shark` | `{x:, y:}`-Hash der Hai-Position in Welt-Koordinaten (von der `DarkShark`-Entity in `to_h` gelesen) |
| `active_world` / `active_world_index` | gecachte aktive `World` + ihr Segment-Index (Neugenerierung nur bei Segmentwechsel) |

Koordinaten-Merksatz: **hoch schwimmen = `depth_y` steigt = flacher.** Der Grund
liegt bei `depth_y = 0`, die Wasserlinie bei `WATERLINE_Y`; `player_y` ist nur die
kamera-projizierte Screen-Position und wird nicht direkt gesetzt.

## Spielmechanik

- **Rundenstart (`spawn_at_surface`):** Jede Runde (erster Start *und* Neustart
  nach game_over) beginnt an der Wasserlinie neben dem Boot (`SURFACE_BOAT_X`),
  Kopf raus/atmend (`depth_y = WATERLINE_Y - SURFACE_FLOAT_DEPTH`). Am Startsegment
  schaukelt ein **Home-Boot** (`home_boat`) an der Wasserlinie, dazu ein dezenter
  Hinweis (`surface_hint`), der zum Abtauchen/Erkunden ermutigt.
- **Auf-/Abtauchen (kontinuierlich):** Es gibt keinen Übergang mehr — der Taucher
  bewegt sich in `depth_y`, die Kamera scrollt die Welt weich durch. Nahe dem
  Grund ruht die Kamera (Dead Zone); schwimmt er höher, folgt sie und die
  Wasserlinie + Himmel kommen ins Bild. `update_depth_and_camera` clampt `depth_y`
  zwischen Meeresgrund (`sea_floor_y`, ruht auf dem Sand) und Atem-Höhe
  (`WATERLINE_Y - SURFACE_FLOAT_DEPTH`, nur der Kopf ragt raus). Er kann das
  Wasser nie ganz verlassen.
- **Nur Wasseroberfläche oben:** An der Oberfläche (`breathing?`) sind Fisch und
  Hai unsichtbar (`fauna_visible?`/`shark_present?`) — man sieht nur die
  Wasseroberfläche + Himmel.
- **Auftrieb:** Der Taucher ist negativ schwimmfähig und `depth_y` sinkt langsam
  (0.15/Tick), solange man nicht ↑ hält. **Ausnahme:** ragt sein Kopf aus dem
  Wasser (`breathing?`, `depth_y + Diver::HEIGHT >= WATERLINE_Y`), sinkt er nicht
  — Ruhe-/Atem-Modus. Sobald er wieder untertaucht, sinkt er weiter.
- **Sauerstoff:** Drain unter Wasser (`OXYGEN_DRAIN`/Tick, ~3 min). Refill **nur**
  wenn `breathing?` — also Kopf über der Wasserlinie. Leer → `game_over` /
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
  `:eaten`.

### Tuning-Konstanten (`app/main.rb`)

`WATERLINE_Y=SCREEN_HEIGHT`, `CAMERA_ANCHOR=SCREEN_HEIGHT/2`,
`SURFACE_FLOAT_DEPTH=20`, `OXYGEN_MAX=100`, `OXYGEN_DRAIN=0.009`,
`OXYGEN_REFILL=1.0`, `SPRINT_MULTIPLIER=2`, `FOG_OF_WAR=true`, `DEBUG=false`.
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

- **`args.state`-Property ≠ Methodenname.** Eine `state.foo`-Property, die wie
  eine `Game`-Methode heißt, ruft die **Methode** auf statt Daten zu lesen →
  Crash `wrong number of arguments`. Deshalb heißen State-Caches bewusst anders
  als die Render-Helfer.
- **Welt vs. Screen trennen.** Fauna/Hai/Deko liegen in **Welt-`y`**; beim
  Rendern immer per `camera_shift` (bzw. `- camera_y`) auf den Screen bringen.
  Hai-Kollision deshalb auf `depth_y` prüfen, nicht auf der Screen-`player_y`.
- **HUD zuletzt rendern.** `render_panel` muss ans Ende von `tick`, sonst
  überdecken Szene/Fog den O2-Balken.
- **`--test` exit-code lügt.** Immer 0 — nur `bin/test` (mit Output-Parsing)
  gibt einen echten Exit-Code für CI.

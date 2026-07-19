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
- `app/scenes/` — `title`/`area1`/`area2`/`surface`/`game_over`, **reopenen
  `class Game`** und definieren `<scene>_tick`; Dispatch via
  `send("#{state.game_scene}_tick")`
- `app/entities/` — `diver` (Spieler), `dark_shark`, `sloppy_scalar` — eigene
  Klassen, bekommen `args` übergeben, lesen Position aus `state`
- `app/world/` — `water` (reopenet `Game`), `sand_tile`, `weed`, `fog_of_war`
- `app/ux/` — `panel` (HUD/UI), eigenständige Klasse
- `sprites/` — Pixel-Art (SpearFishing by Szym, PixelArt Diver by Daniel Kole)
- `sounds/` — Audio

### Spiel-Loop (`Game#tick`)

Ein Tick läuft **in dieser Reihenfolge** — sie ist bewusst so und teils bugfix-
kritisch:

1. `initialize_game` (nur beim ersten Tick, `unless state.initialized`)
2. `update_scene` — setzt `state.game_scene` (State-Machine, s. u.)
3. `update_sprint` — setzt `state.sprinting` + `state.speed` (vor jeder Bewegung)
4. `update_characters` — Hai/Skalare/Weeds ticken; **Hai-Kollision → game_over
   (`death_cause = :eaten`)**
5. `basic_movements_per_tick` — Tastatur-Input, Auftrieb/Sinken, `angle`
6. `apply_vertical_bounds` — Meeresgrund-Clamp + Oberflächen-Übergang
7. `update_oxygen` (außer wenn `game_paused?`) — Drain/Refill, leer → ertrinken
8. `send("#{state.game_scene}_tick")` — rendert die aktive Szene
9. `render_diver` (außer pausiert) — Taucher-Sprite + Fog
10. `render_panel` — **HUD ganz zuletzt**, sonst überdeckt die Szene/der Fog den
   O2-Balken (das war ein realer Bug)

Render-Layering in DragonRuby: `solids < sprites < labels`; innerhalb eines
Buckets bestimmt die Einfüge-Reihenfolge das Layering. Deshalb HUD am Ende.

### Scene-State-Machine (`state.game_scene`)

```
                 up über Screen-Top          ↓ (down) unter Oberfläche
   area1 ⇄ area2 ───────────────────►  surface ──────────────────► area1/area2
     (diver_global_x < 1281 → area1,      (state.surfaced == true)
      sonst area2)

   title ──[Leertaste/z/j/A]──► area1 (Spielstart)
   <überall> ──[Hai / O2 leer]──► game_over ──[Leertaste]──► area1 (reset_game)
   <überall> ──[ESC]──► title
```

`title` und `game_over` sind **pausiert** (`game_paused?`): kein Input-Movement,
kein O2-Drain, kein HUD.

## State-Modell (`args.state`)

Der komplette Spielzustand — Property-Namen dürfen **nicht** wie Methoden heißen
(s. Gotchas):

| Key | Bedeutung |
|-----|-----------|
| `initialized` | Flag, ob `initialize_game` schon lief |
| `game_scene` | aktive Szene (`title`/`area1`/`area2`/`surface`/`game_over`) — steuert Dispatch |
| `scene` | Legacy-Freitext-Label (`"underwater-start"`), rein deskriptiv |
| `player_x` | horizontale Screen-Position (wird `% 1280` gerendert) |
| `player_y` | **vertikale Position = Tiefe.** (0,0) ist unten-links, `y=720` oben. `player_y` hoch = näher an der Oberfläche |
| `diver_global_x` | unbegrenztes horizontales Weltkoordinat des Tauchers → entscheidet area1/area2. Single source of truth (Diver liest daraus) |
| `direction` | `:left` / `:right` (Blickrichtung, hält beim Idle) |
| `angle` | Sprite-Neigung beim Diagonal-Schwimmen |
| `surfaced` | `true`, wenn der Taucher an der Oberfläche ist (surface-Szene aktiv) |
| `sprinting` | `true`, solange die Sprint-Taste gehalten wird *und* geschwommen wird |
| `speed` | effektive Geschwindigkeit dieses Ticks (`Diver::SPEED`, beim Sprint ×`SPRINT_MULTIPLIER`); von Movement *und* `Diver#tick` gelesen |
| `oxygen` | 0..`OXYGEN_MAX`; leer → ertrinken |
| `death_cause` | `:eaten` (Hai) / `:drowned` (O2 leer) / `nil` — steuert Game-Over-Text |
| `player_state` | `:alive` (Alt-Feld, aktuell nicht game-over-relevant) |
| `diver` / `shark` | Entity-Instanzen (`Diver` / `DarkShark`) |
| `scalars` / `weeds` | Arrays von `SloppyScalar` / `Weed` |
| `dark_shark` | `{x:, y:}`-Hash der Hai-Position (von area2 gelesen) |
| `ground_tiles` / `water_bands` / `deepness_values` | gecachte Render-Daten (bewusst so benannt, s. Gotchas) |

Koordinaten-Merksatz: **hoch schwimmen = `player_y` steigt = flacher.** Start bei
`player_y = 710` (dicht unter der Oberfläche), Taucher sinkt langsam ab.

## Spielmechanik

- **Auftauchen (surface-Szene):** Schwimmt der Taucher über den Screen-Top
  hinaus, wird `surfaced = true` und er landet in der surface-Szene.
  `apply_vertical_bounds` clampt seinen Körper **unter** der Wasserlinie
  (`SURFACE_WATERLINE`), sodass nur der Kopf rausschaut (`SURFACE_FLOAT_DEPTH`).
  Er kann das Wasser nie ganz verlassen.
- **Auftrieb:** An der Oberfläche treibt er nach oben und *bleibt* dort; er sinkt
  nur wieder, wenn man aktiv ↓ drückt (dann zurück nach area1/area2). Unter
  Wasser sinkt er langsam, solange man nicht ↑ hält.
- **Sauerstoff:** Drain unter Wasser (`OXYGEN_DRAIN`/Tick, ~33 s). Refill **nur**
  wenn `breathing?` — also aufgetaucht *und* Kopf über der Wasserlinie (nicht
  schon beim bloßen Szenenwechsel). Leer → `game_over` / `:drowned`. O2-Balken-
  HUD wird bei <30 % rot.
- **Sprint:** Sprint-Taste (Leertaste) halten *während* man schwimmt →
  Geschwindigkeit ×`SPRINT_MULTIPLIER` und O2-Verbrauch ×`SPRINT_MULTIPLIER`.
  Reine Entscheidung in `sprint_active?` (nie in pausierten Szenen), Effekt über
  `state.speed` / `oxygen_drain`. Taste im Stehen kostet nichts. Kein Konflikt
  mit `fire_input?` (das nutzt `key_down`, nur in pausierten Szenen).
- **Fog of War:** unter Wasser aktiv (`FOG_OF_WAR`), an der Oberfläche aus (dort
  ist Tageslicht).
- **Hai:** In area2 unterwegs; Kollision (`intersect_rect?`) → `game_over` /
  `:eaten`.

### Tuning-Konstanten (`app/main.rb`)

`SURFACE_WATERLINE=350`, `SURFACE_FLOAT_DEPTH=20`, `OXYGEN_MAX=100`,
`OXYGEN_DRAIN=0.05`, `OXYGEN_REFILL=1.0`, `SPRINT_MULTIPLIER=2`,
`FOG_OF_WAR=true`, `DEBUG=false`.
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

- **`args.state`-Property ≠ Methodenname.** `state.water` würde die Methode
  `water` aufrufen statt Daten zu lesen → Crash `wrong number of arguments`.
  Deshalb heißen die Caches `water_bands`/`ground_tiles`/`deepness_values`.
- **HUD zuletzt rendern.** `render_panel` muss ans Ende von `tick`, sonst
  überdecken Szene/Fog den O2-Balken.
- **`--test` exit-code lügt.** Immer 0 — nur `bin/test` (mit Output-Parsing)
  gibt einen echten Exit-Code für CI.

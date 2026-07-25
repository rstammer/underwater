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
- `app/scenes/` — `title`/`name`/`area1`/`area2`/`game_over`/`pause`, **reopenen `class Game`**
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
- `app/ux/` — `hud` (reopenet `Game`: O2- und Anzug-Balken, Locator, Tiefenanzeige,
  Debug-Readout, und **alle laufenden Meldungen** — s. u.) und `story` (der
  Eröffnungstext, den das Boot erzählt)
  - **Laufende Meldungen** (`render_messages`): was im Sucher ist, was in
    Reichweite liegt, was gerade fotografiert wurde — alles **am unteren Rand**,
    nicht mehr über den Bildschirm verstreut (dort steht der Taucher). **Jede Art
    hat ihren festen Slot** (`SLOT_PHOTO`/`SLOT_PICKUP`/`SLOT_NOTE`/`SLOT_NEW`)
    statt nachzurücken: eine Zeile, die springt, weil woanders etwas auftauchte,
    liest sich schlechter als eine Lücke. Jede Box wird per `calcstringbox` um
    ihren Text gemessen. Der **Blitz** (`render_flash`) ist keine Meldung und
    bleibt vollflächig.
- `sprites/` — Pixel-Art (SpearFishing by Szym, PixelArt Diver by Daniel Kole)
- `sprites/decor/` — selbst generierte Pixel-Art (Blase, Seestern, Koralle,
  Seetang, Fels, Boot; für die Inseln: Palme groß/klein, Busch, Gras, Treibholz,
  Fahne, Möwe)
- `sprites/animals/crustaceans/` — die Krebse (`tools/make_species_sprites.rb`):
  Form und Palette sind getrennt, eine neue Art ist eine Palette statt einer
  neuen Zeichnung; der Laufzyklus wird **erzeugt** (Beinpixel um eine Spalte
  verschoben) statt gezeichnet.
- `sprites/diver_land.png` — der Taucher an Land (`tools/make_diver_land_sprites.rb`):
  **abgeleitet** vom Schwimm-Sheet, nicht neu gezeichnet — Palette daraus gesampelt,
  Kopf/Flasche/Rumpf aus dessen erstem aufrechten Frame getraced, nur die
  Gliedmaßen neu (Arme unten, Flossen flach nach vorn). Gleiches Sheet-Layout,
  deshalb tauscht `Diver#to_h` nur den Pfad.
- **Alle Sprite-Werkzeuge** (`tools/make_*_sprites.rb`) erzeugen PNGs aus ASCII-Art
  + Palette, nur mit Ruby-Stdlib, und laufen in **MRI**, nicht in DragonRuby —
  reine Autoren-Werkzeuge. **Vor dem Einbau hochskaliert anschauen.**
- `sounds/` — Audio

### Spiel-Loop (`Game#tick`)

Ein Tick läuft **in dieser Reihenfolge** — sie ist bewusst so und teils bugfix-
kritisch:

1. `initialize_game` (nur beim ersten Tick, `unless state.initialized`)
2. `update_scene` — setzt `state.game_scene` (State-Machine, s. u.)
2b. `update_home_menu` / `update_exchange` — **vor** dem Pause-Check, denn sie sind
   die einzige Eingabe, die im pausierten Boot-Screen noch zählt (Menü auf/zu,
   Cursor, Umpacken)
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

   title ──[Leertaste/z/j/A]──► name ──[Enter]──► area1 (start_round, atmend)
                                name ──[ESC]──► title
   <überall> ──[Hai / O2 leer]──► game_over ──[Leertaste]──► area1 (reset_game,
                                  **ohne** name/Story — ein Retry klickt nichts weg)
   <am Boot> ──[L]──► home_menu ──[L/ESC]──► area1/area2 (resume_scene)
                      (drin: ←/→ Spalte, ↑/↓ Zeile, E schiebt Rucksack ⇄ Lager)
   <im Wasser> ──[ESC / Pause-Knopf]──► pause ──[ESC/Leertaste/Tap]──► area1/area2
                                        pause ──[Q / Beenden]──► title
```

`title`, `name`, `game_over`, `home_menu` und `pause` sind **pausiert** (`game_paused?`):
kein O2-/Anzug-Drain, kein HUD, **und Bewegung + Kamera stehen still** (die Welt friert
ein, statt dass der Taucher hinter dem Menü davondriftet). Der Menü-Umschalter
`toggle_home_menu(open_or_close)` ist von der Tastenabfrage getrennt, damit er ohne
simulierte Eingaben testbar ist. Der Boot-Screen selbst: `home_menu.rb`.

**Pausenmenü (`app/scenes/pause.rb`):** ESC (oder der Pause-Knopf) im Tauchgang friert
die Runde **ein statt sie wegzuwerfen** — Q/„Beenden" geht zum Titel, ESC/Leertaste/Tap
spielt weiter (`resume_scene`, zurück in den richtigen Sektor). Früher sprang ESC direkt
zum Titel und die Runde war weg.

**ESC (und der Pause-Knopf) werden an genau einer Stelle entschieden** (`update_escape`,
`case state.game_scene`): Boot-Screen zu, Name → Titel, Pause → weiter, im Wasser → Pause
auf. **Gotcha, zweimal gelernt:** ein `key_down`/Tap ist einen ganzen Tick lang wahr —
wer ihn an zwei Stellen liest, verarbeitet ihn zweimal. Beim Pausenmenü hätte derselbe
Tap die Pause geöffnet *und* im selben Tick wieder geschlossen; `open_pause` merkt sich
`state.paused_at = tick_count`, und `read_pause_input` ignoriert den Öffnungs-Tick.

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
  Boden-Farben, Deko-Dichte, Fauna (`fish_count`, `shark`). **Welche** Arten, sagt
  das Biom nicht mehr — das steht im Arten-Register.
- **`Species`** (`app/world/species.rb`) — das Arten-Register, und damit der Inhalt
  des Spielziels: Name, Angler-Latein, Sprite-Sheet, **in welchen Biomen** und
  **zwischen welchen Tiefen** eine Art lebt, ihre Seltenheit und ihre Punkte. Daran
  hängt die ganze Spannung: die seltensten leben **an oder unter der Anzugs-Grenze**
  (`SUIT_DEPTH_LIMIT`), die letzten Seiten des Artenbuchs kosten also echtes Risiko.
  `Species.pick(biome, tiefe)` würfelt gewichtet (`RARITIES`) — häufige Arten müssen
  häufig *sein*, sonst fühlt sich nichts wie ein Fund an; findet sich für eine Tiefe
  nichts, fällt es auf „irgendwas aus diesem Biom" zurück, damit kein Meeresabschnitt
  leer bleibt. Eine Art hinzufügen = **eine Zeile in `ALL`**, sonst nichts.
  - **`habitat` sagt, wo in der Wassersäule eine Art lebt** — und damit, zu welcher
    Bevölkerung sie gehört: `:water` = Schwarm, `:floor` = läuft auf dem Sand,
    `:shore` = läuft **über** der Wasserlinie am Strand. Die drei werden **getrennt
    gewürfelt** (`pick` / `pick_floor` / `pick_shore`), sonst spawnt ein Krebs
    freischwebend im Wasser oder ein Fisch sitzt auf dem Grund.
  - **`pick_floor` hat bewusst KEINEN Fallback** (anders als `pick`): passt für diese
    Tiefe keine Bodenart, bleibt der Sand **leer**. Dass die Abgrundkrabbe erst ab
    105 m vorkommt, ist der ganze Grund, dort runterzutauchen — ein Fallback würde
    sie auf der flachen Bank verschenken.
  - **Tiefenbänder gegen den echten Boden setzen, nicht gegen eine glatte Skala.**
    Beim ersten Wurf war die Languste (`:uncommon`) die **häufigste Art im Meer**:
    sie war die einzige, deren Band die Tiefen abdeckte, auf denen der Meeresboden
    meistens liegt. Bei neuen Bodenarten die Verteilung **messen** (Wegwerf-Test über
    ~80 Segmente, Arten zählen), nicht schätzen.
- **`Creature`** (`app/entities/creature.rb`, früher `SloppyScalar`) — ein Fisch, der
  seine Art trägt; alles Optische kommt aus `species`.
- **`Crustacean`** (`app/entities/crustacean.rb`) — Krebse, Hummer, Langusten:
  dieselbe Idee wie `Creature`, aber die **senkrechte Position gehört ihnen nicht**.
  Sie liegt auf dem Untergrund und wird jeden Tick neu davon gelesen (`ground_y`),
  also klettern sie über Terrassen statt hindurchzugleiten. `ground:` sagt, *welcher*
  Untergrund: `:sand` = Meeresboden (`floor_y_at`), `:crown` = Oberkante des Felsens
  (`crown_y_at`) — also ein **Strand**. Sie **huschen in Schüben** (`DASH`/`REST`)
  statt gleichmäßig zu kriechen; das liest sich als Krebs und macht sie nebenbei zu
  Motiven, an die man sich heranschleichen kann.
- **`WorldGenerator.floor_y_at(world_x)`** — **die eine Wahrheit über den
  Meeresgrund.** Kein Würfeln pro Segment, sondern eine Funktion der Welt-`x`,
  geschichtet aus mehreren Noise-Oktaven: `shelf` (sehr breit — ganze Regionen
  sind Bank oder fallen ab), `basin` (Becken), **`trough`** (breite tiefe Becken,
  s. u.), `crag` (ridged Noise → felsige Spitzen), `dune` (kleines Relief),
  `rough` (Jitter pro 16-px-Zelle → zerklüftete, pixelige Sandkante). Alles rastet
  auf `FLOOR_STEP = 8` px → **Pixel-Terrassen** statt glattem Dach. Gesampelt wird
  **einmal pro Terrasse** (`terrace_start`), und Terrassen sind **unterschiedlich
  breit** (8–64 px, `TERRACE_BLOCK` / `TERRACE_WIDTHS`) — sonst sähe der Boden aus
  wie ein regelmäßiger Kamm. Weil es eine Funktion der Welt-Position ist, passen
  **Nachbarsegmente nahtlos** aneinander.
- **Tiefe / lange Abstiege (`trough_at`, `chasm_at`).** Der Schelf allein war zu
  flach (überall ~kurzer Weg zum Grund). `trough_at` (schwellwertgesteuerte
  smoothstep-Oktave, `TROUGH_*`) senkt **breite** Regionen tief ab → **manche
  Abschnitte sind ein langer Tauchgang** bis zum Grund; `chasm_at` (`CHASM_*`)
  bleibt der seltene, steilere Extremfall. Verteilung: ~43 % flache Bank (<60 m),
  Modus 25–49 m, langer Schwanz runter bis ~290 m. **Beide sind steil-aber-glatt
  by design** und stecken in `ground_level_at` → die Kamera reitet sie über
  `smooth_floor_y_at` (nicht in `test_ground_level_is_the_smooth_shape` messen —
  dort werden `chasm_at` **und** `trough_at` herausgerechnet, wie die Chasm-Wände).
- **`WorldGenerator.generate(index)`** — sampelt diese Funktion für die Spalten
  des Segments und würfelt (per `Rng`) Deko dazu; Biom pro Index gemischt gewählt.
- **`StaticWorlds`** — Registry, um einzelne Indizes mit **handgebauten** Welten zu
  überschreiben (`world_for` = statisch ?: generiert). Der „Mix"-Hook; aktuell leer.
- **Höhlen: `roof` + `air_pockets`.** Eine Heightmap kann **keine** Höhle
  beschreiben (sie kennt nur „Sand bis hierhin"). Deshalb trägt eine Welt über dem
  Sand zusätzlich **Fels-Spannen pro Spalte**: `roof[col]` ist eine **Liste** von
  `{ ceiling:, crown: }` — Fels von `ceiling` (Unterkante, wo der Taucher anstößt)
  bis `crown` (Oberkante); `[]` = offenes Wasser, `roof` selbst `nil` = im ganzen
  Segment kein Fels. **Liste, nicht eine Spanne**, weil eine Spalte mehrere Slabs
  tragen können muss — nur so läuft ein Gang über einem anderen, und nur so wird
  aus einem Korridor ein Netz. Gelesen wird über `World#slabs_at(x)` (unterste
  zuerst), `solid_at?` prüft alle. Dazu `air_pockets`: Rechtecke eingeschlossener
  Luft, deren **Unterkante die Wasseroberfläche darin** ist (`air_line_at`, `air_at?`).
- **Die Wassertasche statt „der Felsspanne".** Weil eine Spalte mehrere Slabs hat,
  fragt der Taucher nicht mehr „welcher Fels ist über mir", sondern **in welcher
  Tasche stecke ich**: `pocket_at(world_x, depth)` liefert den Boden (Sand, oder die
  Oberkante eines Slabs, über dem er schwimmt) und die Decke (Unterkante des
  nächsten Slabs darüber, `nil` bei offenem Wasser); `rock_span_at` nimmt das über
  seine ganze Breite (`footprint`) — höchster Boden, niedrigste Decke, damit er nur
  dort durchpasst, wo er auf **beiden** Seiten durchpasst.
- **`IslandWorld`** — eine Insel: wird **auf** generierte Welten gestempelt
  (`IslandWorld.build(world, sector)`), nicht statt ihrer.
  **Eine Insel ist breiter als ein Segment** (`SPAN_MIN`=1800 … `SPAN_MAX`=2800 px
  gegen 1280 px Segment) — sie wird deshalb auf **jedes** Segment gestempelt, in das
  sie hineinreicht (`covers?`, `Game#islands_over`), und jedes baut seine eigene
  Scheibe. Das funktioniert nur, weil **jede Form eine Funktion der Welt-`x` ist**
  und nie des Segments: `first_x`/`last_x`, `crown_y_at`, `tunnel_floor_y_at`,
  `span_t_at`. Zwei Segmente rechnen dieselbe Insel aus und passen an der Naht
  exakt zusammen (`test_the_slices_line_up_across_a_segment_border` prüft genau
  das). Gewürfelt wird alles aus dem **Heimatsektor** (`shape_for(sector)`, die
  Reihenfolge der Würfe ist die Identität der Form — nicht umsortieren), damit jede
  Scheibe dieselbe Insel rollt. `covers?` reicht um `REACH` px über die Insel
  hinaus, weil die **Skerries vor** den Küsten stehen — ohne das Polster fällt das
  Segment, das nur sie trägt, aus der Stempelung und sie verschwinden lautlos.
  Spannweite (`span`) und Höhe (`peak`) sind gewürfelt, die Silhouette
  (`crown_y_at`) ist Noise **an der Welt-Position** mal einer Hüllkurve
  (`envelope`), die den Fels an beiden Enden ans Wasser bindet — deshalb sieht
  **keine Insel aus wie die andere**. Gelesen wird pro Terrasse
  (`WorldGenerator.terrace_start`), das gibt Plateaus und Schultern statt einer
  glatten Kuppe; nach oben deckelt `CROWN_MAX`, sonst schneidet der Bildrand den
  Gipfel ab.
- **Der Hauptgang** ist pro Insel anders: der Boden (`tunnel_floor_y_at`) ist eine
  Rampe zwischen dem Sand beider Mündungen **plus ein Sack oder Buckel** (`@sag`, an
  den Enden null — deshalb keine Stufe beim Rein-/Rausschwimmen), die Höhe
  (`tunnel_height_at`) wechselt zwischen **Engstelle und Halle**
  (`TUNNEL_MIN`..`TUNNEL_MAX`, nie enger als `MIN_GAP`), und unterwegs heben
  **ein bis zwei Luftkammern** (`chambers`, Position gewürfelt) die Decke — dort
  taucht man auf und atmet. Im Korridor wächst Seetang, Koralle, Fels
  (`tunnel_decor`).
- **Galerien: die zweite Ebene** (`galleries`, `column_slabs`). Über Abschnitten des
  Hauptgangs laufen **waagerechte obere Gänge**, mit einer Felsschicht (`ROCK_SPAN`)
  dazwischen — dafür ist die Slab-Liste pro Spalte da: Korridor-Spalte = ein Slab
  (die Insel darüber), Galerie-Spalte = **zwei** (Zwischenfels + Inseldeckel),
  Kamin-Spalte = wieder eins, weil dort der Zwischenfels fehlt und das Wasser vom
  Korridorboden **durchgehend hochsteht**. Der **Kamin** (`shaft?`, `SHAFT_W`) sitzt
  an jedem offenen Ende; eine von drei Galerien ist eine **Sackgasse** (`dead_end`)
  und hebt am toten Ende ihre Decke (`GALLERY_RISE`) über eine **Luftkammer** — der
  Lohn dafür, den falsch aussehenden Gang hochgeschwommen zu sein.
  - **Gepasst statt gesetzt** (`fit_gallery`): die Galerie ist waagerecht, existiert
    also nur, wo sie zwischen den **höchsten Punkt des Korridors darunter** und den
    **dünnsten Teil der Insel darüber** passt. Passt sie nicht, gibt es keine —
    deshalb hat eine flache, niedrige Insel schlicht einen Korridor und eine hohe
    ist durchlöchert (gemessen: 9 von 11 Inseln bekommen eine).
  - **Über eine Kammer darf sie laufen** (`corridor_ceiling_at` rechnet die Kuppel
    mit ein, die Galerie sitzt dort einfach höher). **Ein Kamin darf es nicht**
    (`shafts_hit_a_chamber?`): der Kamin nimmt den Zwischenfels weg — inklusive der
    Kuppel, die die Kammerluft hielt. Der Taucher taucht dann in Luft ohne Decke
    auf, `clamp_depth` hält ihn dort fest, und der Weg nach oben ist zu. (Genau so
    ist es beim ersten Versuch passiert; die Durchschwimm-Simulation hat es
    gefunden, kein Auge.)
  - Die Galerie bleibt **unter Wasser** (`WATERLINE_Y - MIN_GAP`): darüber würde der
    Taucher im Berginneren an der Meeres-Wasserlinie treiben und `breathing?` wäre
    wahr — Höhle wird taghell, der bekannte Fehlerfall.
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
- **Skerries** (`skerry_columns`/`skerry_clusters`) — zerklüftete Felsen, die vor
  **beiden Küsten** aus dem Wasser ragen (nicht die Insel selbst): eigene
  `roof`-Spalten mit Krone knapp über und Basis knapp unter Wasser
  (`SKERRY_LIP_*`, `SKERRY_DEPTH`). Sie **stoppen an der Oberfläche** (druntertauchen
  geht) und sind fester Fels für Hai & Fische. Von oben sieht man wegen der
  Oberflächen-Occlusion den Fels unter Wasser nicht — die Skerries sind der
  sichtbare Hinweis „hier ist die Insel, nicht durchschwimmbar". Sie halten sich
  aus dem offenen Wasser der Segmentmitte heraus (und nie am Segmentrand, sonst
  Naht). **Gras (`GREEN`) nur noch auf Fels, der `GREEN_MIN` über Wasser steht** —
  die flachen Skerries und die Wasserlinie bleiben nackter Fels.
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

Deko-Sprites für Welten liegen in `sprites/decor/` (seaweed/coral/starfish). Die
frühere **Fels-Deko wurde entfernt** (wirkte in allen Biomen fremd) — kein `rocks`-
Knopf am Biom mehr, kein `"rock"` in Generator/Insel. `decor_tint` (Renderer) dimmt
Deko nur noch mit der Tiefe (`light_at`), damit unten nichts im Dunkeln leuchtet.

## State-Modell (`args.state`)

Der komplette Spielzustand — Property-Namen dürfen **nicht** wie Methoden heißen
(s. Gotchas):

| Key | Bedeutung |
|-----|-----------|
| `initialized` | Flag, ob `initialize_game` schon lief |
| `game_scene` | aktiver Screen (`title`/`area1`/`area2`/`game_over`/`home_menu`) — steuert Dispatch |
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
| `death_cause` | `:eaten` (Hai) / `:drowned` (O2 leer) / `:crushed` (Anzug hin) / `:taken` (Kraken-Griff) / `nil` — steuert Game-Over-Text |
| `kraken` | `{x:, y:, side:}` in Welt-Koordinaten oder `nil` — die Legende, nur tief unten präsent |
| `diver` / `shark` | Entity-Instanzen (`Diver` / `DarkShark`) |
| `crawlers` | Array von `Crustacean` — was auf dem Sand des aktiven Segments läuft (`spawn_crawlers`); lokale Chunk-`x`, `y` vom Boden gelesen |
| `shore_life` | Array von `Crustacean` mit `ground: :crown` — was auf dem **Strand** des Segments läuft (`spawn_shore_life`), leer ohne Insel |
| `fish` | Array von `SloppyScalar` — Schwarm des aktiven Bioms; Positionen als **lokale** Chunk-`x` (0..`SCREEN_WIDTH`) + Welt-`y`, gerendert via `place_in_current_chunk`. Jeder Fisch patrouilliert nur seinen freien Wasserstreifen (`from_x`/`to_x` aus `open_water_span`, dreht an den Enden) und driftet `DRIFT` px um seine Spawn-Tiefe (kein Wrap!) |
| `dark_shark` | `{x:, y:}`-Hash der Hai-Position: **lokale** Chunk-`x` (wrappt bei `SCREEN_WIDTH`) + Welt-`y` (von der `DarkShark`-Entity in `to_h` gelesen). Bei jeder neuen Runde kommt er auf **Taucher-Tiefe** ±`SHARK_PATROL_SPREAD` rein |
| `active_world` / `active_world_index` | gecachtes aktuelles Chunk (Biom/Fauna) + sein Segment-Index (Neu-Setzen nur bei Segmentwechsel) |
| `log_deepest` / `log_sectors` / `log_islands` / `log_caves` | Logbuch der Runde: tiefste Meterzahl + Index-Sets (Sektoren/Inseln/Höhlen); `track_log` füllt, `reset_log` leert |
| `world_items` | versteckte Sammelstücke `{kind:, x:, y:, collected:}` in Welt-Koordinaten (pro Runde gewürfelt, `reset_items`) |
| `inventory` / `stash` | getragene Gegenstände (max `INVENTORY_MAX`) bzw. am Boot eingelagerte (unbegrenzt) |
| `player_name` | der eingetippte Name; `diver_name` liefert ihn bzw. `DIVER_NAME` als Rückfall |
| `album` | `{species_key => quality}` — das dokumentierte Artenbuch. **Überlebt den Tod** |
| `sighted` | `{species_key => true}` — welche Arten gesichtet wurden; steuert, was im Buch überhaupt auftaucht. Überlebt den Tod wie `album` |
| `film_left` / `film_roll` | Aufnahmen übrig bzw. belichtete, noch nicht entwickelte Fotos `{key:, quality:}` — beides pro Runde |
| `shot_at` / `shot_note` | Tick der letzten Aufnahme und was drauf ist, für Blitz und Einblender |
| `boat_page` | `:hold` oder `:book` — welche Seite des Boot-Screens offen ist |
| `story_told` | ob die Eröffnung am Boot durch ist — `false` nur ab `start_round`, wird beim ersten Abtauchen `true` |
| `exchange_side` / `exchange_index` | Cursor im Boot-Screen: welche Spalte (`"pack"`/`"hold"`) und welche Zeile darin — nur dort relevant, `reset_exchange` beim Öffnen |

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
  erscheint eine kleine Karte über dem Boot (`render_boat_hint`): Titel „Dein Boot",
  eine **blinkende** Status-Zeile „Anzug wird repariert" **nur solange
  `repairing_suit?`** (`suit < SUIT_MAX`), dann **Aktionen**: „[ L ] Logbuch &
  Lager", „[ I ] Alles einlagern (N)" (`store_items`) und „[ Q ] Spiel beenden"
  (`quit_game` → `$gtk.request_quit`, alle nur wenn `at_the_boat?`). Sonst bleibt
  der Bildschirm frei von Text (die alten Szenen-Titel sind weg). Die Karte ist am
  **oberen Rand verankert und wächst nach unten** (dynamische Höhe aus den Zeilen),
  damit sie nie über den oberen Bildrand hinausläuft.
- **Name (`app/scenes/name.rb`):** vor dem ersten Tauchgang fragt das Spiel, wie der
  Spieler heißt (`state.player_name`, max `NAME_MAX`). Eingabe läuft über
  **`inputs.keyboard.key_down.char`** — ein Zeichen pro Tick, so wie DragonRubys
  eigene Doku Texteingabe macht. **Nicht** über `args.inputs.text` (s. Gotchas).
  **Enter** bestätigt (nicht
  Leertaste — die ist ein legales Zeichen in einem Namen), Backspace löscht, ESC
  zurück zum Titel. Leer/nur Leerzeichen zählt nicht als Name. `type_name` /
  `backspace_name` / `confirm_name` sind reine State-Änderungen → testbar ohne
  simulierte Tasten.
- **Story am Boot (`app/ux/story.rb`):** die Eröffnung ist **kein eigener Screen**,
  sondern die Karte, die ohnehin über dem Boot hängt (`render_boat_card`) — man liest
  sie an der Oberfläche neben dem Boot, mit dem Meer schon darunter. Solange
  `story_pending?`, trägt die Karte die Story (`boat_story_lines`, Überschrift =
  `diver_name`), danach wieder die Aktionen (`boat_action_lines`). **Quittiert wird
  durchs Abtauchen** (`update_story`: `story_told` sobald `!at_open_surface?`) — keine
  Taste zum Wegklicken, und sie kommt nicht wieder. Nur bei einer Runde **vom Titel**
  (`start_round`); nach game_over geht's direkt weiter. Text in `story_lines`
  (`""` = Absatz), zum Umschreiben gedacht — die Karte **bricht nicht um**, deshalb
  misst `test_the_story_fits_the_card` jede Zeile mit `calcstringbox` gegen `STORY_W`
  und meckert, sobald sie zu lang wird.
- **Tauchhinweis (`dive_hint_lines`, ebenfalls `app/ux/story.rb`):** die Regeln der
  Kamera — Taste, Nähe, Sprint, Filmmenge, Entwickeln — erscheinen **beim ersten
  Abtauchen**, nicht auf der Boot-Karte. Am Boot ist noch nichts davon real; erst
  wenn Wasser über einem steht, bedeuten sie etwas. Ausgelöst wird das vom Wasser
  (`update_dive_hint`: `dive_hint_pending` + `!at_open_surface?`), nicht von einem
  Timer. **Weg ist sie, sobald er `DIVE_HINT_METRES` tiefer ist als beim Auftauchen
  der Karte** — man liest sie knapp unter der Oberfläche, und wer unterwegs ist,
  braucht sie nicht mehr. `DIVE_HINT_TICKS` ist nur noch der Notausgang für
  jemanden, der dort schwebt und zweimal liest; ein Foto räumt sie ebenfalls weg
  (`dismiss_dive_hint` in `take_photo`). Einmal pro Runde **vom Titel**
  (`start_round`), nicht nach jedem Neustart.
- **Fotografieren (`app/world/photography.rb`) — das Ziel des Spiels.** Jede Art,
  die man zum ersten Mal ablichtet, ist eine Seite im **Artenbuch**; `album_score`
  liest die Punkte aus dem Buch (kein mitgeführter Zähler, der aus dem Tritt geraten
  kann). **`F`** ist der Auslöser.
  - **Motiv** (`photo_subject`): die nächste Kreatur in `PHOTO_REACH`, die **vor** ihm
    ist (`in_front?`, `state.direction`) — über die Schulter schießen gilt nicht.
  - **Unter Wasser das Meer, oben das Land** (`creatures_in_view`): welche Kreaturen
    überhaupt in Frage kommen, hängt davon ab, auf welcher Seite der Oberfläche sein
    Kopf ist. Untergetaucht sind es Schwarm + Bodenkrebse, aufgetaucht **nur der
    Strand**. Im offenen Meer heißt das weiterhin „oben gibt es nichts"; neben einer
    Insel heißt es, dass Auftauchen etwas anderes ist als nur Luftholen.
  - **Qualität** (`photo_quality`) aus der Entfernung: `perfekt`/`gut`/`unscharf`,
    und **Sprinten kostet eine Stufe** — man nähert sich also leise statt zu pflügen.
  - **Film ist knapp:** `FILM_MAX` Aufnahmen pro Tauchgang. Ein Foto ist **belichteter
    Film, kein Eintrag** — erst `develop_film` **am Boot** macht Buchseiten daraus und
    legt einen frischen Film ein. **Ertrinken kostet die Rolle**, nie das Buch
    (`reset_film` in `reset_game`, `state.album` nur in `initialize_game`).
  - Ein Foto, das **nicht besser** ist als das vorhandene (auf der Rolle *oder* im
    Buch), kostet **keinen Film** (`improves?`) — sonst wäre Vor-einem-Fisch-Stehen
    eine Strategie.
  - `F` ist Auslöser unter Wasser **und** Dunkelkammer am Boot — dieselbe Taste, weil
    man am Boot an der Oberfläche ist, wo es nie ein Motiv gibt.
  - **Namensgebung-Falle:** nichts hier heißt `camera` — das Wort bedeutet schon die
    Sicht (`state.camera_x/camera_y`).
- **Boot-Screen (Home-Menü):** `L` am Boot öffnet `home_menu` (pausiert, Welt friert
  hinter einem Schleier ein). **Zwei Seiten, `Tab` blättert** (`update_boat_page`,
  `state.boat_page`): das **Artenbuch** (`artenbuch_rows`) und die Runde selbst mit
  drei Spalten in `render_boat_screen`. **Das Buch zeigt nur, was man gesichtet hat**
  (`species_known?` = in `state.sighted` **oder** schon im `album`) — es füllt sich beim
  Erkunden, statt die ganze See vorab zu verraten. Gesichtet = `update_sightings` (jeder
  Tauch-Tick): eine Kreatur unter Wasser in `SIGHT_RANGE`=520 px. Sichtungen **überleben
  den Tod** wie das Album (nur in `initialize_game` geleert, nicht in `reset_game`).
  Gesichtet-aber-nicht-fotografiert = Zeile mit Name/Latein, aber „—" statt Note; der
  Nenner der Kopfzeile ist die **Zahl der gesichteten** Arten (nie die Gesamtzahl, sonst
  verrät er, wie viel noch fehlt); ein dezenter „… und weitere, noch ungesichtet"-Hinweis,
  solange nicht alles gesichtet ist. Das Kraken taucht hier **nie** auf (`update_sightings`
  liest nur `state.fish`+Hai, und `Species::KRAKEN` ist ohnehin nicht in `ALL`):
  - **Logbuch** (links) — die Bilanz der Runde: tiefster Tauchgang, erkundete
    Sektoren, gefundene Inseln, durchtauchte Höhlen. Gezählt wird pro Tauch-Tick in
    `track_log` (Sektoren/Inseln/Höhlen als Index-Sets → kein Doppelzählen; Höhle
    zählt, sobald man in ihrer Luftkammer atmet), zurückgesetzt pro Runde
    (`reset_log`). Zeilen liefert `logbook_rows` (reine Methode → testbar). Was man
    dabei/eingelagert hat, steht **nicht** mehr als Zeile drin — das zeigen die
    beiden Spalten daneben ohnehin genauer.
  - **Rucksack** (Mitte) — `INVENTORY_MAX` Zeilen, leere als dezenter Strich, damit
    man den Platz sieht; die Überschrift wird warm, wenn er voll ist.
  - **Lager** (rechts) — `hold_stacks`: **eine Zeile je Art mit Anzahl** (sechs
    Dosen lesen sich als „Dose 6", nicht als sechs gleiche Zeilen), sortiert wie
    `ITEM_KINDS`, damit die Zeilen unter dem Cursor nicht springen. Bei vollem
    Rucksack sind die Zeilen gedimmt — da kann nichts hoch, bevor was runtergeht.
- **Tauschen am Boot (`app/world/items.rb`, „exchange"):** ein Cursor über beiden
  Listen — `←/→` wählt die Seite (`state.exchange_side`, `"pack"`/`"hold"`),
  `↑/↓` die Zeile (`state.exchange_index`, wrappt an beiden Enden), **`E`**
  schiebt das Ausgewählte auf die andere Seite (`transfer_selected` →
  `stow_selected` / `fetch_selected`). Rein aus dem Lager geht nur, solange der
  Rucksack Platz hat. `clamp_exchange` hält den Cursor auf einer Zeile, die es
  wirklich gibt — auch wenn ein Transfer die Zeile gerade unter ihm wegnimmt (letztes
  Stück eines Stapels). Alles reine State-Änderungen: `update_exchange` liest die
  Tasten (nur wenn `game_scene == "home_menu"`), die Logik selbst ist ohne simulierte
  Eingaben testbar (`tests/stash_tests.rb`). `reset_exchange` beim Öffnen des Menüs
  und pro Runde. **`I` am Boot** bleibt als Abkürzung „alles auf einmal einlagern".
- **Gegenstände / Inventar (`app/world/items.rb`):** Fünf Sammelstücke
  (Flaschenpost, Schuh, Dose, Schmuck, Schlüssel; Sprites via
  `tools/make_item_sprites.rb` → `sprites/items/`) liegen versteckt auf dem
  Meeresgrund. `reset_items` würfelt pro Runde `ITEM_COUNT` Stück in
  `state.world_items` (absolute Welt-Koordinaten, **nie** Home- oder Insel-Sektor,
  nie gestapelt) — bleiben liegen, wenn man wegschwimmt. `render_world_items`
  zeichnet sie kamera-versetzt, nur untergetaucht (wie der Rest). **Aufheben mit
  E** (`grab_item`, Reichweite `ITEM_REACH`) in `state.inventory`, **max
  `INVENTORY_MAX` = 3**; HUD zeigt drei Slots + einen Prompt in Reichweite
  („[ E ] … aufheben" bzw. „Inventar voll"; HUD-Slots **unten links**, klar von den
  Gauges oben getrennt). **Einlagern mit I am Boot** (`store_items`) leert den
  Rucksack in `state.stash` (unbegrenzt) — feiner sortieren geht im Boot-Screen
  (s. „Tauschen am Boot"). Aufheben ist **E**, das Boot-Menü **L** — keine geteilte
  Taste mehr; Items spawnen ohnehin nie am Boot. Loop: tauchen → finden → drei
  tragen → heimbringen → einlagern → **umpacken, was man mit rausnehmen will** →
  weiter.
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
  geht immer, und von einer Insel kommt man immer wieder ins Wasser zurück.
  - **Die Kantentoleranz gilt auch für Fels** (`pocket_at(.., reach)`): früher nur
    für Sand, dadurch waren Inselterrassen eine Treppe, die man sieht und nie
    hochkommt. Sicher gegen Durchsteigen ist das, weil **jede Slab dicker ist als
    die Toleranz** (`ROCK_SPAN`=64 gegen 48; Insel und Skerry weit mehr) — Füße
    innerhalb einer Schrittlänge unter der Oberkante sind zwangsläufig über der
    Unterkante. `clamp_depth` liest mit **derselben** Toleranz: ohne das würde es
    entscheiden, er stünde *unter* der gerade erklommenen Terrasse, und ihn durch
    die Insel fallen lassen.
- **An Land stehen** (`depth_ceiling`): die Wasseroberfläche ist keine absolute
  Decke mehr. Hebt ihn der Fels unter ihm darüber hinaus, **steht er drauf** — und
  dieser Boden ist zugleich seine Decke, also kein Fliegen. Waten und über eine
  Insel laufen ist dasselbe wie auf dem Sand aufliegen, nur auf der anderen Seite
  des Wassers. Oben gilt automatisch alles Übrige: `breathing?` wahr (O2 füllt
  auf), `at_open_surface?` wahr (kein Fog, Fische unsichtbar, **Strandkrebse
  fotografierbar**).
- **Land-Physik** (`state.on_land`, gesetzt in `clamp_depth`): keine Vertikal­eingabe
  (kein Hochschwimmen am Berg), **Schwerkraft statt Auftrieb** (`fall_toward`, von
  der Kante fällt er statt zu springen), Laufen mit `LAND_SPEED`=0.9, kein Sprint,
  keine Sprite-Neigung, und **eigenes Sprite** (`Diver::LAND_PATH`).
  - **Der Laufzyklus läuft auf der Strecke, nicht auf der Uhr** (`Diver#frame`):
    der Frame kommt aus `diver_global_x / LAND_STRIDE`, nicht aus dem globalen
    `frame_index`. Füße, die im Takt zappeln, passen bei genau einer
    Geschwindigkeit zum Boden und schieben sich bei allen anderen — genau das war
    zu sehen. Deshalb hat die Laufzeile **4 Posen** (4 teilt 12, die Zeilenlänge;
    ein 8er-Zyklus in 12 Spalten stottert beim Umlauf).
  - **Springen (Leertaste, `update_jump`)**: nur an Land und nur vom Boden
    (`state.airborne`). Technisch ist es dieselbe Kurve wie das Fallen, rückwärts
    gelesen — `state.fall` startet negativ. Gemessen: **33 px hoch, 0,33 s**.
  - **Der Sprung ist an die Felswand gekoppelt.** Er erhöht, wie hoch er greifen
    kann (Schritt 48 + Sprung 33 = 81 px), also ist `IslandWorld::CLIFF_MIN`=128
    **dagegen** bemessen (+16 px, die die Krone wegrastet → Wand ≥112). **Wer die
    Sprunghöhe hochdreht, muss `CLIFF_MIN` mitziehen** — `room_for_a_wall?` passt
    eine zu niedrige blockierte Insel dann auf `:through` herunter, statt eine
    überspringbare Wand zu bauen.
- **Inseln & Höhlen:** `ISLAND_COUNT` bewachsene Inseln ragen aus dem Wasser, jede
  mit eigener Form und Größe — eine davon in Sichtweite (1–3 Sektoren), der Rest
  weiter draußen. Durch jede führt **unten ein Tunnel**, mit einer **Luftkammer**
  auf halber Strecke, in der man auftaucht und den Sauerstoff auffüllt.
- **Drei Arten von Küste (`shape_for[:shore]`) — ob man an Land kann:**
  - `:rock` — Felsenküste wie bisher: man schwimmt ran und nicht weiter.
  - `:through` — Sand an **beiden** Enden, komplett **überquerbar**.
  - `:blocked` — Sand an **einem** Ende; landeinwärts steht eine **Felswand**, dort
    endet der Spaziergang. Die andere Küste bleibt Fels.
- **Warum eine Felsenküste eine Wand ist** (gemessen, und der Schlüssel zum Ganzen):
  die Silhouette einer Insel steigt ohnehin nur in 16-px-Terrassen und springt nie
  mehr als 32 px — deutlich unter den 48 px (`SOLID_STEP_UP`), die der Taucher
  übersteigt. **Begehbar war sie also immer schon.** Was ihn aufhielt, war einzig
  der *erste* Schritt: treibend hängen seine Füße 52 px unter der Wasserlinie
  (`SURFACE_FLOAT_DEPTH` + `Diver::HEIGHT`), der unterste Fels einer Felsenküste
  steht `SHORE_LIP`=24 px darüber. Genau diese Lücke **ist** die Felsenküste. Ein
  **Strand** fängt stattdessen `BEACH_TOE`=96 px **unter** Wasser an — damit liegt
  seine erste Terrasse in Reichweite und man watet hoch.
- **Der Schelf der blockierten Insel wird gebaut, nicht gewürfelt** (`shelf_ceiling`):
  er läuft auf feste `SHELF_TOP`=64 px über Wasser aus und bleibt immer `CLIFF_MIN`=96
  unter dem Fels an der Wand — die Stufe dort ist also *garantiert* zu hoch. Als
  *Anteil* der Inselhöhe definiert (erster Versuch) blieb der Schelf flacher Inseln
  unter Wasser, also gar kein Strand.
- **Vor Sand stehen keine Skerries** (`skerry_clusters`): sie sagen „hier greift der
  Fels ins Wasser" — das Gegenteil dessen, was ein Strand sagt. Und gemessen: eine
  Skerry ist an der Oberfläche eine Wand, also **genau auf der Höhe, auf der man
  watet** — sie riegelten den Strand komplett ab.
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
  **Nur im Wasser** — an Land ist dieselbe Taste der Hüpfer (`sprint_active?`).
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
  `dark_shark.dir`, Sprite spiegelt sich) statt hindurchzuschwimmen. `shark_blocked?`
  prüft die **ganze Körperhöhe** (`shark_span_solid?`, drei y-Punkte), und die
  vertikale Drift lehnt Ziel-`y` ab, die im Fels läge — sonst schlüpfte er in einen
  dünnen freistehenden Skerry.
- **Kraken — die Legende der Tiefe (`app/world/kraken.rb`).** Kein Jäger wie der Hai,
  sondern ein **Köder**: es hängt ab `KRAKEN_DEPTH`=150 m am Fog-Rand, `KRAKEN_GAP`=230 px
  voraus (innerhalb `PHOTO_REACH`, damit die Kamera es als Motiv liest) und
  `KRAKEN_DROP`=130 px **tiefer** — der Sog geht immer nach unten. Es steht als
  `photo_subject` da („[ F ] ? ? ?"), aber `take_photo` routet auf `attempt_kraken_photo`:
  Blitz, leere Notiz, **kein Film verbraucht** (damit man weiter probiert und weiter
  absteigt). Wer folgt, easet mit ihm in den Anzug-Tod (`:crushed`, simuliert: 150 m →
  zerdrückt bei ~183 m); die **Rettung ist nach oben** (über `KRAKEN_FADE`=120 m löst es
  sich auf, Hysterese). `Species::KRAKEN` steht **nicht in `ALL`** → nie im Artenbuch,
  nie im Register (`Species["kraken"]` = nil). Direkter Griff (`:taken`) nur, wenn man es
  wirklich in eine Grabenwand drängt (`KRAKEN_GRAB`=64 px) — die Retreat-Distanz lässt
  das fast nie zu. **Es soll nie ganz erscheinen** (`render_kraken`, vor dem Fog): kein
  zusammenhängender Körper, sondern **einzeln flackernde Fetzen** (`KRAKEN_PATCHES` +
  Tentakel), jeder mit eigener Phase — sie zeigen sich nie gleichzeitig, die Form fügt
  sich nicht. Darüber eine langsame **Präsenz** (`kraken_presence`, Deckel bei ~0.5), die
  immer wieder fast ins Dunkel absackt; ein kaltes **Auge**, das meist nur glimmt und
  selten kurz aufblitzt. Alphas real: an den meisten Ticks 0–7, Spitzen ~22 (Fetzen) bzw.
  ~64 (Augen-Glanz). Tuning: `KRAKEN_MURK_ALPHA`, `KRAKEN_TENTACLE_ALPHA`,
  `KRAKEN_EYE_DIM/GLINT`, und die Präsenz-Kurve. Die Seite (`side`) ist beim Erscheinen
  fixiert, damit Wegdrehen es hinter einen zieht statt durch einen hindurch.
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

`app/world/island_world.rb` (Inseln): `SPAN_MIN`=1800/`SPAN_MAX`=2800, `REACH`, `PEAK_MIN/MAX`, `CROWN_MAX`,
`SHORE_LIP`, `SHORE_HEIGHT`, `TUNNEL_HEIGHT`, `DOME_SPAN`, `DOME_RISE`;
Küsten: `SHORES`, `BEACH_TOE`=96, `SHELF_TOP`=64, `CLIFF_MIN`=96;
`AIR_DEPTH`, `CROWN_STEP`, `PLANT_SPACING`, `MARGIN`, `GULL_HEIGHT`, `SCALES`;
Tunnel: `TUNNEL_MIN/MAX`, `TUNNEL_WAVE`, `MIN_GAP`, `SAG_MAX`, `DOME_SPAN`,
`DOME_RISE`; Galerien: `GALLERY_MIN/MAX`, `GALLERY_HEIGHT`, `GALLERY_RISE`,
`ROCK_SPAN`, `SHAFT_W`, `GALLERY_GAP`; Skerries: `SKERRY_LIP_MIN/MAX`, `SKERRY_DEPTH`.

`app/main.rb` (Land): `LAND_SPEED=0.6`, `LAND_GRAVITY=0.6`, `LAND_FALL_MAX=14`,
`JUMP_SPEED=6.0` (**hängt mit `IslandWorld::CLIFF_MIN` zusammen**, s. o.).
`app/main.rb`: `WATERLINE_Y=SCREEN_HEIGHT`, `CAMERA_ANCHOR=SCREEN_HEIGHT/2`,
`CAMERA_ANCHOR_X=SCREEN_WIDTH/2`, `FLOOR_VIEW_MARGIN=240`, `CAMERA_FLOOR_SLACK=60`,
`CAMERA_EASE=0.1`,
`SURFACE_FLOAT_DEPTH=20`, `PIXELS_PER_METRE=14`, `OXYGEN_MAX=100`, `OXYGEN_DRAIN=0.009`,
`OXYGEN_REFILL=1.0`, `SUIT_MAX=100`, `SUIT_DEPTH_LIMIT=100`, `SUIT_DRAIN=0.0025`,
`SUIT_REPAIR=0.4`, `BOAT_REACH=160`, `SPRINT_MULTIPLIER=2`, `SHARK_PATROL_SPREAD=200`,
`SOLID_STEP_UP=48`, `ISLAND_MIN_SECTOR=2`, `ISLAND_MAX_SECTOR=10`, `ISLAND_NEAR_SECTOR=3`,
`ISLAND_COUNT=3`,
`FILM_MAX=12`, `PHOTO_REACH=320`, `PHOTO_CLOSE=90`, `PHOTO_MID=190`, `PHOTO_BEHIND=40`,
`QUALITY_FACTOR` (unscharf 0.5 / gut 1.0 / perfekt 1.6), `SHUTTER_TICKS`, `NOTE_TICKS`;
`FOG_OF_WAR=true`, `DEBUG=false`.

`app/world/world_generator.rb` (Geländeform): `FLOOR_TOP_Y`, `SHELF_*`,
`BASIN_*`, `TROUGH_*` (breite tiefe Becken), `CHASM_*`, `CRAG_*`, `DUNE_*`,
`ROUGH_*`, `FLOOR_STEP`, `TERRACE_BLOCK`,
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
- **„Nach oben schwimmen" nicht mit `depth_y = 99_999` simulieren.** Seit man auf
  Fels stehen kann, der aus dem Wasser ragt, heißt eine Position oberhalb der Insel
  schlicht „er steht auf dem Gipfel" — der Clamp lässt ihn dann zu Recht dort. Wer
  prüfen will, dass eine Decke ihn aufhält, muss ihn **tickweise aufsteigen lassen**
  (so wie es im Spiel passiert). Drei Tests hingen an diesem Teleport.
- **Eine Decke stoppt einen Aufstieg — sie darf nie von oben ziehen.**
  `air_line_at` kennt eine Luftkammer nur an ihrer `x`, und eine Kammer tief im Berg
  teilt sich ihre `x` mit dem Gipfel darüber. Sobald man oben laufen konnte, griff
  diese Wasseroberfläche durch hundert Meter Fels und zog den Taucher in die Höhle
  (gemessen: Sturz um 1645 px). Deshalb gilt sie nur, wenn sie **über** ihm liegt.
- **`world_cache` ist schon voll, bevor der Test `island_sectors` setzt.**
  `initialize_game` ruft `center_camera` → `clamp_depth` → und damit ist Segment 0
  bereits **mit den zufällig gewürfelten** Insel-Sektoren gebaut und gecacht. Wer
  danach `state.island_sectors` überschreibt, muss `state.world_cache = {}` setzen,
  sonst testet man gegen die alte Welt. (Kostete beim Verbreitern der Inseln eine
  halbe Stunde Fehlersuche an der richtigen Stelle im falschen Segment.)
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
- **Ein Panel deckt keine Labels ab.** `solids < sprites < labels` gilt *global*,
  nicht nur innerhalb eines Buckets: ein deckendes Menü-Panel (Sprite) verdeckt zwar
  den Kasten der Boot-Karte, aber **nicht deren Text** — der stand mitten im Boot-
  Screen. Ein Overlay macht nichts unsichtbar; was drunter nicht hingehört, darf gar
  nicht erst gezeichnet werden (`render_boat_hint ... && !game_paused?`).
- **`vertical_alignment_enum: 2` heißt: `y` ist die *Oberkante*.** Eine Linie unter
  so eine Überschrift gehört auf `y - calcstringbox(text)[1] - Luft`, nicht auf einen
  geratenen Festwert — sonst läuft sie durch die Buchstaben. Für alles, was sich an
  Textmaßen ausrichtet (Trennlinien, Kartenhöhen, Zeilenumbruch), **messen** statt
  schätzen: `args.gtk.calcstringbox(text, size_enum)` läuft auch im Test-Runner.
- **Texteingabe: `key_down.char`, nicht `args.inputs.text`.** `args.inputs.text`
  füllt sich nur, wenn `DR.start_text_input` lief — und das ist ein **[Pro]-Feature**,
  während hier eine **Standard**-Lizenz läuft: kein Fehler, kein Log, es passiert
  einfach nichts. Das Namensfeld blieb leer und das Spiel war **gar nicht mehr
  startbar**. `inputs.keyboard.key_down.char` liefert das getippte Zeichen ohne
  jeden Modus.
- **Ein Test, der die Engine umgeht, prüft die Engine nicht.** Alle Namens-Tests
  riefen `type_name(["R","o",…])` direkt auf und waren grün, während im Spiel keine
  Taste ankam. Wo Eingabe im Spiel kaputtgehen kann, muss **mindestens ein Test
  durch `game.tick` und über die echten `args.inputs`** gehen
  (`test_a_whole_round_can_be_started_from_the_keyboard`).
- **Ein `key_down` gilt den ganzen Tick.** Wer dieselbe Taste an zwei Stellen im Tick
  abfragt, verarbeitet sie zweimal — so schloss ESC erst das Menü und warf einen
  danach noch auf den Titelbildschirm. Eine Taste, eine Stelle (`update_escape`).
- **`--test` exit-code lügt.** Immer 0 — nur `bin/test` (mit Output-Parsing)
  gibt einen echten Exit-Code für CI.

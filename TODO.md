# Underwater — TODO / Ideen

## Features
- [x] **Surface-Szene** (Wasserlinie oben, nur Kopf darf raus, Auftrieb)
  - [x] **Boot als "home"** (`surface_boat`, generiertes `sprites/decor/boat.png`),
        Taucher spawnt daneben (`SURFACE_BOAT_X`)
  - [ ] Boot weiter ausbauen: als Hub/Menü, Nachschub, Tauchgang-Start
- [x] **Sauerstoff-Mechanik** (O2-Balken, Refill nur beim Atmen an der Oberfläche,
      leer → ertrinken/game_over)
- [x] **Game-Over-Screen** neu (zentriert, ursachen-abhängig: Hai vs. ertrunken)
- [x] **Sprint-Mechanik:** Leertaste halten + schwimmen = schneller (Speed ×2),
      verbraucht schneller Sauerstoff (O2-Drain ×2). `SPRINT_MULTIPLIER`.
- [x] **Start an der Oberfläche** (`spawn_at_surface`) + dezenter Erkundungs-
      Hinweis in der surface-Szene (`surface_hint`)
- [x] **Prozedurale Welten** (chunk-basiert, deterministisch, Biome, gestreute
      Deko, biome-abhängiger Fog & Fauna) + Static-Override-Hook (`StaticWorlds`)
  - [x] Home-abhängige Surface (Boot nur über Startsegment) + dezenter Locator
  - [ ] erste **statische Handbau-Welt** registrieren (z. B. Wrack)
  - [ ] Fauna weiter ausbauen (mehr Arten, Verhalten je Biom)
- [ ] Sammelbares + Score (später, nicht jetzt)

## Tuning-Notizen (Defaults, per Playtest justierbar)
- `SURFACE_WATERLINE = 350`, `SURFACE_FLOAT_DEPTH = 20`
- `OXYGEN_MAX = 100`, `OXYGEN_DRAIN = 0.05` (~33 s), `OXYGEN_REFILL = 1.0`
- `SPRINT_MULTIPLIER = 2` (Speed- und O2-Drain-Faktor beim Sprinten)

## Cleanup (in Arbeit, Branch `cleanup/idiomatic-refactor`)
- [x] Stage 1: Restart-/Idle-Bugs, toter Code, tick_count
- [x] Stage 2: State nach args.state, Diver-Split-Brain
- [x] Stage 3: Game-Klasse (attr_dr) + boot/reset, Performance (path: :solid)
- [x] Testsuite (DragonRuby `--test`, `bin/test`, `tests/`)

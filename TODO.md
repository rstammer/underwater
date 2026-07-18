# Underwater — TODO / Ideen

## Features
- [x] **Surface-Szene** (Wasserlinie oben, nur Kopf darf raus, Auftrieb)
  - [ ] später ausbauen: **Boot als "home" für den Taucher**
- [x] **Sauerstoff-Mechanik** (O2-Balken, Refill nur beim Atmen an der Oberfläche,
      leer → ertrinken/game_over)
- [x] **Game-Over-Screen** neu (zentriert, ursachen-abhängig: Hai vs. ertrunken)
- [ ] **Sprint-Mechanik (nächster Schritt):** Leertaste = schneller schwimmen,
      verbraucht schneller Sauerstoff (Speed↑ ⇒ O2-Verbrauch↑)
- [ ] Sammelbares + Score (später, nicht jetzt)

## Tuning-Notizen (Defaults, per Playtest justierbar)
- `SURFACE_WATERLINE = 350`, `SURFACE_FLOAT_DEPTH = 20`
- `OXYGEN_MAX = 100`, `OXYGEN_DRAIN = 0.05` (~33 s), `OXYGEN_REFILL = 1.0`

## Cleanup (in Arbeit, Branch `cleanup/idiomatic-refactor`)
- [x] Stage 1: Restart-/Idle-Bugs, toter Code, tick_count
- [x] Stage 2: State nach args.state, Diver-Split-Brain
- [x] Stage 3: Game-Klasse (attr_dr) + boot/reset, Performance (path: :solid)
- [x] Testsuite (DragonRuby `--test`, `bin/test`, `tests/`)

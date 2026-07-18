# Underwater — TODO / Ideen

## Features
- [~] **Surface-Szene** (Wasserlinie oben, nur Kopf darf raus) — Schritt 1 in Arbeit.
      Später ausbauen: **Boot als "home" für den Taucher**.
- [ ] **Sauerstoff-Mechanik** (O2-Anzeige, auftauchen an der Surface füllt auf,
      leer → game_over)
- [ ] **Sprint-Mechanik:** Leertaste = schneller schwimmen, verbraucht schneller
      Sauerstoff (Speed↑ ⇒ O2-Verbrauch↑)
- [ ] Sammelbares + Score (später, nicht jetzt)

## Cleanup (in Arbeit, Branch `cleanup/idiomatic-refactor`)
- [x] Stage 1: Restart-/Idle-Bugs, toter Code, tick_count
- [x] Stage 2: State nach args.state, Diver-Split-Brain
- [x] Stage 3: Game-Klasse (attr_dr) + boot/reset, Performance (path: :solid)
- [x] Testsuite (DragonRuby `--test`, `bin/test`, `tests/`)

# underwater — 🐠 DragonRuby-Spiel

Robins erstes Spiel mit **DragonRuby GTK** — ein 2D-Pixel-Art-Spiel, in dem ein
Taucher die Unterwasserwelt erkundet. Pet-Projekt aus Spaß am Game-Dev-Lernen.

Repo: https://github.com/rstammer/underwater · Status: 🟢 active (nicht deployed)

## Lokales Setup (Engine)

Die **DragonRuby-Engine ist bewusst NICHT versioniert** — alle Engine-Dateien
stehen im `.gitignore`. Versioniert sind nur `app/`, `sprites/`, `sounds/`,
`README.md`, `open-source-licenses.txt`, `font.ttf`.

DragonRuby ist lizenzpflichtig (Kauf via itch.io / dragonruby.org). Nach einem
frischen Checkout muss die Engine einmalig in diesen Ordner entpackt werden:

1. DragonRuby GTK (macOS) von itch.io herunterladen & entpacken.
2. Den **Inhalt** von `dragonruby-macos/` (Binary `dragonruby`, `docs/`,
   `samples/`, `.dragonruby/`, `font.ttf` …) in dieses `underwater/`-Verzeichnis
   kopieren — **ohne** die Sample-`mygame/`. Die Engine-Dateien liegen dann neben
   `app/` und werden alle vom `.gitignore` ignoriert.
3. Zuletzt eingerichtet mit einem Build vom **2026-07-04** (Universal-Binary,
   arm64 + x86_64).

## Starten

```sh
./dragonruby .
```

Aus dem `underwater/`-Ordner heraus. Der Game-Ordner-Root ist das Repo-Root
(enthält `app/`); DragonRuby lädt `app/main.rb` als Entry-Point.
(Das `./dragonruby app` in der README.md ist veraltet — `.` ist korrekt.)

## Struktur

- `app/main.rb` — Entry-Point, lädt alle Requires & steuert den Scene-Wechsel
- `app/scenes/` — `title`, `area1`, `area2`, `game_over`
- `app/entities/` — `diver` (Spieler), `little_bass`, `dark_shark`, `sloppy_scalar`
- `app/world/` — `water`, `sand_tile`, `weed`, `fog_of_war`
- `app/ux/` — `panel` (HUD/UI)
- `sprites/` — Pixel-Art-Assets (SpearFishing by Szym, PixelArt Diver by Daniel Kole)
- `sounds/` — Audio

## Konventionen

- Code/Commits in English (wie im gesamten stammerdev-Workspace)
- Requires in `main.rb` immer relativ zum Game-Root mit `app/`-Prefix,
  z. B. `require "app/scenes/title.rb"`

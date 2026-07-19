# 🐠 Underwater

<img width="700" alt="Bildschirmfoto 2024-11-10 um 20 00 34" src="https://github.com/user-attachments/assets/93abe1ed-50a3-4966-9598-7f0db62a5a3f">

**▶ [Play it in your browser](https://stammer.dev/underwater/)**

This is my first game made using DragonRuby. It's a pet project
for the joy of learning on how to make games. 


So - follow me and the adventures of the little diver! 

The goal of the game is to survive and get mesmerized by the beauty of the underwater universe.

### Assets used

I'm highly thankful for the people that provided the lovely pixel art assets
I used in my game, like

* [SpearFishing by Szym](https://nszym.itch.io/spearfishing-assets-pack)
* [PixelArt Diver by Daniel Kole](https://dkproductions.itch.io/pixel-art-diver)

### How to run locally for development

For production we're building OS-specific binaries, but for 
development, if you have dragonruby locally, then:

```sh
./dragonruby .
```

### Building a web (HTML5 / WASM) version

DragonRuby can export the game to WebAssembly so it runs in the browser — this
works even on the **Standard** license. The output is a folder of plain static
files you can host anywhere.

`dragonruby-publish` expects the game as a *subfolder* next to the engine binary,
so if (like here) your game lives in the engine root, stage it into one first:

```sh
mkdir -p _pkg/underwater
cp -R app sprites sounds metadata _pkg/underwater/
./dragonruby-publish --platforms=html5 --package _pkg/underwater
# -> builds/underwater-html5.zip
```

This needs a `metadata/game_metadata.txt` (the publisher tells you the exact
fields if it's missing). Unzip it and test locally with the bundled server:

```sh
mkdir _webtest && cd _webtest && unzip ../builds/underwater-html5.zip
cd .. && ./dragonruby-httpd _webtest    # open http://localhost:8080/
```

**Hosting it elsewhere — the one gotcha:** the WASM runtime uses
`SharedArrayBuffer`, which browsers only grant to a *cross-origin isolated*
page. Serve `index.html` with **both** of these headers or the game won't boot:

```
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
```

`dragonruby-httpd` sets them for you; on your own server you have to add them.
(The export also ships a service worker that can inject them client-side as a
fallback, but setting them on the server is more reliable.)

The live instance runs at <https://stammer.dev/underwater/>.

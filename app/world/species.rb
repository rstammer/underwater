# Everything that swims out there, as a roster. Documenting these is the point
# of the game: each one photographed for the first time goes into the Artenbuch
# and is worth its points.
#
# A species is described by where it lives — which biomes, and between which
# depths — and how often it turns up. Depth is what ties the roster to the rest
# of the game: the rarest things live at or below what the suit is rated for
# (SUIT_DEPTH_LIMIT), so the last few pages of the book cost real risk.
#
# The names are angler's Latin. That is deliberate: a species you can name is a
# species you remember not having yet.
class Species
  # How much of the spawn a rarity gets. Common things have to *be* common, or
  # nothing feels like a find.
  #
  # These are weights *within whatever fits this water*, and most stretches of
  # sea only suit two or three species — so a gentle spread gets flattened out by
  # the small pool. Measured at 8/3/1, an uncommon crab turned up more often than
  # a common one. Steeper, so the tiers can still be told apart at the bottom of
  # a short list.
  RARITIES = { common: 12, uncommon: 3, rare: 1 }

  SCALAR = "sprites/animals/scalar_32_16/"
  BASS = "sprites/animals/bass1_32_16/"
  SHELLS = "sprites/animals/crustaceans/"

  attr_reader :key, :name, :latin, :sheet, :frame_w, :frame_h, :frames_per_row,
              :biomes, :shallowest, :deepest, :rarity, :points, :habitat, :tease

  # habitat says *where in the water* a species lives, and so which of the sea's
  # populations it belongs to: :water is the swarm in the column, :floor walks on
  # the sand. It is not decoration — the two are rolled separately, so a crab
  # never spawns hanging in mid-water and a fish never rests on the bottom.
  #
  # tease is what you call it before you know what it is: down in the water a
  # species gives its name only once it is in the Artenbuch, and until then this
  # is what the lens says instead. It has to be short enough for one line and
  # loose enough to be a guess — what a diver would scribble having seen a thing
  # go past, not a description of it.
  def initialize(key:, name:, latin:, sheet:, biomes:, shallowest:, deepest:,
                 rarity:, points:, tease:, frame_w: 32, frame_h: 16, frames_per_row: 8,
                 habitat: :water)
    @key = key
    @name = name
    @latin = latin
    @sheet = sheet
    @frame_w = frame_w
    @frame_h = frame_h
    @frames_per_row = frames_per_row
    @biomes = biomes
    @shallowest = shallowest
    @deepest = deepest
    @rarity = rarity
    @points = points
    @habitat = habitat
    @tease = tease
  end

  def lives_at?(biome_name, depth)
    biomes.include?(biome_name) && depth >= shallowest && depth <= deepest
  end

  def weight
    RARITIES[rarity]
  end

  ALL = [
    new(key: "burgunder", name: "Blauer Burgunder", latin: "Vinum caeruleum",
        sheet: SCALAR + "blue.png", biomes: ["Sandbank", "Riff"],
        shallowest: 0, deepest: 55, rarity: :common, tease: "etwas Blaues, sehr Gemütliches",
        points: 5),

    new(key: "hornhering", name: "Gemeiner Hornhering", latin: "Clupea cornuta",
        sheet: BASS + "grey.png", biomes: ["Sandbank", "Kelpwald"],
        shallowest: 0, deepest: 70, rarity: :common, tease: "grau, mit Hörnchen am Kopf",
        points: 5),

    new(key: "scalarus", name: "Scalarus Coloris", latin: "Scalarus coloris",
        sheet: SCALAR + "orange.png", biomes: ["Riff", "Sandbank"],
        shallowest: 0, deepest: 60, rarity: :common, tease: "bunt und auffällig flach",
        points: 6),

    new(key: "zottelmaul", name: "Grünes Zottelmaul", latin: "Barbatus vorax",
        sheet: SCALAR + "green.png", biomes: ["Kelpwald"],
        shallowest: 0, deepest: 80, rarity: :common, tease: "grün und ziemlich zottelig",
        points: 8),

    new(key: "doktor", name: "Dicker Doktor", latin: "Medicus obesus",
        sheet: BASS + "orange.png", biomes: ["Kelpwald", "Riff"],
        shallowest: 10, deepest: 75, rarity: :uncommon, tease: "auffällig gut genährt",
        points: 14),

    new(key: "rabauke", name: "Roter Rabaukenbarsch", latin: "Perca turbulenta",
        sheet: BASS + "red.png", biomes: ["Riff"],
        shallowest: 5, deepest: 65, rarity: :uncommon, tease: "rot und schlecht gelaunt",
        points: 16),

    new(key: "prunkflosser", name: "Purpurner Prunkflosser", latin: "Pompa purpurea",
        sheet: SCALAR + "purple.png", biomes: ["Riff", "Tiefsee"],
        shallowest: 40, deepest: 120, rarity: :uncommon, tease: "lila, hält sich für was",
        points: 22),

    new(key: "truebfisch", name: "Tiefblauer Trübfisch", latin: "Obscurus caeruleus",
        sheet: BASS + "blue.png", biomes: ["Tiefsee"],
        shallowest: 60, deepest: 200, rarity: :common, tease: "blau, wirkt bedrückt",
        points: 18),

    new(key: "laternentraeger", name: "Fahler Laternenträger", latin: "Lucerna abyssi",
        sheet: SCALAR + "purple.png", biomes: ["Tiefsee"],
        shallowest: 95, deepest: 260, rarity: :rare, tease: "blass, leuchtet vor sich hin",
        points: 45),

    new(key: "schattenhai", name: "Schwarzer Schattenhai", latin: "Carcharias umbra",
        sheet: "sprites/animals/dark_shark_32_32/shark.png",
        frame_w: 32, frame_h: 32, biomes: ["Tiefsee"],
        shallowest: 0, deepest: 300, rarity: :rare, tease: "groß. sehr groß.",
        points: 70),

    # --- the sea floor ------------------------------------------------------
    # Crustaceans. They are not just more species: they are the reason to look
    # *down*. Everything above swims past you at eye level, so a roster that
    # lives on the sand rewards a different way of diving — slow, close to the
    # bottom, and reading the terrain.
    # The depth bands are set against where the sea floor actually *is* (roughly
    # 20–95 m over the shelf, far deeper in the troughs), not against a tidy
    # scale — otherwise a whole biome's sand comes out bare, and whichever
    # species happens to span the common depths becomes the one you always see
    # however rare it is meant to be.
    new(key: "taschenkrebs", name: "Gemeiner Taschenkrebs", latin: "Cancer vulgaris",
        sheet: SHELLS + "taschenkrebs.png", frame_w: 20, frame_h: 12, habitat: :floor,
        biomes: ["Sandbank", "Riff"],
        shallowest: 0, deepest: 70, rarity: :common, tease: "krabbelt seitwärts, hat Scheren",
        points: 6),

    new(key: "einsiedler", name: "Einsiedler Fritz", latin: "Eremita domestica",
        sheet: SHELLS + "einsiedler.png", frame_w: 20, frame_h: 12, habitat: :floor,
        biomes: ["Sandbank", "Riff"],
        shallowest: 0, deepest: 80, rarity: :common, tease: "ein Schneckenhaus mit Beinen",
        points: 8),

    new(key: "winkerkrabbe", name: "Grüne Winkerkrabbe", latin: "Uca salutans",
        sheet: SHELLS + "winkerkrabbe.png", frame_w: 20, frame_h: 12, habitat: :floor,
        biomes: ["Kelpwald", "Sandbank"],
        shallowest: 0, deepest: 75, rarity: :common, tease: "winkt mit einer Riesenschere",
        points: 10),

    new(key: "schlickkrebs", name: "Grauer Schlickkrebs", latin: "Cancer limosus",
        sheet: SHELLS + "schlickkrebs.png", frame_w: 20, frame_h: 12, habitat: :floor,
        biomes: ["Tiefsee", "Kelpwald"],
        shallowest: 50, deepest: 165, rarity: :common, tease: "grau, staubt beim Laufen",
        points: 12),

    new(key: "hummer", name: "Roter Panzerhummer", latin: "Homarus loricatus",
        sheet: SHELLS + "hummer.png", frame_w: 20, frame_h: 12, habitat: :floor,
        biomes: ["Riff", "Kelpwald"],
        shallowest: 15, deepest: 95, rarity: :uncommon, tease: "rot, gepanzert, sehr wehrhaft",
        points: 20),

    new(key: "languste", name: "Gestreifte Languste", latin: "Palinurus fasciatus",
        sheet: SHELLS + "languste.png", frame_w: 20, frame_h: 12, habitat: :floor,
        biomes: ["Riff", "Tiefsee"],
        shallowest: 55, deepest: 130, rarity: :uncommon, tease: "gestreift, unfassbar lange Fühler",
        points: 28),

    # Down where the suit already complains. The last page of the crustacean
    # chapter costs the same kind of nerve the Laternenträger does.
    new(key: "abgrundkrabbe", name: "Blasse Abgrundkrabbe", latin: "Macrocheira abyssi",
        sheet: SHELLS + "abgrundkrabbe.png", frame_w: 20, frame_h: 12, habitat: :floor,
        biomes: ["Tiefsee"],
        shallowest: 105, deepest: 280, rarity: :rare, tease: "blass, viel zu lange Beine",
        points: 55),

    # --- above the waterline -------------------------------------------------
    # A beach is a habitat too. It photographs from the water with your head in
    # the air, which turns surfacing beside an island into something you do for
    # a reason rather than only for breath. Beaches happen in every biome, so
    # this one is at home on all of them.
    new(key: "strandkrabbe", name: "Flinke Strandkrabbe", latin: "Carcinus litoralis",
        sheet: SHELLS + "strandkrabbe.png", frame_w: 20, frame_h: 12, habitat: :shore,
        biomes: ["Sandbank", "Kelpwald", "Riff", "Tiefsee"],
        shallowest: 0, deepest: 5, rarity: :common, tease: "flink, immer im Trockenen",
        points: 14),
  ]

  # The legend of the deep. Deliberately NOT in ALL: it never joins the roster or
  # the Artenbuch, and it can't really be photographed — it only lets you believe
  # you could (see app/world/kraken.rb). A name of question marks, the way a
  # diver would log a thing they never quite saw.
  KRAKEN = new(key: "kraken", name: "? ? ?", latin: "Architeuthis umbra",
               sheet: "sprites/animals/dark_shark_32_32/shark.png", frame_w: 32, frame_h: 32,
               biomes: [], shallowest: 130, deepest: 400, rarity: :rare, tease: "da ist etwas",
        points: 0)

  BY_KEY = ALL.each_with_object({}) { |species, index| index[species.key] = species }

  def self.[](key)
    BY_KEY[key]
  end

  # What turns up in this water: one of the species that lives in this biome at
  # this depth, weighted so common things are common. Falls back to whatever
  # lives in the biome at all — a stretch of sea should never come out empty
  # just because its floor happens to sit at an awkward depth.
  def self.pick(biome, depth)
    here = swimmers.select { |s| s.lives_at?(biome.name, depth) }
    here = swimmers.select { |s| s.biomes.include?(biome.name) } if here.empty?
    weighted(here)
  end

  # What is walking about on the sand here. Deliberately *without* the fallback
  # the swimming roll has: if nothing on the roster lives on this floor at this
  # depth, the sand is simply bare. The deep crab staying deep is what makes it
  # worth going down for — a fallback would hand it to you on a shallow bank.
  def self.pick_floor(biome, depth)
    weighted(ALL.select { |s| s.habitat == :floor && s.lives_at?(biome.name, depth) })
  end

  # What lives on the beaches of this biome's islands. No depth: up here there
  # is only the one band of sand between the water and the palms.
  def self.pick_shore(biome)
    weighted(ALL.select { |s| s.habitat == :shore && s.biomes.include?(biome.name) })
  end

  # Everything in the water column. The shark is excluded because it is placed
  # by the biome itself, not spawned into the swarm.
  def self.swimmers
    ALL.select { |s| s.habitat == :water && s.key != "schattenhai" }
  end

  def self.weighted(candidates)
    return nil if candidates.empty?

    total = candidates.reduce(0) { |sum, s| sum + s.weight }
    roll = rand(total)
    candidates.each do |species|
      roll -= species.weight
      return species if roll < 0
    end
    candidates.last
  end
end

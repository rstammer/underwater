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
  RARITIES = { common: 8, uncommon: 3, rare: 1 }

  SCALAR = "sprites/animals/scalar_32_16/"
  BASS = "sprites/animals/bass1_32_16/"

  attr_reader :key, :name, :latin, :sheet, :frame_w, :frame_h, :frames_per_row,
              :biomes, :shallowest, :deepest, :rarity, :points

  def initialize(key:, name:, latin:, sheet:, biomes:, shallowest:, deepest:,
                 rarity:, points:, frame_w: 32, frame_h: 16, frames_per_row: 8)
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
        shallowest: 0, deepest: 55, rarity: :common, points: 5),

    new(key: "hornhering", name: "Gemeiner Hornhering", latin: "Clupea cornuta",
        sheet: BASS + "grey.png", biomes: ["Sandbank", "Kelpwald"],
        shallowest: 0, deepest: 70, rarity: :common, points: 5),

    new(key: "scalarus", name: "Scalarus Coloris", latin: "Scalarus coloris",
        sheet: SCALAR + "orange.png", biomes: ["Riff", "Sandbank"],
        shallowest: 0, deepest: 60, rarity: :common, points: 6),

    new(key: "zottelmaul", name: "Grünes Zottelmaul", latin: "Barbatus vorax",
        sheet: SCALAR + "green.png", biomes: ["Kelpwald"],
        shallowest: 0, deepest: 80, rarity: :common, points: 8),

    new(key: "doktor", name: "Dicker Doktor", latin: "Medicus obesus",
        sheet: BASS + "orange.png", biomes: ["Kelpwald", "Riff"],
        shallowest: 10, deepest: 75, rarity: :uncommon, points: 14),

    new(key: "rabauke", name: "Roter Rabaukenbarsch", latin: "Perca turbulenta",
        sheet: BASS + "red.png", biomes: ["Riff"],
        shallowest: 5, deepest: 65, rarity: :uncommon, points: 16),

    new(key: "prunkflosser", name: "Purpurner Prunkflosser", latin: "Pompa purpurea",
        sheet: SCALAR + "purple.png", biomes: ["Riff", "Tiefsee"],
        shallowest: 40, deepest: 120, rarity: :uncommon, points: 22),

    new(key: "truebfisch", name: "Tiefblauer Trübfisch", latin: "Obscurus caeruleus",
        sheet: BASS + "blue.png", biomes: ["Tiefsee"],
        shallowest: 60, deepest: 200, rarity: :common, points: 18),

    new(key: "laternentraeger", name: "Fahler Laternenträger", latin: "Lucerna abyssi",
        sheet: SCALAR + "purple.png", biomes: ["Tiefsee"],
        shallowest: 95, deepest: 260, rarity: :rare, points: 45),

    new(key: "schattenhai", name: "Schwarzer Schattenhai", latin: "Carcharias umbra",
        sheet: "sprites/animals/dark_shark_32_32/shark.png",
        frame_w: 32, frame_h: 32, biomes: ["Tiefsee"],
        shallowest: 0, deepest: 300, rarity: :rare, points: 70),
  ]

  # The legend of the deep. Deliberately NOT in ALL: it never joins the roster or
  # the Artenbuch, and it can't really be photographed — it only lets you believe
  # you could (see app/world/kraken.rb). A name of question marks, the way a
  # diver would log a thing they never quite saw.
  KRAKEN = new(key: "kraken", name: "? ? ?", latin: "Architeuthis umbra",
               sheet: "sprites/animals/dark_shark_32_32/shark.png", frame_w: 32, frame_h: 32,
               biomes: [], shallowest: 130, deepest: 400, rarity: :rare, points: 0)

  BY_KEY = ALL.each_with_object({}) { |species, index| index[species.key] = species }

  def self.[](key)
    BY_KEY[key]
  end

  # What turns up in this water: one of the species that lives in this biome at
  # this depth, weighted so common things are common. Falls back to whatever
  # lives in the biome at all — a stretch of sea should never come out empty
  # just because its floor happens to sit at an awkward depth.
  def self.pick(biome, depth)
    here = ALL.select { |s| s.lives_at?(biome.name, depth) && s.key != "schattenhai" }
    here = ALL.select { |s| s.biomes.include?(biome.name) && s.key != "schattenhai" } if here.empty?
    weighted(here)
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

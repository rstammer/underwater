# Everything that swims out there, as a roster. Documenting these is the point
# of the game: each one photographed for the first time goes into the Artenbuch
# and is worth its fee.
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
  JELLIES = "sprites/animals/jellies/"
  # Everything that holds on rather than swims: the corals, and the seahorse
  # that grips a frond of kelp and stays put.
  ANCHORED = "sprites/animals/anchored/"

  attr_reader :key, :name, :latin, :sheet, :frame_w, :frame_h, :frames_per_row,
              :biomes, :shallowest, :deepest, :rarity, :fee, :habitat, :tease, :shy,
              :size_cm, :photo_span, :shoal

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
  # shy is how close you may come, in px, before it bolts — 0 for anything that
  # has no reason to be frightened of a diver. It is set *above* PHOTO_CLOSE on
  # purpose: a perfect frame is nearer than a shy fish will tolerate being
  # approached, so the only way to get one is to stop and let it come to you.
  # Tied loosely to rarity, which makes a difficulty curve out of nothing.
  #
  # size_cm is how big the animal actually is, which the sprite cannot say — a
  # crab and a shark are both a handful of pixels on the screen. It is what makes
  # a developed print read as a field note rather than a receipt, and it is the
  # first describable property a species has: an assignment like "photograph
  # something over a metre" needs a number to ask about.
  # photo_span multiplies the camera's reach for this animal. A thirty-metre
  # whale cannot be judged by the same distances as a hand-sized fish: at the
  # range where a burgunder is "perfekt" you are looking at one flank and no
  # more. It scales the whole ladder, so the *rule* is untouched — near is still
  # sharp — but what counts as near is a fact about the animal.
  #
  # shoal is how many of a kind swim together, 1 for anything met alone. It
  # exists because a photograph is a *crop* now: a frame can hold more than one
  # animal, and asking for "two fish at once" is only a fair thing to ask if the
  # sea puts two fish together in the first place. It is loosely the opposite of
  # rarity — herring come in numbers, the lanternbearer does not, and the shark
  # least of all — so it doubles as a difficulty curve for group shots.
  def initialize(key:, name:, latin:, sheet:, biomes:, shallowest:, deepest:,
                 rarity:, fee:, tease:, size_cm: 0, frame_w: 32, frame_h: 16,
                 frames_per_row: 8, habitat: :water, shy: 0, photo_span: 1,
                 shoal: 1)
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
    @fee = fee
    @habitat = habitat
    @tease = tease
    @shy = shy
    @size_cm = size_cm
    @photo_span = photo_span
    @shoal = shoal
  end

  def shoals?
    shoal > 1
  end

  def lives_at?(biome_name, depth)
    biomes.include?(biome_name) && depth >= shallowest && depth <= deepest
  end

  # How big it is, said the way a diver would say it. Anything a metre or over
  # stops being a number of centimetres and becomes a number of metres — "380 cm"
  # is arithmetic, "3,8 m" is a shark. German decimal comma, built by hand rather
  # than by a format string, because there is no locale in here to ask.
  def size_label
    return "#{size_cm} cm" if size_cm < 100

    "#{size_cm.idiv(100)},#{(size_cm % 100).idiv(10)} m"
  end

  def weight
    RARITIES[rarity]
  end

  ALL = [
    new(key: "burgunder", name: "Blauer Burgunder", latin: "Vinum caeruleum",
        sheet: SCALAR + "blue.png", biomes: ["Sandbank", "Riff"],
        shallowest: 0, deepest: 55, rarity: :common, tease: "etwas Blaues, sehr Gemütliches",
        shy: 110, shoal: 5, size_cm: 22,
        fee: 5),

    new(key: "hornhering", name: "Gemeiner Hornhering", latin: "Clupea cornuta",
        sheet: BASS + "grey.png", biomes: ["Sandbank", "Kelpwald"],
        shallowest: 0, deepest: 70, rarity: :common, tease: "grau, mit Hörnchen am Kopf",
        shy: 110, shoal: 6, size_cm: 28,
        fee: 5),

    new(key: "scalarus", name: "Scalarus Coloris", latin: "Scalarus coloris",
        sheet: SCALAR + "orange.png", biomes: ["Riff", "Sandbank"],
        shallowest: 0, deepest: 60, rarity: :common, tease: "bunt und auffällig flach",
        shy: 120, shoal: 5, size_cm: 18,
        fee: 6),

    new(key: "zottelmaul", name: "Grünes Zottelmaul", latin: "Barbatus vorax",
        sheet: SCALAR + "green.png", biomes: ["Kelpwald"],
        shallowest: 0, deepest: 80, rarity: :common, tease: "grün und ziemlich zottelig",
        shy: 130, shoal: 4, size_cm: 34,
        fee: 8),

    new(key: "doktor", name: "Dicker Doktor", latin: "Medicus obesus",
        sheet: BASS + "orange.png", biomes: ["Kelpwald", "Riff"],
        shallowest: 10, deepest: 75, rarity: :uncommon, tease: "auffällig gut genährt",
        shy: 150, shoal: 2, size_cm: 41,
        fee: 14),

    new(key: "rabauke", name: "Roter Rabaukenbarsch", latin: "Perca turbulenta",
        sheet: BASS + "red.png", biomes: ["Riff"],
        shallowest: 5, deepest: 65, rarity: :uncommon, tease: "rot und schlecht gelaunt",
        shy: 150, shoal: 3, size_cm: 33,
        fee: 16),

    new(key: "prunkflosser", name: "Purpurner Prunkflosser", latin: "Pompa purpurea",
        sheet: SCALAR + "purple.png", biomes: ["Riff", "Tiefsee"],
        shallowest: 40, deepest: 120, rarity: :uncommon, tease: "lila, hält sich für was",
        shy: 170, shoal: 2, size_cm: 26,
        fee: 22),

    new(key: "truebfisch", name: "Tiefblauer Trübfisch", latin: "Obscurus caeruleus",
        sheet: BASS + "blue.png", biomes: ["Tiefsee", "Blauwasser", "Quallenfeld", "Wrack"],
        shallowest: 60, deepest: 200, rarity: :common, tease: "blau, wirkt bedrückt",
        shy: 130, shoal: 4, size_cm: 47,
        fee: 18),

    new(key: "laternentraeger", name: "Fahler Laternenträger", latin: "Lucerna abyssi",
        sheet: SCALAR + "purple.png", biomes: ["Tiefsee", "Quallenfeld", "Wrack"],
        shallowest: 95, deepest: 260, rarity: :rare, tease: "blass, leuchtet vor sich hin",
        shy: 200, size_cm: 38,
        fee: 45),

    new(key: "schattenhai", name: "Schwarzer Schattenhai", latin: "Carcharias umbra",
        sheet: "sprites/animals/dark_shark_32_32/shark.png",
        frame_w: 32, frame_h: 32, biomes: ["Tiefsee"],
        shallowest: 0, deepest: 300, rarity: :rare, tease: "groß. sehr groß.",
        size_cm: 380,
        fee: 70),

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
        size_cm: 15,
        fee: 6),

    new(key: "einsiedler", name: "Einsiedler Fritz", latin: "Eremita domestica",
        sheet: SHELLS + "einsiedler.png", frame_w: 20, frame_h: 12, habitat: :floor,
        biomes: ["Sandbank", "Riff"],
        shallowest: 0, deepest: 80, rarity: :common, tease: "ein Schneckenhaus mit Beinen",
        size_cm: 9,
        fee: 8),

    new(key: "winkerkrabbe", name: "Grüne Winkerkrabbe", latin: "Uca salutans",
        sheet: SHELLS + "winkerkrabbe.png", frame_w: 20, frame_h: 12, habitat: :floor,
        biomes: ["Kelpwald", "Sandbank"],
        shallowest: 0, deepest: 75, rarity: :common, tease: "winkt mit einer Riesenschere",
        size_cm: 7,
        fee: 10),

    new(key: "schlickkrebs", name: "Grauer Schlickkrebs", latin: "Cancer limosus",
        sheet: SHELLS + "schlickkrebs.png", frame_w: 20, frame_h: 12, habitat: :floor,
        biomes: ["Tiefsee", "Kelpwald", "Quallenfeld", "Blauwasser", "Wrack"],
        shallowest: 50, deepest: 165, rarity: :common, tease: "grau, staubt beim Laufen",
        size_cm: 12,
        fee: 12),

    new(key: "hummer", name: "Roter Panzerhummer", latin: "Homarus loricatus",
        sheet: SHELLS + "hummer.png", frame_w: 20, frame_h: 12, habitat: :floor,
        biomes: ["Riff", "Kelpwald"],
        shallowest: 15, deepest: 95, rarity: :uncommon, tease: "rot, gepanzert, sehr wehrhaft",
        size_cm: 52,
        fee: 20),

    new(key: "languste", name: "Gestreifte Languste", latin: "Palinurus fasciatus",
        sheet: SHELLS + "languste.png", frame_w: 20, frame_h: 12, habitat: :floor,
        biomes: ["Riff", "Tiefsee"],
        shallowest: 55, deepest: 130, rarity: :uncommon, tease: "gestreift, unfassbar lange Fühler",
        size_cm: 44,
        fee: 28),

    # Down where the suit already complains. The last page of the crustacean
    # chapter costs the same kind of nerve the Laternenträger does.
    new(key: "abgrundkrabbe", name: "Blasse Abgrundkrabbe", latin: "Macrocheira abyssi",
        sheet: SHELLS + "abgrundkrabbe.png", frame_w: 20, frame_h: 12, habitat: :floor,
        biomes: ["Tiefsee", "Blauwasser", "Wrack"],
        shallowest: 105, deepest: 280, rarity: :rare, tease: "blass, viel zu lange Beine",
        size_cm: 260,
        fee: 55),

    # --- above the waterline -------------------------------------------------
    # A beach is a habitat too. It photographs from the water with your head in
    # the air, which turns surfacing beside an island into something you do for
    # a reason rather than only for breath. Beaches happen in every biome, so
    # this one is at home on all of them.
    new(key: "strandkrabbe", name: "Flinke Strandkrabbe", latin: "Carcinus litoralis",
        sheet: SHELLS + "strandkrabbe.png", frame_w: 20, frame_h: 12, habitat: :shore,
        biomes: ["Sandbank", "Kelpwald", "Riff", "Tiefsee", "Blauwasser", "Quallenfeld"],
        shallowest: 0, deepest: 5, rarity: :common, tease: "flink, immer im Trockenen",
        size_cm: 6,
        fee: 14),

    # --- the open blue -------------------------------------------------------
    # habitat :open — not part of any swarm. One animal, crossing the whole sea
    # on its own, placed by app/world/whale.rb rather than scattered into a
    # segment. The roster still carries it, because it is a page in the
    # Artenbuch like everything else, and because the camera needs to know what
    # it is looking at.
    #
    # photo_span is here for it: thirty metres of animal cannot be judged by the
    # same reach as a hand-sized fish. See Game#photo_subject.
    new(key: "blauwal", name: "Grosser Blauwal", latin: "Balaenoptera maxima",
        sheet: "sprites/animals/whales/blauwal.png",
        frame_w: 112, frame_h: 38, frames_per_row: 8, habitat: :open,
        biomes: ["Blauwasser"],
        shallowest: 10, deepest: 260, rarity: :rare, tease: "etwas sehr Grosses",
        size_cm: 3200, photo_span: 4,
        fee: 140),

    # --- what drifts ---------------------------------------------------------
    # habitat :drift — jellyfish, spawned as a *field* rather than one at a time
    # (see Game#spawn_jellies). They do not swim and they do not flee; a field is
    # something you steer around, which is a kind of obstacle the sea has not had
    # before.
    new(key: "mondqualle", name: "Bleiche Mondqualle", latin: "Aurelia pallida",
        sheet: JELLIES + "mondqualle.png", frame_w: 24, frame_h: 30, habitat: :drift,
        biomes: ["Quallenfeld", "Blauwasser"],
        shallowest: 20, deepest: 170, rarity: :common, tease: "durchsichtig, schwebt einfach",
        size_cm: 35, shoal: 5,
        fee: 12),

    new(key: "feuerqualle", name: "Rote Feuerqualle", latin: "Cyanea ignis",
        sheet: JELLIES + "feuerqualle.png", frame_w: 24, frame_h: 30, habitat: :drift,
        biomes: ["Quallenfeld"],
        shallowest: 35, deepest: 210, rarity: :uncommon, tease: "rot, und sie brennt",
        size_cm: 62, shoal: 4,
        fee: 24),

    new(key: "laternenqualle", name: "Leuchtende Laternenqualle", latin: "Lucerna gelida",
        sheet: JELLIES + "laternenqualle.png", frame_w: 24, frame_h: 30, habitat: :drift,
        biomes: ["Quallenfeld"],
        shallowest: 95, deepest: 290, rarity: :rare, tease: "leuchtet von innen",
        size_cm: 46, shoal: 3,
        fee: 52),

    # --- the reef ----------------------------------------------------------
    #
    # habitat :reef is the sessile one. Everything else in the book had to be
    # chased, waited out or crept up on, and photographing it was a question of
    # patience; a coral holds perfectly still and lets you frame it exactly.
    # That makes them the pages a beginner can actually fill — which is the
    # point of putting five of them in the shallowest, brightest water there is.
    # They are worth accordingly little each, and the reef is worth swimming to
    # because there are five of them in one place.
    new(key: "hirnkoralle", name: "Rosa Hirnkoralle", latin: "Cerebrum roseum",
        sheet: ANCHORED + "hirnkoralle.png", frame_w: 18, frame_h: 14,
        frames_per_row: 1, habitat: :sessile,
        biomes: ["Riff"],
        shallowest: 0, deepest: 60, rarity: :common,
        tease: "ein rosa Findling voller Furchen",
        size_cm: 70,
        fee: 12),

    new(key: "geweihkoralle", name: "Orange Geweihkoralle", latin: "Cornua aurantia",
        sheet: ANCHORED + "geweihkoralle.png", frame_w: 18, frame_h: 13,
        frames_per_row: 1, habitat: :sessile,
        biomes: ["Riff"],
        shallowest: 0, deepest: 55, rarity: :common,
        tease: "verzweigt sich wie ein Geweih",
        size_cm: 90,
        fee: 14),

    new(key: "faechergorgonie", name: "Violette Fächergorgonie", latin: "Flabellum violaceum",
        sheet: ANCHORED + "faechergorgonie.png", frame_w: 18, frame_h: 15,
        frames_per_row: 1, habitat: :sessile,
        biomes: ["Riff"],
        shallowest: 10, deepest: 80, rarity: :uncommon,
        tease: "ein Netz, quer zur Strömung gestellt",
        size_cm: 110,
        fee: 22),

    new(key: "orgelkoralle", name: "Rote Orgelkoralle", latin: "Tubipora rubra",
        sheet: ANCHORED + "orgelkoralle.png", frame_w: 18, frame_h: 13,
        frames_per_row: 1, habitat: :sessile,
        biomes: ["Riff"],
        shallowest: 5, deepest: 70, rarity: :uncommon,
        tease: "lauter offene Röhren, dicht an dicht",
        size_cm: 45,
        fee: 26),

    # The deep one of the five: it starts where the others stop, so the reef has
    # a page you cannot fill on your first afternoon in it.
    new(key: "lederkoralle", name: "Gelbe Lederkoralle", latin: "Sarcophyton flavum",
        sheet: ANCHORED + "lederkoralle.png", frame_w: 18, frame_h: 14,
        frames_per_row: 1, habitat: :sessile,
        biomes: ["Riff"],
        shallowest: 45, deepest: 120, rarity: :rare,
        tease: "weich und gelb, mit Polypen aussen",
        size_cm: 55,
        fee: 40),

    # The seahorse. Anchored like a coral, because that is what it does — it
    # grips a frond of kelp with its tail and stays there — but it is an animal,
    # and the only one in the book you photograph standing still on purpose.
    # Rare, and only in the kelp: a seahorse you meet by accident is not a
    # seahorse, it is scenery.
    new(key: "seepferdchen", name: "Goldenes Seepferdchen", latin: "Hippocampus aureus",
        sheet: ANCHORED + "seepferdchen.png", frame_w: 10, frame_h: 20,
        frames_per_row: 1, habitat: :sessile,
        biomes: ["Kelpwald"],
        shallowest: 0, deepest: 65, rarity: :rare,
        tease: "steht senkrecht im Tang und wartet ab",
        size_cm: 14,
        fee: 46),
  ]

  # The legend of the deep. Deliberately NOT in ALL: it never joins the roster or
  # the Artenbuch, and it can't really be photographed — it only lets you believe
  # you could (see app/world/kraken.rb). A name of question marks, the way a
  # diver would log a thing they never quite saw.
  KRAKEN = new(key: "kraken", name: "? ? ?", latin: "Architeuthis umbra",
               sheet: "sprites/animals/dark_shark_32_32/shark.png", frame_w: 32, frame_h: 32,
               biomes: [], shallowest: 130, deepest: 400, rarity: :rare, tease: "da ist etwas",
               size_cm: 0, # nobody has ever measured one
        fee: 0)

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

  # What is growing on this stretch of reef. Depth matters as much as it does on
  # the floor — the leather coral starts where the others have stopped.
  def self.pick_sessile(biome, depth)
    weighted(ALL.select { |s| s.habitat == :sessile && s.lives_at?(biome.name, depth) })
  end

  def self.sessile_species
    ALL.select { |s| s.habitat == :sessile }
  end

  # What lives on the beaches of this biome's islands. No depth: up here there
  # is only the one band of sand between the water and the palms.
  def self.pick_shore(biome)
    weighted(ALL.select { |s| s.habitat == :shore && s.biomes.include?(biome.name) })
  end

  # What drifts in this water: the jellyfish of a field. Like the sea floor's
  # roll and unlike the swarm's, there is no fallback — water that suits no
  # jellyfish simply has none, which is what keeps a field somewhere you *find*.
  def self.pick_drift(biome, depth)
    weighted(ALL.select { |s| s.habitat == :drift && s.lives_at?(biome.name, depth) })
  end

  # The one that crosses the open blue on its own. Not weighted and not rolled
  # against a pool: there is one animal this big, and either this water is its
  # water or it is not.
  def self.giant_for(biome)
    ALL.find { |s| s.habitat == :open && s.biomes.include?(biome.name) }
  end

  # Everything in the water column. The shark is excluded because it is placed
  # by the biome itself, not spawned into the swarm; :open and :drift are their
  # own populations, placed by their own code, and would otherwise turn up as
  # ordinary fish — a thirty-metre whale patrolling a rock crevice.
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

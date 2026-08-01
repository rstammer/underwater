# A biome is the *theme* of an underwater world: its water palette, fog, floor
# colours and how densely it's populated with flora and fauna. The generator
# reads these knobs; hand-built static worlds can reuse them too.
class Biome
  # coral is the scattered *decoration*; anchored_count is how many photographable
  # coral colonies grow here (habitat :reef). Two different things with nearly
  # the same name, which is unfortunate but true to what they are: one is set
  # dressing on the sand, the other is a page in the Artenbuch.
  attr_reader :name, :water_top, :water_bottom, :floor_colors, :fog,
              :seaweed, :coral, :starfish,
              :fish_count, :crab_count, :anchored_count, :shark

  def initialize(name:, water_top:, water_bottom:, floor_colors:, fog:,
                 seaweed:, coral:, starfish:,
                 fish_count:, shark:, crab_count: 0, anchored_count: 0)
    @name = name
    @water_top = water_top
    @water_bottom = water_bottom
    @floor_colors = floor_colors
    @fog = fog
    @seaweed = seaweed
    @coral = coral
    @starfish = starfish
    @fish_count = fish_count
    @crab_count = crab_count
    @anchored_count = anchored_count
    @shark = shark
  end

  # Bright, calm and sandy — the gentle default.
  SANDBANK = new(
    name: "Sandbank",
    water_top: [78, 158, 214], water_bottom: [26, 78, 142],
    floor_colors: [[242, 208, 169], [238, 200, 143], [225, 188, 109]],
    fog: 0.12,
    seaweed: 5, coral: 1, starfish: 4,
    fish_count: 6, crab_count: 3, shark: false,
  )

  # A dense green kelp forest.
  KELP = new(
    name: "Kelpwald",
    water_top: [40, 130, 150], water_bottom: [12, 58, 78],
    floor_colors: [[120, 132, 96], [96, 112, 78], [78, 96, 66]],
    fog: 0.42,
    seaweed: 16, coral: 2, starfish: 2,
    fish_count: 9, crab_count: 2, shark: false,
    # Not coral — the seahorse, which grips a frond and stays. Few of them: the
    # whole point of a seahorse is that you have to find one.
    anchored_count: 3,
  )

  # A colourful reef, full of coral and fish.
  REEF = new(
    name: "Riff",
    water_top: [60, 170, 190], water_bottom: [20, 96, 120],
    floor_colors: [[236, 196, 150], [210, 150, 120], [180, 120, 110]],
    fog: 0.18,
    seaweed: 6, coral: 10, starfish: 5,
    fish_count: 12, crab_count: 3, shark: false,
    # Enough that a stretch of reef is a reef rather than a sandbank with three
    # ornaments on it — and the one biome where the colonies are the point.
    anchored_count: 9,
  )

  # The dark deep — sparse, foggy, and a shark prowls.
  DEEP = new(
    name: "Tiefsee",
    water_top: [24, 60, 104], water_bottom: [6, 18, 44],
    floor_colors: [[60, 66, 84], [48, 54, 72], [38, 44, 60]],
    fog: 0.70,
    seaweed: 3, coral: 1, starfish: 1,
    fish_count: 4, crab_count: 2, shark: true,
  )

  # --- the deep biomes ------------------------------------------------------
  #
  # These two are not rolled anywhere; they only happen where the sea floor has
  # genuinely fallen away (see WorldGenerator#pick_biome). That is the whole
  # point of them: they are the reward for swimming out over a trench rather
  # than a theme that might turn up on a sandbank.

  # The open blue: a water column with nothing much in it and a floor a long way
  # down. Deliberately the *clearest* water in the game — the low fog is not
  # decoration, it is what lets you see all thirty metres of a whale at once.
  # In the murk you would meet a flank and never learn what it belonged to.
  BLUE = new(
    name: "Blauwasser",
    water_top: [46, 122, 186], water_bottom: [10, 40, 92],
    floor_colors: [[70, 84, 110], [58, 70, 94], [46, 56, 78]],
    fog: 0.05,
    seaweed: 1, coral: 0, starfish: 1,
    fish_count: 3, crab_count: 1, shark: false,
  )

  # A drifting field of jellyfish, hanging in still, dim, green-lit water.
  # Nothing hunts here; what makes it dangerous is that it is *in the way*.
  JELLY = new(
    name: "Quallenfeld",
    water_top: [32, 96, 122], water_bottom: [8, 34, 60],
    floor_colors: [[64, 78, 82], [52, 64, 70], [42, 52, 58]],
    fog: 0.52,
    seaweed: 2, coral: 1, starfish: 1,
    fish_count: 3, crab_count: 2, shark: false,
  )

  # What may turn up over an ordinary sea floor ...
  SHALLOW = [SANDBANK, KELP, REEF]
  # ... and what only happens where it has dropped away. The deep sea moved in
  # here too: it used to be rolled anywhere, so a shark biome could sit on a
  # sandbank in twenty metres of water.
  ABYSSAL = [DEEP, BLUE, JELLY]

  ALL = SHALLOW + ABYSSAL
end

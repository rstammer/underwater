# A biome is the *theme* of an underwater world: its water palette, fog, floor
# colours and how densely it's populated with flora and fauna. The generator
# reads these knobs; hand-built static worlds can reuse them too.
class Biome
  attr_reader :name, :water_top, :water_bottom, :floor_colors, :fog,
              :seaweed, :coral, :starfish,
              :fish_count, :crab_count, :shark

  def initialize(name:, water_top:, water_bottom:, floor_colors:, fog:,
                 seaweed:, coral:, starfish:,
                 fish_count:, shark:, crab_count: 0)
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
  )

  # A colourful reef, full of coral and fish.
  REEF = new(
    name: "Riff",
    water_top: [60, 170, 190], water_bottom: [20, 96, 120],
    floor_colors: [[236, 196, 150], [210, 150, 120], [180, 120, 110]],
    fog: 0.18,
    seaweed: 6, coral: 10, starfish: 5,
    fish_count: 12, crab_count: 3, shark: false,
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

  ALL = [SANDBANK, KELP, REEF, DEEP]
end

# Procedurally builds a World from an integer index. Fully deterministic: the
# same index always produces the same world, so worlds are stable when you swim
# back and the whole thing is unit-testable.
#
# The sea floor is *not* rolled per segment. It's sampled from one global terrain
# function of the world x (floor_y_at), layered from several octaves of Noise:
#
#   shelf     very broad — whole regions are a shallow bank or drop into the deep
#   basin     medium bowls inside a region
#   crag      ridged noise: rocky outcrops with sharp peaks
#   dune      the small rolling relief
#   rough     un-interpolated per-cell jitter: the ragged, pixelated sand edge
#
# Because it's a function of the world position, neighbouring segments meet
# seamlessly, and every height snaps to FLOOR_STEP so the sand reads as chunky
# pixel terraces instead of a smooth roof.
class WorldGenerator
  FLOOR_TOP_Y = 40 # world y the shallowest sand starts from (0 = the old floor level)

  SHELF_WAVELENGTH = 5120
  SHELF_DROP = 1500
  SHELF_BIAS = 2.2 # >1 skews the shelf shallow: most of the sea is a bank, now and then it drops away
  BASIN_WAVELENGTH = 2560
  BASIN_DROP = 520
  BASIN_BIAS = 1.6
  CRAG_WAVELENGTH = 384
  CRAG_HEIGHT = 130
  DUNE_WAVELENGTH = 128
  DUNE_HEIGHT = 70
  ROUGH_CELL = 16 # px per jitter cell — the width of one ragged notch
  ROUGH_HEIGHT = 26
  FLOOR_STEP = 8 # sand heights snap to this grid (pixel terraces)

  # Distinct seeds so the layers don't rhyme with each other.
  SHELF_SEED = 101
  BASIN_SEED = 202
  CRAG_SEED = 303
  DUNE_SEED = 404
  ROUGH_SEED = 505

  RELIEF = CRAG_HEIGHT + DUNE_HEIGHT / 2 + ROUGH_HEIGHT / 2
  FLOOR_CEILING = FLOOR_TOP_Y + RELIEF                              # shallowest sand
  FLOOR_BOTTOM = FLOOR_TOP_Y - SHELF_DROP - BASIN_DROP -
                 (DUNE_HEIGHT / 2 + ROUGH_HEIGHT / 2) - FLOOR_STEP  # deepest trench

  def self.columns
    SCREEN_WIDTH / World::COLUMN_WIDTH
  end

  # The sea floor's world y at any world x — the single source of terrain truth.
  # Higher y = shallower; deep trenches are far below 0.
  def self.floor_y_at(world_x)
    y = FLOOR_TOP_Y
    y -= (Noise.value(world_x, SHELF_WAVELENGTH, SHELF_SEED)**SHELF_BIAS) * SHELF_DROP
    y -= (Noise.value(world_x, BASIN_WAVELENGTH, BASIN_SEED)**BASIN_BIAS) * BASIN_DROP
    y += crag_at(world_x)
    y += (Noise.value(world_x, DUNE_WAVELENGTH, DUNE_SEED) - 0.5) * DUNE_HEIGHT
    y += (Noise.jitter(world_x.idiv(ROUGH_CELL), ROUGH_SEED) - 0.5) * ROUGH_HEIGHT
    (y / FLOOR_STEP).floor * FLOOR_STEP
  end

  # Ridged noise: folding the value around its midpoint turns soft hills into
  # peaked outcrops — the rocky bits that break up the dunes.
  def self.crag_at(world_x)
    ridge = 1.0 - (2.0 * Noise.value(world_x, CRAG_WAVELENGTH, CRAG_SEED) - 1.0).abs
    ridge * CRAG_HEIGHT
  end

  def self.generate(index)
    new(index).generate
  end

  def initialize(index)
    @index = index
    @rng = Rng.new(index)
    @biome = pick_biome
  end

  def generate
    floor = build_floor
    World.new(index: @index, biome: @biome, floor: floor,
              decorations: build_decorations(floor))
  end

  private

  # A separate seed keeps the biome choice stable even if floor/decor generation
  # changes later.
  def pick_biome
    r = Rng.new(@index * 2_654_435_761 + 17) # Knuth mix so neighbours decorrelate
    r.next_u32                               # warm past the seeded state
    Biome::ALL[r.int(Biome::ALL.length)]
  end

  # One sample of the global terrain function per column of this segment.
  def build_floor
    origin = @index * SCREEN_WIDTH
    (0...self.class.columns).map do |c|
      self.class.floor_y_at(origin + c * World::COLUMN_WIDTH)
    end
  end

  def build_decorations(floor)
    counts = {
      "seaweed" => @biome.seaweed,
      "coral" => @biome.coral,
      "starfish" => @biome.starfish,
      "rock" => @biome.rocks,
    }

    items = []
    counts.each do |kind, count|
      count.times do
        col = @rng.int(floor.length)
        items << {
          kind: kind,
          x: col * World::COLUMN_WIDTH,
          y: floor[col],
          scale: @rng.between(2, 3),
        }
      end
    end
    items
  end
end

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
  FLOOR_TOP_Y = 360 # world y the shallowest sand starts from (near the surface)

  SHELF_WAVELENGTH = 5120
  SHELF_DROP = 460
  SHELF_BIAS = 1.0 # >1 skews the shelf shallow: most of the sea is a bank, now and then it drops away
  BASIN_WAVELENGTH = 2560
  BASIN_DROP = 300
  BASIN_BIAS = 1.0

  # Broad deep basins. Whole stretches of sea where the floor sinks far below the
  # shelf into a long descent — not the sheer plunge of a chasm, but a wide bowl
  # you swim down and down into before the sand comes up to meet you. This is the
  # everyday deep the sea is *made* of, so it's common and broad rather than rare.
  TROUGH_WAVELENGTH = 3072
  TROUGH_THRESHOLD = 0.48 # roughly half the sea sinks into a basin, deepest where the noise peaks
  TROUGH_DROP = 1500

  # Now and then the floor gives way completely. A chasm plunges far past what a
  # standard suit can take — visible, reachable, and lethal to linger in. This is
  # the deep you dive *toward* once you have better gear.
  CHASM_WAVELENGTH = 1600
  CHASM_THRESHOLD = 0.68 # only the top of the noise opens up, so chasms stay rare
  CHASM_DROP = 2600
  CRAG_WAVELENGTH = 384
  CRAG_HEIGHT = 200
  DUNE_WAVELENGTH = 128
  DUNE_HEIGHT = 110
  ROUGH_CELL = 16 # px per jitter cell — the width of one ragged notch
  ROUGH_HEIGHT = 26
  FLOOR_STEP = 8 # sand heights snap to this grid (pixel terraces)

  # Terraces: the floor is sampled once per terrace and held flat across it, and
  # terraces come in different widths so the bottom doesn't read as one regular
  # comb. A block is subdivided into equal terraces; the divisor is drawn per
  # block, weighted toward the narrow end. Blocks tile SCREEN_WIDTH exactly, so a
  # terrace never straddles a segment border.
  TERRACE_BLOCK = 64
  TERRACE_WIDTHS = [8, 8, 16, 16, 32, 64]

  # Distinct seeds so the layers don't rhyme with each other.
  SHELF_SEED = 101
  BASIN_SEED = 202
  CRAG_SEED = 303
  DUNE_SEED = 404
  ROUGH_SEED = 505
  TERRACE_SEED = 606
  CHASM_SEED = 1010
  TROUGH_SEED = 1212

  RELIEF = CRAG_HEIGHT + DUNE_HEIGHT / 2 + ROUGH_HEIGHT / 2
  FLOOR_CEILING = FLOOR_TOP_Y + RELIEF                              # shallowest sand
  FLOOR_BOTTOM = FLOOR_TOP_Y - SHELF_DROP - BASIN_DROP - TROUGH_DROP - CHASM_DROP -
                 (DUNE_HEIGHT / 2 + ROUGH_HEIGHT / 2) - FLOOR_STEP  # bottom of the deepest chasm

  def self.columns
    SCREEN_WIDTH / World::COLUMN_WIDTH
  end

  # The sea floor's world y at any world x — the single source of terrain truth.
  # Higher y = shallower; deep trenches are far below 0. Sampled once per terrace
  # and held flat across it, so the sand steps instead of curving.
  def self.floor_y_at(world_x)
    x = terrace_start(world_x)
    y = ground_level_at(x)
    y += crag_at(x)
    y += (Noise.value(x, DUNE_WAVELENGTH, DUNE_SEED) - 0.5) * DUNE_HEIGHT
    y += (Noise.jitter(x.idiv(ROUGH_CELL), ROUGH_SEED) - 0.5) * ROUGH_HEIGHT
    (y / FLOOR_STEP).floor * FLOOR_STEP
  end

  # The sea floor as a smooth curve: everything except the terracing and the
  # per-cell jitter. This is what the camera rides (Game#camera_floor_y) — it
  # tracks the sand the diver actually stands on to within a few px, but without
  # the steps and notches that would shake the view.
  def self.smooth_floor_y_at(world_x)
    (ground_level_at(world_x) + crag_at(world_x) +
      (Noise.value(world_x, DUNE_WAVELENGTH, DUNE_SEED) - 0.5) * DUNE_HEIGHT).to_i
  end

  # The broad shape alone: shelves, basins and chasms, without the local relief.
  def self.ground_level_at(world_x)
    y = FLOOR_TOP_Y
    y -= (Noise.value(world_x, SHELF_WAVELENGTH, SHELF_SEED)**SHELF_BIAS) * SHELF_DROP
    y -= (Noise.value(world_x, BASIN_WAVELENGTH, BASIN_SEED)**BASIN_BIAS) * BASIN_DROP
    y.to_i + trough_at(world_x) + chasm_at(world_x)
  end

  # How far the floor sinks into a broad deep basin here, or 0 up on the shelf.
  # Above the threshold the bowl opens gradually and its walls come down smoothly
  # (the camera rides this, so it must not step), reaching its full drop where the
  # noise peaks — so basins are wide, common, and a genuinely long swim down.
  def self.trough_at(world_x)
    depth = Noise.value(world_x, TROUGH_WAVELENGTH, TROUGH_SEED)
    return 0 if depth < TROUGH_THRESHOLD

    t = (depth - TROUGH_THRESHOLD) / (1.0 - TROUGH_THRESHOLD)
    (-TROUGH_DROP * (t * t * (3 - 2 * t))).to_i
  end

  # How far the floor has fallen away here, or 0 out on the ordinary shelf. Only
  # the very top of the noise opens into a chasm, and the walls come down
  # smoothly (the camera rides this, so it must not step).
  def self.chasm_at(world_x)
    depth = Noise.value(world_x, CHASM_WAVELENGTH, CHASM_SEED)
    return 0 if depth < CHASM_THRESHOLD

    t = (depth - CHASM_THRESHOLD) / (1.0 - CHASM_THRESHOLD)
    (-CHASM_DROP * (t * t * (3 - 2 * t))).to_i
  end

  # World x where this position's terrace begins — every x on the same terrace
  # answers the same, which is what makes the sand flat across it.
  def self.terrace_start(world_x)
    block = world_x.idiv(TERRACE_BLOCK)
    pick = (Noise.jitter(block, TERRACE_SEED) * TERRACE_WIDTHS.length).to_i
    pick = TERRACE_WIDTHS.length - 1 if pick >= TERRACE_WIDTHS.length
    width = TERRACE_WIDTHS[pick]
    offset = world_x - block * TERRACE_BLOCK
    block * TERRACE_BLOCK + offset.idiv(width) * width
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

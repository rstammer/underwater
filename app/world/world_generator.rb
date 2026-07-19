# Procedurally builds a World from an integer index. Fully deterministic: the
# same index always produces the same world (seeded Rng), so worlds are stable
# when you swim back and the whole thing is unit-testable.
class WorldGenerator
  FLOOR_BASE = 24       # minimum sand height
  FLOOR_AMPLITUDE = 46  # how tall the dunes can rise above the base
  CONTROL_EVERY = 8     # columns between heightmap control points (dune width)

  def self.columns
    SCREEN_WIDTH / World::COLUMN_WIDTH
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

  # Value-noise heightmap: a few random control heights, linearly interpolated
  # into smooth rolling dunes.
  def build_floor
    cols = self.class.columns
    control_count = cols / CONTROL_EVERY + 2
    controls = (0...control_count).map { FLOOR_BASE + @rng.int(FLOOR_AMPLITUDE) }

    (0...cols).map do |c|
      seg = c / CONTROL_EVERY
      t = (c % CONTROL_EVERY) / CONTROL_EVERY.to_f
      a = controls[seg]
      b = controls[seg + 1]
      (a + (b - a) * t).to_i
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

# An island: the hand-built places in an otherwise generated sea.
#
# It is *stamped onto* a generated world rather than replacing it, so the terrain
# still meets its neighbours seamlessly at the segment borders — only the middle
# of the segment is rebuilt. Above the waterline it breaks the surface as a
# terraced, overgrown hump you can swim up to but not climb; at its base a tunnel
# runs all the way through, with a chamber of trapped air halfway.
#
# Every island is built from *its own* segment: span and height are rolled from
# the index, and the skyline is noise sampled at the world position — so no two
# islands look alike.
class IslandWorld
  SPAN_MIN = 880       # px of island across (centred; the segment borders stay untouched)
  SPAN_MAX = 1120
  PEAK_MIN = 220       # how far above the waterline the summit may rise
  PEAK_MAX = 300
  CROWN_MAX = 330      # ... and never higher than this, or the summit is cut off
                       # by the top of the screen when you look from the surface
  SHORE_LIP = 24       # how far the rock still stands out of the water at the shore
  TUNNEL_HEIGHT = 200  # clear water between the tunnel floor and its roof
  DOME_SPAN = 240      # width of the air chamber halfway through the tunnel
  DOME_RISE = 260      # how much higher the chamber's roof sits than the tunnel's
  AIR_DEPTH = 90       # how deep the air trapped under that roof reaches
  CROWN_STEP = 16      # the island's own terrace grid — chunkier than the sea floor
  DECOR_EVERY = 40     # px between the slots plants and rocks may stand in
  SHORE_HEIGHT = 110   # crown height above the water that still counts as beach
  GULL_HEIGHT = 110    # how high over the water the gulls hang
  SHAPE_SEED = 707
  DECOR_SEED = 808

  SCALES = {
    "palm" => 4, "palm_small" => 3, "bush" => 3, "grass" => 3,
    "rock" => 3, "driftwood" => 3, "crab" => 2, "flag" => 3, "gull" => 3,
  }

  def self.build(world)
    new(world).build
  end

  attr_reader :span, :peak

  def initialize(world)
    @world = world
    rng = Rng.new(world.index * 7919 + 31)
    rng.next_u32 # warm past the seeded state
    @span = (SPAN_MIN + rng.int(SPAN_MAX - SPAN_MIN)).idiv(World::COLUMN_WIDTH) * World::COLUMN_WIDTH
    @peak = PEAK_MIN + rng.int(PEAK_MAX - PEAK_MIN)
    @flagged = rng.int(3).zero? # somebody got here first — but not everywhere
  end

  def build
    floor = @world.floor.dup
    roof = Array.new(@world.columns) { nil }
    left = @world.floor[first_column]
    right = @world.floor[last_column - 1]
    # The chamber's roof is level even though the tunnel floor ramps, so the air
    # under it is a clean pocket rather than a wedge.
    dome = tunnel_floor(left, right, chamber_t) + TUNNEL_HEIGHT + DOME_RISE

    (first_column...last_column).each do |col|
      base = tunnel_floor(left, right, span_t(col))
      floor[col] = base
      roof[col] = { ceiling: chamber?(col) ? dome : base + TUNNEL_HEIGHT, crown: crown_y(col) }
    end

    World.new(index: @world.index, biome: @world.biome, floor: floor, roof: roof,
              decorations: decorations(roof), air_pockets: [chamber_air(dome)])
  end

  def first_column
    (SCREEN_WIDTH - span).idiv(2).idiv(World::COLUMN_WIDTH)
  end

  def last_column
    first_column + span.idiv(World::COLUMN_WIDTH)
  end

  def island_column?(col)
    col >= first_column && col < last_column
  end

  # How far along the island a column lies, 0..1.
  def span_t(col)
    (col - first_column) / (last_column - 1 - first_column).to_f
  end

  # The tunnel's bottom: a straight ramp from the sand at one mouth to the sand
  # at the other, so the corridor meets the sea floor flush at both ends and the
  # diver never has to climb a step to get in or out.
  def tunnel_floor(left, right, t)
    y = left + (right - left) * t
    (y / WorldGenerator::FLOOR_STEP).floor * WorldGenerator::FLOOR_STEP
  end

  # The skyline. An envelope pins the rock down to the water at both ends —
  # steeply, so the island has flanks rather than being a dome — while noise
  # sampled from the world position gives it summits, shoulders and saddles of
  # its own. It is all read at the terrace a column belongs to, so the profile
  # steps in plateaus of varying width instead of curving.
  def crown_y(col)
    x = WorldGenerator.terrace_start(world_x(col))
    shape = 0.45 +
            Noise.value(x, 320, SHAPE_SEED) * 0.45 +
            Noise.value(x, 110, SHAPE_SEED + 3) * 0.15
    y = WATERLINE_Y + SHORE_LIP + peak * envelope(terrace_t(x)) * shape
    y = (y / CROWN_STEP).floor * CROWN_STEP
    y = WATERLINE_Y + SHORE_LIP if y < WATERLINE_Y + SHORE_LIP
    y = WATERLINE_Y + CROWN_MAX if y > WATERLINE_Y + CROWN_MAX
    y
  end

  # Steep at the shore, broad up top.
  def envelope(t)
    Math.sin(Math::PI * t)**0.55
  end

  def terrace_t(terraced_world_x)
    t = (terraced_world_x - world_x(first_column)) / (span - World::COLUMN_WIDTH).to_f
    return 0.0 if t < 0.0
    return 1.0 if t > 1.0

    t
  end

  def world_x(col)
    @world.index * SCREEN_WIDTH + col * World::COLUMN_WIDTH
  end

  # Halfway through the tunnel the roof lifts into a chamber. The dome is flat so
  # the air under it is a clean pocket — and leaving it means diving back under
  # the lower tunnel roof.
  def chamber?(col)
    col >= chamber_first && col < chamber_last
  end

  def chamber_first
    (first_column + last_column).idiv(2) - DOME_SPAN.idiv(World::COLUMN_WIDTH).idiv(2)
  end

  def chamber_last
    chamber_first + DOME_SPAN.idiv(World::COLUMN_WIDTH)
  end

  def chamber_t
    span_t((chamber_first + chamber_last).idiv(2))
  end

  # The air trapped under the dome: from the water surface inside the chamber up
  # to the rock. Surfacing in here means breathing — the cave is a rest stop, not
  # a one-way trip.
  def chamber_air(ceiling)
    {
      x: chamber_first * World::COLUMN_WIDTH,
      y: ceiling - AIR_DEPTH,
      w: (chamber_last - chamber_first) * World::COLUMN_WIDTH,
      h: AIR_DEPTH,
    }
  end

  # The sea floor's own decorations survive outside the island (the ones inside
  # would now sit in solid rock); everything else grows on top of it.
  def decorations(roof)
    @world.decorations.reject { |d| island_column?(d[:x].idiv(World::COLUMN_WIDTH)) } +
      plants(roof) + flag(roof) + gulls
  end

  # A slot every DECOR_EVERY px along the crown, most of them filled — the gaps
  # are what keeps it from reading as a row of teeth.
  def plants(roof)
    items = []
    col = first_column
    while col < last_column
      if Noise.jitter(world_x(col), DECOR_SEED) >= 0.22
        kind = plant_for(roof, col)
        items << { kind: kind, x: col * World::COLUMN_WIDTH, y: roof[col][:crown], scale: SCALES[kind] }
      end
      col += DECOR_EVERY.idiv(World::COLUMN_WIDTH)
    end
    items
  end

  # What belongs where: driftwood and crabs down on the beach, palms only on
  # ground flat enough to stand on, bushes and grass up the steep parts.
  def plant_for(roof, col)
    height = roof[col][:crown] - WATERLINE_Y
    kinds =
      if height < SHORE_HEIGHT
        ["grass", "driftwood", "rock", "crab", "grass", "bush"]
      elsif slope_at(roof, col) <= CROWN_STEP
        ["palm", "bush", "palm_small", "grass", "bush", "palm"]
      else
        ["bush", "grass", "rock", "bush", "grass", "palm_small"]
      end
    kinds[(Noise.jitter(world_x(col) + 7, DECOR_SEED + 1) * kinds.length).to_i]
  end

  # How much the crown rises or falls around a column — a palm needs level ground.
  def slope_at(roof, col)
    left = roof[[col - 2, first_column].max][:crown]
    right = roof[[col + 2, last_column - 1].min][:crown]
    (right - left).abs
  end

  # Somebody got to the summit of some of these islands before you did.
  def flag(roof)
    return [] unless @flagged

    col = (first_column...last_column).max_by { |c| roof[c][:crown] }
    [{ kind: "flag", x: col * World::COLUMN_WIDTH, y: roof[col][:crown], scale: SCALES["flag"] }]
  end

  # Gulls hang over the water just off the coast, low enough to actually be in
  # frame from the surface. They drift on their own in the renderer.
  def gulls
    [[first_column - 6, 0], [last_column + 6, 40], [first_column - 18, 26]].map do |col, lift|
      { kind: "gull", x: col * World::COLUMN_WIDTH,
        y: WATERLINE_Y + GULL_HEIGHT + lift, scale: SCALES["gull"] }
    end
  end
end

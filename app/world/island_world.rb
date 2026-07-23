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
  TUNNEL_MIN = 130     # tightest the corridor ever squeezes ...
  TUNNEL_MAX = 300     # ... and the widest it opens out
  TUNNEL_WAVE = 260    # px over which its height changes
  MIN_GAP = 96         # never narrower than this — the diver is 64 tall
  SAG_MAX = 150        # how far the corridor may dip below (or rise above) the straight ramp
  DOME_SPAN = 240      # width of the air chamber halfway through the tunnel
  DOME_RISE = 260      # how much higher the chamber's roof sits than the tunnel's
  AIR_DEPTH = 90       # how deep the air trapped under that roof reaches
  CROWN_STEP = 16      # the island's own terrace grid — chunkier than the sea floor
  PLANT_SPACING = 90   # px of level ground each plant wants for itself
  SHORE_HEIGHT = 110   # crown height above the water that still counts as beach
  SKERRY_LIP_MIN = 20  # lowest a skerry pokes out of the water ...
  SKERRY_LIP_MAX = 76  # ... and highest — low rugged rock, never a summit
  SKERRY_DEPTH = 160   # how far a skerry's base reaches below the waterline
  GULL_HEIGHT = 110    # how high over the water the gulls hang
  # How far out from the island's edges they range, in columns, and how much
  # higher each one flies. Negative = off the left shore, positive = off the right.
  GULL_OFFSETS = [[-92, 30], [-40, 0], [46, 44], [88, 16]]
  MARGIN = 8           # px of bare ground kept at each side of a plant's base
  SHAPE_SEED = 707
  DECOR_SEED = 808
  TUNNEL_SEED = 909
  SKERRY_SEED = 1313
  TUNNEL_PLANTS = ["seaweed", "coral", "rock", "starfish"]

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
    @flagged = rng.int(3).zero?          # somebody got here first — but not everywhere
    @sag = rng.int(SAG_MAX * 2) - SAG_MAX # this tunnel dips, or humps, on its way through
    @chamber_count = 1 + rng.int(2)       # one big chamber, or two smaller stops
    @spot_shift = rng.int(12) / 100.0     # and they aren't always in the same place
  end

  def build
    floor = @world.floor.dup
    roof = Array.new(@world.columns) { nil }

    (first_column...last_column).each do |col|
      base = tunnel_floor_y(col)
      floor[col] = base
      dome = chamber_roof_at(col)
      ceiling = dome || base + tunnel_height(col)
      ceiling = base + MIN_GAP if ceiling - base < MIN_GAP # always swimmable
      roof[col] = { ceiling: ceiling, crown: crown_y(col) }
    end

    skerry_columns.each { |col, rock| roof[col] = rock }

    World.new(index: @world.index, biome: @world.biome, floor: floor, roof: roof,
              decorations: decorations(roof) + tunnel_decor(floor),
              air_pockets: chambers.map { |chamber| chamber_air(chamber) })
  end

  # Rugged rocks that break the surface in the water off the island's shores.
  # They are not the island itself — they make plain that the rock reaches out
  # here and you can't swim straight through: you bump into them up top and dive
  # under to pass. Solid like everything else, so the diver, shark and fish all
  # respect them. Keyed by column so build can drop them straight into the roof.
  def skerry_columns
    @skerry_columns ||= begin
      cols = {}
      skerry_clusters.each do |start, width|
        width.times do |w|
          col = start + w
          next unless col >= 1 && col < @world.columns - 1 # never touch the segment borders
          next if island_column?(col)                      # nor overwrite the island itself

          cols[col] = { ceiling: WATERLINE_Y - SKERRY_DEPTH, crown: skerry_crown(col) }
        end
      end
      cols
    end
  end

  # A skerry pokes out of the water by a rolled amount, its top snapped to the
  # island's terrace grid so it reads as chunky rock rather than a spike.
  def skerry_crown(col)
    lip = SKERRY_LIP_MIN + (Noise.jitter(world_x(col), SKERRY_SEED) * (SKERRY_LIP_MAX - SKERRY_LIP_MIN)).to_i
    ((WATERLINE_Y + lip) / CROWN_STEP).floor * CROWN_STEP
  end

  # Where the stacks stand: a cluster hugging each shore, just off the island's
  # edge in the shallows — [first column, width in columns], rolled from the index
  # so they scatter differently every round. They keep clear of the open water in
  # the middle of the segment, so the rock reads plainly as *the island's*.
  def skerry_clusters
    [
      [first_column - 6 - skerry_roll(1, 3), 3 + skerry_roll(2, 3)],
      [last_column + 2 + skerry_roll(5, 3), 3 + skerry_roll(6, 3)],
    ]
  end

  def skerry_roll(salt, span)
    (Noise.jitter(@world.index * 131 + salt, SKERRY_SEED + 4) * span).to_i
  end

  def mouth_left
    @world.floor[first_column]
  end

  def mouth_right
    @world.floor[last_column - 1]
  end

  # The corridor's bottom: a ramp between the sand at both mouths, plus a sag (or
  # a rise) along the way, so it isn't the same straight run through every island.
  # The deflection is zero at both ends, so the mouths still meet the sea floor
  # flush and there is no step to climb going in or out.
  def tunnel_floor_y(col)
    t = span_t(col)
    y = mouth_left + (mouth_right - mouth_left) * t + @sag * Math.sin(Math::PI * t)
    (y / WorldGenerator::FLOOR_STEP).floor * WorldGenerator::FLOOR_STEP
  end

  # How much clear water the corridor has here — it squeezes down to a crawl in
  # places and opens into halls in others.
  def tunnel_height(col)
    (TUNNEL_MIN +
      (TUNNEL_MAX - TUNNEL_MIN) * Noise.value(world_x(col), TUNNEL_WAVE, TUNNEL_SEED)).to_i
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

  # Along the way the roof lifts into one or two chambers. Each dome is level, so
  # the air under it is a clean pocket — and leaving one means diving back under
  # the lower corridor roof.
  def chambers
    @chambers ||= chamber_spots.map do |spot|
      first = first_column + ((last_column - first_column) * spot).to_i
      last = first + DOME_SPAN.idiv(World::COLUMN_WIDTH)
      mid = (first + last).idiv(2)
      { first: first, last: last, ceiling: tunnel_floor_y(mid) + tunnel_height(mid) + DOME_RISE }
    end
  end

  def chamber_spots
    return [0.42 + @spot_shift] if @chamber_count == 1

    [0.22 + @spot_shift, 0.64 + @spot_shift]
  end

  def chamber_roof_at(col)
    chamber = chambers.find { |c| col >= c[:first] && col < c[:last] }
    chamber && chamber[:ceiling]
  end

  # For anything that just wants "the" chamber — the first one along the tunnel.
  def chamber_first
    chambers.first[:first]
  end

  def chamber_last
    chambers.first[:last]
  end

  # The air trapped under a dome: from the water surface inside the chamber up to
  # the rock. Surfacing in here means breathing — the cave is a rest stop, not a
  # one-way trip.
  def chamber_air(chamber)
    {
      x: chamber[:first] * World::COLUMN_WIDTH,
      y: chamber[:ceiling] - AIR_DEPTH,
      w: (chamber[:last] - chamber[:first]) * World::COLUMN_WIDTH,
      h: AIR_DEPTH,
    }
  end

  # The cave isn't barren: weed, coral and rocks along the corridor floor.
  def tunnel_decor(floor)
    items = []
    col = first_column + 4
    while col < last_column - 4
      roll = Noise.jitter(world_x(col) + 3, DECOR_SEED + 2)
      if roll > 0.45
        kind = TUNNEL_PLANTS[(roll * TUNNEL_PLANTS.length).to_i]
        items << { kind: kind, x: col * World::COLUMN_WIDTH, y: floor[col], scale: 2 }
      end
      col += 9
    end
    items
  end

  # The sea floor's own decorations survive outside the island (the ones inside
  # would now sit in solid rock); everything else grows on top of it.
  def decorations(roof)
    @world.decorations.reject { |d| island_column?(d[:x].idiv(World::COLUMN_WIDTH)) } +
      plants(roof) + flag(roof) + gulls
  end

  # Plants stand on the plateaus, spaced out along them. Placing them at fixed
  # intervals put palms on the very lip of a terrace with half the crown hanging
  # over the drop; a plant belongs on level ground wide enough to hold it.
  def plants(roof)
    items = []
    plateaus(roof).each do |flat|
      ground = flat[:width] * World::COLUMN_WIDTH
      slots = ground.idiv(PLANT_SPACING)
      slots = 1 if slots < 1
      room = ground.idiv(slots)

      slots.times do |i|
        seed = world_x(flat[:first]) + i * 37
        next if Noise.jitter(seed, DECOR_SEED) < 0.18 # leave gaps

        kind = plant_for(flat, room, seed)
        next unless kind

        items << { kind: kind, y: flat[:y], scale: SCALES[kind],
                   x: flat[:first] * World::COLUMN_WIDTH + room * i + room.idiv(2) }
      end
    end
    items
  end

  # The crown as runs of equal height: |first column, width in columns, world y|.
  def plateaus(roof)
    runs = []
    first = first_column
    (first_column + 1..last_column).each do |col|
      next if col < last_column && roof[col][:crown] == roof[first][:crown]

      runs << { first: first, width: col - first, y: roof[first][:crown] }
      first = col
    end
    runs
  end

  # What belongs where: driftwood and crabs down on the beach, and further up
  # whatever actually fits in the space — a palm needs room to stand, a tuft of
  # grass doesn't.
  def plant_for(flat, room, seed)
    kinds =
      if flat[:y] - WATERLINE_Y < SHORE_HEIGHT
        ["grass", "driftwood", "rock", "crab", "grass", "bush"]
      elsif room >= base_width("palm") + MARGIN
        ["palm", "bush", "palm", "palm_small", "bush", "palm"]
      elsif room >= base_width("palm_small") + MARGIN
        ["palm_small", "bush", "grass", "bush", "palm_small", "grass"]
      else
        ["grass", "bush", "grass", "rock", "grass", "bush"]
      end
    kind = kinds[(Noise.jitter(seed + 7, DECOR_SEED + 1) * kinds.length).to_i]
    room >= base_width(kind) + MARGIN ? kind : nil
  end

  # What a plant actually needs level ground for is its foot, not its crown — a
  # palm's fronds may hang out over the drop, its trunk may not.
  def base_width(kind)
    foot = Game::DECOR_SPRITES[kind][:w] * SCALES[kind] / 3
    foot < 16 ? 16 : foot
  end

  # Somebody got to the summit of some of these islands before you did.
  def flag(roof)
    return [] unless @flagged

    top = plateaus(roof).max_by { |flat| flat[:y] * 1000 + flat[:width] } # highest, then widest
    [{ kind: "flag", y: top[:y], scale: SCALES["flag"],
       x: (top[:first] * World::COLUMN_WIDTH) + (top[:width] * World::COLUMN_WIDTH).idiv(2) }]
  end

  # Gulls range well out over the water on both sides, not just over the coast:
  # spotting birds on the horizon is the first hint that there's land out there.
  # They're low enough to be in frame from the surface, and drift on their own in
  # the renderer.
  def gulls
    GULL_OFFSETS.map do |offset, lift|
      col = offset < 0 ? first_column + offset : last_column + offset
      { kind: "gull", x: col * World::COLUMN_WIDTH,
        y: WATERLINE_Y + GULL_HEIGHT + lift, scale: SCALES["gull"] }
    end
  end
end

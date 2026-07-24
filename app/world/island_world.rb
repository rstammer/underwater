# An island: the hand-built places in an otherwise generated sea.
#
# It is *stamped onto* generated worlds rather than replacing them, so the sea
# floor still runs into it seamlessly. An island is **wider than a segment**, so
# it is stamped onto every segment it reaches: each one builds its own slice, and
# because every shape here is a function of the *world* position (never of the
# segment), the slices line up exactly across the borders. Above the waterline it
# breaks the surface as a terraced, overgrown ridge you can swim up to but not
# climb; through its base runs a tunnel with chambers of trapped air.
#
# Everything about an island is rolled from its home sector — the segment it is
# centred on — so every segment that carries a piece of it rolls the same island.
class IslandWorld
  SPAN_MIN = 1800      # px of island across, centred on its home sector: wider
  SPAN_MAX = 2800      # than a segment, so it always crosses at least one border
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
  GALLERY_MIN = 400    # px of upper passage, at the least ...
  GALLERY_MAX = 1000   # ... and at the most
  GALLERY_HEIGHT = 150 # how much clear water an upper passage has
  GALLERY_RISE = 150   # how much its roof lifts where it ends in a dead end
  ROCK_SPAN = 64       # rock between the corridor and the passage above it, and
                       # between that passage and the open sky above the island
  SHAFT_W = 80         # width of the chimney joining the two levels — wide enough
                       # to swim up, narrow enough to have to look for it
  GALLERY_GAP = 240    # air kept between a gallery and a chamber, or another one
  CROWN_STEP = 16      # the island's own terrace grid — chunkier than the sea floor
  PLANT_SPACING = 90   # px of level ground each plant wants for itself
  SHORE_HEIGHT = 110   # crown height above the water that still counts as beach
  SKERRY_LIP_MIN = 20  # lowest a skerry pokes out of the water ...
  SKERRY_LIP_MAX = 76  # ... and highest — low rugged rock, never a summit
  SKERRY_DEPTH = 160   # how far a skerry's base reaches below the waterline
  REACH = 160          # px of open water off each shore the island still reaches
                       # into — far enough to hold the furthest skerry
  GULL_HEIGHT = 110    # how high over the water the gulls hang
  # How far out from the island's edges they range, in columns, and how much
  # higher each one flies. Negative = off the left shore, positive = off the right.
  GULL_OFFSETS = [[-92, 30], [-40, 0], [46, 44], [88, 16]]
  MARGIN = 8           # px of bare ground kept at each side of a plant's base
  SHAPE_SEED = 707
  DECOR_SEED = 808
  TUNNEL_SEED = 909
  SKERRY_SEED = 1313
  TUNNEL_PLANTS = ["seaweed", "coral", "starfish"]

  SCALES = {
    "palm" => 4, "palm_small" => 3, "bush" => 3, "grass" => 3,
    "driftwood" => 3, "crab" => 2, "flag" => 3, "gull" => 3,
  }

  def self.build(world, sector)
    new(world, sector).build
  end

  # Everything rolled about an island, from its home sector alone — so every
  # segment it reaches into rolls exactly the same island. The order of the rolls
  # is the shape's identity: don't reorder them, every island in every saved
  # round would change.
  def self.shape_for(sector)
    rng = Rng.new(sector * 7919 + 31)
    rng.next_u32 # warm past the seeded state
    {
      span: (SPAN_MIN + rng.int(SPAN_MAX - SPAN_MIN)).idiv(World::COLUMN_WIDTH) * World::COLUMN_WIDTH,
      peak: PEAK_MIN + rng.int(PEAK_MAX - PEAK_MIN),
      flagged: rng.int(3).zero?,             # somebody got here first — but not everywhere
      sag: rng.int(SAG_MAX * 2) - SAG_MAX,   # this tunnel dips, or humps, on its way through
      chamber_count: 1 + rng.int(2),         # one big chamber, or two smaller stops
      spot_shift: rng.int(12) / 100.0,       # and they aren't always in the same place
      # Upper passages: where along the island they run, how long, and whether
      # they come back down at the far end or simply stop.
      gallery_count: 1 + rng.int(2),
      gallery_rolls: 2.times.map do
        { spot: rng.int(64) / 100.0,
          span: GALLERY_MIN + rng.int(GALLERY_MAX - GALLERY_MIN),
          dead_end: rng.int(3).zero? }
      end,
    }
  end

  def self.centre_x(sector)
    sector * SCREEN_WIDTH + SCREEN_WIDTH.idiv(2)
  end

  # Does the island centred on this sector reach into that segment? Wider than a
  # segment means a segment two along can still be carrying its flank. The reach
  # runs past the island itself: the skerries stand *off* its shores, in the open
  # water either side, and a segment holding only those still has to be stamped
  # or they quietly vanish.
  def self.covers?(sector, index)
    span = shape_for(sector)[:span]
    first = centre_x(sector) - span.idiv(2) - REACH
    segment = index * SCREEN_WIDTH
    first < segment + SCREEN_WIDTH && first + span + REACH * 2 > segment
  end

  attr_reader :span, :peak, :sector

  def initialize(world, sector)
    @world = world
    @sector = sector
    shape = self.class.shape_for(sector)
    @span = shape[:span]
    @peak = shape[:peak]
    @flagged = shape[:flagged]
    @sag = shape[:sag]
    @chamber_count = shape[:chamber_count]
    @spot_shift = shape[:spot_shift]
    @gallery_count = shape[:gallery_count]
    @gallery_rolls = shape[:gallery_rolls]
  end

  # --- Where the island lies, in world x -----------------------------------

  def first_x
    self.class.centre_x(sector) - span.idiv(2)
  end

  def last_x
    first_x + span
  end

  def segment_x
    @world.index * SCREEN_WIDTH
  end

  # Segment-local column range of the island *in this segment*, clamped — the
  # island usually runs off both ends of it.
  def first_column
    local = (first_x - segment_x).idiv(World::COLUMN_WIDTH)
    local < 0 ? 0 : local
  end

  def last_column
    local = (last_x - segment_x).idiv(World::COLUMN_WIDTH)
    local > @world.columns ? @world.columns : local
  end

  def in_segment?(world_x)
    world_x >= segment_x && world_x < segment_x + SCREEN_WIDTH
  end

  def build
    floor = @world.floor.dup
    # Another island may already have stamped this segment — keep what's there.
    roof = @world.roof ? @world.roof.map { |slabs| slabs.dup } : Array.new(@world.columns) { [] }

    (first_column...last_column).each do |col|
      floor[col] = tunnel_floor_y(col)
      roof[col] = column_slabs(world_x(col))
    end

    skerry_columns.each { |col, rock| roof[col] = [rock] }

    World.new(index: @world.index, biome: @world.biome, floor: floor, roof: roof,
              decorations: decorations(roof) + tunnel_decor(floor),
              air_pockets: @world.air_pockets + air_rects)
  end

  # --- The tunnel system ----------------------------------------------------
  #
  # The corridor along the bottom is the way through. Above stretches of it run
  # *galleries*: level upper passages with a slab of rock between, reached by a
  # chimney at either end — and one in three simply stops, with a pocket of air
  # under its raised roof for whoever bothered to swim up and look.
  #
  # This is what the list of slabs per column is for. A column of plain corridor
  # carries one slab (the island above it); a column of gallery carries two, the
  # rock between the levels and the island's lid; and a chimney column carries
  # only the lid, so the water runs from the corridor floor straight up.

  def column_slabs(world_x)
    corridor = corridor_ceiling_at(world_x)
    crown = crown_y_at(world_x)
    gallery = gallery_at(world_x)
    return [{ ceiling: corridor, crown: crown }] unless gallery
    return [{ ceiling: gallery_ceiling_at(gallery, world_x), crown: crown }] if shaft?(gallery, world_x)

    [{ ceiling: corridor, crown: gallery[:floor] },
     { ceiling: gallery_ceiling_at(gallery, world_x), crown: crown }]
  end

  # The corridor's own roof: a chamber dome where there is one, otherwise the
  # rolling tunnel height — never tighter than the diver.
  def corridor_ceiling_at(world_x)
    base = tunnel_floor_y_at(world_x)
    ceiling = chamber_ceiling_at(world_x) || base + tunnel_height_at(world_x)
    ceiling - base < MIN_GAP ? base + MIN_GAP : ceiling
  end

  def gallery_at(world_x)
    galleries.find { |g| world_x >= g[:from] && world_x < g[:to] }
  end

  # A chimney sits at each open end of a gallery. A dead end has one only — the
  # far end is where the passage stops.
  def shaft?(gallery, world_x)
    return true if world_x < gallery[:from] + SHAFT_W
    return false if gallery[:dead_end]

    world_x >= gallery[:to] - SHAFT_W
  end

  # The roof of a gallery, lifted over the last stretch of a dead end so the air
  # trapped up there has somewhere to sit.
  def gallery_ceiling_at(gallery, world_x)
    return gallery[:ceiling] unless gallery[:dome] && world_x >= gallery[:to] - DOME_SPAN

    gallery[:ceiling] + GALLERY_RISE
  end

  # Where the upper passages run. Rolled from the home sector, then *fitted*: a
  # gallery is level, so it only exists where it fits between the highest point
  # of the corridor below and the thinnest part of the island above. Where it
  # doesn't fit there simply isn't one — which is why a flat, low island has a
  # plain corridor and a tall one is riddled.
  def galleries
    @galleries ||= begin
      list = []
      @gallery_rolls.first(@gallery_count).each_with_index do |roll, i|
        # Two galleries get their own half of the island, or they'd sit on top of
        # each other and the second would always be thrown away.
        from = snap(first_x + (span * (0.12 + i * 0.42 + roll[:spot] * 0.3)).to_i)
        to = snap(from + roll[:span])
        limit = last_x - GALLERY_GAP
        to = limit if to > limit
        next if to - from < GALLERY_MIN
        next if list.any? { |g| g[:to] + GALLERY_GAP > from && g[:from] - GALLERY_GAP < to }
        next if shafts_hit_a_chamber?(from, to, roll[:dead_end])

        fitted = fit_gallery(from, to, roll[:dead_end])
        list << fitted if fitted
      end
      list
    end
  end

  # A gallery may run *over* a chamber, but a chimney may not come up through
  # one. A chimney takes the rock away between the levels — including the dome
  # that was holding the chamber's air up — and the diver, surfacing in air with
  # nothing above it, floats there and can go no further. So the two keep apart.
  def shafts_hit_a_chamber?(from, to, dead_end)
    shafts = [[from, from + SHAFT_W]]
    shafts << [to - SHAFT_W, to] unless dead_end
    shafts.any? do |shaft_from, shaft_to|
      chambers.any? { |c| c[:to] > shaft_from - MARGIN && c[:from] < shaft_to + MARGIN }
    end
  end

  # Does a level passage fit through here, with rock above and below it? It is
  # allowed to run over a chamber — corridor_ceiling_at already includes the
  # dome, so the gallery simply sits higher where it passes one. (Refusing to
  # cross a chamber was what left almost every island with a plain corridor: a
  # single chamber sits right in the middle, exactly where a gallery wants to be.)
  def fit_gallery(from, to, dead_end)
    roof_below = WATERLINE_Y - 100_000
    lid = WATERLINE_Y + 100_000
    x = from
    while x < to
      ceiling = corridor_ceiling_at(x)
      roof_below = ceiling if ceiling > roof_below
      crown = crown_y_at(x)
      lid = crown if crown < lid
      x += World::COLUMN_WIDTH
    end

    floor_y = roof_below + ROCK_SPAN
    # Stay under water — a passage flooded to the roof, not a hall with a sky —
    # and leave the island a lid.
    top = [WATERLINE_Y - MIN_GAP, lid - ROCK_SPAN].min
    room = top - floor_y
    return nil if room < MIN_GAP

    ceiling = floor_y + (room < GALLERY_HEIGHT ? room : GALLERY_HEIGHT)
    dome = dead_end && ceiling + GALLERY_RISE <= top
    { from: from, to: to, floor: floor_y, ceiling: ceiling, dead_end: dead_end, dome: dome }
  end

  # Air sits in two kinds of place: the domes along the corridor, and under the
  # raised roof at the end of a dead-end gallery — the reward for going up.
  def air_rects
    rects = chambers.map { |c| chamber_air(c) }
    galleries.each do |gallery|
      next unless gallery[:dome]

      rects << clip_air(gallery[:to] - DOME_SPAN, gallery[:to],
                        gallery[:ceiling] + GALLERY_RISE)
    end
    rects.compact
  end

  # Rugged rocks that break the surface in the water off the island's shores.
  # They are not the island itself — they make plain that the rock reaches out
  # here and you can't swim straight through: you bump into them up top and dive
  # under to pass. Solid like everything else, so the diver, shark and fish all
  # respect them. Keyed by column so build can drop them straight into the roof.
  def skerry_columns
    @skerry_columns ||= begin
      cols = {}
      skerry_clusters.each do |start_x, width|
        width.times do |w|
          wx = start_x + w * World::COLUMN_WIDTH
          next unless in_segment?(wx)

          col = (wx - segment_x).idiv(World::COLUMN_WIDTH)
          next if island_column?(col) # never overwrite the island itself

          cols[col] = { ceiling: WATERLINE_Y - SKERRY_DEPTH, crown: skerry_crown(wx) }
        end
      end
      cols
    end
  end

  # A skerry pokes out of the water by a rolled amount, its top snapped to the
  # island's terrace grid so it reads as chunky rock rather than a spike.
  def skerry_crown(world_x)
    lip = SKERRY_LIP_MIN + (Noise.jitter(world_x, SKERRY_SEED) * (SKERRY_LIP_MAX - SKERRY_LIP_MIN)).to_i
    ((WATERLINE_Y + lip) / CROWN_STEP).floor * CROWN_STEP
  end

  # Where the stacks stand: a cluster hugging each shore, just off the island's
  # edge in the shallows — [first world x, width in columns], rolled from the home
  # sector so they scatter differently every round. In world x, so both segments
  # of a shore that falls on a border place the same rocks.
  def skerry_clusters
    [
      [first_x - (6 + skerry_roll(1, 3)) * World::COLUMN_WIDTH, 3 + skerry_roll(2, 3)],
      [last_x + (2 + skerry_roll(5, 3)) * World::COLUMN_WIDTH, 3 + skerry_roll(6, 3)],
    ]
  end

  def skerry_roll(salt, span)
    (Noise.jitter(sector * 131 + salt, SKERRY_SEED + 4) * span).to_i
  end

  # The sand at either mouth, read from the *global* terrain function — the mouths
  # usually sit in a different segment than the one being built.
  def mouth_left
    WorldGenerator.floor_y_at(first_x)
  end

  def mouth_right
    WorldGenerator.floor_y_at(last_x - World::COLUMN_WIDTH)
  end

  # The corridor's bottom: a ramp between the sand at both mouths, plus a sag (or
  # a rise) along the way, so it isn't the same straight run through every island.
  # The deflection is zero at both ends, so the mouths still meet the sea floor
  # flush and there is no step to climb going in or out.
  def tunnel_floor_y(col)
    tunnel_floor_y_at(world_x(col))
  end

  def tunnel_floor_y_at(world_x)
    t = span_t_at(world_x)
    y = mouth_left + (mouth_right - mouth_left) * t + @sag * Math.sin(Math::PI * t)
    (y / WorldGenerator::FLOOR_STEP).floor * WorldGenerator::FLOOR_STEP
  end

  # How much clear water the corridor has here — it squeezes down to a crawl in
  # places and opens into halls in others.
  def tunnel_height(col)
    tunnel_height_at(world_x(col))
  end

  def tunnel_height_at(world_x)
    (TUNNEL_MIN +
      (TUNNEL_MAX - TUNNEL_MIN) * Noise.value(world_x, TUNNEL_WAVE, TUNNEL_SEED)).to_i
  end

  def island_column?(col)
    col >= first_column && col < last_column
  end

  # How far along the island a world x lies, 0..1.
  def span_t_at(world_x)
    t = (world_x - first_x) / (span - World::COLUMN_WIDTH).to_f
    return 0.0 if t < 0.0
    return 1.0 if t > 1.0

    t
  end

  def span_t(col)
    span_t_at(world_x(col))
  end

  # The skyline. An envelope pins the rock down to the water at both ends —
  # steeply, so the island has flanks rather than being a dome — while noise
  # sampled from the world position gives it summits, shoulders and saddles of
  # its own. It is all read at the terrace a column belongs to, so the profile
  # steps in plateaus of varying width instead of curving.
  def crown_y(col)
    crown_y_at(world_x(col))
  end

  def crown_y_at(world_x)
    x = WorldGenerator.terrace_start(world_x)
    shape = 0.45 +
            Noise.value(x, 320, SHAPE_SEED) * 0.45 +
            Noise.value(x, 110, SHAPE_SEED + 3) * 0.15
    y = WATERLINE_Y + SHORE_LIP + peak * envelope(span_t_at(x)) * shape
    y = (y / CROWN_STEP).floor * CROWN_STEP
    y = WATERLINE_Y + SHORE_LIP if y < WATERLINE_Y + SHORE_LIP
    y = WATERLINE_Y + CROWN_MAX if y > WATERLINE_Y + CROWN_MAX
    y
  end

  # Steep at the shore, broad up top.
  def envelope(t)
    Math.sin(Math::PI * t)**0.55
  end

  def world_x(col)
    @world.index * SCREEN_WIDTH + col * World::COLUMN_WIDTH
  end

  # Along the way the roof lifts into one or two chambers. Each dome is level, so
  # the air under it is a clean pocket — and leaving one means diving back under
  # the lower corridor roof.
  def chambers
    @chambers ||= chamber_spots.map do |spot|
      from = snap(first_x + (span * spot).to_i)
      to = from + DOME_SPAN
      mid = (from + to).idiv(2)
      { from: from, to: to,
        ceiling: tunnel_floor_y_at(mid) + tunnel_height_at(mid) + DOME_RISE }
    end
  end

  def chamber_spots
    return [0.42 + @spot_shift] if @chamber_count == 1

    [0.22 + @spot_shift, 0.64 + @spot_shift]
  end

  def chamber_ceiling_at(world_x)
    chamber = chambers.find { |c| world_x >= c[:from] && world_x < c[:to] }
    chamber && chamber[:ceiling]
  end

  # The air trapped under a dome: from the water surface inside the chamber up to
  # the rock. Surfacing in here means breathing — the cave is a rest stop, not a
  # one-way trip. Clipped to the segment being built, so a chamber straddling a
  # border becomes a piece of air in each.
  def chamber_air(chamber)
    clip_air(chamber[:from], chamber[:to], chamber[:ceiling])
  end

  # A rect of air under a roof, clipped to the segment being built — a chamber
  # straddling a border becomes a piece of air in each.
  def clip_air(from_x, to_x, ceiling)
    from = from_x < segment_x ? segment_x : from_x
    to = to_x > segment_x + SCREEN_WIDTH ? segment_x + SCREEN_WIDTH : to_x
    return nil if to <= from

    { x: from - segment_x, y: ceiling - AIR_DEPTH, w: to - from, h: AIR_DEPTH }
  end

  def snap(world_x)
    world_x.idiv(World::COLUMN_WIDTH) * World::COLUMN_WIDTH
  end

  # The cave isn't barren: weed, coral and rocks along the corridor floor.
  def tunnel_decor(floor)
    items = []
    x = first_x + 32
    while x < last_x - 32 # stepped in world x, so the spacing runs on across borders
      if in_segment?(x)
        roll = Noise.jitter(x + 3, DECOR_SEED + 2)
        if roll > 0.45
          col = (x - segment_x).idiv(World::COLUMN_WIDTH)
          kind = TUNNEL_PLANTS[(roll * TUNNEL_PLANTS.length).to_i]
          items << { kind: kind, x: col * World::COLUMN_WIDTH, y: floor[col], scale: 2 }
        end
      end
      x += 9 * World::COLUMN_WIDTH
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
  # Reads the *topmost* slab of a column: deeper in the rock there may be others,
  # but the skyline plants stand on is the one at the top.
  def plateaus(roof)
    runs = []
    first = first_column
    (first_column + 1..last_column).each do |col|
      next if col < last_column && skyline(roof, col) == skyline(roof, first)

      runs << { first: first, width: col - first, y: skyline(roof, first) }
      first = col
    end
    runs
  end

  def skyline(roof, col)
    slabs = roof[col]
    slabs.empty? ? nil : slabs.map { |slab| slab[:crown] }.max
  end

  # What belongs where: driftwood and crabs down on the beach, and further up
  # whatever actually fits in the space — a palm needs room to stand, a tuft of
  # grass doesn't.
  def plant_for(flat, room, seed)
    kinds =
      if flat[:y] - WATERLINE_Y < SHORE_HEIGHT
        ["grass", "driftwood", "crab", "grass", "driftwood", "bush"]
      elsif room >= base_width("palm") + MARGIN
        ["palm", "bush", "palm", "palm_small", "bush", "palm"]
      elsif room >= base_width("palm_small") + MARGIN
        ["palm_small", "bush", "grass", "bush", "palm_small", "grass"]
      else
        ["grass", "bush", "grass", "bush", "grass", "bush"]
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

  # Somebody got to the summit of some of these islands before you did. The
  # summit is found across the *whole* island, not per segment — otherwise a wide
  # island would sprout a flag on every slice of itself.
  def flag(_roof)
    return [] unless @flagged
    return [] unless in_segment?(summit_x)

    [{ kind: "flag", y: crown_y_at(summit_x), scale: SCALES["flag"],
       x: summit_x - segment_x }]
  end

  # Middle of the island's highest terrace, in world x.
  def summit_x
    @summit_x ||= begin
      step = World::COLUMN_WIDTH * 2
      best = first_x
      x = first_x
      while x < last_x
        best = x if crown_y_at(x) > crown_y_at(best)
        x += step
      end
      last = best
      last += step while last + step < last_x && crown_y_at(last + step) == crown_y_at(best)
      snap((best + last).idiv(2))
    end
  end

  # Gulls range well out over the water on both sides, not just over the coast:
  # spotting birds on the horizon is the first hint that there's land out there.
  # They're low enough to be in frame from the surface, and drift on their own in
  # the renderer.
  def gulls
    birds = []
    GULL_OFFSETS.each do |offset, lift|
      edge = offset < 0 ? first_x : last_x
      wx = edge + offset * World::COLUMN_WIDTH
      next unless in_segment?(wx)

      birds << { kind: "gull", x: wx - segment_x,
                 y: WATERLINE_Y + GULL_HEIGHT + lift, scale: SCALES["gull"] }
    end
    birds
  end
end

# Which worlds exist, which of them are on screen, and how their coordinates map
# onto it. The world is an endless row of segments; this is what streams them
# past the diver. Reopens Game. Drawing lives in world_renderer.rb.
class Game
  FAUNA_BAND = 420 # how high above the sand a segment's fish are spread

  # The world for the diver's current horizontal segment. Drives biome, fauna and
  # fog. Regenerated only when the segment changes; deterministic, so swimming
  # back shows the same world.
  def current_world
    idx = world_index
    if state.active_world_index != idx
      state.active_world_index = idx
      state.active_world = world_at(idx)
      spawn_fauna(state.active_world)
    end
    state.active_world
  end

  # Any segment's world, memoised so the neighbours we render while scrolling
  # aren't regenerated every frame. Deterministic per index.
  def world_at(index)
    state.world_cache ||= {}
    state.world_cache[index] ||= world_for(index)
  end

  # A hand-built static world overrides generation when one is registered for
  # this index; otherwise we generate procedurally — and stamp the island onto
  # the segment it landed on this round.
  def world_for(index)
    StaticWorlds.for(index) || open_sea_or_island(index)
  end

  def open_sea_or_island(index)
    islands_over(index).reduce(WorldGenerator.generate(index)) do |world, sector|
      IslandWorld.build(world, sector)
    end
  end

  # An island is wider than a segment, so this one may be carrying a flank of an
  # island centred a segment or two away — and, where two of them lie close
  # together, slices of both.
  def islands_over(index)
    return [] unless state.island_sectors

    state.island_sectors.select { |sector| IslandWorld.covers?(sector, index) }
  end

  def island_here?(index)
    !islands_over(index).empty?
  end

  def world_index
    state.diver_global_x.idiv(SCREEN_WIDTH)
  end

  # The segments that overlap the screen right now — usually the diver's chunk and
  # one neighbour, so the terrain scrolls continuously across the boundary.
  def visible_world_indices
    left = state.camera_x.idiv(SCREEN_WIDTH)
    right = (state.camera_x + SCREEN_WIDTH).idiv(SCREEN_WIDTH)
    (left..right).to_a
  end

  # Screen x offset for a segment's local coordinates: world x minus the camera.
  def chunk_offset_x(index)
    index * SCREEN_WIDTH - state.camera_x
  end

  # Place a sprite that lives in the diver's current chunk (fauna) onto the
  # screen: shift its local x into that chunk and drop by the vertical camera.
  def place_in_current_chunk(sprite)
    sprite.merge(x: sprite[:x] + chunk_offset_x(world_index),
                 y: sprite[:y] - state.camera_y)
  end

  # Home is the starting segment; the boat shows whenever it's on screen.
  def home_visible?
    visible_world_indices.include?(0)
  end

  CRAWL_CLEARANCE = 20 # px of water a crab needs over the sand to be standing there
  CRAWL_RANGE = 200    # ... and how far along the floor it wanders from where it hatched

  # Everything alive in this segment: the swarm, the crabs on its floor, and the
  # crabs on its beach. This is the list that gets ticked.
  def creatures
    sea_creatures + shore_creatures
  end

  # In the water — what the swarm and the sea floor hold.
  def sea_creatures
    (state.fish || []) + (state.crawlers || [])
  end

  # Above the waterline, on an island's beach.
  def shore_creatures
    state.shore_life || []
  end

  # What the camera and the eye can reach right now — and it is one or the other,
  # never both, because your head is on one side of the surface or the other.
  # Ducked under, you are looking at the sea; up in the air, at the land. That is
  # what gives surfacing beside an island a point beyond catching your breath.
  def creatures_in_view
    at_open_surface? ? shore_creatures : sea_creatures
  end

  # A fresh population for the world's biome: the swarm in the water column, and
  # whatever walks about on its floor.
  def spawn_fauna(world)
    spawn_swarm(world)
    spawn_crawlers(world)
    spawn_shore_life(world)
  end

  # A fresh fish swarm for the world's biome (colours and count from the biome).
  # They're spawned in the water just above this segment's own sea floor, so a
  # deep trench has its own fish down there instead of an empty void.
  FAUNA_CLEARANCE = 10 # water kept between an animal and the rock or the surface

  def spawn_swarm(world)
    biome = world.biome
    state.fish = biome.fish_count.times.map { spawn_one_fish(world, biome) }.compact
  end

  # One fish, or nothing if the column it drew has no water for it. The span walk
  # only ever tested the *neighbours* of the spawn column, never the column
  # itself — so a fish that drew a solid one started life inside it and stayed
  # there, penned between a from_x and a to_x that were the same wall.
  def spawn_one_fish(world, biome)
    8.times do
      fish = try_fish(world, biome, rand(world.columns))
      return fish if fish
    end
    nil
  end

  def try_fish(world, biome, col)
    floor_y = world.floor[col]
    slabs = world.roof ? (world.roof[col] || []) : []
    # Under rock they stay in the passage they spawned in: the lowest slab over
    # them is their sky.
    top = slabs.empty? ? WATERLINE_Y : slabs.map { |slab| slab[:ceiling] }.min

    species = Species.pick(biome, depth_in_metres(floor_y))
    return nil unless species

    size = Creature::SIZES.sample
    fish_w = species.frame_w * size
    fish_h = species.frame_h * size
    # The water it may use, worked out for *the whole animal*: it is drawn out
    # and up from its x/y, so a y that is in open water is no promise that its
    # back is. Half of them were hanging out of cliffs and poking through the
    # surface.
    low = floor_y + FAUNA_CLEARANCE
    high = top - fish_h - FAUNA_CLEARANCE
    high = low + FAUNA_BAND if high > low + FAUNA_BAND # they keep near the bottom
    return nil if high < low                            # no room here for this one

    # And the column it drew has to hold it too. Nothing checked that before: the
    # span walk only ever tested the *neighbours*, so a fish that drew a solid
    # column started life inside it, penned between a from_x and a to_x that were
    # the same wall.
    return nil unless open_water?(world, col, low, high, fish_w, fish_h)

    from_x, to_x = open_water_span(world, col, low, high, fish_w, fish_h)
    Creature.new(args, 0, species: species, size: size,
                 x: col * World::COLUMN_WIDTH, y: low + rand(high - low + 1),
                 from_x: from_x, to_x: to_x, low: low, high: high)
  end

  # What walks on this segment's sand. Depth is read from the floor itself, so a
  # segment whose bottom lies in a trench gets the things that live down there
  # and a shallow bank gets its own. Where nothing on the roster fits — the deep
  # sea up on a shelf, say — the sand is simply bare; pick_floor doesn't invent
  # a resident the way the swimming roll does.
  def spawn_crawlers(world)
    biome = world.biome
    state.crawlers = biome.crab_count.times.map do
      col = rand(world.columns)
      floor_y = world.floor[col]
      next unless standing_room?(world, col)

      species = Species.pick_floor(biome, depth_in_metres(floor_y))
      next unless species

      x = col * World::COLUMN_WIDTH
      from_x, to_x = crawl_span(world, col)
      Crustacean.new(args, 0, species: species, world: world,
                     x: x, from_x: from_x, to_x: to_x)
    end.compact
  end

  # How far along the sand a crab can walk from here before rock is in its way.
  # It reads the floor rather than the water column a fish gets: what stops a
  # crab is an island's flank sitting *on* the bottom, not a roof overhead.
  def crawl_span(world, col)
    reach = CRAWL_RANGE.idiv(World::COLUMN_WIDTH)
    left = col
    left -= 1 while left > 0 && col - left < reach && standing_room?(world, left - 1)
    right = col
    right += 1 while right < world.columns - 1 && right - col < reach && standing_room?(world, right + 1)
    [left * World::COLUMN_WIDTH, right * World::COLUMN_WIDTH]
  end

  # Is there open water resting on the sand in this column, or is the floor here
  # buried under rock?
  def standing_room?(world, col)
    x = col * World::COLUMN_WIDTH
    !world.solid_at?(x, world.floor[col] + CRAWL_CLEARANCE)
  end

  SHORE_BAND = 110  # px of rock above the water that still counts as beach
  SHORE_CRABS = 4   # how many of them a beach carries at most

  # Crabs on the beach, where an island breaks the surface. Placed off the world
  # itself rather than off the island's own decor list, so any rock standing in
  # the sun gets them — and a segment with no island simply comes out empty.
  def spawn_shore_life(world)
    beaches = beach_columns(world)
    state.shore_life = []
    return if beaches.empty?

    species = Species.pick_shore(world.biome)
    return unless species

    SHORE_CRABS.times do
      col = beaches[rand(beaches.length)]
      from_x, to_x = beach_span(world, col)
      state.shore_life << Crustacean.new(args, 0, species: species, world: world,
                                         x: col * World::COLUMN_WIDTH,
                                         from_x: from_x, to_x: to_x, ground: :crown)
    end
  end

  # The columns of a segment whose rock stands out of the water, but only just —
  # the strip between the waterline and the point where a beach becomes a cliff.
  def beach_columns(world)
    (0...world.columns).select { |col| beach?(world, col) }
  end

  def beach?(world, col)
    crown = world.crown_y_at(col * World::COLUMN_WIDTH)
    !crown.nil? && crown > WATERLINE_Y && crown <= WATERLINE_Y + SHORE_BAND
  end

  # How far along the beach it can walk before the sand runs out — into the sea
  # at one end, up the cliff at the other.
  def beach_span(world, col)
    left = col
    left -= 1 while left > 0 && beach?(world, left - 1)
    right = col
    right += 1 while right < world.columns - 1 && beach?(world, right + 1)
    [left * World::COLUMN_WIDTH, right * World::COLUMN_WIDTH]
  end

  SIGHT_RANGE = 520 # px within which a creature is close enough to have been seen

  # Note which species the diver has laid eyes on. The Artenbuch lists only these,
  # so the book fills in as you explore rather than spoiling the whole sea up
  # front. Sighting is being near a creature you can actually see — the sea from
  # under it, the beach from above it — and the fog doesn't reach much past this
  # range anyway.
  def update_sightings
    state.sighted ||= {}
    creatures_in_view.each do |creature|
      mark_sighted(creature.species.key, world_index * SCREEN_WIDTH + creature.x, creature.y)
    end
    if shark_present?
      mark_sighted("schattenhai", world_index * SCREEN_WIDTH + state.dark_shark.x, state.dark_shark.y)
    end
  end

  # Only the *first* sighting of a species writes anything: after that this is a
  # comparison and nothing else, which is what makes saving on sight affordable.
  def mark_sighted(key, world_x, world_y)
    return if state.sighted[key]
    return if photo_distance(world_x, world_y) > SIGHT_RANGE

    state.sighted[key] = true
    save_book
  end

  # How deep a world y is, in the metres the roster and the HUD talk in.
  def depth_in_metres(world_y)
    depth = (WATERLINE_Y - world_y) / PIXELS_PER_METRE
    depth < 0 ? 0 : depth.to_i
  end

  # How far a fish can swim either way before it would run into rock. Checked
  # across the whole band it may drift through *and* across its own length, so
  # neither its back nor its nose can be in a wall its x/y is clear of. The nose
  # is what mattered in practice: a fish turns at a column whose *anchor* is
  # still in water, with most of the animal already inside the cliff.
  def open_water_span(world, col, low, high, fish_w, fish_h)
    left = col
    left -= 1 while left > 0 && open_water?(world, left - 1, low, high, fish_w, fish_h)
    right = col
    right += 1 while right < world.columns - 1 && open_water?(world, right + 1, low, high, fish_w, fish_h)
    [left * World::COLUMN_WIDTH, right * World::COLUMN_WIDTH]
  end

  # Every column the animal covers, not just the two ends of it: a fish is up to
  # 64 px long, which is eight columns, and a pillar standing in the middle of
  # them fits neatly between two end probes.
  def open_water?(world, col, low, high, fish_w, fish_h)
    x = col * World::COLUMN_WIDTH
    probes = []
    step = x
    while step <= x + fish_w
      probes << step
      step += World::COLUMN_WIDTH
    end
    probes << x + fish_w
    # ... and the height it really occupies: high is where its *belly* may get to,
    # so the ceiling that matters is high + fish_h. Probing the anchor band alone
    # let a column with a lower roof pass while the fish's back was in it.
    levels = [low, (low + high).idiv(2), high, high + fish_h]
    probes.all? { |probe| levels.none? { |level| world.solid_at?(probe, level) } }
  end
end

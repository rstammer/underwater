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

  # Home is wherever the boat is moored; it shows whenever that segment is on
  # screen. It used to be segment 0 flat, which was the same thing right up
  # until the boat could be sailed somewhere else.
  def home_visible?
    visible_world_indices.include?(boat_sector)
  end

  CRAWL_CLEARANCE = 20 # px of water a crab needs over the sand to be standing there
  CRAWL_RANGE = 200    # ... and how far along the floor it wanders from where it hatched

  # Everything alive in this segment: the swarm, the crabs on its floor, and the
  # crabs on its beach. This is the list that gets ticked.
  def creatures
    sea_creatures + shore_creatures
  end

  # In the water — what the swarm, the sea floor and any drifting field hold.
  # The jellies are in here rather than kept apart so that everything the sea
  # already does to living things happens to them for nothing: they get ticked,
  # they can be photographed, and they go into the Artenbuch on sight.
  def sea_creatures
    (state.fish || []) + (state.crawlers || []) + (state.jellies || []) +
      (state.corals || [])
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
    spawn_jellies(world)
    spawn_corals(world)
  end

  # The colonies growing on this stretch of floor. Spaced rather than scattered:
  # two corals on the same column are one coral drawn twice, and the frame is a
  # crop now — a photograph of a reef wants them side by side, not stacked.
  CORAL_SPACING = 3 # columns kept clear each side of a colony

  def spawn_corals(world)
    biome = world.biome
    taken = []
    state.corals = biome.anchored_count.times.map do
      col = rand(world.columns)
      next if taken.any? { |used| (used - col).abs <= CORAL_SPACING }
      next unless standing_room?(world, col)

      species = Species.pick_sessile(biome, depth_in_metres(world.floor[col]))
      next unless species

      taken << col
      Coral.new(args, 0, species: species, world: world, x: col * World::COLUMN_WIDTH)
    end.compact
  end

  # A *field*, not a scattering. Jellyfish are the first thing out here that is
  # terrain rather than fauna: something you steer around, and you only steer
  # around a wall of them. Rolled one at a time across the segment they would be
  # a fish that happens to be a jellyfish, and the whole idea would be gone.
  #
  # So one place is chosen and the animals are packed into it — a patch a few
  # hundred pixels across, hanging in the water column. Where the biome has no
  # jellyfish (Species.pick_drift has no fallback, like the sea floor's roll),
  # there is no field, which is what keeps one worth finding.
  JELLY_FIELD_W = 10      # columns either side of the centre a field spreads over ...
  JELLY_FIELD_H = 260     # ... and how tall it hangs
  JELLY_COUNT = 18        # animals in one
  JELLY_CLEARANCE = 40    # water kept between a bell and the rock

  # Tries several places before giving up, the way the swarm does. One draw meant
  # a jellyfield biome whose one rolled column had no room came out with no field
  # at all — rare enough to look like a flake in the tests and to be invisible in
  # the sea, which is the worst way for a thing to be wrong.
  JELLY_TRIES = 16

  def spawn_jellies(world)
    state.jellies = []
    col, floor_y, species, centre = nil
    JELLY_TRIES.times do
      col = rand(world.columns)
      floor_y = world.floor[col]
      species = Species.pick_drift(world.biome, depth_in_metres(floor_y))
      next unless species

      centre = jelly_field_centre(world, col, floor_y)
      break if centre
    end
    return unless species && centre

    state.jellies = JELLY_COUNT.times.map do |i|
      Jelly.new(args, 0, species: species,
                x: centre[:x] + rand(2 * JELLY_FIELD_W + 1) * World::COLUMN_WIDTH -
                   JELLY_FIELD_W * World::COLUMN_WIDTH,
                y: centre[:y] + rand(JELLY_FIELD_H) - JELLY_FIELD_H / 2,
                # Spread across the beat: a field pulsing in unison is a
                # screensaver, one pulsing out of step is a crowd.
                phase: i * 37)
    end
  end

  # Somewhere in the open column with room for the whole field above the sand
  # and under whatever is overhead.
  def jelly_field_centre(world, col, floor_y)
    slabs = world.roof ? (world.roof[col] || []) : []
    top = slabs.empty? ? WATERLINE_Y : slabs.map { |slab| slab[:ceiling] }.min
    low = floor_y + JELLY_CLEARANCE + JELLY_FIELD_H / 2
    high = top - JELLY_CLEARANCE - JELLY_FIELD_H / 2
    return nil if high < low

    { x: col * World::COLUMN_WIDTH, y: low + rand(high - low + 1) }
  end

  # A fresh fish swarm for the world's biome (colours and count from the biome).
  # They're spawned in the water just above this segment's own sea floor, so a
  # deep trench has its own fish down there instead of an empty void.
  FAUNA_CLEARANCE = 10 # water kept between an animal and the rock or the surface

  # The swarm is drawn as *schools* rather than as individuals. Rolled one fish
  # per column, two of a kind close enough to share a frame was pure luck — and
  # a photograph is a crop now, so "two fish at once" has to be something you can
  # go and look for rather than something you happen upon.
  #
  # The biome's count is still exactly what a segment holds; what changed is that
  # the fish arrive in groups. Each draw is asked for no more than the room that
  # is left, so clustering can never quietly multiply the population.
  def spawn_swarm(world)
    biome = world.biome
    fish = []
    biome.fish_count.times do
      room = biome.fish_count - fish.length
      break if room <= 0

      fish.concat(spawn_one_school(world, biome, room))
    end
    state.fish = fish
  end

  # One school, or nothing if the columns it drew have no water for it. The span
  # walk only ever tested the *neighbours* of the spawn column, never the column
  # itself — so a fish that drew a solid one started life inside it and stayed
  # there, penned between a from_x and a to_x that were the same wall.
  # Tries hard rather than a few times: over a trench most columns are wall, and
  # a fish that runs out of attempts is simply missing from the swarm. Measured
  # across 81 segments it was one fish in a hundred — invisible in the sea, but
  # enough to make "the segment holds its biome's count" a coin toss.
  SPAWN_TRIES = 24

  def spawn_one_school(world, biome, room)
    SPAWN_TRIES.times do
      school = try_fish(world, biome, rand(world.columns), room)
      return school if school
    end
    []
  end

  def try_fish(world, biome, col, room = 1)
    floor_y = world.floor[col]
    slabs = world.roof ? (world.roof[col] || []) : []
    # Under rock they stay in the passage they spawned in: the lowest slab over
    # them is their sky.
    top = slabs.empty? ? WATERLINE_Y : slabs.map { |slab| slab[:ceiling] }.min
    # A cave with air trapped in it has a water surface of its own, *below* the
    # rock — so the ceiling alone let fish rise straight out of the water into
    # the air pocket. Whichever is lower is where the water stops.
    air = world.air_line_at(col * World::COLUMN_WIDTH)
    top = air if air && air < top

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
    count = school_size(species, room)
    shoal_of(species, size, count, x: col * World::COLUMN_WIDTH,
                                   y: low + rand(high - low + 1),
                                   from_x: from_x, to_x: to_x, low: low, high: high)
  end

  # Two at the least, never more than the species keeps company with or the
  # segment has room for. Rolled rather than always full, so a school is a thing
  # of a *size* — coming across nine herring should not feel like the same event
  # as coming across two.
  def school_size(species, room)
    most = species.shoal < room ? species.shoal : room
    return 1 if most < 2

    2 + rand(most - 1)
  end

  SHOAL_GAP = 46      # px between neighbours in a school ...
  SHOAL_STAGGER = 26  # ... and how far the rank behind sits above or below

  # A school, placed as a formation: strung out along the water it was given,
  # staggered so they read as a crowd rather than a queue, and every one of them
  # inside the water the leader was checked into — which is why they are clamped
  # to the span rather than trusted to the offset.
  #
  # They are laid around the middle rather than out from the first one, so the
  # place the sea picked is the place the school *is*.
  def shoal_of(species, size, count, x:, y:, from_x:, to_x:, low:, high:)
    count = 1 if count < 1
    count = 1 unless species.shoals? # met alone, whatever the swarm asked for
    speed = Creature::SPEEDS.sample  # one pace for all of them — see Creature
    count.times.map do |i|
      offset = (i - (count - 1) / 2.0) * SHOAL_GAP
      fish_y = y + (i.even? ? SHOAL_STAGGER : -SHOAL_STAGGER) * (i.idiv(2) % 2 + 1) / 2
      Creature.new(args, 0, species: species, size: size, speed: speed,
                   x: clamp(x + offset, from_x, to_x),
                   y: clamp(fish_y, low, high),
                   from_x: from_x, to_x: to_x, low: low, high: high)
    end
  end

  def clamp(value, low, high)
    return low if value < low
    return high if value > high

    value
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
    # You can hardly miss it, so it counts as seen from much further off — the
    # sighting range is written for something a hand's width across.
    return unless whale_present? && whale_species

    mark_sighted(whale_species.key, state.whale.x, state.whale.y)
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
    # ... and the height it really occupies, asked *exactly* rather than sampled.
    # Sampling a few levels across a band that can be 420 px tall leaves gaps
    # wider than a slab is thick, and a slab sitting in one of them let the fish
    # straight through — rarely enough that the test only failed one run in three.
    # A slab [ceiling, crown] is in the way iff it overlaps the fish's [low, top].
    top = high + fish_h
    probes.all? do |probe|
      air = world.air_line_at(probe)
      next false if air && air < top # it would surface into a chamber's air

      world.floor_y_at(probe) <= low &&
        world.slabs_at(probe).none? { |slab| slab[:ceiling] <= top && slab[:crown] >= low }
    end
  end
end

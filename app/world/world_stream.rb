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
    world = WorldGenerator.generate(index)
    index == state.island_sector ? IslandWorld.build(world) : world
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

  # A fresh fish swarm for the world's biome (colours and count from the biome).
  # They're spawned in the water just above this segment's own sea floor, so a
  # deep trench has its own fish down there instead of an empty void.
  def spawn_fauna(world)
    biome = world.biome
    state.fish = biome.fish_count.times.map do
      col = rand(world.columns)
      floor_y = world.floor[col]
      rock = world.roof && world.roof[col]
      top = rock ? rock[:ceiling] : WATERLINE_Y # under a cave roof they stay in the tunnel
      headroom = top - floor_y - 100
      headroom = FAUNA_BAND if headroom > FAUNA_BAND
      headroom = 30 if headroom < 30
      SloppyScalar.new(args, 0,
                       x: col * World::COLUMN_WIDTH,
                       y: floor_y + 30 + rand(headroom),
                       color: biome.fish_colors.sample.to_sym)
    end
  end
end

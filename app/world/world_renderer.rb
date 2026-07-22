# Renders a World to the screen. Reopens Game so the underwater scenes can just
# call render_world(current_world). The World itself is pure data (app/world/
# world.rb); all the sprite/solid building lives here.
class Game
  DECOR_SPRITES = {
    "seaweed"  => { path: "sprites/decor/seaweed.png",  w: 14, h: 44 },
    "coral"    => { path: "sprites/decor/coral.png",    w: 28, h: 30 },
    "starfish" => { path: "sprites/decor/starfish.png", w: 16, h: 16 },
    "rock"     => { path: "sprites/decor/rock.png",     w: 22, h: 15 },
  }

  # The world for the diver's current horizontal segment. Regenerated only when
  # the segment changes; deterministic, so swimming back shows the same world.
  def current_world
    idx = world_index
    if state.active_world_index != idx
      state.active_world_index = idx
      state.active_world = world_for(idx)
      spawn_fauna(state.active_world)
    end
    state.active_world
  end

  def world_index
    state.diver_global_x.idiv(SCREEN_WIDTH)
  end

  # Home is the starting segment — the only place the home boat floats.
  def at_home?
    world_index == 0
  end

  # A hand-built static world overrides generation when one is registered for
  # this index; otherwise we generate procedurally.
  def world_for(index)
    StaticWorlds.for(index) || WorldGenerator.generate(index)
  end

  # A fresh fish swarm for the world's biome (colours and count from the biome).
  def spawn_fauna(world)
    biome = world.biome
    state.fish = biome.fish_count.times.map do
      SloppyScalar.new(args, 0,
                       x: rand(SCREEN_WIDTH),
                       y: 90 + rand(360),
                       color: biome.fish_colors.sample.to_sym)
    end
  end

  # A shark only prowls in shark biomes, and never while the diver is up
  # breathing at the surface.
  def shark_present?
    !breathing? && current_world.biome.shark
  end

  # At the surface you only see the water surface and the sky — the fish below
  # are out of view. Underwater the swarm is drawn.
  def fauna_visible?
    !breathing?
  end

  # Brighter biomes (low fog) let the diver see farther; the dark deep closes in.
  def fog_radius(biome)
    (120 + 290 * (1.0 - biome.fog)).to_i
  end

  # Tint the fog with the biome's deep water so it blends instead of a flat blue.
  def fog_color(biome)
    b = biome.water_bottom
    [(b[0] * 0.45).to_i, (b[1] * 0.45).to_i, (b[2] * 0.45).to_i]
  end

  def render_world(world)
    outputs.sprites << sky_fill
    outputs.sprites << world_water(world)
    outputs.sprites << surface_line
    outputs.sprites << world_floor(world)
    outputs.sprites << world_decorations(world)
    if at_home?
      outputs.sprites << home_boat
      outputs.labels << surface_hint if breathing?
    end
  end

  # Shift a world-space sprite onto the screen by the current camera offset.
  def camera_shift(sprite)
    sprite.merge(y: sprite[:y] - state.camera_y)
  end

  # Daylight sky above the waterline, filling whatever the camera reveals once
  # the diver rises. Empty (nothing to draw) while he's deep and the camera rests.
  def sky_fill
    waterline = WATERLINE_Y - state.camera_y
    return [] if waterline >= SCREEN_HEIGHT

    { x: 0, y: waterline, w: grid.w, h: SCREEN_HEIGHT - waterline,
      r: 135, g: 206, b: 235, path: :solid }
  end

  # The bright line where water meets sky.
  def surface_line
    { x: 0, y: WATERLINE_Y - state.camera_y - 3, w: grid.w, h: 6,
      r: 200, g: 230, b: 245, path: :solid }
  end

  # Vertical water gradient from the biome's palette (deep at the bottom, bright
  # at the waterline), spanning the whole water column and shifted by the camera.
  def world_water(world)
    top = world.biome.water_top
    bottom = world.biome.water_bottom
    bands = 24
    (0...bands).map do |i|
      t = i / (bands - 1.0)
      {
        x: 0,
        y: i * WATERLINE_Y / bands - state.camera_y,
        w: grid.w,
        h: WATERLINE_Y / bands + 1,
        r: lerp(bottom[0], top[0], t),
        g: lerp(bottom[1], top[1], t),
        b: lerp(bottom[2], top[2], t),
        path: :solid,
      }
    end
  end

  # The rolling sand floor: a uniform base following the dune heightmap, topped
  # by a lighter sunlit cap. The relief carries the interest, no tiling pattern.
  def world_floor(world)
    base = world.biome.floor_colors[1]
    cap = world.biome.floor_colors[0]
    cam = state.camera_y
    tiles = []
    world.floor.each_with_index do |h, col|
      x = col * World::COLUMN_WIDTH
      tiles << { x: x, y: 0 - cam, w: World::COLUMN_WIDTH + 1, h: h,
                 r: base[0] - 14, g: base[1] - 14, b: base[2] - 14, path: :solid }
      tiles << { x: x, y: h - 4 - cam, w: World::COLUMN_WIDTH + 1, h: 4,
                 r: cap[0], g: cap[1], b: cap[2], path: :solid } # sunlit cap
    end
    tiles
  end

  def world_decorations(world)
    world.decorations.map do |d|
      sprite = DECOR_SPRITES[d[:kind]]
      sway = d[:kind] == "seaweed" ? Math.sin((Kernel.tick_count + d[:x]) / 45.0) * 3 : 0
      {
        x: d[:x],
        y: d[:y] - state.camera_y,
        w: sprite[:w] * d[:scale],
        h: sprite[:h] * d[:scale],
        path: sprite[:path],
        anchor_x: 0.5,
        anchor_y: 0,
        angle: sway,
      }
    end
  end

  # The diver's home: a small boat bobbing on the waterline over the starting
  # segment. The diver spawns right next to it (see spawn_at_surface).
  def home_boat
    scale = 3
    bob = Math.sin(Kernel.tick_count / 45.0) * 4
    {
      x: SURFACE_BOAT_X,
      y: WATERLINE_Y - 24 + bob - state.camera_y,
      w: 48 * scale,
      h: 34 * scale,
      path: "sprites/decor/boat.png",
    }
  end

  # A quiet nudge in the sky, shown while resting at the surface, encouraging the
  # player to dive and explore. Deliberately low-contrast so it stays background.
  def surface_hint
    {
      x: grid.w / 2,
      y: grid.h - 60,
      text: "Tauche ab und erkunde die Unterwasserwelt",
      size_enum: 2,
      alignment_enum: 1,
      r: 30,
      g: 60,
      b: 80,
      a: 170,
    }
  end

  def lerp(a, b, t)
    (a + (b - a) * t).to_i
  end
end

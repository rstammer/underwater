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

  # A shark only prowls in shark biomes, and never at the surface.
  def shark_present?
    !state.surfaced && current_world.biome.shark
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
    outputs.sprites << world_water(world)
    outputs.sprites << world_floor(world)
    outputs.sprites << world_decorations(world)
  end

  # Vertical water gradient from the biome's palette (deep at the bottom).
  def world_water(world)
    top = world.biome.water_top
    bottom = world.biome.water_bottom
    bands = 24
    (0...bands).map do |i|
      t = i / (bands - 1.0)
      {
        x: 0,
        y: i * grid.h / bands,
        w: grid.w,
        h: grid.h / bands + 1,
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
    tiles = []
    world.floor.each_with_index do |h, col|
      x = col * World::COLUMN_WIDTH
      tiles << { x: x, y: 0, w: World::COLUMN_WIDTH + 1, h: h,
                 r: base[0] - 14, g: base[1] - 14, b: base[2] - 14, path: :solid }
      tiles << { x: x, y: h - 4, w: World::COLUMN_WIDTH + 1, h: 4,
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
        y: d[:y],
        w: sprite[:w] * d[:scale],
        h: sprite[:h] * d[:scale],
        path: sprite[:path],
        anchor_x: 0.5,
        anchor_y: 0,
        angle: sway,
      }
    end
  end

  def lerp(a, b, t)
    (a + (b - a) * t).to_i
  end
end

# Draws the visible slice of the world through the camera: water, sky, sea floor,
# decorations and the home boat. Reopens Game so the underwater scenes can just
# call render_world. The World itself is pure data (app/world/world.rb) and which
# segments are on screen is world_stream.rb's job; all the sprite building is here.
class Game
  WATER_TWILIGHT = 1400 # px below the waterline over which the biome gradient plays out
  WATER_ABYSS = 3400    # px below the waterline where the light is as good as gone
  ABYSS_DIM = 0.82      # how much of the light the abyss swallows
  WATER_BANDS = 24      # horizontal strips the water gradient is drawn in
  BOAT_HINT_W = 460
  BOAT_HINT_H = 164
  AIR_COLOR = [20, 26, 32]            # the gloom inside an air chamber
  AIR_SURFACE_COLOR = [150, 190, 205] # the water surface trapped under it
  FLOOR_FILL_DEPTH = 1120 # how far down a sand column is filled — a screen height plus slack

  GREEN = [96, 146, 74]       # the green cap on rock that stands well out of the water
  GREEN_CAP = 10              # how thick that band of grass is
  GREEN_MIN = 96             # rock must clear the water by this much to grow grass — bare wet
                             # rock at the waterline and the low skerries stay stone
  ISLAND_ROCK = [138, 122, 102] # sun-bleached stone — an island wears its own colour,
                                # not the palette of the sea floor around it
  CAVE_DIM = 0.5              # inside a cave it is dark whatever the depth says
  ROOF_FADE = 300             # px under the surface over which rock loses the daylight

  BOAT_SPRITE = { path: "sprites/decor/boat.png", w: 41, h: 20 }

  DECOR_SPRITES = {
    "seaweed"  => { path: "sprites/decor/seaweed.png",  w: 14, h: 44 },
    "coral"    => { path: "sprites/decor/coral.png",    w: 28, h: 30 },
    "starfish" => { path: "sprites/decor/starfish.png", w: 16, h: 16 },
    "rock"     => { path: "sprites/decor/rock.png",     w: 22, h: 15 },
    "palm"     => { path: "sprites/decor/palm.png",     w: 20, h: 16 },
    "bush"     => { path: "sprites/decor/bush.png",     w: 12, h: 7 },
    "grass"    => { path: "sprites/decor/grass.png",    w: 12, h: 5 },
    "gull"     => { path: "sprites/decor/gull.png",     w: 12, h: 4 },
    "palm_small" => { path: "sprites/decor/palm_small.png", w: 14, h: 10 },
    "driftwood"  => { path: "sprites/decor/driftwood.png",  w: 14, h: 5 },
    "crab"       => { path: "sprites/decor/crab.png",       w: 12, h: 6 },
    "flag"       => { path: "sprites/decor/flag.png",       w: 12, h: 10 },
  }

  # A shark only prowls in shark biomes, and never while the diver is up
  # breathing at the surface.
  def shark_present?
    !at_open_surface? && current_world.biome.shark
  end

  # At the surface you only see the water surface and the sky — the fish below
  # are out of view. Underwater the swarm is drawn.
  def fauna_visible?
    !at_open_surface?
  end

  # From up in the air you don't see *through* the water: the sea floor, the
  # things growing on it and anything in a cave are all out of view, and rock
  # only shows where it breaks the surface. Dip your head under and it's there.
  def submerged_visible?
    !at_open_surface?
  end

  # Brighter biomes (low fog) let the diver see farther; the dark deep closes in.
  # Depth tightens it further: the deeper you go, the less you see coming.
  def fog_radius(biome)
    ((120 + 290 * (1.0 - biome.fog)) * (0.55 + 0.45 * light_at(state.depth_y))).to_i
  end

  # Tint the fog with the biome's deep water so it blends instead of a flat blue,
  # and let it darken with depth along with the water itself.
  def fog_color(biome)
    b = biome.water_bottom
    dim = 0.45 * (0.35 + 0.65 * light_at(state.depth_y))
    [(b[0] * dim).to_i, (b[1] * dim).to_i, (b[2] * dim).to_i]
  end

  # Draw the visible slice of the world: water fills the screen (the diver's
  # biome, shaded by how deep the camera is looking), sky covers whatever lies
  # above the waterline, then every on-screen segment's floor and decorations
  # scroll past, and the home boat if the starting segment is in view.
  def render_world
    outputs.sprites << world_water(current_world)
    outputs.sprites << sky_fill
    outputs.sprites << surface_line
    visible_world_indices.each do |index|
      world = world_at(index)
      dx = chunk_offset_x(index)
      outputs.sprites << world_floor(world, dx) if submerged_visible?
      outputs.sprites << world_roof(world, dx)
      outputs.sprites << world_air(world, dx) if submerged_visible?
      outputs.sprites << world_decorations(world, dx)
    end
    if home_visible?
      outputs.sprites << home_boat
      render_boat_hint if at_the_boat?
    end
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

  # How much daylight reaches a world y: full at the waterline, fading through
  # the twilight zone, essentially gone in the abyss. Water *and* sand read from
  # this, so the deep looks deep instead of just further down the same picture.
  def light_at(world_y)
    below = WATERLINE_Y - world_y
    return 1.0 if below <= WATER_TWILIGHT

    fade = (below - WATER_TWILIGHT) / (WATER_ABYSS - WATER_TWILIGHT).to_f
    fade = 1.0 if fade > 1.0
    1.0 - ABYSS_DIM * fade
  end

  # The biome's water colour at a world y: its bright top near the surface
  # blending into its deep tone, then dimmed further down toward the abyss.
  def water_color_at(world_y, biome)
    top = biome.water_top
    bottom = biome.water_bottom
    below = WATERLINE_Y - world_y
    below = 0 if below < 0
    t = below / WATER_TWILIGHT.to_f
    t = 1.0 if t > 1.0
    dim = light_at(world_y)

    (0..2).map { |i| ((bottom[i] + (top[i] - bottom[i]) * (1.0 - t)) * dim).to_i }
  end

  # Water fills the whole screen; each band takes its colour from the world depth
  # it currently shows, so the gradient stays put in the world as you dive
  # through it. The sky is painted over the part above the waterline.
  def world_water(world)
    band_h = SCREEN_HEIGHT / WATER_BANDS
    (0...WATER_BANDS).map do |i|
      y = i * band_h
      c = water_color_at(y + state.camera_y, world.biome)
      { x: 0, y: y, w: grid.w, h: band_h + 1, r: c[0], g: c[1], b: c[2], path: :solid }
    end
  end

  # The sea floor, drawn as terraces: adjacent columns of the same height become
  # one solid filled downward from the sand surface, topped by a lighter cap.
  # Terraces vary in width and their heights snap to a grid, so the bottom reads
  # as chunky pixel steps. Tinting follows the height (like strata) rather than
  # the column, which keeps a terrace one flat colour, and everything darkens
  # with depth.
  def world_floor(world, dx)
    body = world.biome.floor_colors[1].map { |c| c - 14 }
    cap = world.biome.floor_colors[0]
    tiles = []
    each_run(world.floor) do |top, first_col, width|
      y = top - state.camera_y
      next if y < 0 || y - FLOOR_FILL_DEPTH > SCREEN_HEIGHT # this terrace is off screen

      x = first_col * World::COLUMN_WIDTH + dx
      w = width * World::COLUMN_WIDTH + 1
      shade = (top.idiv(WorldGenerator::FLOOR_STEP) % 5 - 2) * 4 # strata, not stripes
      dim = light_at(top)
      tiles << sand({ x: x, y: y - FLOOR_FILL_DEPTH, w: w, h: FLOOR_FILL_DEPTH }, body, shade, dim)
      tiles << sand({ x: x, y: y - 4, w: w, h: 4 }, cap, shade, dim) # sunlit cap
    end
    tiles
  end

  # A solid rect in a floor colour, tinted by its strata shade and dimmed by how
  # little daylight is left down there.
  def sand(rect, color, shade, dim)
    rect.merge(r: ((color[0] + shade) * dim).to_i,
               g: ((color[1] + shade) * dim).to_i,
               b: ((color[2] + shade) * dim).to_i,
               path: :solid)
  end

  # How lit a slab of rock is, judged by the highest point of it you can see: an
  # island's flank standing in the sun is bright, the same rock below the surface
  # is the inside of a mountain and goes dark.
  def roof_light(top)
    above = (top - (WATERLINE_Y - ROOF_FADE)) / ROOF_FADE.to_f
    above = 1.0 if above > 1.0
    above = 0.0 if above < 0.0
    (CAVE_DIM + (1.0 - CAVE_DIM) * above) * light_at(top)
  end

  # Walk a per-column array as runs of equal value: |value, first column, width|.
  # Merging equal columns is what turns the heightmap into terraces to draw.
  def each_run(values)
    first = 0
    (1..values.length).each do |col|
      next if col < values.length && values[col] == values[first]

      yield(values[first], first, col - first)
      first = col
    end
  end

  # Rock hanging overhead — a cave roof, or a whole island seen from the side.
  # Only the part inside the camera's view is drawn, and it takes its light from
  # the top of *that*: an island's flank above the water is in daylight while the
  # same slab is pitch dark down at the tunnel. A slab that breaks the surface
  # gets earth colours and a band of green along its crown.
  def world_roof(world, dx)
    return [] unless world.roof

    tiles = []
    each_run(world.roof) do |rock, first_col, width|
      next unless rock

      top = [rock[:crown], state.camera_y + SCREEN_HEIGHT].min
      bottom = [rock[:ceiling], state.camera_y].max
      bottom = WATERLINE_Y if !submerged_visible? && bottom < WATERLINE_Y # only what's above water
      next if top <= bottom # this slab is off screen

      island = rock[:crown] > WATERLINE_Y
      grassy = rock[:crown] > WATERLINE_Y + GREEN_MIN
      body = island ? ISLAND_ROCK : world.biome.floor_colors[2]
      x = first_col * World::COLUMN_WIDTH + dx
      w = width * World::COLUMN_WIDTH + 1
      shade = (rock[:ceiling].idiv(WorldGenerator::FLOOR_STEP) % 5 - 2) * 4
      dim = roof_light(top)

      tiles << sand({ x: x, y: bottom - state.camera_y, w: w, h: top - bottom }, body, shade, dim)
      tiles << sand({ x: x, y: rock[:ceiling] - state.camera_y, w: w, h: 4 },
                    world.biome.floor_colors[0], shade, dim) # lit rim under the rock
      tiles << sand({ x: x, y: rock[:crown] - state.camera_y - GREEN_CAP, w: w, h: GREEN_CAP },
                    GREEN, shade, 1.0) if grassy # grass on top of the island
    end
    tiles
  end

  # Air trapped under rock — the cave's own little sky, with the water surface
  # inside drawn as a bright line along its bottom edge.
  def world_air(world, dx)
    world.air_pockets.flat_map do |air|
      x = air[:x] + dx
      y = air[:y] - state.camera_y
      [
        { x: x, y: y, w: air[:w], h: air[:h],
          r: AIR_COLOR[0], g: AIR_COLOR[1], b: AIR_COLOR[2], path: :solid },
        { x: x, y: y - 2, w: air[:w], h: 4,
          r: AIR_SURFACE_COLOR[0], g: AIR_SURFACE_COLOR[1], b: AIR_SURFACE_COLOR[2], path: :solid },
      ]
    end
  end

  def world_decorations(world, dx)
    decorations = world.decorations
    decorations = decorations.select { |d| d[:y] >= WATERLINE_Y } unless submerged_visible?
    decorations.map do |d|
      sprite = DECOR_SPRITES[d[:kind]]
      sway = d[:kind] == "seaweed" ? Math.sin((Kernel.tick_count + d[:x]) / 45.0) * 3 : 0
      drift_x, drift_y = decor_drift(d)
      {
        x: d[:x] + dx + drift_x,
        y: d[:y] - state.camera_y + drift_y,
        w: sprite[:w] * d[:scale],
        h: sprite[:h] * d[:scale],
        path: sprite[:path],
        anchor_x: 0.5,
        anchor_y: 0,
        angle: sway,
      }
    end
  end

  # Most decor stands still. Gulls don't — they drift over the coast on a long,
  # lazy loop — and the crabs scuttle a few steps along the beach.
  def decor_drift(d)
    phase = Kernel.tick_count + d[:x]
    case d[:kind]
    when "gull" then [Math.sin(phase / 150.0) * 190, Math.sin(phase / 47.0) * 14]
    when "crab" then [Math.sin(phase / 90.0) * 26, 0]
    else [0, 0]
    end
  end

  # The diver's home: a small boat bobbing on the waterline over the starting
  # segment (world x SURFACE_BOAT_X). The diver spawns right next to it.
  def home_boat
    scale = 4
    bob = Math.sin(Kernel.tick_count / 45.0) * 4
    {
      x: SURFACE_BOAT_X - state.camera_x,
      y: WATERLINE_Y - 20 + bob - state.camera_y, # hull and ladder reach into the water
      w: BOAT_SPRITE[:w] * scale,
      h: BOAT_SPRITE[:h] * scale,
      path: BOAT_SPRITE[:path],
    }
  end

  # A little card over the boat while you're alongside it: this is home, and this
  # is what home does for you. Only shown when you're actually there, so it reads
  # as the boat talking rather than as a permanent caption.
  def render_boat_hint
    x = SURFACE_BOAT_X - state.camera_x
    y = WATERLINE_Y + 150 - state.camera_y
    left = x - BOAT_HINT_W / 2

    # The card, with a bright rule along its top edge.
    outputs.sprites << { x: left, y: y, w: BOAT_HINT_W, h: BOAT_HINT_H,
                         r: 18, g: 42, b: 66, a: 175, path: :solid }
    outputs.sprites << { x: left, y: y + BOAT_HINT_H - 3, w: BOAT_HINT_W, h: 3,
                         r: 120, g: 190, b: 220, a: 190, path: :solid }

    # Text laid out from the top down; each label's y is the top of its line
    # (vertical_alignment_enum 2), so every line keeps its full height above the
    # card's bottom edge instead of spilling past it.
    outputs.labels << { x: x, y: y + BOAT_HINT_H - 16, text: "Dein Boot",
                        size_enum: 2, alignment_enum: 1, vertical_alignment_enum: 2,
                        r: 232, g: 244, b: 252 }
    outputs.labels << { x: x, y: y + BOAT_HINT_H - 48, text: "Anzug wird repariert · Luft füllt sich auf",
                        size_enum: 0, alignment_enum: 1, vertical_alignment_enum: 2,
                        r: 176, g: 206, b: 226 }
    outputs.labels << { x: x, y: y + BOAT_HINT_H - 84, text: "Aktionen",
                        size_enum: 0, alignment_enum: 1, vertical_alignment_enum: 2,
                        r: 132, g: 168, b: 194 }
    outputs.labels << { x: x, y: y + BOAT_HINT_H - 110, text: "[ E ]  Logbuch öffnen",
                        size_enum: 0, alignment_enum: 1, vertical_alignment_enum: 2,
                        r: 150, g: 198, b: 224 }
    outputs.labels << { x: x, y: y + BOAT_HINT_H - 136, text: "[ Q ]  Spiel beenden",
                        size_enum: 0, alignment_enum: 1, vertical_alignment_enum: 2,
                        r: 150, g: 198, b: 224 }
  end
end

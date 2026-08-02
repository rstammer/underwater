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
  AIR_COLOR = [20, 26, 32]            # the gloom inside an air chamber
  AIR_SURFACE_COLOR = [150, 190, 205] # the water surface trapped under it
  FLOOR_FILL_DEPTH = 1120 # how far down a sand column is filled — a screen height plus slack

  GREEN = [96, 146, 74]       # the green cap on rock that stands well out of the water
  GREEN_CAP = 10              # how thick that band of grass is
  GREEN_MIN = 96             # rock must clear the water by this much to grow grass — bare wet
                             # rock at the waterline and the low skerries stay stone
  ISLAND_ROCK = [138, 122, 102] # sun-bleached stone — an island wears its own colour,
                                # not the palette of the sea floor around it
  # Waterlogged oak, a century down. The wreck was drawn in the biome's own
  # floor colour before this, which is to say in the colour of the mud it lies
  # in — so the one hand-built thing in the sea read as an outcrop of rock. A
  # ship is made of something, and what it is made of is most of what says ship.
  WRECK_TIMBER = [104, 76, 50]
  BEACH_SAND = [231, 208, 156]  # ... except where it meets the water as a beach, which
                                # is sand and has to look like it (IslandWorld tags those
                                # slabs; a rock coast and the skerries never carry it)
  CAVE_DIM = 0.5              # inside a cave it is dark whatever the depth says
  ROOF_FADE = 300             # px under the surface over which rock loses the daylight

  BOAT_SPRITE = { path: "sprites/decor/boat.png", w: 41, h: 20 }
  # The same boat with her ladder hauled in, for when she is making way — one
  # trailing over the side at seven pixels a tick is a ladder somebody is about
  # to lose. Same size, so nothing but the path changes.
  BOAT_UNDERWAY_SPRITE = { path: "sprites/decor/boat_underway.png", w: 41, h: 20 }

  DECOR_SPRITES = {
    "seaweed"  => { path: "sprites/decor/seaweed.png",  w: 14, h: 44 },
    "coral"    => { path: "sprites/decor/coral.png",    w: 28, h: 30 },
    "starfish" => { path: "sprites/decor/starfish.png", w: 16, h: 16 },
    "palm"     => { path: "sprites/decor/palm.png",     w: 20, h: 16 },
    "bush"     => { path: "sprites/decor/bush.png",     w: 12, h: 7 },
    "grass"    => { path: "sprites/decor/grass.png",    w: 12, h: 5 },
    "gull"     => { path: "sprites/decor/gull.png",     w: 12, h: 4 },
    "palm_small" => { path: "sprites/decor/palm_small.png", w: 14, h: 10 },
    "driftwood"  => { path: "sprites/decor/driftwood.png",  w: 14, h: 5 },
    "crab"       => { path: "sprites/decor/crab.png",       w: 12, h: 6 },
    "flag"       => { path: "sprites/decor/flag.png",       w: 12, h: 10 },
    "rock"       => { path: "sprites/decor/rock.png",       w: 14, h: 10 },
    "fern"       => { path: "sprites/decor/fern.png",       w: 14, h: 9 },
    "shop"       => { path: "sprites/decor/shop.png",       w: 152, h: 44 },
    # The wood. Kept in step with what tools/make_decor_sprites.rb prints —
    # tests/vegetation_tests.rb holds this table against the pictures.
    "broadleaf"   => { path: "sprites/decor/broadleaf.png",   w: 20, h: 15 },
    "tree_fern"   => { path: "sprites/decor/tree_fern.png",   w: 15, h: 11 },
    "banana"      => { path: "sprites/decor/banana.png",      w: 15, h: 10 },
    "snag"        => { path: "sprites/decor/snag.png",        w: 8,  h: 10 },
    "flower_bush" => { path: "sprites/decor/flower_bush.png", w: 12, h: 7 },
    "cannon"      => { path: "sprites/decor/cannon.png",      w: 20, h: 9 },
    "barrel"      => { path: "sprites/decor/barrel.png",      w: 10, h: 6 },
    "wheel"       => { path: "sprites/decor/wheel.png",       w: 11, h: 14 },
    "anchor"      => { path: "sprites/decor/anchor.png",      w: 9,  h: 11 },
    "chest"       => { path: "sprites/decor/chest.png",       w: 12, h: 8 },
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
    bare = (120 + 290 * (1.0 - biome.fog)) * (0.55 + 0.45 * light_at(state.depth_y))
    (bare * sight_factor).to_i # ... and a better mask sees through more of it
  end

  # The slice of screen the fog leaves open, as [left, right] — or nil where
  # there is no fog and the whole screen is on show.
  #
  # The fog is opaque and it is a circle, so terrain outside it is built, drawn,
  # and then painted straight over. Across the sea that is about seven rects in
  # ten. Everything that draws the sea draws the fog with it (render_fog), so
  # the same three conditions decide both — which is what keeps this from
  # cutting a hole in a picture that has nothing over it: the surface, the
  # framing screens where the diver floats at the boat, and the boat itself.
  #
  # A cell of slack either side, because the fog is snapped out to its own grid
  # and the clear circle can reach that much further than the radius says.
  def fog_window
    return nil unless FOG_OF_WAR
    return nil if at_open_surface?
    return nil if state.aboard

    reach = fog_radius(current_world.biome) + FogOfWar::CELL
    [state.player_x - reach, state.player_x + reach]
  end

  # Is this run of columns entirely outside that slice, and so entirely behind
  # the fog? Always false where there is no window, which is how the surface and
  # the framing screens keep the whole picture.
  def behind_the_fog?(window, x, w)
    return false unless window

    x + w < window[0] || x > window[1]
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
    # Distance, before anything near is drawn: the island has to occlude it.
    render_backdrop
    outputs.sprites << surface_line
    # Her, then the rock. Steering has one axis, so there is no navigating round
    # an island — rather than make it a wall she goes *astern* of it, and the
    # only thing that takes is being painted before it. She reappears the far
    # side, which is exactly what watching a boat pass behind a headland looks
    # like.
    render_home_boat
    window = fog_window
    visible_world_indices.each do |index|
      world = world_at(index)
      dx = chunk_offset_x(index)
      outputs.sprites << world_floor(world, dx, window) if submerged_visible?
      outputs.sprites << world_roof(world, dx, window)
      outputs.sprites << world_air(world, dx) if submerged_visible?
      outputs.sprites << world_decorations(world, dx)
    end
    render_shop_hut
    # Not while he is talking: the bubble hangs over the same stall, and the two
    # were drawn straight through each other.
    render_shop_hint if at_the_shop? && !game_paused? && !islander_speaking?
    render_camp
    render_islanders
    render_ball
    unless game_paused?
      render_islander_hint
      render_islander_speech
    end
    # The card is not the boat: it has to stay readable when she is behind an
    # island, so it is drawn with the rest of the writing rather than with her.
    # Not while the boat screen is up either — labels always draw over sprites
    # in DragonRuby, so its text would come straight through the menu panel
    # even though its own backing box sits behind it.
    render_boat_hint if home_visible? && at_the_boat? && !game_paused?
  end

  def render_home_boat
    return unless home_visible?
    return if boat_behind_island?

    render_wake
    outputs.sprites << home_boat
  end

  # The view every screen outside the water is built on: the game's own sea, its
  # own renderer, parked beside the boat and high enough to hold the horizon.
  #
  # It is the reason those screens look like the game rather than like title
  # cards — an abstract gradient behind a menu is somebody else's picture. Only
  # the camera moves; the diver is floating at the surface, so submerged_visible?
  # is false and the sea floor stays out of it, which is the clean horizon this
  # wants. HORIZON is where the waterline lands on screen, and menus hang their
  # own layout off it.
  HORIZON = 470
  BOAT_VIEW_X = 380 # how far right of the boat the camera looks, so it sits left

  def render_boat_horizon
    state.camera_x = boat_x - CAMERA_ANCHOR_X + BOAT_VIEW_X
    state.camera_y = WATERLINE_Y - HORIZON
    render_world
  end

  # Two, not three. At three the stall stood three and a bit divers high: the
  # counter came up over his head, the trestle table with it, and the man
  # behind it read as twice his size. It is a market stall on a beach, not a
  # civic building — the whole thing was simply drawn too big for the world,
  # which is one number rather than three details to nudge.
  SHOP_SCALE = 2
  SHOP_REACH = 220 # how close counts as being at the stalls — it is a row of
                   # them now, so the reach covers its whole width

  # Where the hut stands, in world coordinates. Read off the island that is
  # actually stamped there rather than off the island's own maths: if the two
  # ever disagreed the shop would hang in the air or sit buried, and the world
  # is the one that is true.
  def shop_x
    IslandWorld.centre_x(IslandWorld::SHOP_SECTOR)
  end

  # The *lowest* rock under the whole width of the stall, not the height at its
  # middle. The island is terraced, so a stall centred on a step had its far end
  # hanging in the air over the drop — counter, boards and all. Sitting it on the
  # lowest ground buries a pixel or two of the near end instead, which reads as a
  # building dug into a slope rather than one floating off a cliff.
  def shop_ground_y
    sprite = DECOR_SPRITES["shop"]
    half = sprite[:w] * SHOP_SCALE / 2
    crowns = [shop_x - half, shop_x, shop_x + half].map do |x|
      slabs = world_at(x.idiv(SCREEN_WIDTH)).slabs_at(x % SCREEN_WIDTH)
      slabs.empty? ? nil : slabs.map { |slab| slab[:crown] }.max
    end.compact
    return nil if crowns.empty?

    crowns.min
  end

  # On the island, on foot, near the door. On foot matters: you cannot shop by
  # treading water underneath it.
  def at_the_shop?
    return false unless on_land?

    ground = shop_ground_y
    return false unless ground

    (state.diver_global_x - shop_x).abs <= SHOP_REACH
  end

  def shop_hut_visible?
    visible_world_indices.include?(shop_x.idiv(SCREEN_WIDTH))
  end

  def render_shop_hut
    return unless shop_hut_visible?

    ground = shop_ground_y
    return unless ground

    sprite = DECOR_SPRITES["shop"]
    outputs.sprites << { x: shop_x - state.camera_x - sprite[:w] * SHOP_SCALE / 2,
                         y: ground - state.camera_y,
                         w: sprite[:w] * SHOP_SCALE, h: sprite[:h] * SHOP_SCALE,
                         path: sprite[:path] }
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
  def world_floor(world, dx, window = nil)
    body = world.biome.floor_colors[1].map { |c| c - 14 }
    cap = world.biome.floor_colors[0]
    tiles = []
    each_run(world.floor) do |top, first_col, width|
      y = top - state.camera_y
      next if y < 0 || y - FLOOR_FILL_DEPTH > SCREEN_HEIGHT # this terrace is off screen

      x = first_col * World::COLUMN_WIDTH + dx
      w = width * World::COLUMN_WIDTH + 1
      next if behind_the_fog?(window, x, w)

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
  def world_roof(world, dx, window = nil)
    return [] unless world.roof

    tiles = []
    each_run(world.roof) do |slabs, first_col, width|
      next if slabs.nil? || slabs.empty?
      next if behind_the_fog?(window, first_col * World::COLUMN_WIDTH + dx,
                              width * World::COLUMN_WIDTH + 1)

      slabs.each { |rock| roof_slab(tiles, world, rock, first_col, width, dx) }
    end
    tiles
  end

  # Where the sea stops you seeing rock. From in the water that is the waterline
  # itself: an island is a wall of sand ending at the surface, and the skerries
  # in front of it are the only warning that there is more underneath.
  #
  # Aboard the boat it has to reach a little deeper, because *she* reaches a
  # little deeper — with the cut exactly at the waterline there was nothing
  # drawn to cover her hull and her ladder, and they showed straight through the
  # island she was passing. Only as far as her keel: any more and the sea starts
  # giving away what is under it, which it is not supposed to do.
  def surface_clip_y
    state.aboard ? WATERLINE_Y - BOAT_DRAUGHT : WATERLINE_Y
  end

  # One slab of a column run: its body, the lit rim under it, and grass on top if
  # it stands far enough out of the water.
  def roof_slab(tiles, world, rock, first_col, width, dx)
    top = [rock[:crown], state.camera_y + SCREEN_HEIGHT].min
    bottom = [rock[:ceiling], state.camera_y].max
    bottom = surface_clip_y if !submerged_visible? && bottom < surface_clip_y
    return if top <= bottom # this slab is off screen

    island = rock[:crown] > WATERLINE_Y
    grassy = rock[:crown] > WATERLINE_Y + GREEN_MIN
    body = if rock[:sand] then BEACH_SAND
           elsif rock[:wood] then WRECK_TIMBER
           elsif island then ISLAND_ROCK
           else world.biome.floor_colors[2]
           end
    x = first_col * World::COLUMN_WIDTH + dx
    w = width * World::COLUMN_WIDTH + 1
    shade = (rock[:ceiling].idiv(WorldGenerator::FLOOR_STEP) % 5 - 2) * 4
    dim = roof_light(top)

    tiles << sand({ x: x, y: bottom - state.camera_y, w: w, h: top - bottom }, body, shade, dim)
    # The lit rim goes on the underside of the rock — but only when that
    # underside is the thing being looked at. Drawn at the slab's own ceiling
    # regardless, it survived the clip above: a skerry's ceiling is 160 px below
    # the water, so from the surface every island trailed a four-pixel brown line
    # across the open sea in front of it, rock with no rock attached to it.
    tiles << sand({ x: x, y: bottom - state.camera_y, w: w, h: 4 },
                  world.biome.floor_colors[0], shade, dim) if bottom == rock[:ceiling]
    tiles << sand({ x: x, y: rock[:crown] - state.camera_y - GREEN_CAP, w: w, h: GREEN_CAP },
                  GREEN, shade, 1.0) if grassy # grass on top of the island
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
      tint = decor_tint(d, world)
      {
        x: d[:x] + dx + drift_x,
        y: d[:y] - state.camera_y + drift_y,
        w: sprite[:w] * d[:scale],
        h: sprite[:h] * d[:scale],
        path: sprite[:path],
        anchor_x: 0.5,
        anchor_y: 0,
        angle: sway,
        r: tint[0], g: tint[1], b: tint[2],
      }
    end
  end

  # Decorations keep their own colour but lose light with depth, so nothing glows
  # down in the dark.
  def decor_tint(d, _world)
    v = (255 * light_at(d[:y])).to_i
    [v, v, v]
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
  # waterline wherever it is moored (state.boat_x). The diver spawns beside it.
  # boat_x is her *middle*, hence the anchor. It used to be her left edge, which
  # is only ever a corner of a picture and not a place a boat is — everything
  # measuring against her (how close counts as home, whether an island is across
  # her) was quietly out by half a hull.
  #
  # She is drawn pointing the way she was last driven. The motor is at her stern
  # in the drawing, so turning the picture round is what keeps it there instead
  # of leaving her steaming along backwards.
  def home_boat
    scale = 4
    bob = Math.sin(Kernel.tick_count / 45.0) * 4
    {
      x: boat_x - state.camera_x,
      y: WATERLINE_Y - 20 + bob - state.camera_y, # hull and ladder reach into the water
      w: BOAT_SPRITE[:w] * scale,
      h: BOAT_SPRITE[:h] * scale,
      anchor_x: 0.5,
      flip_horizontally: boat_heading.negative?,
      path: state.aboard ? BOAT_UNDERWAY_SPRITE[:path] : BOAT_SPRITE[:path],
    }
  end

  # A little card over the boat while you're alongside it: this is home, and this
  # is what home does for you. Only shown when you're actually there, so it reads
  # as the boat talking rather than as a permanent caption. The card is anchored
  # by its *top* and grows downward, so adding lines can never push it off the top
  # of the screen; the repair line shows (blinking) only while the suit is
  # actually being patched up.
  # Before the first dive the card carries the story instead of the actions —
  # same card, same place, so the opening is something the boat says rather than
  # a screen to click past.
  def render_boat_hint
    render_boat_card(boat_action_lines, BOAT_HINT_W,
                     boat_x - state.camera_x,
                     WATERLINE_Y + 210 - state.camera_y)
  end

  SHOP_HINT_W = 400

  # The same card the boat gets, over the hut. Without it the shop was a
  # building you could stand in front of and nothing else: the boat tells you
  # every key it answers to, and a shop that keeps its own key a secret is a
  # shop nobody opens. (Which is exactly what happened.)
  def render_shop_hint
    ground = shop_ground_y
    return unless ground

    render_boat_card(shop_action_lines, SHOP_HINT_W,
                     shop_x - state.camera_x,
                     ground + DECOR_SPRITES["shop"][:h] * SHOP_SCALE + 150 - state.camera_y)
  end

  # Both things you can do here on one card, rather than a second card floating
  # over this one saying "[ E ] ansprechen": the stall and the man behind it are
  # one place, and two panels stacked on the same spot is how it looked when
  # they were kept apart.
  def shop_action_lines
    [{ text: SHOP_NAME, size: 2, color: [232, 244, 252] },
     { text: "[ L ]  Ausrüstung kaufen", size: 0, color: [232, 226, 150] },
     { text: "[ E ]  #{SHOP_KEEPER} ansprechen", size: 0, color: [232, 226, 150] },
     { text: "#{state.credits} Cr dabei", size: 0, color: [150, 198, 224] }]
  end

  # Under way the card has one job — say how to stop and what stopping costs.
  # The list of things you can do at a moored boat is not a list you can act on
  # while you are steering it.
  def sailing_lines
    sectors = ((boat_x - state.boarded_x.to_i).abs / SCREEN_WIDTH.to_f).round
    [{ text: "Unterwegs", size: 2, color: [232, 244, 252] },
     { text: "←  →   steuern", size: 0, color: [150, 198, 224] },
     { text: "[ E ]  hier ankern", size: 0, color: [232, 226, 150] },
     { text: "Sprit bisher: #{sectors * BOAT_FUEL} Cr",
       size: 0, color: [232, 202, 150] }]
  end

  def boat_action_lines
    return sailing_lines if state.aboard

    lines = [{ text: "Dein Boot", size: 2, color: [232, 244, 252] }]
    lines << { text: "Anzug wird repariert", size: 0, color: [232, 202, 150], blink: true } if repairing_suit?
    lines << { text: "Aktionen", size: 0, color: [132, 168, 194] }
    if state.film_roll.length > 0
      lines << { text: "[ F ]  Film entwickeln (#{state.film_roll.length})",
                 size: 0, color: [232, 226, 150] }
    end
    lines << { text: "[ T ]  #{boat_card_assignment}", size: 0, color: boat_card_assignment_ink }
    lines << { text: "[ E ]  Ablegen — Boot versetzen", size: 0, color: [232, 226, 150] }
    lines << { text: "[ S ]  Schlafen — Tag #{state.day} beenden", size: 0, color: [180, 214, 180] }
    lines << { text: "[ L ]  Logbuch & Lager", size: 0, color: [150, 198, 224] }
    lines << { text: "[ I ]  Alles einlagern (#{state.inventory.length})", size: 0, color: [150, 198, 224] }
    lines << { text: "[ Q ]  Spiel beenden", size: 0, color: [150, 198, 224] }
    lines
  end

  # The job, in the list of things you can do here. Its own state is worth a
  # word: a job already delivered is not something to go and read.
  def boat_card_assignment
    return "Tagesauftrag — erledigt" if assignment_paid?
    return "Tagesauftrag — im Kasten" if assignment_done?

    "Tagesauftrag ansehen"
  end

  def boat_card_assignment_ink
    return [180, 214, 180] if assignment_paid?
    return [232, 226, 150] if assignment_done?

    [150, 198, 224]
  end

  # Anchored rather than pinned to the boat: the shop uses the same card, over
  # its own hut. It hangs *down* from `top` so a long card can never run off the
  # upper edge of the screen.
  def render_boat_card(lines, width, x, top)
    pad = 16
    height = pad + 12
    lines.each { |line| height += boat_line_height(line) }

    left = x - width / 2

    outputs.sprites << { x: left, y: top - height, w: width, h: height,
                         r: 18, g: 42, b: 66, a: 220, path: :solid }
    outputs.sprites << { x: left, y: top - 3, w: width, h: 3,
                         r: 120, g: 190, b: 220, a: 190, path: :solid }

    ly = top - pad
    lines.each do |line|
      unless line[:blink] && !Kernel.tick_count.idiv(30).even? # blink: dark half of the cycle
        outputs.labels << { x: x, y: ly, text: line[:text], size_enum: line[:size],
                            alignment_enum: 1, vertical_alignment_enum: 2,
                            r: line[:color][0], g: line[:color][1], b: line[:color][2] }
      end
      ly -= boat_line_height(line)
    end
  end

  def boat_line_height(line)
    line[:size] >= 2 ? 34 : 26
  end

  # The boat only patches the suit up when there's damage to mend.
  def repairing_suit?
    state.suit < SUIT_MAX
  end
end

# What a frame is allowed to cost.
#
# The game runs in a browser as well as on a desktop, and the browser is where
# it showed: mruby is a good deal slower under WASM and every primitive has to
# cross into the engine, so a frame that a Mac shrugs off is a frame the web
# build stutters on. Three things were paying for that and none of them had to:
#
#   * the far ridge was re-rolling hills that had not moved (app/world/backdrop.rb)
#   * the fog was drawn one 40 px cell at a time (app/world/fog_of_war.rb)
#   * the sea floor was drawn out to the screen edge, under opaque fog
#
# These are the guards on all three. They are budgets rather than exact numbers:
# the point is that nobody quietly puts a thousand rects back.
class RenderBudgetTests
  def build_game(args)
    game = Game.new
    game.args = args
    game.initialize_game(0)
    args.state.game_scene = "area1"
    game
  end

  # Stand the diver in the open water of a segment, a little above its floor.
  def dive_at(game, args, sector)
    x = sector * SCREEN_WIDTH + 640
    args.state.diver_global_x = x
    args.state.depth_y = WorldGenerator.floor_y_at(x) + 320
    game.center_camera
    game.current_world
  end

  # Float him at a given x and say whether his head actually came out. It may
  # not have: an island reaches a long way out under water, and a spot that
  # looks like open sea beside one is often the roof of its flank, which holds
  # him under (clamp_depth).
  def surface_at(game, args, x)
    args.state.diver_global_x = x
    args.state.depth_y = WATERLINE_Y
    game.center_camera
    game.current_world
    game.at_open_surface?
  end

  # Open water within sight of an island: near enough that its far range is in
  # the picture, clear enough of it that he is floating rather than under rock.
  def surface_beside(game, args, sector)
    centre = IslandWorld.centre_x(sector)
    [900, 1400, 1900, 2400, -900, -1400, -1900, -2400].each do |offset|
      return centre + offset if surface_at(game, args, centre + offset)
    end
    nil
  end

  def primitives(args)
    args.outputs.sprites.flatten.compact.length
  end

  def one_tick(game, args)
    args.outputs.sprites.clear
    args.outputs.labels.clear
    game.tick
    primitives(args)
  end

  # --- the frame budget ------------------------------------------------------

  # Measured across the sea it was 500–1344 primitives a frame, of which the fog
  # alone was up to 582 and the sea floor mostly hidden behind it. This is the
  # ceiling that keeps that from coming back; a comfortable frame is well under.
  FRAME_BUDGET = 800

  def test_a_dive_stays_inside_the_frame_budget(args, assert)
    game = build_game(args)
    worst = 0
    worst_at = nil

    (-6..12).each do |sector|
      dive_at(game, args, sector)
      count = one_tick(game, args)
      if count > worst
        worst = count
        worst_at = sector
      end
    end

    assert.true! worst <= FRAME_BUDGET,
                 "sector #{worst_at} draws #{worst} primitives, over the #{FRAME_BUDGET} budget"
  end

  # The surface next to an island is the other busy place: no fog to hide the
  # terrain, and the far range drawn on top. It gets a looser budget because it
  # genuinely has more to show, but not an open one.
  SURFACE_BUDGET = 1200

  def test_the_surface_beside_an_island_stays_inside_its_budget(args, assert)
    game = build_game(args)
    worst = 0
    worst_at = nil

    args.state.island_sectors.each do |sector|
      next unless surface_beside(game, args, sector)

      assert.true! game.backdrop_visible?, "island #{sector} has its range in view"
      count = one_tick(game, args)
      if count > worst
        worst = count
        worst_at = sector
      end
    end

    assert.true! worst > 0, "no island had open water beside it to float in"
    assert.true! worst <= SURFACE_BUDGET,
                 "island #{worst_at} draws #{worst} primitives, over the #{SURFACE_BUDGET} budget"
  end

  # --- the terrain clip ------------------------------------------------------

  # Under water the fog is opaque, so terrain outside its circle is drawn and
  # then painted over. It is left out instead — but only what the fog would
  # have covered, which is what this holds it to: everything the player could
  # actually see is still built.
  def test_the_clip_drops_nothing_the_diver_could_see(args, assert)
    game = build_game(args)

    (-6..12).each do |sector|
      dive_at(game, args, sector)
      window = game.fog_window
      assert.true! !window.nil?, "sector #{sector} is under water, so there is a fog window"

      game.visible_world_indices.each do |index|
        world = game.world_at(index)
        dx = game.chunk_offset_x(index)
        drawn = (game.world_floor(world, dx, window) +
                 game.world_roof(world, dx, window)).flatten.compact
        every = (game.world_floor(world, dx) + game.world_roof(world, dx)).flatten.compact

        missing = every.reject do |rect|
          rect[:x] + rect[:w] < window[0] || rect[:x] > window[1] ||
            drawn.any? { |kept| kept[:x] == rect[:x] && kept[:y] == rect[:y] && kept[:w] == rect[:w] }
        end
        assert.equal! missing.length, 0,
                      "sector #{sector} dropped #{missing.length} rects inside the fog window"
      end
    end
  end

  def test_the_clip_actually_leaves_something_out(args, assert)
    game = build_game(args)
    clipped = 0
    every = 0

    (-6..12).each do |sector|
      dive_at(game, args, sector)
      window = game.fog_window
      game.visible_world_indices.each do |index|
        world = game.world_at(index)
        dx = game.chunk_offset_x(index)
        clipped += (game.world_floor(world, dx, window) +
                    game.world_roof(world, dx, window)).flatten.compact.length
        every += (game.world_floor(world, dx) + game.world_roof(world, dx)).flatten.compact.length
      end
    end

    assert.true! clipped < every / 2,
                 "the clip only saved #{every - clipped} of #{every} rects — it is not biting"
  end

  # There is nothing to hide behind at the surface, so nothing may be left out
  # there. The framing screens (the title, the recap, the boat menus) park the
  # camera at the boat with the diver floating, and they go through the same
  # gate — a clipped horizon would be a hole in the picture.
  def test_nothing_is_clipped_where_there_is_no_fog(args, assert)
    game = build_game(args)
    found = surface_beside(game, args, args.state.island_sectors.first)
    assert.true! !found.nil?, "found open water beside the island to float in"

    assert.true! game.at_open_surface?, "the diver is up in the air"
    assert.true! game.fog_window.nil?, "no fog up here, so no window to clip to"

    # Which is to say render_world asks for a window, gets nil, and draws the lot
    # — the same list it builds when nobody clips at all.
    game.visible_world_indices.each do |index|
      world = game.world_at(index)
      dx = game.chunk_offset_x(index)
      assert.equal! game.world_floor(world, dx, game.fog_window).flatten.compact.length,
                    game.world_floor(world, dx).flatten.compact.length,
                    "the floor was clipped at the surface"
      assert.equal! game.world_roof(world, dx, game.fog_window).flatten.compact.length,
                    game.world_roof(world, dx).flatten.compact.length,
                    "the rock was clipped at the surface"
    end
  end

  # Aboard, the diver is not drawn and neither is his fog, whatever the depth
  # says. Clipping to a circle that is not there would cut the sea in half.
  def test_nothing_is_clipped_from_the_boat(args, assert)
    game = build_game(args)
    dive_at(game, args, 0)
    assert.true! !game.fog_window.nil?, "in the water there is a window"

    args.state.aboard = true

    assert.true! game.fog_window.nil?, "aboard there is no fog, so nothing to clip to"
  end
end

class SurfaceTests
  def build_game(args)
    game = Game.new
    game.args = args
    game
  end

  def test_swim_up_past_top_enters_surface(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.surfaced = false
    args.state.player_y = SCREEN_HEIGHT # reached the top of the underwater view

    game.apply_vertical_bounds

    assert.true! args.state.surfaced, "should have surfaced"
    # Reaching the top means you're up: arrive right at the breathing position,
    # not at the bottom of the surface scene with a whole water column to climb.
    assert.equal! args.state.player_y, SURFACE_WATERLINE - SURFACE_FLOAT_DEPTH
    assert.true! game.breathing?, "can breathe immediately after surfacing"
  end

  def test_head_clamped_at_waterline_in_surface(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.surfaced = true
    args.state.player_y = 99_999 # try to swim out of the water

    game.apply_vertical_bounds

    # body can't leave the water — clamped below the waterline (only the head pokes out)
    assert.equal! args.state.player_y, SURFACE_WATERLINE - SURFACE_FLOAT_DEPTH
  end

  def test_dipping_head_under_waterline_dives_under(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.surfaced = true
    args.state.player_y = SURFACE_WATERLINE - Diver::HEIGHT - 1 # head just slipped under

    game.apply_vertical_bounds

    # Symmetric with surfacing: the moment the head dips under you're diving, so
    # hand straight over to the underwater scene — no long descent in the surface.
    assert.false! args.state.surfaced, "head under the waterline -> diving under"
    assert.true! args.state.player_y > SURFACE_WATERLINE, "re-enters just below the surface"
  end

  def test_sea_floor_clamp_when_underwater(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.surfaced = false
    args.state.player_y = -10

    game.apply_vertical_bounds

    assert.equal! args.state.player_y, 1
  end

  def test_surface_shows_the_home_boat(args, assert)
    game = build_game(args)
    game.initialize_game(0)

    boat = game.surface_boat

    assert.true! boat[:path].include?("boat"), "the surface shows the home boat"
    assert.true! boat[:y] < SURFACE_WATERLINE, "the boat floats at the waterline"
  end

  def test_spawn_syncs_screen_and_world_x(args, assert)
    # If these drift apart, the sector boundary no longer lines up with the edge.
    game = build_game(args)
    game.initialize_game(0)

    game.spawn_at_surface

    assert.equal! args.state.player_x, args.state.diver_global_x
  end

  def test_diver_starts_beside_the_home_boat(args, assert)
    game = build_game(args)
    game.initialize_game(0)

    game.spawn_at_surface

    assert.true! (args.state.player_x - SURFACE_BOAT_X).abs < 200, "diver starts near the boat"
  end

  def test_update_scene_selects_surface_when_surfaced(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.game_scene = "area1" # un-pause so update_scene runs
    args.state.surfaced = true

    game.update_scene

    assert.equal! args.state.game_scene, "surface"
  end
end

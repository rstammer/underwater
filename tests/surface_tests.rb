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
    assert.true! args.state.player_y < SCREEN_HEIGHT, "player_y should reset low when entering the surface"
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

  def test_swim_down_from_surface_returns_underwater(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.surfaced = true
    args.state.player_y = -5 # dive back down past the bottom of the surface view

    game.apply_vertical_bounds

    assert.false! args.state.surfaced, "should return underwater"
    assert.true! args.state.player_y > SURFACE_WATERLINE, "player_y should reset high when re-entering the water"
  end

  def test_sea_floor_clamp_when_underwater(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.surfaced = false
    args.state.player_y = -10

    game.apply_vertical_bounds

    assert.equal! args.state.player_y, 1
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

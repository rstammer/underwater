class LocatorTests
  def build_game(args)
    game = Game.new
    game.args = args
    game
  end

  def test_home_only_in_the_starting_segment(args, assert)
    game = build_game(args)
    game.initialize_game(0)

    args.state.diver_global_x = 100
    assert.true! game.at_home?, "the starting segment is home"

    args.state.diver_global_x = 3000
    assert.false! game.at_home?, "far away is not home"
  end

  def test_depth_is_zero_at_the_waterline(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.surfaced = true
    args.state.player_y = SURFACE_WATERLINE

    assert.equal! game.current_depth, 0
  end

  def test_depth_grows_when_sinking_in_the_surface_scene(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.surfaced = true
    args.state.player_y = 50 # sunk well below the waterline, still in the surface scene

    assert.true! game.current_depth > 0, "depth must not stay 0 while sinking at the surface"
  end

  def test_depth_grows_as_you_dive(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.surfaced = false

    args.state.player_y = SCREEN_HEIGHT
    shallow = game.current_depth

    args.state.player_y = 200
    deep = game.current_depth

    assert.true! deep > shallow, "deeper player_y means greater depth"
  end

  def test_locator_text_reports_sector_and_depth(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.diver_global_x = 2600 # sector 2
    args.state.surfaced = false
    args.state.player_y = 320

    text = game.locator_text

    assert.true! text.include?("Sektor 2"), "shows the sector"
    assert.true! text.include?(game.current_depth.to_s), "shows the depth"
  end
end

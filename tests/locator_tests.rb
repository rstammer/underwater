class LocatorTests
  def build_game(args)
    game = Game.new
    game.args = args
    game
  end

  def test_depth_is_zero_at_the_waterline(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.depth_y = WATERLINE_Y

    assert.equal! game.current_depth, 0
  end

  def test_depth_grows_below_the_waterline(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.depth_y = 500 # below the waterline

    assert.true! game.current_depth > 0, "depth grows once below the waterline"
  end

  def test_depth_is_a_whole_number(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.depth_y = 517.3 # the diver's y is fractional (slow sinking)

    assert.equal! game.current_depth, game.current_depth.to_i, "depth reads as whole metres, no decimals"
  end

  def test_depth_grows_as_you_dive(args, assert)
    game = build_game(args)
    game.initialize_game(0)

    args.state.depth_y = WATERLINE_Y
    shallow = game.current_depth

    args.state.depth_y = 200
    deep = game.current_depth

    assert.true! deep > shallow, "a lower depth_y means greater depth"
  end

  def test_locator_text_reports_sector_and_depth(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.diver_global_x = 2600 # sector 2
    args.state.depth_y = 320

    text = game.locator_text

    assert.true! text.include?("Sektor 2"), "shows the sector"
    assert.true! text.include?(game.current_depth.to_s), "shows the depth"
  end
end

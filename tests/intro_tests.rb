class IntroTests
  def build_game(args)
    game = Game.new
    game.args = args
    game
  end

  def test_spawn_at_surface_floats_at_the_waterline(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.depth_y = 100 # somewhere deep

    game.spawn_at_surface

    assert.equal! args.state.depth_y, WATERLINE_Y - SURFACE_FLOAT_DEPTH
    assert.true! game.breathing?, "head should be out of the water, breathing"
  end

  def test_reset_starts_the_round_at_the_surface(args, assert)
    # Every round (start and restart) begins floating at the surface.
    game = build_game(args)
    game.initialize_game(0)

    game.reset_game

    assert.true! game.breathing?
  end

  def test_surface_hint_encourages_exploration(args, assert)
    game = build_game(args)
    game.initialize_game(0)

    hint = game.surface_hint

    assert.true! hint[:text].length > 0, "hint should carry text"
    assert.true! hint[:text].downcase.include?("erkunde"), "hint should encourage exploring"
  end
end

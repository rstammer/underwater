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

  # Alongside the boat a little card explains what home is for. It only shows up
  # there — everywhere else the screen stays clear of captions.
  def test_the_boat_greets_you_when_you_are_alongside(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    game.spawn_at_surface
    args.state.game_scene = "area1"

    game.area1_tick
    text = args.outputs.labels.map { |label| label[:text] }.join(" ")

    assert.true! text.include?("Boot"), "the card names the boat"
    assert.true! text.downcase.include?("anzug"), "and says the suit gets repaired here"
  end

  def test_no_card_once_you_have_left_the_boat(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    game.spawn_at_surface
    args.state.diver_global_x = SURFACE_BOAT_X + 600 # swum off along the surface
    game.update_depth_and_camera
    args.state.game_scene = "area1"

    game.area1_tick
    text = args.outputs.labels.map { |label| label[:text] }.join(" ")

    assert.false! text.include?("zu Hause"), "no caption once you're away from it"
  end
end

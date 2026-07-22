class OxygenTests
  def build_game(args)
    game = Game.new
    game.args = args
    game
  end

  def test_initialize_starts_with_full_oxygen(args, assert)
    game = build_game(args)
    game.initialize_game(0)

    assert.equal! args.state.oxygen, OXYGEN_MAX
  end

  def test_oxygen_drains_underwater(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.depth_y = 300 # submerged, head under water
    args.state.oxygen = 50

    game.update_oxygen

    assert.equal! args.state.oxygen, 50 - OXYGEN_DRAIN
  end

  def test_oxygen_refills_only_when_head_is_above_water(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.depth_y = WATERLINE_Y # floated up, head pokes out
    args.state.oxygen = 50

    game.update_oxygen

    assert.equal! args.state.oxygen, 50 + OXYGEN_REFILL
  end

  def test_oxygen_drains_when_near_but_still_submerged(args, assert)
    # Close to the surface but the head is still under — no air yet.
    game = build_game(args)
    game.initialize_game(0)
    args.state.depth_y = 600
    args.state.oxygen = 50

    game.update_oxygen

    assert.equal! args.state.oxygen, 50 - OXYGEN_DRAIN
  end

  def test_oxygen_does_not_exceed_max(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.depth_y = WATERLINE_Y
    args.state.oxygen = OXYGEN_MAX

    game.update_oxygen

    assert.equal! args.state.oxygen, OXYGEN_MAX
  end

  def test_empty_oxygen_triggers_game_over(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.depth_y = 300
    args.state.game_scene = "area1"
    args.state.oxygen = OXYGEN_DRAIN # one more tick drains it to 0

    game.update_oxygen

    assert.equal! args.state.oxygen, 0
    assert.equal! args.state.game_scene, "game_over"
    assert.equal! args.state.death_cause, :drowned
  end
end

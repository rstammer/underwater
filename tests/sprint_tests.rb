class SprintTests
  def build_game(args)
    game = Game.new
    game.args = args
    game
  end

  # --- the sprint decision (pure: key held AND actually swimming, never paused) ---

  def test_sprint_active_when_key_held_and_moving(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.game_scene = "area1" # un-paused

    assert.true! game.sprint_active?(true, true)
  end

  def test_no_sprint_without_key(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.game_scene = "area1"

    assert.false! game.sprint_active?(false, true)
  end

  def test_no_sprint_without_movement(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.game_scene = "area1"

    assert.false! game.sprint_active?(true, false)
  end

  def test_no_sprint_while_paused(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.game_scene = "title" # paused scene

    assert.false! game.sprint_active?(true, true)
  end

  # --- effects: speed and oxygen scale with the sprint flag ---

  def test_speed_is_base_when_not_sprinting(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.sprinting = false

    assert.equal! game.current_speed, Diver::SPEED
  end

  def test_speed_doubles_when_sprinting(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.sprinting = true

    assert.equal! game.current_speed, Diver::SPEED * SPRINT_MULTIPLIER
  end

  def test_sprinting_drains_oxygen_faster_underwater(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.depth_y = 300 # submerged, head under water
    args.state.sprinting = true
    args.state.oxygen = 50

    game.update_oxygen

    assert.equal! args.state.oxygen, 50 - OXYGEN_DRAIN * SPRINT_MULTIPLIER
  end

  def test_sprinting_does_not_affect_surface_refill(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.depth_y = WATERLINE_Y # head above water -> breathing
    args.state.sprinting = true
    args.state.oxygen = 50

    game.update_oxygen

    assert.equal! args.state.oxygen, 50 + OXYGEN_REFILL
  end

  def test_initialize_starts_without_sprint(args, assert)
    game = build_game(args)
    game.initialize_game(0)

    assert.false! args.state.sprinting
    assert.equal! args.state.speed, Diver::SPEED
  end
end

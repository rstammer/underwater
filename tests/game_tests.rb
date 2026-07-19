class GameTests
  def build_game(args)
    game = Game.new
    game.args = args
    game
  end

  def test_initialize_game_sets_starting_state(args, assert)
    game = build_game(args)
    game.initialize_game(0)

    assert.equal! args.state.game_scene, "title"
    assert.equal! args.state.player_x, Diver::START_X
    assert.equal! args.state.diver_global_x, Diver::START_X
    assert.true! args.state.initialized
    assert.equal! args.state.dark_shark.x, -300
    assert.equal! args.state.dark_shark.y, 300
    assert.equal! args.state.fish.length, 0 # a swarm is spawned per world, not at boot
    assert.true! args.state.diver.is_a?(Diver)
  end

  def test_update_scene_switches_to_area2_when_far_right(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.game_scene = "area1" # un-pause so update_scene runs
    args.state.diver_global_x = 2000

    game.update_scene

    assert.equal! args.state.game_scene, "area2"
  end

  def test_update_scene_returns_to_area1_when_left(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.game_scene = "area2"
    args.state.diver_global_x = 100

    game.update_scene

    assert.equal! args.state.game_scene, "area1"
  end

  def test_game_paused_only_on_title_and_game_over(args, assert)
    game = build_game(args)

    args.state.game_scene = "title"
    assert.true! game.game_paused?

    args.state.game_scene = "game_over"
    assert.true! game.game_paused?

    args.state.game_scene = "area1"
    assert.false! game.game_paused?
  end
end

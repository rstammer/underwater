class GameOverTests
  def build_game(args)
    game = Game.new
    game.args = args
    game
  end

  def test_shark_collision_ends_game_as_eaten(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.game_scene = "area2"   # un-paused, underwater
    args.state.diver_global_x = 1500  # a shark biome (Tiefsee)
    args.state.player_x = 100
    args.state.depth_y = 100           # collide in world space at this depth
    args.state.dark_shark = { x: 100, y: 100 } # overlapping the diver

    game.update_characters(0)

    assert.equal! args.state.game_scene, "game_over"
    assert.equal! args.state.death_cause, :eaten
  end

  def test_death_message_depends_on_cause(args, assert)
    game = build_game(args)
    game.initialize_game(0)

    args.state.death_cause = :eaten
    assert.true! game.death_message.include?("gefressen"), "eaten message should mention being eaten"

    args.state.death_cause = :drowned
    assert.true! game.death_message.downcase.include?("luft"), "drowned message should mention air"
  end
end

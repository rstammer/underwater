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
    args.state.diver_global_x = 1500  # a shark biome (Tiefsee), world x 1500
    args.state.depth_y = 100           # collide in world space at this depth
    # Shark local x 220 in segment 1 -> world x 1280 + 220 = 1500, overlapping the diver.
    args.state.dark_shark = { x: 220, y: 100 }

    game.update_characters(0)

    assert.equal! args.state.game_scene, "game_over"
    assert.equal! args.state.death_cause, :eaten
  end

  # In a shark biome, under water, with the shark placed by hand.
  def hunted(args, shark_x:, shark_y:)
    game = build_game(args)
    game.initialize_game(0)
    args.state.game_scene = "area2"
    args.state.diver_global_x = 1500 # Tiefsee, world x 1500
    args.state.depth_y = 100
    args.state.dark_shark = { x: shark_x - SCREEN_WIDTH, y: shark_y } # local x in segment 1
    game.update_characters(0)
    game
  end

  # The frustrating one. Both bodies used to be collided as their whole sprite
  # frame — and the diver's was pinned by its corner while his position is his
  # centre — so the shark ate you from most of a body-length away, with clear
  # water still showing between you.
  def test_the_shark_does_not_eat_you_across_clear_water(args, assert)
    hunted(args, shark_x: 1500 + 60, shark_y: 100)

    assert.equal! args.state.game_scene, "area2", "60 px of open water is not a bite"
    assert.equal! args.state.death_cause, nil
  end

  def test_nor_from_a_body_length_above(args, assert)
    hunted(args, shark_x: 1500, shark_y: 100 + 70)

    assert.equal! args.state.game_scene, "area2", "a shark cruising overhead is not a bite"
  end

  # ... but it still bites when it really is on you.
  def test_the_shark_does_eat_you_when_it_is_on_you(args, assert)
    hunted(args, shark_x: 1500 - 20, shark_y: 100 - 30)

    assert.equal! args.state.game_scene, "game_over"
    assert.equal! args.state.death_cause, :eaten
  end

  # The box has to sit on him, not beside him: his position is his middle.
  def test_the_divers_hitbox_is_centred_on_him(args, assert)
    box = Diver.new(args, 0).hitbox(1000, 500)

    assert.equal! box[:x] + box[:w] / 2, 1000, "centred left to right"
    assert.equal! box[:y] + box[:h] / 2, 500, "and top to bottom"
    assert.true! box[:w] < Diver::WIDTH * 2, "and it is the man, not his sprite's empty corners"
    assert.true! box[:h] < Diver::HEIGHT * 2
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

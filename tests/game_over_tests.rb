class GameOverTests
  def build_game(args)
    game = Game.new
    game.args = args
    game
  end

  # Which segment has a shark in it is a fact about the sea floor now, not about
  # the index — the deep biomes only happen where the ground has fallen away. So
  # the tests go and find one instead of assuming segment 1 is the deep sea.
  def a_shark_segment(game)
    (0..80).find { |i| game.world_for(i).biome.shark }
  end

  def test_shark_collision_ends_game_as_eaten(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.game_scene = "area2"   # un-paused, underwater
    sector = a_shark_segment(game)
    args.state.diver_global_x = sector * SCREEN_WIDTH + 220
    args.state.depth_y = 100          # collide in world space at this depth
    # The shark's x is local to the diver's segment, so the same 220 puts the
    # two of them on top of each other.
    args.state.dark_shark = { x: 220, y: 100 }

    game.update_characters(0)

    assert.equal! args.state.game_scene, "game_over"
    assert.equal! args.state.death_cause, :eaten
  end

  # In a shark biome, under water, with the shark placed by hand.
  def hunted(args, gap_x:, shark_y:)
    game = build_game(args)
    game.initialize_game(0)
    args.state.game_scene = "area2"
    sector = a_shark_segment(game)
    args.state.diver_global_x = sector * SCREEN_WIDTH + 220
    args.state.depth_y = 100
    # gap_x is how far the shark sits from him, in world px; its own x is local
    # to the segment he is in.
    args.state.dark_shark = { x: 220 + gap_x, y: shark_y }
    game.update_characters(0)
    game
  end

  # The frustrating one. Both bodies used to be collided as their whole sprite
  # frame — and the diver's was pinned by its corner while his position is his
  # centre — so the shark ate you from most of a body-length away, with clear
  # water still showing between you.
  def test_the_shark_does_not_eat_you_across_clear_water(args, assert)
    hunted(args, gap_x: 60, shark_y: 100)

    assert.equal! args.state.game_scene, "area2", "60 px of open water is not a bite"
    assert.equal! args.state.death_cause, nil
  end

  def test_nor_from_a_body_length_above(args, assert)
    hunted(args, gap_x: 0, shark_y: 100 + 70)

    assert.equal! args.state.game_scene, "area2", "a shark cruising overhead is not a bite"
  end

  # ... but it still bites when it really is on you.
  def test_the_shark_does_eat_you_when_it_is_on_you(args, assert)
    hunted(args, gap_x: -20, shark_y: 100 - 30)

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

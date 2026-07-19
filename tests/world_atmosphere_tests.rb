class WorldAtmosphereTests
  def build_game(args)
    game = Game.new
    game.args = args
    game
  end

  def test_brighter_biome_sees_farther(args, assert)
    game = build_game(args)

    assert.true! game.fog_radius(Biome::SANDBANK) > game.fog_radius(Biome::DEEP),
                 "the bright Sandbank should see farther than the dark Deep"
  end

  def test_only_the_deep_has_a_shark(args, assert)
    assert.true! Biome::DEEP.shark
    assert.false! Biome::SANDBANK.shark
    assert.false! Biome::REEF.shark
    assert.false! Biome::KELP.shark
  end

  def test_no_shark_at_the_surface(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.diver_global_x = 1500 # a shark biome underwater
    args.state.surfaced = true

    assert.false! game.shark_present?, "the shark can't reach the surface"
  end

  def test_spawn_fauna_matches_the_biome(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    world = WorldGenerator.generate(0)

    game.spawn_fauna(world)

    assert.equal! args.state.fish.length, world.biome.fish_count
  end

  def test_static_hook_defaults_to_generation(args, assert)
    assert.equal! StaticWorlds.for(123), nil
    assert.true! WorldGenerator.generate(5).is_a?(World)
  end
end

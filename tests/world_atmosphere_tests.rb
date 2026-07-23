class WorldAtmosphereTests
  def build_game(args)
    game = Game.new
    game.args = args
    game
  end

  def test_brighter_biome_sees_farther(args, assert)
    game = build_game(args)
    game.initialize_game(0)

    assert.true! game.fog_radius(Biome::SANDBANK) > game.fog_radius(Biome::DEEP),
                 "the bright Sandbank should see farther than the dark Deep"
  end

  # The deeper the dive, the less daylight is left and the closer the dark sits.
  def test_the_deep_closes_in(args, assert)
    game = build_game(args)
    game.initialize_game(0)

    args.state.depth_y = WATERLINE_Y - 200 # just under the surface
    shallow = game.fog_radius(Biome::SANDBANK)

    args.state.depth_y = -2000 # down in a trench
    deep = game.fog_radius(Biome::SANDBANK)

    assert.true! deep < shallow, "sight should shrink with depth (#{deep} vs #{shallow})"
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
    args.state.depth_y = WATERLINE_Y # floated up, head out -> breathing at the surface

    assert.false! game.shark_present?, "the shark can't reach the surface"
  end

  def test_spawn_fauna_matches_the_biome(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    world = WorldGenerator.generate(0)

    game.spawn_fauna(world)

    assert.equal! args.state.fish.length, world.biome.fish_count
  end

  # Fish belong to their segment's own water column, however deep it is.
  def test_fauna_spawns_above_this_segments_sea_floor(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    world = WorldGenerator.generate(3)

    game.spawn_fauna(world)

    args.state.fish.each do |fish|
      y = fish.to_h[:y]
      assert.true! y > world.floor.min, "a fish should swim above the sand (#{y})"
      assert.true! y < WATERLINE_Y, "and below the waterline (#{y})"
    end
  end

  # The shark hunts the diver's depth instead of patrolling a fixed band, so a
  # trench is just as dangerous as the shallows.
  def test_the_shark_patrols_at_the_divers_depth(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.diver_global_x = 1500 # a shark biome
    args.state.depth_y = -99_999     # dive to the bottom, wherever that is here
    game.update_depth_and_camera
    args.state.dark_shark = { x: SCREEN_WIDTH + 1, y: 300 } # about to swing round for another pass

    game.update_shark(0)

    y = args.state.dark_shark.y
    assert.true! (y - args.state.depth_y).abs <= SHARK_PATROL_SPREAD + 30,
                 "the shark should come back in near the diver (#{y} vs #{args.state.depth_y})"
    assert.true! y >= game.sea_floor_y, "and never inside the sand (#{y})"
  end

  def test_static_hook_defaults_to_generation(args, assert)
    assert.equal! StaticWorlds.for(123), nil
    assert.true! WorldGenerator.generate(5).is_a?(World)
  end
end

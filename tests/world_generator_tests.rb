class WorldGeneratorTests
  def test_same_index_is_deterministic(args, assert)
    a = WorldGenerator.generate(4)
    b = WorldGenerator.generate(4)

    assert.equal! a.floor, b.floor
    assert.equal! a.decorations, b.decorations
    assert.equal! a.biome.name, b.biome.name
  end

  def test_floor_covers_every_column(args, assert)
    world = WorldGenerator.generate(1)

    assert.equal! world.floor.length, WorldGenerator.columns
    assert.true! world.floor.all? { |h| h >= WorldGenerator::FLOOR_BASE }
  end

  def test_decorations_rest_on_the_floor(args, assert)
    world = WorldGenerator.generate(2)

    assert.true! world.decorations.length > 0, "a world should have decorations"
    world.decorations.each do |d|
      col = d[:x] / World::COLUMN_WIDTH
      assert.equal! d[:y], world.floor[col], "#{d[:kind]} should sit on the floor"
    end
  end

  def test_different_indices_differ(args, assert)
    a = WorldGenerator.generate(1)
    b = WorldGenerator.generate(50)

    assert.true! a.floor != b.floor, "different indices should yield different floors"
  end

  def test_biome_is_stable_per_index(args, assert)
    assert.equal! WorldGenerator.generate(3).biome.name,
                  WorldGenerator.generate(3).biome.name
  end
end

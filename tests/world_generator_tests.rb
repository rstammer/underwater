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
    assert.true! world.floor.all? { |y| y <= WorldGenerator::FLOOR_CEILING },
                 "the sand never rises above the shallow ceiling"
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

  # The floor is a *world y* now (0 = the old sea-floor level, negative = deeper),
  # sampled from a global terrain function — so a segment lines up with its
  # neighbour instead of stepping at the seam.
  def test_floor_is_seamless_across_a_segment_boundary(args, assert)
    left = WorldGenerator.generate(0).floor.last
    right = WorldGenerator.generate(1).floor.first

    assert.true! (right - left).abs <= 60,
                 "segments must meet at the seam (#{left} -> #{right})"
  end

  # Some stretches are shallow banks, others drop away into real depth — that
  # variety is the whole point of diving.
  def test_some_stretches_are_far_deeper_than_others(args, assert)
    worlds = (-12..12).map { |i| WorldGenerator.generate(i) }
    lows = worlds.map { |w| w.deepest_y }
    highs = worlds.map { |w| w.floor.max }

    assert.true! lows.min < -1200, "somewhere the floor should drop into a real trench (#{lows.min})"
    assert.true! lows.max - lows.min > 800, "how deep you can get must vary a lot between stretches"
    assert.true! highs.max > -100, "and somewhere the sand rises into a shallow bank (#{highs.max})"
  end

  # Chunky, terraced sand instead of a smooth roof: heights snap to a pixel grid
  # and neighbouring columns actually step against each other.
  def test_floor_is_stepped_and_ragged(args, assert)
    floor = WorldGenerator.generate(7).floor

    assert.true! floor.all? { |y| y % WorldGenerator::FLOOR_STEP == 0 },
                 "every column snaps to the terrain step grid"

    steps = (1...floor.length).count { |i| floor[i] != floor[i - 1] }
    assert.true! steps > floor.length / 4,
                 "the sand edge should be ragged, not one smooth curve (#{steps} steps)"
  end

  # The terrain function is what the world (and the diver's footing) reads, so it
  # must answer for any world x, including left of the starting segment.
  def test_floor_y_at_works_anywhere_in_the_world(args, assert)
    a = WorldGenerator.floor_y_at(-9_000)
    b = WorldGenerator.floor_y_at(-9_000)

    assert.equal! a, b, "the terrain function is deterministic"
    assert.true! a <= WorldGenerator::FLOOR_CEILING
    assert.true! a >= WorldGenerator::FLOOR_BOTTOM
  end
end

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
    lows = worlds.map { |w| w.floor.min }
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

  # The sand is cut into terraces of *varying* width, so the bottom doesn't read
  # as one regular comb of equal-width steps.
  def test_floor_terraces_vary_in_width(args, assert)
    floor = WorldGenerator.generate(11).floor

    runs = []
    run = 1
    (1...floor.length).each do |i|
      if floor[i] == floor[i - 1]
        run += 1
      else
        runs << run
        run = 1
      end
    end
    runs << run
    widths = runs.map { |r| r * World::COLUMN_WIDTH }

    assert.true! widths.uniq.length >= 3, "terraces should come in different widths (#{widths.uniq.sort})"
    assert.true! widths.max >= 32, "some terraces should be broad (#{widths.max})"
    assert.true! widths.min <= 16, "and some narrow (#{widths.min})"
  end

  # The camera needs the broad shape of the ground, without the crags, dunes and
  # jitter that would shake the view. (Chasm and basin walls are steep by design,
  # so they're measured out of it here — they're smooth, just not gentle.)
  def test_ground_level_is_the_smooth_shape_of_the_floor(args, assert)
    steps = (0..1200).map do |i|
      x = i * 8 + 1
      WorldGenerator.ground_level_at(x) - WorldGenerator.chasm_at(x) - WorldGenerator.trough_at(x)
    end
    jumps = (1...steps.length).map { |i| (steps[i] - steps[i - 1]).abs }

    assert.true! jumps.max <= 8, "the broad shelf must not step (#{jumps.max} px)"
  end

  # The sea isn't uniformly shallow: whole stretches fall away into a long
  # descent, well past the suit's rating, so reaching the bottom there is a real
  # dive down and back — the deep you go looking for.
  def test_some_stretches_are_a_long_dive_to_the_bottom(args, assert)
    long_dives = 0
    samples = 0
    x = 0
    while x < 120_000
      metres = (WATERLINE_Y - WorldGenerator.floor_y_at(x)) / PIXELS_PER_METRE
      long_dives += 1 if metres > 120 # past the suit's rating, a long way down
      samples += 1
      x += 64
    end

    assert.true! long_dives > samples / 12,
                 "deep stretches have to be common enough to find (#{long_dives}/#{samples})"
  end

  # ...but plenty of the sea is still a shallow bank you can work comfortably,
  # so the deep reads as the exception it should be, not the whole map.
  def test_shallow_banks_are_still_common(args, assert)
    shallow = 0
    samples = 0
    x = 0
    while x < 120_000
      metres = (WATERLINE_Y - WorldGenerator.floor_y_at(x)) / PIXELS_PER_METRE
      shallow += 1 if metres < 60 # easy suit range, a short hop to the sand
      samples += 1
      x += 64
    end

    assert.true! shallow > samples / 5,
                 "there must still be plenty of shallow bank to play on (#{shallow}/#{samples})"
  end

  # And when the floor does give way, it gives way properly.
  def test_a_chasm_plunges_far_past_the_suits_limit(args, assert)
    deepest = (0..4000).map { |i| WorldGenerator.floor_y_at(i * 64) }.min
    metres = (WATERLINE_Y - deepest) / PIXELS_PER_METRE

    assert.true! metres > SUIT_DEPTH_LIMIT * 2,
                 "a chasm should be twice the suit's rating deep (#{metres} m)"
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

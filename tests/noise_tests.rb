class NoiseTests
  def test_value_is_deterministic(args, assert)
    a = Noise.value(1234, 512, 7)
    b = Noise.value(1234, 512, 7)

    assert.equal! a, b, "the same x/wavelength/seed must always give the same value"
  end

  def test_value_stays_in_the_unit_range(args, assert)
    (0..40).each do |i|
      v = Noise.value(i * 97, 256, 3)
      assert.true! v >= 0.0 && v <= 1.0, "noise out of range at #{i * 97}: #{v}"
    end
  end

  def test_value_is_continuous(args, assert)
    wavelength = 512
    x = 4096
    step = Noise.value(x + 1, wavelength, 5) - Noise.value(x, wavelength, 5)

    assert.true! step.abs < 0.02, "neighbouring samples must not jump (was #{step})"
  end

  # World segments are generated independently, so the terrain function must be
  # continuous across a segment boundary or the floor would show a seam.
  def test_value_is_continuous_across_a_segment_boundary(args, assert)
    left = Noise.value(SCREEN_WIDTH - 1, 1280, 11)
    right = Noise.value(SCREEN_WIDTH, 1280, 11)

    assert.true! (right - left).abs < 0.02, "seam at the segment boundary: #{left} -> #{right}"
  end

  def test_value_works_left_of_the_origin(args, assert)
    v = Noise.value(-5000, 640, 2)

    assert.true! v >= 0.0 && v <= 1.0, "negative world x must be sampled too (was #{v})"
  end

  def test_different_seeds_give_different_terrain(args, assert)
    a = (0..20).map { |i| Noise.value(i * 128, 512, 1) }
    b = (0..20).map { |i| Noise.value(i * 128, 512, 2) }

    assert.true! a != b, "different seeds must decorrelate"
  end

  # Jitter is the deliberately *un*-interpolated layer: it makes the sand edge
  # ragged instead of a smooth roof, so neighbouring cells must differ.
  def test_jitter_is_deterministic_and_varies_per_cell(args, assert)
    assert.equal! Noise.jitter(9, 4), Noise.jitter(9, 4)

    values = (0..20).map { |cell| Noise.jitter(cell, 4) }
    assert.true! values.uniq.length > 10, "jitter should vary from cell to cell"
    assert.true! values.all? { |v| v >= 0.0 && v <= 1.0 }, "jitter stays in the unit range"
  end
end

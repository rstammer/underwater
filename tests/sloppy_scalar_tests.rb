class SloppyScalarTests
  def test_path_uses_explicit_color(args, assert)
    scalar = SloppyScalar.new(args, 0, x: 0, y: 0, color: :blue)

    assert.equal! scalar.path, "sprites/animals/scalar_32_16/blue.png"
  end

  def test_to_h_structure_and_source_dimensions(args, assert)
    scalar = SloppyScalar.new(args, 0, x: 100, y: 200, color: :green)
    h = scalar.to_h

    assert.equal! h[:x], 100
    assert.equal! h[:y], 200
    assert.equal! h[:source_w], SloppyScalar::WIDTH
    assert.equal! h[:source_h], SloppyScalar::HEIGHT
    assert.equal! h[:path], "sprites/animals/scalar_32_16/green.png"
    # size is 1 or 2, so width/height are a whole multiple of the sprite size
    assert.true! [SloppyScalar::WIDTH, SloppyScalar::WIDTH * 2].include?(h[:w])
    assert.true! [SloppyScalar::HEIGHT, SloppyScalar::HEIGHT * 2].include?(h[:h])
  end

  # A fish given a stretch of open water turns around at its ends instead of
  # carrying on into whatever rock is there.
  def test_tick_turns_around_at_the_ends_of_its_water(args, assert)
    scalar = SloppyScalar.new(args, 0, x: 300, y: 0, color: :blue, from_x: 280, to_x: 340)

    400.times do
      scalar.tick(args, 0)
      x = scalar.to_h[:x]
      assert.true! x >= 280 && x <= 340, "the fish should stay in its water, was #{x}"
    end
  end

  def test_tick_turns_around_at_the_segment_edge(args, assert)
    # Start just shy of the right edge; any speed (>= 0.15) pushes it past
    # SCREEN_WIDTH, where it has to turn rather than carry on.
    scalar = SloppyScalar.new(args, 0, x: SCREEN_WIDTH - 0.05, y: 0, color: :orange)
    scalar.tick(args, 0)
    scalar.tick(args, 0)
    h = scalar.to_h

    assert.true! h[:x] <= SCREEN_WIDTH, "it stays in the segment, was #{h[:x]}"
    assert.true! h[:x] < SCREEN_WIDTH, "and is heading back, was #{h[:x]}"
    assert.true! h[:flip_horizontally], "swimming left, so the sprite faces left"
  end

  # Fish live at whatever depth they were spawned at — including far below the
  # old sea-floor level in a trench — and only drift around that home depth.
  def test_tick_keeps_the_fish_near_its_home_depth(args, assert)
    scalar = SloppyScalar.new(args, 0, x: 0, y: -1500, color: :blue)
    400.times { scalar.tick(args, 0) }
    y = scalar.to_h[:y]

    assert.true! (y - -1500).abs <= SloppyScalar::DRIFT,
                 "a deep fish should stay in its depth band, was #{y}"
  end
end

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

  def test_tick_wraps_x_at_screen_width(args, assert)
    # Start just shy of the right edge; any speed (>= 0.15) pushes it past
    # SCREEN_WIDTH and it must wrap back to a small positive x.
    scalar = SloppyScalar.new(args, 0, x: SCREEN_WIDTH - 0.05, y: 0, color: :orange)
    scalar.tick(args, 0)
    x = scalar.to_h[:x]

    assert.true! x >= 0,               "x should stay non-negative, was #{x}"
    assert.true! x < 1.0,              "x should have wrapped near 0, was #{x}"
  end
end

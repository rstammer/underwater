class SandTileTests
  # SandTile#to_h does not use the grid, so nil is fine here.
  def test_to_h_position_and_fixed_width(args, assert)
    h = SandTile.new(nil, 50, 3).to_h

    assert.equal! h[:x], 50
    assert.equal! h[:y], 3
    assert.equal! h[:w], 8
    assert.equal! h[:path], :solid
  end

  def test_height_stays_within_expected_jitter(args, assert)
    # h is 12 + rand(4) => 12..15. Sample a bunch to be confident.
    10.times do
      h = SandTile.new(nil, 0, 0).to_h[:h]
      assert.true! h >= 12 && h <= 15, "height out of range: #{h}"
    end
  end

  def test_colors_are_present_integers(args, assert)
    h = SandTile.new(nil, 0, 0).to_h

    assert.true! h[:r].is_a?(Integer)
    assert.true! h[:g].is_a?(Integer)
    assert.true! h[:b].is_a?(Integer)
  end
end

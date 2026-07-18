class WeedTests
  def test_to_h_is_deterministic(args, assert)
    weed = Weed.new(args, 5, x: 100, y: 20, size: 3)
    h = weed.to_h

    assert.equal! h[:x], 100
    assert.equal! h[:y], 20
    assert.equal! h[:w], Weed::WIDTH * 3
    assert.equal! h[:h], Weed::HEIGHT * 3
    assert.equal! h[:path], Weed::PATH
    assert.equal! h[:source_w], Weed::WIDTH
    assert.equal! h[:source_h], Weed::HEIGHT
  end

  def test_source_x_indexes_by_sprite_frame(args, assert)
    assert.equal! Weed.new(args, 0, x: 0, y: 0, size: 1).to_h[:source_x], 0
    assert.equal! Weed.new(args, 4, x: 0, y: 0, size: 1).to_h[:source_x], Weed::WIDTH * 4
  end
end

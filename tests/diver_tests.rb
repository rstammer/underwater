class DiverTests
  # to_h renders at the camera-projected on-screen x and reflects direction.
  def test_to_h_uses_the_screen_x_and_faces_right(args, assert)
    args.state.player_x = 640
    args.state.player_y = 200
    args.state.direction = :right
    args.state.angle = 0

    diver = Diver.new(args, 0)
    h = diver.to_h

    assert.equal! h[:x], 640 # already the on-screen x, no wrapping
    assert.equal! h[:y], 200
    assert.equal! h[:w], Diver::WIDTH * 2
    assert.equal! h[:h], Diver::HEIGHT * 2
    assert.equal! h[:flip_horizontally], false
    assert.equal! h[:source_x], 0
    assert.equal! h[:path], Diver::PATH
  end

  def test_to_h_flips_and_indexes_sprite_when_left(args, assert)
    args.state.player_x = 0
    args.state.player_y = 0
    args.state.direction = :left
    args.state.angle = 0

    diver = Diver.new(args, 3)
    h = diver.to_h

    assert.equal! h[:flip_horizontally], true
    assert.equal! h[:source_x], Diver::WIDTH * 3
  end

  def test_global_position_x_reads_state(args, assert)
    args.state.diver_global_x = 4242
    diver = Diver.new(args, 0)

    assert.equal! diver.global_position_x, 4242
  end
end

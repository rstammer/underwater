# Getting onto an island with a thumb.
#
# Walking ashore is a whole half of the game — beaches, crabs to photograph, a
# way over an island — and on a phone it was unreachable. The hop is on the
# space bar, the diving controls are a joystick, a shutter and a pause, and a
# phone has no space bar: you could wade to the first terrace and no further.
class JumpTests
  def build_game(args)
    game = Game.new
    game.args = args
    game
  end

  def ashore(args)
    game = build_game(args)
    game.initialize_game(0)
    args.state.game_scene = "area1"
    args.state.on_land = true
    args.state.airborne = false
    args.state.touch_seen = true
    game
  end

  def in_the_water(args)
    game = ashore(args)
    args.state.on_land = false
    game
  end

  def jump_button(game)
    game.control_layout.find { |button| button[:id] == :jump }
  end

  def test_there_is_a_jump_button_once_he_is_ashore(args, assert)
    game = ashore(args)

    assert.false! jump_button(game).nil?, "something to press to get up the rock"
  end

  # Underwater the same key is the sprint, which is held rather than tapped and
  # is already the joystick's job — a button for it would be a lie.
  def test_there_is_none_while_he_is_swimming(args, assert)
    game = in_the_water(args)

    assert.equal! jump_button(game), nil, "nothing to hop off down here"
  end

  def test_the_shutter_survives_going_ashore(args, assert)
    game = ashore(args)

    ids = game.control_layout.map { |button| button[:id] }
    assert.true! ids.include?(:photo), "beach crabs are photographed from up here"
    assert.true! ids.include?(:pause)
  end

  # A button you can see is a button you can press: the layout the renderer
  # draws is the layout the hit-test reads, so they cannot drift apart.
  def test_the_button_is_where_the_hit_test_looks(args, assert)
    game = ashore(args)
    button = jump_button(game)

    point = { id: 1, x: button[:x] + button[:w] / 2, y: button[:y] + button[:h] / 2 }

    assert.equal! game.button_at(point), :jump
  end

  def test_it_does_not_sit_on_top_of_the_shutter(args, assert)
    game = ashore(args)
    jump = jump_button(game)
    photo = game.control_layout.find { |button| button[:id] == :photo }

    apart = jump[:x] + jump[:w] <= photo[:x] || photo[:x] + photo[:w] <= jump[:x]
    assert.true! apart, "two buttons, two places (#{jump[:x]}..#{jump[:x] + jump[:w]} against #{photo[:x]}..#{photo[:x] + photo[:w]})"
  end

  # A word is not a letter: "F" fits any button, "SPRUNG" has to be measured
  # against the one it is written on.
  def test_the_label_fits_the_button(args, assert)
    game = ashore(args)
    button = jump_button(game)

    width = args.gtk.calcstringbox(button[:label], button[:size] || 6)[0]

    assert.true! width < button[:w] - 16,
                 "#{button[:label]} is #{width.round} px wide on a #{button[:w]} px button"
  end

  # --- and it actually hops ---------------------------------------------------

  def test_tapping_it_counts_as_wanting_to_jump(args, assert)
    game = ashore(args)
    args.state.touch_tapped = [:jump]

    assert.true! game.wants_jump?, "the thumb says up"
  end

  def test_tapping_it_lifts_him_off_the_rock(args, assert)
    game = ashore(args)
    args.state.depth_y = 400
    args.state.touch_tapped = [:jump]

    game.update_jump

    assert.true! args.state.depth_y > 400, "he left the ground (#{args.state.depth_y})"
    assert.true! args.state.airborne
  end

  # Same rule as the key: one hop per push, no climbing the sky by holding on.
  def test_a_thumb_still_on_the_button_does_not_hop_again(args, assert)
    game = ashore(args)
    args.state.touch_pressed = [:jump]
    args.state.touch_tapped = [] # held, not freshly landed

    assert.false! game.wants_jump?
  end
end

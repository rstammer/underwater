# The on-screen touch controls: the joystick vector, button hit-testing, the
# rising edge of a tap, and that touch and keyboard OR together.
class ControlsTests
  def build_game(args)
    game = Game.new
    game.args = args
    game
  end

  # Diving, so the touch controls are live.
  def diving(args)
    game = build_game(args)
    game.initialize_game(0)
    args.state.game_scene = "area1"
    args.state.depth_y = -400
    game
  end

  # Put a set of touches on the screen: [{id:, x:, y:}, ...].
  def touch(args, touches)
    args.inputs.touch.clear
    touches.each { |t| args.inputs.touch[t[:id]] = { x: t[:x], y: t[:y] } }
  end

  # --- the pure pieces ------------------------------------------------------

  def test_stick_vector_reads_as_directions(args, assert)
    game = build_game(args)
    d = Game::STICK_DEADZONE

    assert.equal! game.stick_vector_intents(0, 0), {}, "at rest, nothing"
    assert.true! game.stick_vector_intents(d + 5, 0)[:right], "pushed right"
    assert.true! game.stick_vector_intents(-(d + 5), 0)[:left], "pushed left"
    assert.true! game.stick_vector_intents(0, d + 5)[:up], "pushed up is dy positive"
    assert.true! game.stick_vector_intents(0, -(d + 5))[:down], "pushed down is dy negative"

    diag = game.stick_vector_intents(d + 5, d + 5)
    assert.true! diag[:up] && diag[:right], "a diagonal raises both, for angling"
  end

  def test_a_full_push_means_sprint(args, assert)
    game = build_game(args)

    near = game.stick_vector_intents(Game::STICK_DEADZONE + 4, 0)
    assert.false! !!near[:sprint], "a gentle push is not a sprint"

    far = game.stick_vector_intents(Game::STICK_SPRINT + 10, 0)
    assert.true! far[:sprint], "pushed to the rim, he sprints"
    assert.true! far[:right], "and still steers"
  end

  def test_button_hit_testing(args, assert)
    game = diving(args)
    button = game.control_layout.first

    inside = { x: button[:x] + button[:w] / 2, y: button[:y] + button[:h] / 2 }
    assert.equal! game.button_at(inside), :photo, "a touch on the F button is the shutter"

    outside = { x: button[:x] - 40, y: button[:y] }
    assert.equal! game.button_at(outside), nil, "a touch beside it is nothing"
  end

  # --- through update_controls ----------------------------------------------

  def test_the_joystick_steers_the_diver(args, assert)
    game = diving(args)

    # Touch down in the left zone: claims the stick, anchors here, no push yet.
    touch(args, [{ id: 1, x: 200, y: 360 }])
    game.update_controls
    assert.false! game.will_right?, "resting on the anchor, no direction"

    # Drag the same finger to the right, past the sprint threshold.
    touch(args, [{ id: 1, x: 200 + Game::STICK_SPRINT + 20, y: 360 }])
    game.update_controls
    assert.true! game.will_right?, "dragged right, he swims right"
    assert.true! game.will_sprint?, "and far enough out, he sprints"
    assert.true! game.moving?, "so he is moving"
  end

  def test_a_button_tap_fires_once(args, assert)
    game = diving(args)
    button = game.control_layout.first
    on = { id: 7, x: button[:x] + 10, y: button[:y] + 10 }

    touch(args, [on])
    game.update_controls
    assert.true! game.tapped?(:photo), "the press fires the shutter"

    game.update_controls # finger still down
    assert.false! game.tapped?(:photo), "holding it does not fire again"

    touch(args, []) # lift
    game.update_controls
    touch(args, [on]) # press again
    game.update_controls
    assert.true! game.tapped?(:photo), "a fresh press fires again"
  end

  def test_touch_and_keyboard_or_together(args, assert)
    game = diving(args)
    touch(args, [])
    game.update_controls

    assert.false! game.will_left?, "no touch, no keyboard, nothing"

    args.inputs.keyboard.key_down.left = true
    assert.true! game.will_left?, "the keyboard still works alongside touch"
  end

  def test_controls_stay_asleep_until_the_first_touch(args, assert)
    game = diving(args)
    touch(args, [])
    game.update_controls
    assert.false! args.state.touch_seen, "no buttons for a keyboard player"

    touch(args, [{ id: 1, x: 200, y: 360 }])
    game.update_controls
    assert.true! args.state.touch_seen, "once a finger lands, the controls wake up"
  end

  # A thumb on the left of a frozen menu must not drive the diver behind it.
  def test_no_steering_while_paused(args, assert)
    game = diving(args)
    args.state.game_scene = "home_menu"
    touch(args, [{ id: 1, x: 200, y: 360 }])
    game.update_controls
    touch(args, [{ id: 1, x: 360, y: 360 }])
    game.update_controls

    assert.false! game.will_right?, "the joystick is off in a menu"
  end

  def test_a_tapped_photo_takes_the_picture(args, assert)
    game = diving(args)
    args.state.diver_global_x = 600
    args.state.direction = :right
    game.current_world
    args.state.fish = [Creature.new(args, 0, species: Species["burgunder"], x: 640, y: -400)]
    args.state.touch_tapped = [:photo] # as if the F button was just pressed

    game.update_camera

    assert.equal! args.state.film_roll.length, 1, "the shutter fired from the button"
  end

  # --- getting past the paused screens on a phone ---------------------------

  def test_a_tap_gets_past_the_title(args, assert)
    game = build_game(args)
    game.initialize_game(0) # scene: title
    # With no book on disk the title takes a tap anywhere; with one it offers a
    # choice and puts buttons up instead. Said out loud because initialize_game
    # really does read the file, and another test in the run may have left one.
    args.state.saved_book = SaveFile.blank
    touch(args, [{ id: 1, x: 640, y: 360 }])

    game.tick

    assert.equal! args.state.game_scene, "name", "a tap on the title moves on to the name"
  end

  def test_the_start_button_dives_in_under_the_default_name(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.game_scene = "name" # no name typed — a phone has no keyboard
    button = game.control_layout.find { |b| b[:id] == :start }
    touch(args, [{ id: 1, x: button[:x] + 10, y: button[:y] + 10 }])

    game.tick

    assert.equal! args.state.game_scene, "area1", "tapping start dives in"
    assert.equal! game.diver_name, Game::DIVER_NAME, "under the default name"
    assert.true! game.breathing?, "floating at the surface, ready"
  end

  def test_a_typed_name_still_wins_over_the_default(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.game_scene = "name"
    game.type_name(["P", "i", "a"])
    game.touch_start_name

    assert.equal! args.state.game_scene, "area1"
    assert.equal! game.diver_name, "Pia", "the name he typed, not the default"
  end

  def test_a_tap_retries_after_game_over(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.game_scene = "game_over"
    args.state.death_cause = :drowned
    touch(args, [{ id: 1, x: 640, y: 360 }])

    game.tick

    assert.equal! args.state.game_scene, "area1", "a tap tries again"
  end

  # A held finger from one screen must not carry through and skip the next.
  def test_a_held_finger_does_not_double_advance(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.saved_book = SaveFile.blank # no book, so the title is a doorway
    touch(args, [{ id: 1, x: 640, y: 360 }])
    game.tick # title -> name
    assert.equal! args.state.game_scene, "name"

    game.tick # same finger still down, no new touch
    assert.equal! args.state.game_scene, "name", "holding it doesn't tap through the name screen"
  end

  def test_the_controls_render_without_error(args, assert)
    game = diving(args)
    touch(args, [{ id: 1, x: 220, y: 380 }])
    game.update_controls

    game.render_touch_controls

    assert.true! args.outputs.sprites.length > 0, "the joystick and button draw"
  end
end

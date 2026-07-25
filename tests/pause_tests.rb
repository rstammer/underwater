# The pause menu: ESC freezes the dive with a choice instead of throwing the
# round away, and you can carry on or end the dive.
class PauseTests
  # Fog squares are a 40x40 grid of solids; nothing else in the scene is.
  def fog_squares(args)
    args.outputs.sprites.flatten.count { |s| s[:w] == 40 && s[:h] == 40 && s[:path] == :solid }
  end

  # Pausing showed the whole map. The dark is part of the world, but it was being
  # drawn as part of the *diver* — and the pause screen draws the world without
  # him, so the fog simply lifted. Free x-ray, one key press.
  def test_pausing_does_not_lift_the_fog(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.game_scene = "area1"
    args.state.diver_global_x = 4000
    args.state.depth_y = -600 # well under, where the dark closes in
    game.center_camera

    game.area1_tick
    game.render_diver
    diving = fog_squares(args)
    assert.true! diving > 0, "there is fog down here to begin with (#{diving})"

    args.outputs.sprites.clear
    args.state.game_scene = "pause"
    args.state.paused_at = Kernel.tick_count # so the menu doesn't read its own key
    game.pause_tick

    assert.true! fog_squares(args) >= diving,
                 "and it is still there behind the menu (#{fog_squares(args)} of #{diving})"
  end

  def build_game(args)
    game = Game.new
    game.args = args
    game
  end

  def diving(args)
    game = build_game(args)
    game.initialize_game(0)
    args.state.game_scene = "area1"
    args.state.diver_global_x = 600
    args.state.depth_y = -400
    game
  end

  def test_esc_opens_the_pause_menu_and_freezes_the_dive(args, assert)
    game = diving(args)

    args.inputs.keyboard.key_down.escape = true
    game.tick

    assert.equal! args.state.game_scene, "pause"
    assert.true! game.game_paused?, "oxygen, the suit and the world all hold"
  end

  def test_esc_in_the_pause_menu_carries_on(args, assert)
    game = diving(args)
    args.state.game_scene = "pause" # already in the menu, from an earlier tick

    args.inputs.keyboard.key_down.escape = true
    game.tick

    assert.equal! args.state.game_scene, "area1", "ESC resumes the dive where it was"
  end

  def test_space_carries_on(args, assert)
    game = diving(args)
    args.state.game_scene = "pause" # already in the menu, from an earlier tick

    args.inputs.keyboard.key_down.space = true
    game.tick

    assert.equal! args.state.game_scene, "area1", "Space carries on too"
  end

  def test_q_ends_the_dive_to_the_title(args, assert)
    game = diving(args)
    args.state.game_scene = "pause" # already in the menu, from an earlier tick

    args.inputs.keyboard.key_down.q = true
    game.tick

    assert.equal! args.state.game_scene, "title", "Q ends the dive back at the title"
  end

  # The dive resumes in whichever sector you paused in.
  def test_resuming_returns_to_the_right_sector(args, assert)
    game = diving(args)
    args.state.diver_global_x = 3 * SCREEN_WIDTH + 100 # a far sector -> area2
    game.open_pause

    game.resume_scene

    assert.equal! args.state.game_scene, "area2"
  end

  def test_the_pause_menu_renders(args, assert)
    game = diving(args)
    game.open_pause

    game.pause_tick

    text = args.outputs.labels.map { |label| label[:text] }.join(" ")
    assert.true! text.include?("PAUSE"), "it names itself"
    assert.true! text.include?("weiterspielen") || text.include?("Weiterspielen"), "and how to carry on"
  end

  # --- touch ----------------------------------------------------------------

  def touch(args, touches)
    args.inputs.touch.clear
    touches.each { |t| args.inputs.touch[t[:id]] = { x: t[:x], y: t[:y] } }
  end

  def test_the_pause_button_opens_the_menu_on_a_phone(args, assert)
    game = diving(args)
    button = game.control_layout.find { |b| b[:id] == :pause }
    touch(args, [{ id: 1, x: button[:x] + 10, y: button[:y] + 10 }])

    game.tick

    assert.equal! args.state.game_scene, "pause", "the pause button pauses"
  end

  def test_a_tap_anywhere_carries_on(args, assert)
    game = diving(args)
    args.state.game_scene = "pause" # already in the menu, from an earlier tick
    touch(args, [{ id: 1, x: 200, y: 500 }]) # not on the Beenden button

    game.tick

    assert.equal! args.state.game_scene, "area1", "a tap in the clear carries on"
  end

  def test_the_beenden_button_ends_the_dive(args, assert)
    game = diving(args)
    args.state.game_scene = "pause" # already in the menu, from an earlier tick
    args.state.touch_seen = true
    button = game.control_layout.find { |b| b[:id] == :quit }
    touch(args, [{ id: 9, x: button[:x] + 10, y: button[:y] + 10 }])

    game.tick

    assert.equal! args.state.game_scene, "title", "tapping Beenden ends the dive"
  end
end

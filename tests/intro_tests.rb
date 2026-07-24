# The way into a round: the title asks for your name, and the boat tells you the
# rest while you float alongside it.
class IntroTests
  def build_game(args)
    game = Game.new
    game.args = args
    game
  end

  # A round started from the title goes past the name screen first.
  def test_the_title_asks_for_a_name(args, assert)
    game = build_game(args)
    game.initialize_game(0)

    args.inputs.keyboard.key_down.space = true
    game.tick

    assert.equal! args.state.game_scene, "name"
    assert.true! game.game_paused?, "nothing drains while you type"
  end

  def test_typing_fills_the_field(args, assert)
    game = build_game(args)
    game.initialize_game(0)

    game.type_name(["R", "o", "b", "i", "n"])

    assert.equal! args.state.player_name, "Robin"
    assert.equal! game.diver_name, "Robin", "and that's who goes down there"
  end

  # The one that matters: drive it the way the *engine* does, one character per
  # tick through inputs.keyboard.key_down.char, and start the round with Enter.
  # The first version read args.inputs.text instead, which only fills while
  # DR.start_text_input is on — a Pro tier feature that quietly does nothing on
  # this build. Nothing could be typed, so the game could not be started at all,
  # and every test passed because they all called type_name directly.
  def test_a_whole_round_can_be_started_from_the_keyboard(args, assert)
    game = build_game(args)
    game.initialize_game(0)

    args.inputs.keyboard.key_down.space = true # "Leertaste drücken zum Starten"
    game.tick
    assert.equal! args.state.game_scene, "name"

    "Pia".each_char do |char|
      args.inputs.keyboard.key_down.space = false
      args.inputs.keyboard.key_down.char = char
      game.tick
    end
    assert.equal! args.state.player_name, "Pia", "the keys land in the field"

    args.inputs.keyboard.key_down.char = nil
    args.inputs.keyboard.key_down.enter = true
    game.tick

    assert.equal! args.state.game_scene, "area1", "and Enter puts him in the water"
    assert.equal! game.diver_name, "Pia", "under his own name"
  end

  # Backspace has to reach the field the same way.
  def test_backspace_reaches_the_field_through_the_keyboard(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.game_scene = "name"
    game.type_name(["A", "b"])

    args.inputs.keyboard.key_down.backspace = true
    game.tick

    assert.equal! args.state.player_name, "A"
  end

  def test_backspace_takes_a_letter_back(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    game.type_name(["A", "b"])

    game.backspace_name
    assert.equal! args.state.player_name, "A"

    game.backspace_name
    game.backspace_name # one too many
    assert.equal! args.state.player_name, "", "an empty field stays empty"
  end

  def test_the_field_has_a_limit_and_ignores_control_characters(args, assert)
    game = build_game(args)
    game.initialize_game(0)

    game.type_name(["x"] * (Game::NAME_MAX + 8))
    assert.equal! args.state.player_name.length, Game::NAME_MAX, "the field fills up and stops"

    game.backspace_name
    game.type_name(["\t"])
    assert.equal! args.state.player_name.length, Game::NAME_MAX - 1, "a tab is not a letter"
  end

  def test_a_name_may_contain_spaces(args, assert)
    game = build_game(args)
    game.initialize_game(0)

    game.type_name(["A", "n", "n", " ", "K", "a"])

    assert.equal! args.state.player_name, "Ann Ka", "space types, it doesn't confirm"
  end

  def test_enter_needs_an_actual_name(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.game_scene = "name"

    game.confirm_name
    assert.equal! args.state.game_scene, "name", "a blank field goes nowhere"

    game.type_name(["   "]) # nothing but blanks is still blank
    game.confirm_name
    assert.equal! args.state.game_scene, "name", "and neither does whitespace"

    game.type_name(["P", "i", "a"])
    game.confirm_name
    assert.equal! args.state.game_scene, "area1", "a name gets you in the water"
    assert.true! game.breathing?, "floating beside the boat"
  end

  def test_esc_backs_out_of_the_name_screen(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.game_scene = "name"

    args.inputs.keyboard.key_down.escape = true
    game.tick

    assert.equal! args.state.game_scene, "title"
  end

  # The story is on the boat's own card, in the world — not a screen in between.
  def test_the_boat_tells_the_story_before_the_first_dive(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    game.type_name(["P", "i", "a"])
    game.confirm_name

    game.area1_tick
    text = args.outputs.labels.map { |label| label[:text] }.join(" ")

    assert.true! game.story_pending?, "it hasn't been told yet"
    assert.true! text.include?("Pia"), "the boat greets you by name"
    assert.true! text.include?("Schatzsucher"), "and says what you're out here for"
  end

  # Diving is the acknowledgement — after that the card is the boat's actions again.
  def test_the_story_retires_once_you_dive(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    game.type_name(["P", "i", "a"])
    game.confirm_name

    args.state.depth_y = -400 # under you go
    game.update_story
    assert.false! game.story_pending?, "told, once and for all"

    game.spawn_at_surface # and back up at the boat again
    game.update_story
    args.outputs.labels.clear
    game.area1_tick
    text = args.outputs.labels.map { |label| label[:text] }.join(" ")

    assert.false! text.include?("Neugier"), "the story doesn't come back"
    assert.true! text.include?("Logbuch"), "the card is the boat's actions now"
  end

  # A retry after drowning drops you straight back in — no name screen, no story.
  def test_a_retry_skips_the_way_in(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.game_scene = "game_over"

    args.inputs.keyboard.key_down.space = true
    game.tick

    assert.equal! args.state.game_scene, "area1", "back in the water"
    assert.false! game.story_pending?, "and the boat doesn't start over"
  end

  # The card doesn't wrap: it draws the lines as written. So measure them — this
  # is the test that complains when the prose gets rewritten a little too long.
  def test_the_story_fits_the_card(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    usable = Game::STORY_W - 32

    game.story_lines.each do |line|
      width = args.gtk.calcstringbox(line, 0)[0]
      assert.true! width <= usable, "\"#{line}\" runs #{width.to_i} px, the card holds #{usable}"
    end
    assert.true! args.gtk.calcstringbox(game.story_closing, 0)[0] <= usable, "so does the closing line"
    assert.true! args.gtk.calcstringbox("W" * Game::NAME_MAX, 2)[0] <= usable, "and the longest name"
  end

  def test_spawn_at_surface_floats_at_the_waterline(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.depth_y = 100 # somewhere deep

    game.spawn_at_surface

    assert.equal! args.state.depth_y, WATERLINE_Y - SURFACE_FLOAT_DEPTH
    assert.true! game.breathing?, "head should be out of the water, breathing"
  end

  def test_reset_starts_the_round_at_the_surface(args, assert)
    # Every round (start and restart) begins floating at the surface.
    game = build_game(args)
    game.initialize_game(0)

    game.reset_game

    assert.true! game.breathing?
  end

  # Alongside the boat a little card explains what home is for. It only shows up
  # there — everywhere else the screen stays clear of captions.
  def test_the_boat_greets_you_when_you_are_alongside(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    game.spawn_at_surface
    args.state.game_scene = "area1"

    game.area1_tick
    text = args.outputs.labels.map { |label| label[:text] }.join(" ")

    assert.true! text.include?("Boot"), "the card names the boat"
    assert.true! text.include?("Logbuch"), "and offers what home is for"
  end

  # The 'Anzug wird repariert' line is only on the card while there's damage to
  # mend — a whole suit says nothing.
  def test_the_repair_line_shows_only_while_the_suit_is_damaged(args, assert)
    game = build_game(args)
    game.initialize_game(0)

    args.state.suit = SUIT_MAX
    assert.false! game.repairing_suit?, "a whole suit needs no mending"

    args.state.suit = 40
    assert.true! game.repairing_suit?, "a damaged one does"
  end

  def test_no_card_once_you_have_left_the_boat(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    game.spawn_at_surface
    args.state.diver_global_x = SURFACE_BOAT_X + 600 # swum off along the surface
    game.update_depth_and_camera
    args.state.game_scene = "area1"

    game.area1_tick
    text = args.outputs.labels.map { |label| label[:text] }.join(" ")

    assert.false! text.include?("zu Hause"), "no caption once you're away from it"
  end
end

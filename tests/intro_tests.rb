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
    # This is the *first* round anyone plays: no book on disk, so the title is a
    # doorway rather than a choice. Said out loud because initialize_game really
    # does read the file, and another test in the run may have left one there.
    args.state.saved_book = SaveFile.blank

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
    assert.equal! args.state.game_scene, "intro", "Enter takes him to the opening"

    args.inputs.keyboard.key_down.enter = false
    args.inputs.keyboard.key_down.space = true
    game.tick

    assert.equal! args.state.game_scene, "area1", "and reading it puts him in the water"
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
    assert.equal! args.state.game_scene, "intro", "a name gets you to the opening"
    game.intro_tick # nothing pressed, so it just draws
    assert.equal! args.state.game_scene, "intro", "which waits for you"
  end

  def test_esc_backs_out_of_the_name_screen(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.game_scene = "name"

    args.inputs.keyboard.key_down.escape = true
    game.tick

    assert.equal! args.state.game_scene, "title"
  end

  # The opening is its own screen now. It lived on the boat's card for a while,
  # which was a nice idea until the story got longer than a card beside a boat
  # can hold and still be read.
  def test_the_opening_is_a_screen_of_its_own(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    game.type_name(["P", "i", "a"])
    game.confirm_name

    game.intro_tick
    text = args.outputs.labels.flatten.map { |label| label[:text] }.join(" ")

    assert.equal! args.state.game_scene, "intro"
    assert.true! game.game_paused?, "nothing drains while you read"
    assert.true! text.include?("Pia"), "it greets you by name"
    assert.true! text.include?("Fotograf"), "and says what you are out here for"
  end

  def test_a_key_gets_you_out_of_the_opening_and_into_the_water(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    game.type_name(["P", "i", "a"])
    game.confirm_name

    args.inputs.keyboard.key_down.space = true
    game.intro_tick

    assert.equal! args.state.game_scene, "area1", "in you go"
    assert.true! game.breathing?, "floating beside the boat"
    assert.true! args.state.dive_hint_pending, "and the camera's rules still to come"
  end

  # And the boat's card is the boat's actions, always — it never carries the
  # story any more, so it never has to be got rid of.
  def test_the_boat_card_is_the_boats_actions(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    game.type_name(["P", "i", "a"])
    game.confirm_name
    game.start_round

    game.area1_tick
    text = args.outputs.labels.flatten.map { |label| label[:text] }.join(" ")

    assert.false! text.include?("Neugier"), "no story on the card"
    assert.true! text.include?("Logbuch"), "just what the boat can do for you"
  end

  # A retry after drowning drops you straight back in — no name screen, no story.
  def test_a_retry_skips_the_way_in(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.game_scene = "game_over"

    args.inputs.keyboard.key_down.space = true
    game.tick

    assert.equal! args.state.game_scene, "area1", "back in the water"
    assert.false! args.state.dive_hint_pending, "and nothing is explained twice"
  end

  # The boat says what the camera is for before you ever go under.
  def test_the_boat_explains_the_camera(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    text = (game.story_lines + [game.story_closing]).join(" ")

    assert.true! text.include?("Kamera"), "it names the camera"
    assert.true! text.include?("Artenbuch"), "and what it fills"
    assert.true! text.include?("Entwickelt"), "that film has to be developed"
    assert.true! text.include?("Geld"), "and that this is what pays"
  end

  # The rules of the camera arrive when they start to mean something: with water
  # over your head, not on a screen you clicked past at the surface.
  def test_the_camera_rules_come_up_on_the_first_dive(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    game.type_name(["P", "i", "a"])
    game.confirm_name
    game.start_round # past the opening: floating at the surface beside the boat

    game.update_dive_hint
    assert.false! game.dive_hint_visible?, "not while his head is still out"

    args.state.depth_y = -400 # under he goes
    game.update_dive_hint
    assert.true! game.dive_hint_visible?, "now that the water has closed over him"

    text = game.dive_hint_lines.join(" ")
    assert.true! text.include?("[ F ]"), "it says which key"
    assert.true! text.include?("Sprinten"), "what spoils a shot"
    assert.true! text.include?("#{Game::FILM_MAX}"), "how much film there is"
    assert.true! text.include?("Boot"), "and where it gets developed"
  end

  # The thing that actually puts it away: swimming on down. You read it hanging
  # under the surface; a few metres deeper and it is gone.
  def test_the_camera_rules_go_once_he_swims_on_down(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.dive_hint_pending = true
    args.state.depth_y = WATERLINE_Y - 3 * PIXELS_PER_METRE # just under, 3 m down
    game.update_dive_hint
    assert.true! game.dive_hint_visible?, "it's there while he reads"

    args.state.depth_y -= (Game::DIVE_HINT_METRES - 2) * PIXELS_PER_METRE
    game.update_dive_hint # the tick asks every frame; so does this
    assert.true! game.dive_hint_visible?, "a metre or two doesn't count as leaving"

    args.state.depth_y -= 4 * PIXELS_PER_METRE
    game.update_dive_hint
    assert.false! game.dive_hint_visible?, "but swimming on down puts it away"
  end

  # Putting it away has to be one-way. Written as a live condition on how deep he
  # is *now*, the card came back the moment he rose again — and surfacing for air
  # brought it up beside the boat, the one place its rules mean nothing.
  def test_the_camera_rules_stay_gone_when_he_comes_back_up(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.dive_hint_pending = true
    args.state.depth_y = WATERLINE_Y - 3 * PIXELS_PER_METRE
    game.update_dive_hint
    assert.true! game.dive_hint_visible?, "it's there while he reads"

    args.state.depth_y -= (Game::DIVE_HINT_METRES + 4) * PIXELS_PER_METRE
    game.update_dive_hint
    assert.false! game.dive_hint_visible?, "swimming on down puts it away"

    args.state.depth_y = WATERLINE_Y - SURFACE_FLOAT_DEPTH # up for a breath
    game.update_dive_hint

    assert.false! game.dive_hint_visible?, "and coming back up does not bring it back"
  end

  # And a backstop for someone who hovers there rather than diving.
  def test_the_camera_rules_time_out_eventually(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.dive_hint_pending = true
    args.state.depth_y = WATERLINE_Y - 3 * PIXELS_PER_METRE
    game.update_dive_hint
    assert.true! game.dive_hint_visible?

    args.state.dive_hint_at = Kernel.tick_count - Game::DIVE_HINT_TICKS - 1
    game.update_dive_hint

    assert.false! game.dive_hint_visible?, "it doesn't hang there for ever"
  end

  def test_the_camera_rules_come_up_only_once(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    game.type_name(["P", "i", "a"])
    game.confirm_name
    args.state.depth_y = -400
    game.update_dive_hint
    game.dismiss_dive_hint # read, or a photo taken

    game.update_dive_hint

    assert.false! game.dive_hint_visible?, "it doesn't come back every time he dives"
  end

  def test_taking_a_photo_puts_the_card_away(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.game_scene = "area1"
    args.state.diver_global_x = 600
    args.state.depth_y = -400
    args.state.direction = :right
    args.state.dive_hint_pending = true
    game.update_dive_hint
    assert.true! game.dive_hint_visible?

    game.current_world
    args.state.fish = [Creature.new(args, 0, species: Species["burgunder"], x: 640, y: -400)]
    game.take_photo

    assert.false! game.dive_hint_visible?, "he has got it"
  end

  def test_the_dive_hint_renders(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.dive_hint_pending = true
    args.state.depth_y = -400
    game.update_dive_hint

    game.render_dive_hint

    assert.true! args.outputs.labels.length > game.dive_hint_lines.length, "every line draws"
  end

  # The card doesn't wrap: it draws the lines as written. So measure them — this
  # is the test that complains when the prose gets rewritten a little too long.
  # The intro screen does not wrap: a line that is too long simply runs off the
  # column, and one that sits too low prints over the prompt. Both are measured
  # rather than eyeballed — the prompt printing across the last paragraph is
  # exactly what happened the first time.
  def test_the_opening_fits_its_screen(args, assert)
    game = build_game(args)
    game.initialize_game(0)

    (game.story_lines + [game.story_closing]).each do |line|
      next if line.empty?

      width = args.gtk.calcstringbox(line, 2)[0]
      assert.true! width <= Game::INTRO_W,
                   "\"#{line}\" runs #{width.to_i} px, the column holds #{Game::INTRO_W}"
    end

    assert.true! game.intro_prompt_y > 40, "the prompt is still on the screen (#{game.intro_prompt_y})"
    assert.true! game.intro_body_bottom > game.intro_prompt_y,
                 "and the story stops above it, not across it"
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

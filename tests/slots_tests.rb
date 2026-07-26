# Five careers on a shelf, and the rule that none of them may be written over.
#
# This is the test file the lost save should have had. Everything here is about
# one thing: a book only ever changes when you point at it.
class SlotsTests
  def build_game(args)
    game = Game.new
    game.args = args
    game
  end

  def a_shelf(args)
    game = build_game(args)
    game.initialize_game(0)
    args.state.saved_book = nil
    args.state.slots = Array.new(Game::SAVE_SLOTS)
    args.state.slots[0] = SaveFile.decode("name Gero\nday 6\ncredits 400\nalbum burgunder gut\nsighted hummer")
    args.state.slots[2] = SaveFile.decode("name Kins\nday 2\nalbum hummer perfekt")
    game
  end

  def test_a_used_slot_says_who_and_how_far(args, assert)
    game = a_shelf(args)
    summary = game.slot_summary(1)

    assert.equal! summary[:name], "Gero"
    assert.equal! summary[:day], 6
    assert.equal! summary[:documented], 1
    assert.equal! summary[:sighted], 2, "documented counts as seen"
    assert.equal! summary[:credits], 400
  end

  def test_an_empty_slot_has_nothing_to_say(args, assert)
    game = a_shelf(args)

    assert.equal! game.slot_summary(2), nil
    assert.false! game.slot_used?(2)
    assert.true! game.slot_used?(3)
  end

  # The whole point of the exercise: a new career never lands on an old one.
  def test_a_new_career_goes_to_the_first_free_slot(args, assert)
    game = a_shelf(args)

    game.fresh_round

    assert.equal! args.state.book_slot, 2, "past Gero, into the empty one"
    assert.equal! game.slot_summary(1)[:name], "Gero", "and Gero is untouched"
  end

  def test_starting_in_a_slot_you_pointed_at_is_allowed(args, assert)
    game = a_shelf(args)

    game.fresh_round(5)

    assert.equal! args.state.book_slot, 5
  end

  def test_carrying_one_on_opens_that_slot(args, assert)
    game = a_shelf(args)

    game.continue_round(3)

    assert.equal! args.state.book_slot, 3
    assert.equal! args.state.player_name, "Kins"
  end

  # Nothing is written unless a book is open. Before, any first sighting wrote
  # the current state to the one file whatever was going on.
  def test_no_open_book_means_no_writing(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.book_slot = nil

    assert.equal! game.book_path(Object.new), nil
  end

  def test_deleting_only_touches_the_slot_you_named(args, assert)
    game = a_shelf(args)

    game.delete_slot(3)

    assert.equal! game.slot_summary(3), nil, "that one is gone"
    assert.equal! game.slot_summary(1)[:name], "Gero", "and the others are not"
  end

  def test_deleting_the_open_book_closes_it(args, assert)
    game = a_shelf(args)
    game.open_slot(1)

    game.delete_slot(1)

    assert.equal! args.state.book_slot, nil, "nothing is open, so nothing is written"
  end

  # --- the title shelf --------------------------------------------------------

  def test_the_cursor_wraps_round_the_shelf(args, assert)
    game = a_shelf(args)
    Game::SAVE_SLOTS.times { game.move_title_row(1) }

    assert.equal! game.title_slot, 1, "all the way round"
  end

  # Against the screen position, not the index: an index test passes just as
  # happily when the arrows are the wrong way round.
  def test_down_moves_down_the_screen(args, assert)
    game = a_shelf(args)
    args.state.game_scene = "title"
    was_at = game.title_layout[game.title_row][:y]

    args.inputs.keyboard.key_down.down = true
    game.read_title_input

    assert.true! game.title_layout[game.title_row][:y] < was_at,
                 "the cursor went down the screen, not up it"
  end

  def test_up_moves_up_the_screen(args, assert)
    game = a_shelf(args)
    args.state.game_scene = "title"
    game.move_title_row(1)
    was_at = game.title_layout[game.title_row][:y]

    args.inputs.keyboard.key_down.up = true
    game.read_title_input

    assert.true! game.title_layout[game.title_row][:y] > was_at,
                 "and up goes back up it"
  end

  def test_pressing_on_an_empty_row_starts_there(args, assert)
    game = a_shelf(args)
    args.state.game_scene = "title"
    game.move_title_row(1) # slot 2, empty

    args.inputs.keyboard.key_down.space = true
    game.title_tick

    assert.equal! args.state.game_scene, "name"
    assert.equal! args.state.book_slot, 2
    assert.equal! game.slot_summary(1)[:name], "Gero", "Gero was never in danger"
  end

  # Deleting is the one thing on this screen that destroys something, so it asks
  # first — and the question names the career it means.
  # A menu you pick a row in is a menu you confirm with Enter.
  def test_enter_opens_the_row_you_are_on(args, assert)
    game = a_shelf(args)
    args.state.game_scene = "title"
    game.move_title_row(2) # slot 3, Kins

    args.inputs.keyboard.key_down.enter = true
    game.title_tick

    assert.equal! args.state.book_slot, 3
    assert.equal! args.state.player_name, "Kins"
  end

  def test_enter_starts_a_career_in_an_empty_row(args, assert)
    game = a_shelf(args)
    args.state.game_scene = "title"
    game.move_title_row(1) # slot 2, empty

    args.inputs.keyboard.key_down.enter = true
    game.title_tick

    assert.equal! args.state.game_scene, "name"
    assert.equal! args.state.book_slot, 2
  end

  # The dangerous action answers only to the key that asked for it: Enter is the
  # universal yes everywhere else, and here it means "no".
  def test_enter_does_not_delete_a_career(args, assert)
    game = a_shelf(args)
    args.state.game_scene = "title"
    args.inputs.keyboard.key_down.delete = true
    game.read_title_input

    args.inputs.keyboard.key_down.delete = false
    args.inputs.keyboard.key_down.enter = true
    game.read_title_input

    assert.equal! game.slot_summary(1)[:name], "Gero", "still there"
    assert.false! game.confirming_delete?, "and the question is dropped"
  end

  def test_deleting_takes_two_presses(args, assert)
    game = a_shelf(args)
    args.state.game_scene = "title"

    args.inputs.keyboard.key_down.delete = true
    game.read_title_input
    assert.true! game.confirming_delete?, "it asks"
    assert.equal! game.slot_summary(1)[:name], "Gero", "and has not done it yet"

    game.read_title_input
    assert.equal! game.slot_summary(1), nil, "the second press does it"
  end

  def test_changing_your_mind_calls_it_off(args, assert)
    game = a_shelf(args)
    args.state.game_scene = "title"
    args.inputs.keyboard.key_down.delete = true
    game.read_title_input

    args.inputs.keyboard.key_down.delete = false
    args.inputs.keyboard.key_down.space = true
    game.read_title_input

    assert.false! game.confirming_delete?
    assert.equal! game.slot_summary(1)[:name], "Gero", "still there"
  end

  # Pointing somewhere else drops the question rather than carrying it along to
  # a different career.
  def test_moving_the_cursor_cancels_the_question(args, assert)
    game = a_shelf(args)
    args.state.game_scene = "title"
    args.inputs.keyboard.key_down.delete = true
    game.read_title_input

    game.move_title_row(1)

    assert.equal! args.state.title_confirm, nil
  end

  def test_an_empty_row_cannot_be_deleted(args, assert)
    game = a_shelf(args)
    game.move_title_row(1) # slot 2, empty

    game.ask_to_delete

    assert.equal! args.state.title_confirm, nil, "nothing to ask about"
  end

  def test_the_shelf_renders_without_error(args, assert)
    game = a_shelf(args)
    args.state.game_scene = "title"

    game.title_tick

    assert.true! args.outputs.sprites.flatten.length > 0
  end

  # Five rows have to fit between the waterline and the foot of the screen.
  def test_the_shelf_fits_on_the_screen(args, assert)
    game = a_shelf(args)

    assert.true! game.title_card_bottom > 60, "there is air under the panel"
    game.title_layout.each do |button|
      assert.true! button[:y] >= game.title_card_bottom, "#{button[:id]} is inside it"
      assert.true! button[:y] + button[:h] <= game.title_card_top
    end
  end
end

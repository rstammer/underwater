# The title. It is built on the game's own sea now, with one left-hand column of
# type and the choice as buttons, so most of what there is to check is that the
# layout hangs together and that what you can see is what you can press.
class TitleTests
  def build_game(args)
    game = Game.new
    game.args = args
    game
  end

  def with_a_book(args)
    game = build_game(args)
    game.initialize_game(0)
    args.state.game_scene = "title"
    args.state.saved_book = SaveFile.blank.merge(
      name: "Kins", album: { "burgunder" => :gut },
      sighted: { "burgunder" => true, "doktor" => true }, day: 4
    )
    game
  end

  def test_title_shows_the_game_name(args, assert)
    game = build_game(args)
    game.initialize_game(0)

    texts = game.title_labels.map { |l| l[:text] }

    assert.true! texts.include?("Underwater"), "title should show the game name"
  end

  def test_title_has_decorative_fish(args, assert)
    game = build_game(args)
    game.initialize_game(0)

    fish = game.title_fish

    assert.equal! fish.length, Game::TITLE_FISH.length
    assert.true! fish.all? { |f| f[:path].include?("animals") }, "fish reuse the animal sprites"
  end

  # They are the life in the water half. One up in the sky would be a fish in
  # the sky.
  def test_the_fish_swim_below_the_waterline(args, assert)
    assert.true! Game::TITLE_FISH.all? { |f| f[:y] < Game::HORIZON },
                 "every lane is under the horizon"
  end

  def test_it_renders_on_the_games_own_sea(args, assert)
    game = with_a_book(args)

    game.title_tick

    paths = args.outputs.sprites.flatten.map { |sprite| sprite[:path] }
    assert.true! paths.include?(Game::BOAT_SPRITE[:path]), "his own boat is out there"
  end

  # --- the choice ------------------------------------------------------------

  # One row per slot, always — the choice is which career you are opening, not
  # whether to keep the one book or throw it away.
  def test_the_shelf_has_a_row_for_every_slot(args, assert)
    game = with_a_book(args)

    ids = game.title_layout.map { |button| button[:id] }

    assert.equal! ids.length, Game::SAVE_SLOTS
    assert.equal! ids.first, :slot_1
  end

  # Said out loud rather than left to whatever the runner's book file happens to
  # hold: initialize_game loads one off disk, and a leftover from an earlier run
  # would quietly turn this into the two-button case.
  def test_an_untouched_shelf_is_all_empty_slots(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.saved_book = SaveFile.blank
    args.state.slots = Array.new(Game::SAVE_SLOTS)

    assert.true! game.title_rows.all? { |row| row[:summary].nil? }
    assert.false! game.saved_book?, "nothing on this machine yet"
  end

  # A row has to say whose career it is and how far along, or opening one is a
  # leap of faith.
  def test_a_row_names_the_diver_and_counts_the_book(args, assert)
    game = with_a_book(args)
    row = game.title_rows.first

    assert.equal! row[:title], "Kins", "whose book"
    assert.true! row[:detail].include?("1 von 2"), "how far along: #{row[:detail]}"
    assert.true! row[:detail].include?("Tag 4")
  end

  def test_an_empty_row_says_so(args, assert)
    game = with_a_book(args)
    row = game.title_rows.last

    assert.equal! row[:summary], nil
    assert.true! row[:title].length > 0, "it still says something"
  end

  # A button you can see is a button you can press: both come off title_layout,
  # and both have to sit inside the panel that frames them.
  def test_the_buttons_sit_inside_the_card(args, assert)
    game = with_a_book(args)

    game.title_layout.each do |button|
      assert.true! button[:y] >= game.title_card_bottom,
                   "#{button[:id]} sits above the card's bottom edge"
      assert.true! button[:y] + button[:h] <= game.title_card_top,
                   "#{button[:id]} sits under the card's top edge"
    end
  end

  # The old title stacked five lines of type down the middle and printed the
  # controls straight through the key prompts. Nothing may reach the footer.
  def test_the_card_clears_the_footer(args, assert)
    game = with_a_book(args)

    assert.true! game.title_card_bottom > 100, "there is air under the panel"
  end

  def test_the_panel_hangs_off_the_horizon(args, assert)
    game = with_a_book(args)

    assert.equal! game.title_card_top, Game::HORIZON, "its top edge is the waterline"
  end
end

# The Artenbuch outliving the session, and the choice the title then has to
# offer: carry that book on, or put it down and start over.
#
# Everything about the *format* is tested against the pure encoder, which never
# touches a file — a test that wrote to SaveFile::PATH would overwrite whatever
# the person running it had actually collected.
class SaveTests
  def build_game(args)
    game = Game.new
    game.args = args
    game
  end

  def a_book
    { name: "Kins Klausky",
      album: { "burgunder" => :perfekt, "hummer" => :unscharf },
      sighted: { "burgunder" => true, "hummer" => true, "laternentraeger" => true } }
  end

  def test_a_book_survives_the_round_trip(args, assert)
    book = a_book

    back = SaveFile.decode(SaveFile.encode(**book))

    assert.equal! back[:name], "Kins Klausky", "the diver keeps his name"
    assert.equal! back[:album]["burgunder"], :perfekt, "and the grades of his photos"
    assert.equal! back[:album]["hummer"], :unscharf
    assert.true! back[:sighted]["laternentraeger"], "and what he has only laid eyes on"
    assert.equal! back[:album].length, 2, "nothing extra crept into the book"
  end

  def test_nothing_saved_is_an_empty_book(args, assert)
    book = SaveFile.decode(nil)

    assert.true! SaveFile.empty?(book), "a first run has nothing to carry on"
    assert.equal! book[:album], {}
    assert.equal! book[:name], ""
  end

  # The file has to survive the roster changing under it. A species that has been
  # renamed or dropped must not be able to stop the game starting.
  def test_a_species_that_no_longer_exists_is_simply_skipped(args, assert)
    text = "name Alt\nalbum burgunder gut\nalbum seekuh perfekt\nsighted seepferd\n"

    book = SaveFile.decode(text)

    assert.equal! book[:album].length, 1, "the one that still exists is kept"
    assert.equal! book[:album]["burgunder"], :gut
    assert.false! book[:sighted].key?("seepferd"), "and the ones that don't are dropped"
  end

  def test_a_broken_line_cannot_stop_the_game(args, assert)
    book = SaveFile.decode("name\nalbum\nalbum burgunder\nalbum burgunder wolkig\n\nrubbish\n")

    assert.equal! book[:album], {}, "nothing usable, nothing taken"
    assert.true! SaveFile.empty?(book)
  end

  # Documented implies seen, so it is only written once.
  def test_documenting_a_species_does_not_write_it_twice(args, assert)
    text = SaveFile.encode(**a_book)

    assert.equal! text.split("\n").count { |l| l.start_with?("sighted") }, 1,
                  "only the one he has seen but not got:\n#{text}"
  end

  # Through the engine's own filesystem and back. Everything above works on
  # strings, which proves the format and nothing about whether the game can
  # actually keep a book — and "the file never arrives" is exactly the kind of
  # failure that leaves every other test in here green.
  #
  # Its own path, under the gitignored tmp/, so running the suite never costs
  # anybody the book they collected.
  SCRATCH = "tmp/test_artenbuch.txt"

  def test_the_book_really_reaches_the_disk_and_comes_back(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.player_name = "Kins Klausky"
    args.state.album = { "burgunder" => :perfekt }
    args.state.sighted = { "burgunder" => true, "hummer" => true }

    game.save_book(SCRATCH)
    raw = game.read_book_file(SCRATCH)

    assert.false! raw.nil?, "the file is there afterwards"
    back = SaveFile.decode(raw)
    assert.equal! back[:name], "Kins Klausky"
    assert.equal! back[:album]["burgunder"], :perfekt, "and holds what he had"
    assert.true! back[:sighted]["hummer"]
  end

  def test_a_book_that_was_never_saved_reads_as_nothing(args, assert)
    game = build_game(args)
    game.initialize_game(0)

    raw = game.read_book_file("tmp/no_such_book_#{Species::ALL.length}.txt")

    assert.true! raw.nil?, "a missing file is nothing, not a crash"
    assert.true! SaveFile.empty?(SaveFile.decode(raw))
  end

  # --- what the title does with it ------------------------------------------

  def with_saved_book(args, book)
    game = build_game(args)
    game.initialize_game(0)
    args.state.saved_book = book
    args.state.game_scene = "title"
    game
  end

  def test_without_a_saved_book_the_title_is_a_doorway(args, assert)
    game = with_saved_book(args, SaveFile.blank)

    assert.false! game.saved_book?, "there is nothing to carry on"
    args.inputs.keyboard.key_down.space = true
    game.title_tick

    assert.equal! args.state.game_scene, "name", "so it goes straight to the name"
  end

  def test_carrying_the_book_on_skips_the_introductions(args, assert)
    game = with_saved_book(args, a_book)
    assert.true! game.saved_book?, "there is a book to carry on"

    args.inputs.keyboard.key_down.space = true
    game.title_tick

    assert.equal! args.state.game_scene, "area1", "straight into the water"
    assert.equal! args.state.player_name, "Kins Klausky", "as the diver it belongs to"
    assert.equal! args.state.album["burgunder"], :perfekt, "with his book"
    assert.true! args.state.story_told, "and no opening story — he has been here"
    assert.false! args.state.dive_hint_pending, "nor the camera's rules"
  end

  def test_starting_over_asks_for_a_name_and_empties_the_book(args, assert)
    game = with_saved_book(args, a_book)

    args.inputs.keyboard.key_down.n = true
    game.title_tick

    assert.equal! args.state.game_scene, "name", "it asks who is going down there"
    assert.equal! args.state.album, {}, "with an empty book"
    assert.equal! args.state.sighted, {}
    assert.equal! args.state.player_name, ""
  end

  # Change your mind on the name screen and last session's book is still there:
  # the file isn't touched until somebody actually takes it over.
  def test_backing_out_of_starting_over_leaves_the_saved_book_alone(args, assert)
    game = with_saved_book(args, a_book)
    args.inputs.keyboard.key_down.n = true
    game.title_tick

    game.abandon_name

    assert.equal! args.state.game_scene, "title"
    assert.true! game.saved_book?, "the old book is still on offer"
    assert.equal! args.state.saved_book[:name], "Kins Klausky"
  end

  # The title has to say whose book it is and how far along it is, or "carry on"
  # is a leap of faith.
  def test_the_title_says_what_it_is_offering(args, assert)
    game = with_saved_book(args, a_book)

    game.title_tick
    text = args.outputs.labels.flatten.map { |label| label[:text] }.join("  ")

    assert.true! text.include?("Kins Klausky"), "whose book it is"
    assert.true! text.include?("2 von 3"), "and how far along: #{game.saved_book_summary}"
  end

  # On a phone there is no space bar, so the choice has to be two buttons.
  def test_the_choice_is_tappable(args, assert)
    game = with_saved_book(args, a_book)
    args.state.touch_seen = true

    ids = game.control_layout.map { |b| b[:id] }
    assert.true! ids.include?(:carry_on), "a button to carry on"
    assert.true! ids.include?(:start_over), "and one to start over"

    args.state.touch_tapped = [:start_over]
    game.title_tick
    assert.equal! args.state.game_scene, "name", "and tapping it starts over"
  end

  def test_with_no_book_the_title_has_no_buttons_in_the_way(args, assert)
    game = with_saved_book(args, SaveFile.blank)
    args.state.touch_seen = true

    assert.equal! game.control_layout.length, 0, "a tap anywhere goes, so nothing to press"
  end
end

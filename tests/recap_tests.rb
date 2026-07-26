# Coming back to a career already under way.
#
# Carrying a book on used to drop you straight in the water, mid-afternoon of a
# day you had no memory of, with a balance you had to open the boat screen to
# find. Now the game says where you left off first, and you say when to go on.
class RecapTests
  def build_game(args)
    game = Game.new
    game.args = args
    game
  end

  def at_the_title_with_a_book(args, book = {})
    game = build_game(args)
    game.initialize_game(0)
    args.state.game_scene = "title"
    args.state.saved_book = SaveFile.blank.merge(
      { name: "Kins", album: { "burgunder" => :gut }, sighted: { "burgunder" => true, "doktor" => true },
        credits: 134, day: 4, energy: 60, best: 148, dives: 5, stash: ["can", "jewel"] }.merge(book)
    )
    game
  end

  def carrying_on(args, book = {})
    game = at_the_title_with_a_book(args, book)
    args.inputs.keyboard.key_down.space = true
    game.title_tick
    # Let go of it. A key_down stays true for the rest of the tick, and the recap
    # reads the same key to move on — holding it would mean the screen never
    # actually gets drawn.
    args.inputs.keyboard.key_down.space = false
    game
  end

  def test_carrying_a_book_on_stops_to_say_where_you_are(args, assert)
    game = carrying_on(args)

    assert.equal! args.state.game_scene, "recap", "not straight into the water"
  end

  def test_it_has_already_loaded_the_career_behind_it(args, assert)
    game = carrying_on(args)

    assert.equal! args.state.credits, 134, "the numbers are real, not a preview"
    assert.equal! args.state.day, 4
    assert.equal! args.state.player_name, "Kins"
  end

  def test_it_says_who_where_and_how_much(args, assert)
    game = carrying_on(args)

    game.recap_tick
    text = args.outputs.labels.flatten.map { |label| label[:text] }.join("  ")

    assert.true! text.include?("Kins"), "whose career: #{text}"
    assert.true! text.include?("Tag 4"), "which day he is in the middle of"
    assert.true! text.include?("134 Cr"), "and what he is worth"
    assert.true! text.include?("148 m"), "how deep he has been"
  end

  def test_the_book_is_counted_against_what_he_has_seen(args, assert)
    game = carrying_on(args)

    rows = game.recap_rows.map { |label, value| "#{label} #{value}" }.join("  ")

    assert.true! rows.include?("1 / 2"), "one of the two he has laid eyes on: #{rows}"
  end

  # Pressing on is what starts the dive — nothing before that counts as one.
  def test_saying_okay_puts_him_in_the_water(args, assert)
    game = carrying_on(args)
    dives = args.state.log_dives

    args.inputs.keyboard.key_down.space = true
    game.recap_tick

    assert.equal! args.state.game_scene, "area1", "in the water beside the boat"
    assert.equal! args.state.log_dives, dives + 1, "and that is the dive counted"
  end

  # He has been here before: no opening story, no card of camera rules.
  def test_he_is_not_told_the_story_again(args, assert)
    game = carrying_on(args)

    args.inputs.keyboard.key_down.space = true
    game.recap_tick

    assert.false! args.state.dive_hint_pending, "he knows how the camera works"
  end

  def test_a_new_diver_never_sees_it(args, assert)
    game = at_the_title_with_a_book(args)

    game.move_title_row(1) # onto an empty slot
    args.inputs.keyboard.key_down.space = true
    game.title_tick

    assert.equal! args.state.game_scene, "name", "a fresh career starts at the name"
  end

  def test_it_is_a_frozen_screen_like_the_others(args, assert)
    game = carrying_on(args)

    assert.true! game.game_paused?, "nothing drains while he reads"
  end

  def test_it_renders_without_error(args, assert)
    game = carrying_on(args)

    game.recap_tick

    assert.true! args.outputs.sprites.flatten.length > 0, "there is a sea behind it"
  end

  # The layout hangs off the tally, so a row more can never print the prompt
  # over the last line.
  def test_the_prompt_clears_the_tally(args, assert)
    game = carrying_on(args)
    last_row = game.recap_rows_top - Game::RECAP_ROW_H * (game.recap_rows.length - 1)

    assert.true! game.recap_prompt_y < last_row - 20,
                 "the prompt sits below the last row (#{game.recap_prompt_y} against #{last_row})"
  end
end

# The evening. Sleeping used to be a keypress that silently put the numbers
# back up; now the day is read out before it is closed, and the reading is the
# thing that closes it.
class NightTests
  def build_game(args)
    game = Game.new
    game.args = args
    game
  end

  def at_the_boat(args)
    game = build_game(args)
    game.initialize_game(0)
    game.spawn_at_surface
    args.state.game_scene = "area1"
    game
  end

  def evening(args)
    game = at_the_boat(args)
    game.sleep_at_boat
    game
  end

  def test_the_night_reports_the_day_just_had(args, assert)
    game = evening(args)
    args.state.day = 3
    args.state.day_earned = 84
    args.state.day_species = 2
    args.state.day_deepest = 190
    args.state.day_sold = 5

    game.night_tick
    text = args.outputs.labels.flatten.map { |label| label[:text] }.join("  ")

    assert.true! text.include?("Tag 3"), "which day it was: #{text}"
    assert.true! text.include?("84 Cr"), "what it earned"
    assert.true! text.include?("190 m"), "how deep it went"
  end

  def test_it_renders_without_error(args, assert)
    game = evening(args)

    game.night_tick

    assert.true! args.outputs.sprites.flatten.length > 0, "there is a night out there"
  end

  # The whole point of a day-scoped tally: the numbers are the day's, not the
  # career's and not the last dive's.
  def test_a_new_day_starts_the_tally_over(args, assert)
    game = evening(args)
    args.state.day_earned = 84
    args.state.day_species = 2
    args.state.day_deepest = 190
    args.state.day_sold = 5

    game.wake_up

    assert.equal! args.state.day_earned, 0, "yesterday's money is not today's"
    assert.equal! args.state.day_species, 0
    assert.equal! args.state.day_deepest, 0
    assert.equal! args.state.day_sold, 0
  end

  def test_the_career_total_is_not_reset_with_it(args, assert)
    game = evening(args)
    args.state.log_earned = 400
    args.state.day_earned = 84

    game.wake_up

    assert.equal! args.state.log_earned, 400, "a career outlives its days"
  end

  # Dying and going back out is still the same day, so the evening has to count
  # both halves of it — which is why these are not the round's own log.
  def test_the_day_survives_a_drowning(args, assert)
    game = at_the_boat(args)
    args.state.day_earned = 40
    args.state.day_deepest = 120

    game.reset_game

    assert.equal! args.state.day_earned, 40, "the morning still happened"
    assert.equal! args.state.day_deepest, 120
  end

  def test_a_blank_day_gets_a_kind_word(args, assert)
    game = evening(args)
    args.state.day_earned = 0
    args.state.day_species = 0

    assert.false! game.night_verdict.nil?, "there is always something to say"
    assert.true! game.night_verdict.length > 0
  end

  # The layout hangs off the tally, so a row more can never land the prompt on
  # the last line — the same mistake the intro made once.
  def test_the_prompt_clears_the_tally(args, assert)
    game = evening(args)
    last_row = game.night_rows_top - Game::NIGHT_ROW_H * (game.night_rows.length - 1)

    assert.true! game.night_prompt_y < last_row - 20,
                 "the prompt sits below the last row (#{game.night_prompt_y} against #{last_row})"
  end

  # --- and it survives the session ------------------------------------------

  def test_the_day_tally_travels_with_the_book(args, assert)
    text = SaveFile.encode(name: "Kins", album: {}, sighted: {}, day: 3,
                           day_earned: 84, day_species: 2, day_deepest: 190, day_sold: 5)
    back = SaveFile.decode(text)

    assert.equal! back[:day_earned], 84
    assert.equal! back[:day_species], 2
    assert.equal! back[:day_deepest], 190
    assert.equal! back[:day_sold], 5
  end

  # Closing the game at lunchtime and coming back must not hand him a morning he
  # has not earned — the gauge says afternoon, so the tally has to agree.
  def test_carrying_a_book_on_carries_the_unfinished_day(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.game_scene = "title"
    args.state.saved_book = SaveFile.blank.merge(
      name: "Kins", album: { "burgunder" => :gut }, sighted: { "burgunder" => true },
      day: 3, energy: 40, day_earned: 84, day_species: 2, day_deepest: 190, day_sold: 5
    )

    args.inputs.keyboard.key_down.space = true
    game.title_tick

    assert.equal! args.state.day, 3, "the same day"
    assert.equal! args.state.day_earned, 84, "and what it had already come to"
    assert.equal! args.state.day_deepest, 190
  end

  def test_a_fresh_diver_starts_the_day_at_nothing(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.day_earned = 84

    game.fresh_round

    assert.equal! args.state.day_earned, 0, "nobody inherits somebody else's day"
    assert.equal! args.state.day, 1
  end
end

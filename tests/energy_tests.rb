# Energy is the day. It runs down over about fifteen minutes and the only way to
# get it back is to go home and sleep, which ends the day and starts the next —
# so the third gauge is also the calendar and the clock, and there is only one
# number behind all three.
class EnergyTests
  def build_game(args)
    game = Game.new
    game.args = args
    game
  end

  def diving(args)
    game = build_game(args)
    game.initialize_game(0)
    args.state.game_scene = "area1"
    args.state.diver_global_x = 6000 # well away from the boat
    args.state.depth_y = -400
    game
  end

  def test_a_career_starts_on_the_first_morning(args, assert)
    game = diving(args)

    assert.equal! args.state.day, 1, "day one"
    assert.equal! args.state.energy, ENERGY_MAX, "rested"
    assert.equal! game.time_of_day, :morgen, "and early"
  end

  def test_energy_lasts_about_a_quarter_of_an_hour(args, assert)
    game = diving(args)

    minutes = ENERGY_MAX / ENERGY_DRAIN / 60.0 / 60.0

    assert.true! minutes > 12 && minutes < 18, "a day is about 15 minutes (#{minutes.round(1)})"
  end

  def test_the_day_runs_down_while_you_are_out(args, assert)
    game = diving(args)
    before = args.state.energy

    600.times { game.update_energy }

    assert.true! args.state.energy < before, "the day passes"
  end

  # The clock is the gauge: nothing else has to be counted or kept in step.
  def test_the_time_of_day_is_read_off_the_energy(args, assert)
    game = diving(args)
    seen = []

    spent = 0
    while spent <= ENERGY_MAX
      args.state.energy = ENERGY_MAX - spent
      seen << game.time_of_day
      spent += 2
    end

    assert.equal! seen.uniq, Game::DAY_PHASES, "it goes through the day in order: #{seen.uniq.inspect}"
  end

  def test_an_empty_gauge_is_night(args, assert)
    game = diving(args)
    args.state.energy = 0

    assert.equal! game.time_of_day, :nacht
  end

  # Running out doesn't kill you — it just makes getting home hard work.
  def test_running_out_leaves_you_able_to_get_home(args, assert)
    game = diving(args)
    args.state.energy = 0
    game.update_energy

    assert.equal! args.state.game_scene, "area1", "nobody dies of a long day"
    assert.true! game.exhausted?, "but he is done in"

    game.update_sprint
    tired = args.state.speed
    args.state.energy = ENERGY_MAX
    game.update_sprint

    assert.true! args.state.speed > tired, "and he is slower for it (#{tired} against #{args.state.speed})"
  end

  # --- sleeping -------------------------------------------------------------

  def at_the_boat(args)
    game = build_game(args)
    game.initialize_game(0)
    game.spawn_at_surface
    args.state.game_scene = "area1"
    game
  end

  def test_sleeping_ends_the_day_and_starts_the_next(args, assert)
    game = at_the_boat(args)
    args.state.energy = 12
    args.state.suit = 40

    game.sleep_at_boat

    assert.equal! args.state.day, 2, "a new day"
    assert.equal! args.state.energy, ENERGY_MAX, "rested"
    assert.equal! game.time_of_day, :morgen, "and it is morning again"
    assert.equal! args.state.suit, SUIT_MAX, "the suit got seen to overnight"
  end

  def test_you_can_only_sleep_at_the_boat(args, assert)
    game = diving(args)
    args.state.energy = 12

    game.sleep_at_boat

    assert.equal! args.state.day, 1, "no bed out here"
    assert.equal! args.state.energy, 12
  end

  def test_s_is_the_key(args, assert)
    game = at_the_boat(args)
    args.state.energy = 30
    args.inputs.keyboard.key_down.s = true

    game.update_sleep

    assert.equal! args.state.day, 2
  end

  # --- what you can see -----------------------------------------------------

  def test_the_hud_shows_the_day_and_the_time(args, assert)
    game = diving(args)
    args.state.day = 4
    args.state.energy = ENERGY_MAX * 0.45 # somewhere in the afternoon

    game.render_panel
    text = args.outputs.labels.flatten.map { |l| l[:text] }.join("  ")

    assert.true! text.include?("Tag 4"), "which day it is: #{text}"
    assert.true! text.downcase.include?(game.time_of_day.to_s), "and roughly what time"
  end

  def test_there_is_an_icon_for_the_time_of_day(args, assert)
    game = diving(args)

    Game::DAY_PHASES.each_with_index do |phase, i|
      args.state.energy = ENERGY_MAX - (i + 0.5) * ENERGY_MAX / Game::DAY_PHASES.length
      args.outputs.sprites.clear
      game.render_panel

      icon = args.outputs.sprites.flatten.find { |s| s[:path] == Game::DAYTIME_SHEET }
      assert.false! icon.nil?, "#{phase} has a picture"
      assert.equal! icon[:source_x], i * Game::DAYTIME_FRAME, "and it is #{phase}'s"
    end
  end

  def test_the_energy_gauge_is_up_there_with_the_others(args, assert)
    game = diving(args)

    game.render_panel
    text = args.outputs.labels.flatten.map { |l| l[:text] }.join("  ")

    assert.true! text.include?("Energie"), "a third gauge, labelled"
  end

  # --- and it survives the session ------------------------------------------

  def test_the_day_travels_with_the_book(args, assert)
    text = SaveFile.encode(name: "Kins", album: {}, sighted: { "burgunder" => true },
                           day: 7, energy: 42)
    back = SaveFile.decode(text)

    assert.equal! back[:day], 7, "which day he was on"
    assert.equal! back[:energy], 42, "and how much of it was left"
  end

  def test_carrying_a_book_on_carries_the_day(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.game_scene = "title"
    args.state.saved_book = SaveFile.blank.merge(
      name: "Kins", album: { "burgunder" => :gut }, sighted: { "burgunder" => true },
      day: 7, energy: 42
    )

    args.inputs.keyboard.key_down.space = true
    game.title_tick

    assert.equal! args.state.day, 7, "he picks the day up where he left it"
    assert.equal! args.state.energy, 42, "half worn out, as he was"
  end
end

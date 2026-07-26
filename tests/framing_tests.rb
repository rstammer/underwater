# Composing a photograph. The shutter is held, a frame closes while you hold it,
# and letting go is the picture — so the skill is where you are standing and
# when you stop, not how near you swam.
class FramingTests
  def build_game(args)
    game = Game.new
    game.args = args
    game
  end

  # One fish, right where the frame closes onto.
  def with_a_fish(args, off: 0, size: 2)
    game = build_game(args)
    game.initialize_game(0)
    args.state.game_scene = "area1"
    args.state.diver_global_x = 600
    args.state.depth_y = -400
    args.state.direction = :right
    game.current_world
    args.state.fish = [Creature.new(args, 0, species: Species["burgunder"],
                                    x: 600 + Game::FRAME_AHEAD + off, y: -400, size: size)]
    args.state.crawlers = []
    args.state.jellies = []
    game
  end

  def hold(game, args, ticks)
    args.inputs.keyboard.key_held.f = true
    ticks.times { game.update_camera }
  end

  def release(game, args)
    args.inputs.keyboard.key_held.f = false
    game.update_camera
  end

  # --- the frame itself -------------------------------------------------------

  def test_holding_opens_a_frame_that_closes(args, assert)
    game = with_a_fish(args)

    hold(game, args, 1)
    wide = args.state.frame_w
    hold(game, args, 40)

    assert.true! game.framing?
    assert.true! args.state.frame_w < wide, "it closes while you hold it"
  end

  # One way only. An oscillating frame would be a quick-time event; closing
  # steadily means the question is when it fits, not whether you caught a beat.
  def test_it_only_ever_closes(args, assert)
    game = with_a_fish(args)
    widths = []

    args.inputs.keyboard.key_held.f = true
    60.times { game.update_camera; widths << args.state.frame_w }

    assert.equal! widths, widths.sort.reverse, "never wider than the tick before"
  end

  def test_it_stops_closing_at_the_tightest(args, assert)
    game = with_a_fish(args)

    hold(game, args, 400)

    assert.equal! args.state.frame_w, Game::FRAME_TIGHT
  end

  # --- what the picture is worth ----------------------------------------------

  def test_a_composed_shot_is_perfect(args, assert)
    game = with_a_fish(args)

    hold(game, args, 114)
    release(game, args)

    assert.equal! args.state.film_roll[0][:quality], :perfekt
  end

  def test_letting_go_early_leaves_a_speck_in_a_wide_frame(args, assert)
    game = with_a_fish(args)

    hold(game, args, 20)
    release(game, args)

    assert.equal! args.state.film_roll[0][:quality], :unscharf
  end

  # The mistake the old rule could not make. It held that nearer is always
  # better, which is how a thirty-metre whale broke it.
  def test_holding_too_long_clips_the_animal(args, assert)
    game = with_a_fish(args)

    hold(game, args, 135)
    release(game, args)

    assert.equal! args.state.film_roll[0][:quality], :unscharf, "half a fish is a bad photograph"
  end

  # Closing the frame shrinks it around its own middle, so an animal that is a
  # little off drifts to the edge. Standing in the right place *is* the skill.
  def test_a_fish_off_to_one_side_cannot_be_composed(args, assert)
    game = with_a_fish(args, off: 45)

    hold(game, args, 114)
    report = game.frame_report

    assert.true! report[:centred] > Game::CENTRED_ENOUGH,
                 "it has drifted to the edge by the time the frame is tight (#{report[:centred].round(2)})"
    assert.false! game.frame_quality(report) == :perfekt
  end

  # For a species shot. A later assignment reads the same number the other way
  # round — that is why the report keeps a count rather than a verdict.
  def test_company_spoils_a_portrait(args, assert)
    game = with_a_fish(args)
    args.state.fish << Creature.new(args, 0, species: Species["hornhering"],
                                    x: 600 + Game::FRAME_AHEAD + 20, y: -390, size: 1)

    hold(game, args, 114)
    report = game.frame_report

    assert.equal! report[:company], 1, "somebody else got in the picture"
    assert.false! game.frame_quality(report) == :perfekt
  end

  # --- a picture of more than one animal -----------------------------------------
  #
  # A rank of fish laid so that the middle of the group sits exactly where the
  # frame will close onto — which is the thing you have to do in the water, only
  # here it is arranged rather than swum.

  def with_a_school(args, count: 2, species: Species["hornhering"], gap: 46)
    game = build_game(args)
    game.initialize_game(0)
    args.state.game_scene = "area1"
    args.state.diver_global_x = 600
    args.state.depth_y = -400
    args.state.direction = :right
    game.current_world
    centre = 600 + Game::FRAME_AHEAD
    width = (count - 1) * gap + species.frame_w
    args.state.fish = count.times.map do |i|
      Creature.new(args, 0, species: species, size: 1,
                   x: centre - width / 2 + i * gap, y: -400 - species.frame_h / 2)
    end
    args.state.crawlers = []
    args.state.jellies = []
    game
  end

  def test_two_of_a_kind_are_a_group_photograph(args, assert)
    game = with_a_school(args)

    hold(game, args, 125)
    report = game.frame_report

    assert.equal! report[:flock], 2, "both of them, whole, in the picture"
    assert.equal! game.frame_kind(report), :gruppe
    assert.equal! game.frame_quality(report), :perfekt
  end

  def test_one_animal_is_still_a_portrait(args, assert)
    game = with_a_school(args, count: 1)

    hold(game, args, 125)
    report = game.frame_report

    assert.equal! report[:flock], 1
    assert.equal! game.frame_kind(report), :portrait
  end

  # The demand a group makes that a portrait does not: the frame has to stay
  # wide enough for all of them. Hold on past that and the ones at the ends go
  # over the edge — so a bigger group is released earlier, which is the whole
  # difference in the skill.
  def test_holding_too_long_cuts_the_ends_off_a_group(args, assert)
    game = with_a_school(args, count: 3)

    hold(game, args, 132)
    report = game.frame_report

    assert.true! report[:flock] < 3, "the outer ones are half out of frame"
  end

  def test_a_loose_group_is_worth_less_than_a_tight_one(args, assert)
    game = with_a_school(args)

    hold(game, args, 100)

    assert.equal! game.frame_quality(game.frame_report), :gut, "they are in it, but small"
  end

  # Somebody else's species in the picture spoils a group the same way it spoils
  # a portrait — a school of herring with a bass in the corner is a picture of
  # nothing in particular.
  def test_a_stray_spoils_a_group(args, assert)
    game = with_a_school(args)
    args.state.fish << Creature.new(args, 0, species: Species["burgunder"],
                                    x: 600 + Game::FRAME_AHEAD + 20, y: -420, size: 1)

    hold(game, args, 125)
    report = game.frame_report

    assert.equal! report[:strays], 1
    assert.false! game.frame_quality(report) == :perfekt
  end

  # The window has to be long enough to aim at rather than to react to. A pair is
  # the tightest case — the frame has least room to travel between holding all of
  # them and cutting the ends off — so it is the one worth pinning down.
  def test_a_pair_gives_you_a_moment_rather_than_a_reflex(args, assert)
    game = with_a_school(args)
    perfect = 0

    args.inputs.keyboard.key_held.f = true
    160.times do
      game.update_camera
      perfect += 1 if game.frame_quality(game.frame_report) == :perfekt
    end

    assert.true! perfect >= 15, "a moment you can aim at, not a beat you catch (#{perfect} ticks)"
  end

  # The count is kept as a number rather than folded into the grade, because an
  # assignment reads it the other way round: "a group of at least three" is a
  # question about this field, not about the quality it produced.
  def test_the_report_counts_the_whole_school(args, assert)
    game = with_a_school(args, count: 4, gap: 34)

    hold(game, args, 100)

    assert.equal! game.frame_report[:flock], 4
  end

  # --- letting go without shooting ---------------------------------------------

  def test_cancelling_costs_nothing(args, assert)
    game = with_a_fish(args)
    film = args.state.film_left

    hold(game, args, 60)
    game.cancel_framing

    assert.false! game.framing?
    assert.equal! args.state.film_left, film, "film is spent by the shutter, not the frame"
    assert.equal! args.state.film_roll.length, 0
  end

  def test_escape_drops_the_frame_rather_than_pausing(args, assert)
    game = with_a_fish(args)
    hold(game, args, 40)

    args.inputs.keyboard.key_down.escape = true
    game.update_escape

    assert.false! game.framing?, "the frame is what a cancel means while it is up"
    assert.equal! args.state.game_scene, "area1", "and it does not open the pause menu"
  end

  # --- what the viewfinder tells you --------------------------------------------

  def test_the_line_talks_about_the_crop_once_the_shutter_is_down(args, assert)
    game = with_a_school(args, count: 3)

    hold(game, args, 100)
    line = game.photo_message

    assert.true! line[:text].include?("3 ×"), "how many of them are in it (#{line[:text]})"
    assert.true! line[:text].include?("perfekt") || line[:text].include?("gut"),
                 "and what the picture would be worth (#{line[:text]})"
  end

  def test_an_empty_frame_says_so(args, assert)
    game = with_a_school(args)
    args.state.fish = []

    hold(game, args, 40)

    assert.equal! game.photo_message[:text], "nichts im Bild"
  end

  # The corners are the answer to "when do I let go", and they have to be
  # readable on a phone, where there is no key to feel and nothing else to go by.
  def test_the_corners_change_colour_with_the_grade(args, assert)
    game = with_a_school(args)

    hold(game, args, 30)
    loose = game.viewfinder_ink
    hold(game, args, 95)
    composed = game.viewfinder_ink

    assert.equal! game.frame_quality(game.frame_report), :perfekt
    assert.not_equal! loose, composed, "the frame says when it fits"
  end

  # --- and it is drawn ---------------------------------------------------------

  def test_the_viewfinder_is_only_up_while_you_hold(args, assert)
    game = with_a_fish(args)

    game.render_viewfinder
    assert.equal! args.outputs.sprites.flatten.length, 0, "nothing while the shutter is up"

    hold(game, args, 20)
    game.render_viewfinder
    assert.true! args.outputs.sprites.flatten.length > 0, "corners once it is down"
  end
end

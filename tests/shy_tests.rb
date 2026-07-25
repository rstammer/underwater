# Fish that won't be swum up to. A perfect frame wants PHOTO_CLOSE — closer than
# a shy fish will let you come — so the only way to get one is to stop, wait, and
# let it drift back to you. Approaching costs you the shot.
#
# Not every animal: the shark hunts you, so bolting would be nonsense, and the
# crabs already scuttle. It is a property of the species, not of the sea.
class ShyTests
  def build_game(args)
    game = Game.new
    game.args = args
    game
  end

  # A diver under water with one fish beside him, and control over whether he is
  # moving — which is the thing that frightens them.
  def diving_with(args, species_key:, away:, moving: true)
    game = build_game(args)
    game.initialize_game(0)
    args.state.game_scene = "area1"
    args.state.diver_global_x = 600
    args.state.depth_y = -400
    args.state.direction = :right
    game.current_world
    args.state.fish = [Creature.new(args, 0, species: Species[species_key],
                                    x: 600 + away, y: -400, from_x: 0, to_x: SCREEN_WIDTH)]
    args.state.crawlers = []
    args.state.shore_life = []
    game.define_singleton_method(:moving?) { moving }
    game
  end

  def test_some_species_are_shy_and_some_are_not(args, assert)
    shy = Species::ALL.select { |s| s.shy > 0 }

    assert.true! shy.length >= 5, "a good few of them won't be approached (#{shy.length})"
    assert.equal! Species["schattenhai"].shy, 0, "the shark comes at *you*"
    assert.equal! Species["taschenkrebs"].shy, 0, "and a crab already scuttles"
  end

  # The one that matters: shy enough that a perfect frame is out of reach by
  # swimming, so it has to be earned by waiting.
  def test_a_shy_fish_will_not_let_you_close_enough_for_a_perfect_frame(args, assert)
    Species::ALL.select { |s| s.shy > 0 }.each do |species|
      assert.true! species.shy > Game::PHOTO_CLOSE,
                   "#{species.name} bolts (#{species.shy}) before perfect range (#{Game::PHOTO_CLOSE})"
    end
  end

  def test_a_moving_diver_scatters_them(args, assert)
    game = diving_with(args, species_key: "burgunder", away: 60)
    fish = args.state.fish.first
    before = (fish.x - args.state.diver_global_x).abs

    30.times { game.update_characters(0) }

    assert.true! (fish.x - args.state.diver_global_x).abs > before,
                 "it put water between you (#{before} -> #{(fish.x - args.state.diver_global_x).abs})"
  end

  # Away from him, whichever side he is on.
  def test_they_flee_away_from_him_not_past_him(args, assert)
    [-60, 60].each do |away|
      game = diving_with(args, species_key: "burgunder", away: away)
      fish = args.state.fish.first
      start = fish.x

      30.times { game.update_characters(0) }

      moved = fish.x - start
      assert.true! away.negative? ? moved < 0 : moved > 0,
                   "a fish #{away} px away goes further that way (moved #{moved})"
    end
  end

  # The promise the whole thing makes: stop, and it comes to you. Patrolling
  # alone would only mean *hoping* it wandered back.
  def test_holding_still_brings_them_to_you(args, assert)
    game = diving_with(args, species_key: "burgunder", away: 300, moving: false)
    fish = args.state.fish.first
    before = (fish.x - args.state.diver_global_x).abs

    600.times { game.update_characters(0) } # ten seconds of holding still
    after = (fish.x - args.state.diver_global_x).abs

    assert.true! after < before, "it came to have a look (#{before} -> #{after})"
    assert.true! after <= Game::PHOTO_CLOSE, "and near enough for a perfect frame (#{after})"
  end

  def test_the_shark_does_not_flinch(args, assert)
    game = diving_with(args, species_key: "schattenhai", away: 40)
    fish = args.state.fish.first
    start = fish.x

    60.times { game.update_characters(0) }

    assert.true! (fish.x - start).abs < 60, "it carries on about its business"
  end

  # However hard you chase it, it must not bolt through rock.
  def test_a_frightened_fish_stays_in_its_own_water(args, assert)
    game = diving_with(args, species_key: "burgunder", away: 40)
    fish = args.state.fish.first
    fish.instance_variable_set(:@from_x, 500)
    fish.instance_variable_set(:@to_x, 700)

    400.times { game.update_characters(0) }

    assert.true! fish.x >= 500 && fish.x <= 700, "it kept to its stretch (#{fish.x})"
  end

  # Through the real inputs and whole ticks, because "moving" is a keyboard
  # question and every test above answers it with a stub. If holding a direction
  # stopped counting as movement, all of them would stay green.
  def test_a_held_key_is_what_frightens_them(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.saved_book = SaveFile.blank
    args.state.game_scene = "area1"
    args.state.diver_global_x = 600
    args.state.depth_y = -400
    game.center_camera
    game.current_world
    args.state.fish = [Creature.new(args, 0, species: Species["burgunder"],
                                    x: 700, y: -400, from_x: 0, to_x: SCREEN_WIDTH)]
    args.state.crawlers = []
    args.state.shore_life = []
    fish = args.state.fish.first
    args.inputs.keyboard.key_held.right = true

    start = fish.x
    40.times { game.tick }

    assert.true! fish.x > start, "swimming at it drives it off (#{start} -> #{fish.x})"
  end

  # The whole loop, end to end: chase and you never get the shot; hold still and
  # it comes to you.
  def test_chasing_costs_the_shot_and_waiting_earns_it(args, assert)
    game = diving_with(args, species_key: "burgunder", away: 100)
    chased = 99_999
    200.times do
      game.update_characters(0)
      subject = game.photo_subject
      chased = subject[:distance] if subject && subject[:distance] < chased
    end
    assert.true! chased > Game::PHOTO_CLOSE,
                 "chasing never gets you a perfect frame (closest #{chased.to_i})"

    game.define_singleton_method(:moving?) { false } # stop, and wait
    waited = 99_999
    600.times do
      game.update_characters(0)
      subject = game.photo_subject
      waited = subject[:distance] if subject && subject[:distance] < waited
    end
    assert.true! waited < chased, "waiting brings it nearer than chasing did (#{waited.to_i})"
  end
end

# The whale. Most of these are about the two words the whole thing has to
# deliver — calm, and gigantic — because both are properties you can measure and
# both are easy to lose to a tuning change made for some other reason.
class WhaleTests
  def build_game(args)
    game = Game.new
    game.args = args
    game
  end

  # A segment of the open blue, which is the only water a whale is in.
  def blue_water(args)
    game = build_game(args)
    game.initialize_game(0)
    args.state.island_sectors = []
    args.state.world_cache = {}
    args.state.active_world_index = nil
    sector = (0..120).find { |i| game.world_for(i).biome.name == "Blauwasser" }
    args.state.game_scene = "area1"
    args.state.diver_global_x = sector * SCREEN_WIDTH + 640
    args.state.depth_y = WorldGenerator.floor_y_at(args.state.diver_global_x) + 420
    game.center_camera
    game.current_world
    game
  end

  def with_a_whale(args)
    game = blue_water(args)
    args.state.whale = game.new_whale
    game
  end

  # --- where it lives --------------------------------------------------------

  def test_the_blue_has_a_whale_in_it(args, assert)
    game = blue_water(args)

    assert.false! game.whale_species.nil?, "the open blue is its water"
    assert.true! game.whale_water?, "and he is down in it"
  end

  def test_it_is_the_only_water_that_has_one(args, assert)
    others = Biome::ALL.reject { |biome| biome.name == "Blauwasser" }

    others.each do |biome|
      assert.equal! Species.giant_for(biome), nil, "#{biome.name} has no whale"
    end
  end

  # It must never be rolled into an ordinary swarm: a thirty-metre animal
  # patrolling a rock crevice would be absurd, and the fit check would spend its
  # life rejecting it.
  def test_it_is_not_one_of_the_fish(args, assert)
    assert.false! Species.swimmers.any? { |s| s.key == "blauwal" }, "not in the swarm"
    assert.equal! Species.pick_floor(Biome::BLUE, 150)&.key != "blauwal", true
  end

  def test_nothing_starts_a_pass_while_his_head_is_out(args, assert)
    game = blue_water(args)
    args.state.depth_y = WATERLINE_Y - SURFACE_FLOAT_DEPTH

    assert.false! game.whale_water?, "you would only see the tail leaving"
  end

  # --- gigantic --------------------------------------------------------------

  def test_it_is_drawn_far_larger_than_the_diver(args, assert)
    game = blue_water(args)

    assert.true! game.whale_width > Diver::WIDTH * 10,
                 "#{game.whale_width} px of animal against a diver of #{Diver::WIDTH}"
    assert.true! game.whale_width > SCREEN_WIDTH / 4, "and a good slice of the screen"
  end

  # A number the roster carries, so the darkroom and any future assignment can
  # ask about it — and so nobody quietly shrinks it.
  def test_the_roster_says_it_is_tens_of_metres(args, assert)
    whale = Species["blauwal"]

    assert.true! whale.size_cm >= 2000, "#{whale.size_label} is whale-sized"
    assert.true! whale.size_label.include?("m"), "and it reads in metres"
  end

  # --- calm ------------------------------------------------------------------

  def test_it_is_slower_than_a_diver(args, assert)
    assert.true! Game::WHALE_SPEED < Diver::SPEED / 2.0,
                 "you can catch it up (#{Game::WHALE_SPEED} against #{Diver::SPEED})"
  end

  def test_it_holds_its_line_and_does_not_chase(args, assert)
    game = with_a_whale(args)
    whale = args.state.whale
    started_at = whale.x
    home = whale.home_y

    600.times { game.update_whale }

    assert.equal! args.state.whale.home_y, home, "its track is its own business"
    assert.true! (args.state.whale.x - started_at).abs > 200, "it went somewhere"
  end

  # The rise and fall is a drift, not a swim. If it ever moved further per tick
  # vertically than horizontally it would read as agitated.
  def test_the_rise_and_fall_is_gentler_than_the_swim(args, assert)
    game = with_a_whale(args)
    steepest = 0

    900.times do
      before = args.state.whale.y
      game.update_whale
      break unless args.state.whale

      rise = (args.state.whale.y - before).abs
      steepest = rise if rise > steepest
    end

    assert.true! steepest < Game::WHALE_SPEED,
                 "it drifts up and down slower than it swims (#{steepest.round(3)})"
  end

  # A shy fish treats you as a peer. This one does not look up, and that is the
  # single strongest thing that says how big it is.
  def test_it_takes_no_notice_of_the_diver(args, assert)
    assert.equal! Species["blauwal"].shy, 0, "nothing frightens it"
  end

  # --- and it goes away again ------------------------------------------------

  def test_it_leaves_once_it_is_well_past(args, assert)
    game = with_a_whale(args)
    args.state.whale.x = args.state.diver_global_x + Game::WHALE_GONE + 10

    game.update_whale

    assert.equal! args.state.whale, nil, "gone, and the blue is empty again"
  end

  def test_a_new_round_has_no_whale_in_it(args, assert)
    game = with_a_whale(args)

    game.reset_game

    assert.equal! args.state.whale, nil
  end

  # --- photographing it ------------------------------------------------------

  # The reach is scaled by the animal. At the distance a burgunder is "perfekt"
  # you are looking at one flank of this.
  def test_you_can_photograph_it_from_much_further_off(args, assert)
    game = blue_water(args)
    whale = Species["blauwal"]

    assert.true! game.photo_reach(whale) > Game::PHOTO_REACH * 3, "a whale reads at range"
    assert.equal! game.photo_reach(Species["burgunder"]), Game::PHOTO_REACH, "and a fish does not"
  end

  def test_close_is_still_sharp_just_further_away(args, assert)
    game = blue_water(args)
    whale = Species["blauwal"]

    assert.equal! game.photo_quality(Game::PHOTO_CLOSE * 3, whale), :perfekt
    assert.equal! game.photo_quality(Game::PHOTO_CLOSE * 3, Species["burgunder"]), :unscharf
  end

  # The viewfinder and the shutter must grade the same frame the same way. They
  # did not: the HUD asked photo_quality without the species, so it judged a
  # whale by a sardine's distances — it read "unscharf" over a shot that came
  # out perfect, and ran improves? on that wrong grade.
  def test_the_viewfinder_grades_it_the_same_way_the_shutter_does(args, assert)
    game = with_a_whale(args)
    args.state.direction = :right
    args.state.fish = []
    args.state.crawlers = []
    args.state.whale.x = args.state.diver_global_x + Game::PHOTO_CLOSE * 3
    args.state.whale.y = args.state.depth_y

    subject = game.photo_subject
    assert.equal! subject[:species].key, "blauwal"
    assert.equal! game.photo_quality(subject[:distance], subject[:species]), :perfekt

    assert.true! game.photo_message[:text].include?("perfekt"),
                 "and the viewfinder says so too: #{game.photo_message[:text]}"
  end

  # It has to lose to the fish under your nose, or the whale two screens off
  # would be the subject for the whole of a dive.
  def test_a_fish_in_your_face_beats_a_whale_across_the_water(args, assert)
    game = with_a_whale(args)
    args.state.direction = :right
    args.state.whale.x = args.state.diver_global_x + 900
    args.state.whale.y = args.state.depth_y
    args.state.fish = [Creature.new(args, 0, species: Species["truebfisch"],
                                    x: (args.state.diver_global_x % SCREEN_WIDTH) + 50,
                                    y: args.state.depth_y)]
    args.state.crawlers = []

    subject = game.photo_subject

    assert.equal! subject[:species].key, "truebfisch", "the near thing wins"
  end
end

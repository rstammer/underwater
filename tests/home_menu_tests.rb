class HomeMenuTests
  def build_game(args)
    game = Game.new
    game.args = args
    game
  end

  # Standing at the boat, up at the surface, E opens the logbook and pauses.
  def test_e_opens_the_logbook_at_the_boat(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    game.spawn_at_surface # right beside the boat, head out
    args.state.game_scene = "area1" # in the water, not on the title screen
    assert.true! game.at_the_boat?, "the diver is at the boat"

    game.toggle_home_menu(true, false)

    assert.equal! args.state.game_scene, "home_menu"
    assert.true! game.game_paused?, "and the world is paused behind it"
  end

  # Out in open water, E is not the menu key — nothing opens.
  def test_e_does_nothing_away_from_the_boat(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.game_scene = "area1"
    args.state.diver_global_x = 4000 # far from home
    args.state.depth_y = -400        # and under water

    game.toggle_home_menu(true, false)

    assert.equal! args.state.game_scene, "area1", "no boat here, no menu"
  end

  # E or ESC closes it again, dropping back into the sector you're in.
  def test_the_menu_closes_again(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    game.spawn_at_surface
    args.state.game_scene = "area1"

    game.toggle_home_menu(true, false) # open
    game.toggle_home_menu(false, true) # ESC
    assert.equal! args.state.game_scene, "area1", "ESC drops back into the near sector"

    game.toggle_home_menu(true, false) # open again
    game.toggle_home_menu(true, false) # E
    assert.equal! args.state.game_scene, "area1", "E closes it too"
  end

  # The log fills in as you dive: the deepest you reached, the sectors and islands
  # you crossed, and any cave you surfaced to breathe in.
  def test_the_log_records_the_dive(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.island_sectors = [2, -3]

    # A shallow pass through the home sector.
    args.state.diver_global_x = 300
    args.state.depth_y = WATERLINE_Y - 40 * PIXELS_PER_METRE
    game.track_log
    shallow = args.state.log_deepest

    # A deep pass through an island sector.
    args.state.diver_global_x = 2 * SCREEN_WIDTH + 200
    args.state.depth_y = WATERLINE_Y - 150 * PIXELS_PER_METRE
    game.track_log

    assert.true! args.state.log_deepest > shallow, "it keeps the deepest reading (#{args.state.log_deepest})"
    assert.equal! args.state.log_sectors.length, 2, "two distinct sectors seen"
    assert.equal! args.state.log_islands.length, 1, "and one of them was an island"
  end

  # The deepest reading only ever grows — coming back up doesn't erase it.
  def test_the_deepest_reading_only_grows(args, assert)
    game = build_game(args)
    game.initialize_game(0)

    args.state.depth_y = WATERLINE_Y - 120 * PIXELS_PER_METRE
    game.track_log
    deep = args.state.log_deepest

    args.state.depth_y = WATERLINE_Y - 10 * PIXELS_PER_METRE # back up to the shallows
    game.track_log

    assert.equal! args.state.log_deepest, deep, "the record holds (#{args.state.log_deepest})"
  end

  # A new round wipes the log clean.
  def test_a_new_round_resets_the_log(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.depth_y = -900
    game.track_log
    assert.true! args.state.log_deepest > 0, "something got logged"

    game.reset_game

    assert.equal! args.state.log_deepest, 0, "the log starts fresh"
    assert.equal! args.state.log_sectors.length, 0
  end

  def test_the_rows_reflect_the_log(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.log_deepest = 137
    args.state.log_islands = { 2 => true }
    args.state.log_sectors = { 0 => true, 1 => true, 2 => true }
    args.state.log_caves = {}

    rows = Hash[game.logbook_rows]

    assert.equal! rows["Tiefster Tauchgang"], "137 m"
    assert.equal! rows["Inseln gefunden"], "1 / #{ISLAND_COUNT}"
    assert.equal! rows["Sektoren erkundet"], "3"
    assert.equal! rows["Höhlen durchtaucht"], "0"
  end

  def test_the_menu_renders_without_error(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    game.spawn_at_surface
    game.toggle_home_menu(true, false)

    game.home_menu_tick

    assert.true! true, "the logbook draws over the frozen world"
  end
end

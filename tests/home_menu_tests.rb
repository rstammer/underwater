class HomeMenuTests
  def build_game(args)
    game = Game.new
    game.args = args
    game
  end

  # Standing at the boat, up at the surface, L opens the logbook and pauses.
  def test_l_opens_the_logbook_at_the_boat(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    game.spawn_at_surface # right beside the boat, head out
    args.state.game_scene = "area1" # in the water, not on the title screen
    assert.true! game.at_the_boat?, "the diver is at the boat"

    game.toggle_home_menu(true)

    assert.equal! args.state.game_scene, "home_menu"
    assert.true! game.game_paused?, "and the world is paused behind it"
  end

  # Out in open water there is no boat to open a logbook at — nothing happens.
  def test_the_menu_does_not_open_away_from_the_boat(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.game_scene = "area1"
    args.state.diver_global_x = 4000 # far from home
    args.state.depth_y = -400        # and under water

    game.toggle_home_menu(true)

    assert.equal! args.state.game_scene, "area1", "no boat here, no menu"
  end

  # L closes it again, dropping back into the sector you're in.
  def test_the_menu_closes_again(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    game.spawn_at_surface
    args.state.game_scene = "area1"

    game.toggle_home_menu(true) # open
    game.toggle_home_menu(true) # L
    assert.equal! args.state.game_scene, "area1", "L closes it"
  end

  # ESC closes the boat screen too — and *only* that. It used to close the menu
  # and then fall straight through to the title in the same tick, which threw the
  # round away; so this one goes through a whole tick with the key held.
  def test_esc_closes_the_menu_without_falling_through_to_the_title(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    game.spawn_at_surface
    args.state.game_scene = "area1"
    game.toggle_home_menu(true)

    args.inputs.keyboard.key_down.escape = true
    game.tick

    assert.equal! args.state.game_scene, "area1", "ESC drops back into the water, no further"
  end

  # Out in the water it still is the way back to the title screen.
  def test_esc_in_the_water_goes_to_the_title(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.game_scene = "area1"
    args.state.diver_global_x = 4000
    args.state.depth_y = -400

    args.inputs.keyboard.key_down.escape = true
    game.tick

    assert.equal! args.state.game_scene, "title", "ESC out there still bails out"
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
    game.toggle_home_menu(true)

    game.home_menu_tick

    assert.true! true, "the logbook draws over the frozen world"
  end
end

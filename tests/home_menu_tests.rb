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

  # Out in the water ESC opens the pause menu — it does not throw the round away.
  def test_esc_in_the_water_opens_the_pause_menu(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.game_scene = "area1"
    args.state.diver_global_x = 4000
    args.state.depth_y = -400

    args.inputs.keyboard.key_down.escape = true
    game.tick

    assert.equal! args.state.game_scene, "pause", "ESC pauses rather than bailing out"
    assert.true! game.game_paused?, "and the world freezes behind it"
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

    assert.equal! rows["Tiefster Punkt"], "137 m"
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

  # --- the frame holds ------------------------------------------------------
  #
  # Three pages now, on nearly the whole screen. Each is measured against the
  # frame rather than looked at: the Artenbuch already once ran its last rows
  # down through the footer and printed over it.

  def at_the_boat_with_things(args)
    game = build_game(args)
    game.initialize_game(0)
    game.spawn_at_surface
    args.state.game_scene = "area1"
    args.state.sighted = Species::ALL.each_with_object({}) { |sp, h| h[sp.key] = true }
    args.state.inventory = ["jewel", "can"]
    args.state.stash = ["can", "can", "key", "bottle", "shoe"]
    args.state.credits = 1234
    game.toggle_home_menu(true)
    game
  end

  def test_every_page_stays_inside_the_frame(args, assert)
    game = at_the_boat_with_things(args)

    Game::BOAT_PAGES.each do |page|
      args.state.boat_page = page[:id]
      args.outputs.labels.clear
      args.outputs.sprites.clear
      game.home_menu_tick

      labels = args.outputs.labels.flatten
      low = labels.select { |l| l[:y] < game.body_bottom - 2 }
      assert.true! low.length <= 1,
                   "#{page[:title]}: nothing but the footer below the frame " \
                   "(#{low.map { |l| l[:text] }.inspect})"
      high = labels.select { |l| l[:y] > game.menu_top }
      assert.equal! high.length, 0, "#{page[:title]}: and nothing above it"
    end
  end

  # Tab has to reach all three, and come back round.
  def test_tab_walks_all_three_pages(args, assert)
    game = at_the_boat_with_things(args)
    seen = []

    Game::BOAT_PAGES.length.times do
      seen << args.state.boat_page
      args.inputs.keyboard.key_down.tab = true
      game.update_boat_page
    end

    assert.equal! seen.uniq.length, Game::BOAT_PAGES.length, "each page once (#{seen.inspect})"
    assert.equal! args.state.boat_page, seen.first, "and round to where it started"
  end

  # The log is a career, not just this dive — that contrast is the point of it.
  def test_the_logbook_page_shows_the_career_as_well_as_the_dive(args, assert)
    game = at_the_boat_with_things(args)
    args.state.log_deepest = 88
    args.state.log_best = 214
    args.state.log_dives = 9
    args.state.log_sold = 4
    args.state.log_earned = 3200
    args.state.boat_page = :log

    game.home_menu_tick
    text = args.outputs.labels.flatten.map { |l| l[:text] }.join("  ")

    assert.true! text.include?("88 m"), "this dive's deepest"
    assert.true! text.include?("214 m"), "and the deepest ever"
    assert.true! text.include?("9"), "how many dives"
    assert.true! text.include?("3200 Cr"), "and what it has all been worth"
  end

  # The balance moved into the head band, so it is on every page now.
  def test_the_balance_is_on_every_page(args, assert)
    game = at_the_boat_with_things(args)

    Game::BOAT_PAGES.each do |page|
      args.state.boat_page = page[:id]
      args.outputs.labels.clear
      game.home_menu_tick
      text = args.outputs.labels.flatten.map { |l| l[:text] }.join("  ")
      assert.true! text.include?("1234 Cr"), "#{page[:title]} shows the balance"
    end
  end
end

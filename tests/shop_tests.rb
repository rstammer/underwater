# Andi's, on the island in sector 3.
class ShopTests
  def build_game(args)
    game = Game.new
    game.args = args
    game
  end

  # Standing at the door, on foot, the way you would after wading up the beach.
  def at_the_door(args, credits: 1000)
    game = build_game(args)
    game.initialize_game(0)
    args.state.game_scene = "area2"
    args.state.credits = credits
    args.state.diver_global_x = game.shop_x
    args.state.on_land = true
    game.current_world
    game
  end

  # --- where it is -----------------------------------------------------------

  # Fixed, not rolled. A shop you have to look for is not somewhere you pop back
  # to — and the sea floor is a pure function of the world position, so this
  # stretch of coast is the same in everybody's game.
  def test_there_is_always_an_island_at_the_shop_sector(args, assert)
    game = build_game(args)
    10.times do
      game.initialize_game(0)
      assert.true! args.state.island_sectors.include?(IslandWorld::SHOP_SECTOR),
                   "the shop island is there every round"
    end
  end

  # It has to have a beach: a shop behind a cliff face is no shop.
  def test_the_shop_island_can_be_walked_up(args, assert)
    assert.equal! IslandWorld.shape_for(IslandWorld::SHOP_SECTOR)[:shore], :through
  end

  def test_the_hut_stands_on_the_rock_and_not_in_the_air(args, assert)
    game = at_the_door(args)

    assert.false! game.shop_ground_y.nil?, "there is ground under it"
    assert.true! game.shop_ground_y > WATERLINE_Y, "and it is out of the water"
  end

  # --- getting in ------------------------------------------------------------

  def test_you_have_to_be_ashore_to_shop(args, assert)
    game = at_the_door(args)
    args.state.on_land = false

    assert.false! game.at_the_shop?, "no shopping while treading water under it"
  end

  def test_you_have_to_be_at_the_door(args, assert)
    game = at_the_door(args)
    args.state.diver_global_x = game.shop_x + 900

    assert.false! game.at_the_shop?
  end

  def test_l_opens_and_closes_it(args, assert)
    game = at_the_door(args)
    assert.true! game.at_the_shop?

    args.inputs.keyboard.key_down.l = true
    game.update_shop
    assert.equal! args.state.game_scene, "shop"
    assert.true! game.game_paused?, "nothing drains while you shop"

    game.update_shop
    assert.false! args.state.game_scene == "shop", "and the same key lets you out"
  end

  # --- the shelf -------------------------------------------------------------

  def in_the_shop(args, credits: 1000)
    game = at_the_door(args, credits: credits)
    args.state.shop_met = 1 # past her introduction, which the shelf is deaf behind
    game.open_shop
    game
  end

  def test_the_shelf_shows_what_you_have_and_what_you_would_get(args, assert)
    game = in_the_shop(args)
    row = game.shop_rows.find { |r| r[:key] == :suit }

    assert.equal! row[:now], SUIT_DEPTH_LIMIT, "what you are wearing"
    assert.equal! row[:nxt], Game::SUIT_STEPS[1], "and what you would be"
    assert.false! row[:price].nil?
  end

  def test_the_cursor_walks_the_shelf_and_wraps(args, assert)
    game = in_the_shop(args)
    first = game.selected_gear

    Game::GEAR.length.times { game.move_shop_cursor(1) }

    assert.equal! game.selected_gear, first, "all the way round"
  end

  # The same inversion lived here, and the title's was copied from it. Measured
  # against where the row is drawn rather than against its index.
  def test_the_arrows_walk_the_shelf_the_way_it_is_drawn(args, assert)
    game = in_the_shop(args)
    first = game.selected_gear

    args.inputs.keyboard.key_down.down = true
    game.update_shop_input

    assert.equal! game.selected_gear, Game::GEAR[1][:key],
                  "down goes to the row drawn underneath, not the one above"
    assert.false! game.selected_gear == first
  end

  def test_buying_from_the_shelf_takes_the_money(args, assert)
    game = in_the_shop(args, credits: 1000)
    game.state.shop_row = Game::GEAR.index { |i| i[:key] == :air }
    price = game.gear_price(:air)

    assert.true! game.buy_selected

    assert.equal! args.state.credits, 1000 - price
    assert.equal! game.air_capacity, Game::AIR_STEPS[1]
  end

  def test_an_empty_wallet_buys_nothing(args, assert)
    game = in_the_shop(args, credits: 0)

    assert.false! game.buy_selected
    assert.equal! args.state.credits, 0
  end

  # --- Andi ------------------------------------------------------------

  # Her line is picked off your state, not out of a hat: the first thing that is
  # true about this diver is the most useful thing to tell them.
  def test_she_says_something_different_to_a_beginner(args, assert)
    game = at_the_door(args)
    args.state.log_dives = 1

    first = game.shop_tip
    args.state.log_dives = 40
    args.state.gear = { film: 2, air: 2, suit: 2 }
    args.state.sighted = { "blauwal" => true, "mondqualle" => true }
    args.state.credits = 0

    assert.false! game.shop_tip == first, "she notices where you are up to"
  end

  # The one bit of signposting the game has for water you have not found yet.
  def test_she_points_you_at_the_whale_once_you_are_going(args, assert)
    game = at_the_door(args)
    args.state.log_dives = 20
    args.state.gear = { film: 1, air: 1, suit: 1 }
    args.state.sighted = {}
    args.state.suit = SUIT_MAX

    assert.true! game.shop_tip.include?("klare"), "she mentions the clear water: #{game.shop_tip}"
  end

  def test_she_always_has_something_to_say(args, assert)
    game = at_the_door(args)
    args.state.log_dives = 20
    args.state.gear = { film: 2, air: 2, suit: 2 }
    args.state.sighted = { "blauwal" => true, "mondqualle" => true }
    args.state.credits = 0
    args.state.suit = SUIT_MAX

    assert.false! game.shop_tip.nil?
    assert.true! game.shop_tip.length > 0
  end

  # Settled on entry, so it cannot change under your eyes while you read it.
  def test_her_line_holds_still_while_you_read_it(args, assert)
    game = in_the_shop(args)
    said = args.state.shop_said

    args.state.log_dives = 99

    assert.equal! args.state.shop_said, said
  end

  def test_she_says_something_about_what_you_bought(args, assert)
    game = in_the_shop(args, credits: 5000)
    said = args.state.shop_said

    game.buy_selected

    assert.false! args.state.shop_said == said, "she remarks on the sale"
  end

  # --- and the deep keeps its teeth ------------------------------------------

  # The kraken kills by drawing you past what your suit is rated for. Fixed at
  # 150 m it would lure a diver in a 250 m suit into water that cannot hurt him
  # — the deep would go harmless exactly when it gets interesting.
  def test_the_kraken_hangs_below_your_own_suit(args, assert)
    game = at_the_door(args, credits: 5000) # enough for the whole ladder

    assert.equal! game.kraken_depth, 150, "at the starting suit, the old number"

    game.buy_gear(:suit)
    game.buy_gear(:suit)

    assert.equal! game.suit_limit, 250
    assert.true! game.kraken_depth > 300, "and it moves down with you (#{game.kraken_depth} m)"
    assert.true! game.kraken_fade_depth < game.kraken_depth, "with the hysteresis intact"
  end

  # --- the first time -------------------------------------------------------

  def test_she_introduces_herself_on_the_first_visit(args, assert)
    game = at_the_door(args)
    args.state.shop_met = 0

    game.open_shop

    assert.true! game.shop_intro?, "she says who she is"
  end

  # Once per career, not per session — it lives in the save file, so coming back
  # tomorrow does not get the speech again.
  def test_she_only_says_it_once(args, assert)
    game = at_the_door(args)
    args.state.shop_met = 0
    game.open_shop
    game.dismiss_shop_intro

    game.close_shop
    game.open_shop

    assert.false! game.shop_intro?, "she has met you now"
    assert.equal! args.state.shop_met, 1
  end

  def test_it_travels_with_the_book(args, assert)
    back = SaveFile.decode(SaveFile.encode(name: "Kins", album: {}, sighted: {}, shop_met: 1))

    assert.equal! back[:shop_met], 1
  end

  # Nothing reaches the shelf until she has finished talking, or the same press
  # would dismiss her *and* buy something.
  def test_the_shelf_is_deaf_while_she_talks(args, assert)
    game = at_the_door(args, credits: 5000)
    args.state.shop_met = 0
    game.open_shop
    before = args.state.credits

    args.inputs.keyboard.key_down.e = true
    game.update_shop_input

    assert.equal! args.state.credits, before, "the key that ends her speech buys nothing"
    assert.false! game.shop_intro?, "and it does end it"
  end

  def test_the_speech_fits_its_panel(args, assert)
    game = at_the_door(args)

    Game::SHOP_INTRO_LINES.each do |line|
      width = args.gtk.calcstringbox(line, 2)[0]
      assert.true! width <= Game::SHOP_INTRO_W,
                   "\"#{line}\" is #{width.round} px on a #{Game::SHOP_INTRO_W} px column"
    end
  end

  def test_the_intro_renders_without_error(args, assert)
    game = at_the_door(args)
    args.state.shop_met = 0
    game.open_shop

    game.shop_tick

    assert.true! args.outputs.labels.flatten.length > 0
  end

  def test_it_renders_without_error(args, assert)
    game = in_the_shop(args)

    game.shop_tick

    assert.true! args.outputs.sprites.flatten.length > 0
  end
end

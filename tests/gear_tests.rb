# Kit: the three clocks the game runs on, as things you own rather than rules.
class GearTests
  def build_game(args)
    game = Game.new
    game.args = args
    game
  end

  def a_diver(args, credits: 1000)
    game = build_game(args)
    game.initialize_game(0)
    args.state.credits = credits
    game
  end

  # The bottom rung is written out in gear.rb because the constants are defined
  # below the requires that load it. This is what keeps the two honest.
  def test_the_first_rung_is_the_game_without_any_gear(args, assert)
    assert.equal! Game::FILM_STEPS[0], Game::FILM_MAX, "an unbought roll is FILM_MAX"
    assert.equal! Game::AIR_STEPS[0], OXYGEN_MAX, "an unbought bottle is OXYGEN_MAX"
    assert.equal! Game::SUIT_STEPS[0], SUIT_DEPTH_LIMIT, "and the suit is as rated"
  end

  def test_a_new_diver_owns_nothing(args, assert)
    game = a_diver(args)

    assert.equal! game.film_capacity, Game::FILM_MAX
    assert.equal! game.air_capacity, OXYGEN_MAX
    assert.equal! game.suit_limit, SUIT_DEPTH_LIMIT
  end

  # The starting bottle is short on purpose: the swim home has to be something
  # you count from the very first dive.
  def test_the_first_bottle_is_about_a_minute_and_a_half(args, assert)
    seconds = OXYGEN_MAX / OXYGEN_DRAIN / 60.0

    assert.true! seconds > 80 && seconds < 100, "#{seconds.round} s of air to start with"
  end

  def test_each_rung_is_better_than_the_last(args, assert)
    Game::GEAR.each do |item|
      item[:steps].each_cons(2) do |lower, higher|
        assert.true! higher > lower, "#{item[:name]}: #{higher} beats #{lower}"
      end
    end
  end

  def test_every_rung_past_the_first_has_a_price(args, assert)
    Game::GEAR.each do |item|
      assert.equal! item[:prices].length, item[:steps].length, "#{item[:name]} prices its ladder"
      item[:prices].drop(1).each_cons(2) do |cheaper, dearer|
        assert.true! dearer > cheaper, "#{item[:name]} gets dearer as it gets better"
      end
    end
  end

  # --- buying ----------------------------------------------------------------

  def test_buying_costs_the_money_and_raises_the_ladder(args, assert)
    game = a_diver(args, credits: 1000)
    price = game.gear_price(:suit)

    assert.true! game.buy_gear(:suit)

    assert.equal! args.state.credits, 1000 - price
    assert.equal! game.suit_limit, Game::SUIT_STEPS[1]
  end

  def test_you_cannot_buy_what_you_cannot_afford(args, assert)
    game = a_diver(args, credits: 5)

    assert.false! game.can_afford?(:suit)
    assert.false! game.buy_gear(:suit), "and the shop does not sell it"
    assert.equal! args.state.credits, 5, "nor take the money"
    assert.equal! game.suit_limit, SUIT_DEPTH_LIMIT
  end

  def test_the_top_of_a_ladder_is_the_top(args, assert)
    game = a_diver(args, credits: 100_000)
    game.buy_gear(:air)
    game.buy_gear(:air)

    assert.true! game.gear_top?(:air), "nothing left to sell him"
    assert.equal! game.gear_price(:air), nil
    assert.false! game.buy_gear(:air)
  end

  # You have just paid for it. Standing on an island holding a bigger empty
  # bottle would be a poor thank you.
  def test_a_new_bottle_comes_full(args, assert)
    game = a_diver(args)
    args.state.oxygen = 3

    game.buy_gear(:air)

    assert.equal! args.state.oxygen, game.air_capacity
  end

  def test_a_new_roll_comes_loaded(args, assert)
    game = a_diver(args)
    args.state.film_left = 0

    game.buy_gear(:film)

    assert.equal! args.state.film_left, game.film_capacity
  end

  # --- what you are wearing, by name -----------------------------------------

  def test_every_rung_has_a_name(args, assert)
    Game::GEAR.each do |item|
      assert.equal! item[:titles].length, item[:steps].length,
                    "#{item[:name]} names every rung it sells"
      assert.true! item[:titles].all? { |t| t.length > 0 }
    end
  end

  def test_the_kit_page_lists_everything_you_wear(args, assert)
    game = a_diver(args)
    rows = game.kit_rows

    assert.equal! rows.length, Game::GEAR.length, "including what you never upgraded"
    assert.true! rows.all? { |row| row[:title].length > 0 }
  end

  def test_buying_changes_what_your_kit_is_called(args, assert)
    game = a_diver(args, credits: 5000)
    was = game.gear_title(:fins)

    game.buy_gear(:fins)

    assert.false! game.gear_title(:fins) == was, "new fins, new name"
  end

  # --- the mask and the fins do something -------------------------------------

  def test_a_better_mask_sees_further(args, assert)
    game = a_diver(args, credits: 5000)
    bare = game.fog_radius(Biome::DEEP)

    game.buy_gear(:mask)

    assert.true! game.fog_radius(Biome::DEEP) > bare, "the dark backs off a little"
  end

  def test_better_fins_swim_faster(args, assert)
    game = a_diver(args, credits: 5000)
    args.state.sprinting = false
    args.state.on_land = false
    bare = game.current_speed

    game.buy_gear(:fins)

    assert.true! game.current_speed > bare
  end

  # Bare kit has to leave the game exactly as it was, or every number tuned
  # before the shop existed is quietly wrong.
  def test_unbought_mask_and_fins_change_nothing(args, assert)
    game = a_diver(args)

    assert.equal! game.sight_factor, 1.0
    assert.equal! game.swim_factor, 1.0
  end

  # --- and it is career, so it survives ---------------------------------------

  def test_the_suit_you_bought_is_the_suit_the_pressure_reads(args, assert)
    game = a_diver(args)
    game.buy_gear(:suit)
    args.state.depth_y = WATERLINE_Y - (SUIT_DEPTH_LIMIT + 20) * PIXELS_PER_METRE

    assert.false! game.too_deep?, "a hundred and twenty metres is nothing to this one"
  end

  # Every ladder, not the three that existed first. A mask you bought and lost
  # on the next boot is the bug we had just finished fixing.
  def test_gear_travels_with_the_book(args, assert)
    text = SaveFile.encode(name: "Kins", album: {}, sighted: {},
                           gear_film: 1, gear_air: 2, gear_suit: 1,
                           gear_mask: 2, gear_fins: 1)
    back = SaveFile.decode(text)

    assert.equal! back[:gear_film], 1
    assert.equal! back[:gear_air], 2
    assert.equal! back[:gear_suit], 1
    assert.equal! back[:gear_mask], 2
    assert.equal! back[:gear_fins], 1
  end

  # Through the game's own encoder, so a ladder added later cannot be left out
  # of the writing side while the format happily supports it.
  def test_everything_the_shop_sells_is_written_down(args, assert)
    game = a_diver(args, credits: 100_000)
    Game::GEAR.each { |item| game.buy_gear(item[:key]) }

    back = SaveFile.decode(game.encode_book)

    Game::GEAR.each do |item|
      assert.equal! back[:"gear_#{item[:key]}"], 1, "#{item[:name]} is in the book"
    end
  end

  def test_carrying_a_book_on_carries_the_kit(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.game_scene = "title"
    args.state.saved_book = SaveFile.blank.merge(
      name: "Kins", album: { "burgunder" => :gut }, sighted: { "burgunder" => true },
      gear_air: 2, gear_suit: 1
    )

    args.inputs.keyboard.key_down.space = true
    game.title_tick

    assert.equal! game.air_capacity, Game::AIR_STEPS[2], "his own bottle"
    assert.equal! game.suit_limit, Game::SUIT_STEPS[1], "and his own suit"
  end

  # A book written before there was any kit is not an error; that diver simply
  # owns nothing.
  def test_a_book_from_before_the_shop_still_opens(args, assert)
    back = SaveFile.decode("name Kins\nalbum burgunder gut")
    game = build_game(args)
    game.initialize_game(0)
    args.state.gear = { film: back[:gear_film] || 0, air: back[:gear_air] || 0,
                        suit: back[:gear_suit] || 0 }

    assert.equal! game.air_capacity, OXYGEN_MAX
  end
end

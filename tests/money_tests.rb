# Money. A photograph is not a score any more — a magazine pays for it, and what
# you fetch off the sea floor gets sold from the boat. The balance is the one
# number a freelance never stops knowing, so it is always on screen.
class MoneyTests
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

  def test_a_round_starts_broke(args, assert)
    game = at_the_boat(args)

    assert.equal! args.state.credits, 0, "nobody has paid you yet"
  end

  def test_developing_a_photo_is_what_pays(args, assert)
    game = at_the_boat(args)
    args.state.film_roll = [{ key: "burgunder", quality: :perfekt }]

    game.develop_film

    assert.equal! args.state.credits, game.photo_fee(Species["burgunder"], :perfekt),
                  "the magazine pays for the picture"
    assert.true! args.state.credits > 0, "and it is worth something"
  end

  # The film is worth nothing until it is developed — that is the whole reason
  # coming home matters.
  def test_an_undeveloped_roll_pays_nothing(args, assert)
    game = at_the_boat(args)
    args.state.film_roll = [{ key: "burgunder", quality: :perfekt }]

    assert.equal! args.state.credits, 0, "exposed film is not money"
  end

  # A better picture of the same animal earns the difference, not the fee over
  # again — otherwise shooting a fish badly and then well would pay twice for one
  # fish.
  def test_a_better_picture_pays_only_the_difference(args, assert)
    game = at_the_boat(args)
    args.state.film_roll = [{ key: "burgunder", quality: :unscharf }]
    game.develop_film
    poor = args.state.credits

    args.state.film_roll = [{ key: "burgunder", quality: :perfekt }]
    game.develop_film

    assert.equal! args.state.credits, game.photo_fee(Species["burgunder"], :perfekt),
                  "paid up to what the picture is now worth, not twice over"
    assert.true! args.state.credits > poor, "improving it did earn something"
  end

  # Which leaves a tidy invariant: what the photography has earned is exactly
  # what the book is worth.
  def test_the_book_is_worth_what_the_photos_earned(args, assert)
    game = at_the_boat(args)
    args.state.film_roll = [{ key: "burgunder", quality: :gut },
                            { key: "hornhering", quality: :perfekt }]

    game.develop_film

    assert.equal! args.state.credits, game.album_score
  end

  def test_the_balance_survives_drowning(args, assert)
    game = at_the_boat(args)
    args.state.film_roll = [{ key: "burgunder", quality: :perfekt }]
    game.develop_film
    earned = args.state.credits

    game.reset_game

    assert.equal! args.state.credits, earned, "the money is banked, like the book"
  end

  # --- selling what you found -----------------------------------------------

  def test_every_find_is_worth_something_and_they_differ(args, assert)
    values = Game::ITEM_KINDS.map { |kind| Game::ITEM_VALUES[kind] }

    assert.equal! values.compact.length, Game::ITEM_KINDS.length, "all five have a price"
    assert.true! values.uniq.length > 2, "and they are not all the same"
    assert.true! Game::ITEM_VALUES["jewel"] > Game::ITEM_VALUES["can"],
                 "jewellery beats a tin can"
  end

  def test_selling_takes_one_piece_and_pays_for_it(args, assert)
    game = at_the_boat(args)
    args.state.stash = ["can", "can", "jewel"]
    args.state.exchange_side = Game::HOLD_SIDE
    args.state.exchange_index = 0 # the cans, ordered like ITEM_KINDS

    game.sell_selected

    assert.equal! args.state.stash.length, 2, "one piece gone"
    assert.equal! args.state.credits, Game::ITEM_VALUES["can"], "and paid for"
  end

  def test_selling_the_last_of_a_kind_keeps_the_cursor_somewhere_real(args, assert)
    game = at_the_boat(args)
    args.state.stash = ["jewel"]
    args.state.exchange_side = Game::HOLD_SIDE
    args.state.exchange_index = 0

    game.sell_selected

    assert.equal! args.state.stash.length, 0
    assert.equal! args.state.exchange_index, 0, "the cursor didn't fall off the end"
  end

  # You sell what you have brought home and put away — not what is still in your
  # hands, which is the pack side of the screen.
  def test_you_cannot_sell_out_of_the_pack(args, assert)
    game = at_the_boat(args)
    args.state.inventory = ["jewel"]
    args.state.exchange_side = Game::PACK_SIDE
    args.state.exchange_index = 0

    game.sell_selected

    assert.equal! args.state.inventory.length, 1, "it stays in the pack"
    assert.equal! args.state.credits, 0, "and nobody paid for it"
  end

  def test_v_is_the_key_that_sells(args, assert)
    game = at_the_boat(args)
    args.state.stash = ["jewel"]
    game.toggle_home_menu(true)
    args.state.exchange_side = Game::HOLD_SIDE
    args.state.exchange_index = 0
    args.inputs.keyboard.key_down.v = true

    game.update_exchange

    assert.equal! args.state.credits, Game::ITEM_VALUES["jewel"], "V sold it"
  end

  # --- it has to be visible -------------------------------------------------

  def test_the_balance_is_on_screen_while_diving(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.game_scene = "area1"
    args.state.depth_y = -400
    args.state.credits = 137

    game.render_panel
    text = args.outputs.labels.flatten.map { |label| label[:text] }.join(" ")

    assert.true! text.include?("137"), "the balance is up there: #{text}"
  end

  def test_the_boat_screen_shows_the_balance_too(args, assert)
    game = at_the_boat(args)
    args.state.credits = 421
    game.toggle_home_menu(true)
    args.state.boat_page = :book

    game.home_menu_tick
    text = args.outputs.labels.flatten.map { |label| label[:text] }.join(" ")

    assert.true! text.include?("421"), "and on the book's page as well"
    assert.false! text.include?("Punkte"), "which no longer talks about points"
  end

  # --- and it survives the session ------------------------------------------

  def test_the_balance_travels_with_the_book(args, assert)
    text = SaveFile.encode(name: "Kins", album: { "burgunder" => :gut },
                           sighted: { "burgunder" => true }, seed: 1, credits: 512)

    assert.equal! SaveFile.decode(text)[:credits], 512, "the money comes back with him"
  end

  def test_carrying_a_book_on_carries_the_money(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.game_scene = "title"
    args.state.saved_book = { name: "Kins", album: { "burgunder" => :gut },
                              sighted: { "burgunder" => true }, seed: 4711, credits: 512 }

    args.inputs.keyboard.key_down.space = true
    game.title_tick

    assert.equal! args.state.credits, 512
  end

  def test_starting_over_starts_broke(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.game_scene = "title"
    args.state.saved_book = { name: "Kins", album: { "burgunder" => :gut },
                              sighted: { "burgunder" => true }, seed: 4711, credits: 512 }

    args.inputs.keyboard.key_down.n = true
    game.title_tick

    assert.equal! args.state.credits, 0, "a new diver has not been paid yet"
  end
end

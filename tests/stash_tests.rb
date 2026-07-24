# The exchange at the boat: moving finds out of the pack into the hold and back
# out again. The cursor and the transfers are plain state changes, so they test
# without faking a single key press.
class StashTests
  def build_game(args)
    game = Game.new
    game.args = args
    game
  end

  # At the boat, ready to sort through what you've brought up.
  def at_the_boat(args)
    game = build_game(args)
    game.initialize_game(0)
    game.spawn_at_surface
    args.state.game_scene = "area1"
    game
  end

  def test_the_hold_lists_one_stack_per_kind(args, assert)
    game = at_the_boat(args)
    args.state.stash = ["can", "bottle", "can", "can"]

    stacks = game.hold_stacks

    assert.equal! stacks.length, 2, "two kinds down there, however many of each"
    assert.equal! stacks[0], { kind: "bottle", count: 1 }, "in the order the kinds are listed"
    assert.equal! stacks[1], { kind: "can", count: 3 }, "three cans on one row"
  end

  def test_an_empty_hold_lists_nothing(args, assert)
    game = at_the_boat(args)

    assert.equal! game.hold_stacks, [], "nothing stored, nothing to show"
  end

  def test_stowing_the_selected_item_moves_it_into_the_hold(args, assert)
    game = at_the_boat(args)
    args.state.inventory = ["bottle", "jewel", "key"]
    game.reset_exchange
    game.move_exchange(0, 1) # down to the jewel

    game.transfer_selected

    assert.equal! args.state.inventory, ["bottle", "key"], "the jewel left the pack"
    assert.equal! args.state.stash, ["jewel"], "and lies in the hold"
  end

  def test_fetching_from_a_stack_takes_one_back_into_the_pack(args, assert)
    game = at_the_boat(args)
    args.state.stash = ["can", "can", "key"]
    game.reset_exchange
    game.move_exchange(1, 0) # over to the hold, first stack (cans)

    game.transfer_selected

    assert.equal! args.state.inventory, ["can"], "one can comes back up"
    assert.equal! game.hold_stacks[0], { kind: "can", count: 1 }, "the stack is one lighter"
    assert.equal! args.state.stash.length, 2, "and the hold keeps the rest"
  end

  def test_a_full_pack_takes_nothing_more_out_of_the_hold(args, assert)
    game = at_the_boat(args)
    args.state.inventory = ["shoe", "shoe", "shoe"]
    args.state.stash = ["jewel"]
    game.reset_exchange
    game.move_exchange(1, 0)

    game.transfer_selected

    assert.equal! args.state.inventory.length, Game::INVENTORY_MAX, "there's no room for it"
    assert.equal! args.state.stash, ["jewel"], "so it stays in the hold"
  end

  def test_an_empty_side_transfers_nothing(args, assert)
    game = at_the_boat(args)
    game.reset_exchange # empty pack, empty hold

    game.transfer_selected
    game.move_exchange(1, 0)
    game.transfer_selected

    assert.equal! args.state.inventory.length, 0, "nothing appears out of nowhere"
    assert.equal! args.state.stash.length, 0, "on either side"
  end

  def test_the_cursor_walks_the_rows_and_wraps(args, assert)
    game = at_the_boat(args)
    args.state.inventory = ["bottle", "jewel", "key"]
    game.reset_exchange

    game.move_exchange(0, 1)
    assert.equal! args.state.exchange_index, 1, "down a row"
    game.move_exchange(0, 1)
    game.move_exchange(0, 1)
    assert.equal! args.state.exchange_index, 0, "off the bottom it comes back to the top"
    game.move_exchange(0, -1)
    assert.equal! args.state.exchange_index, 2, "and up from the top wraps to the last row"
  end

  def test_the_cursor_switches_sides(args, assert)
    game = at_the_boat(args)
    args.state.inventory = ["bottle", "jewel"]
    args.state.stash = ["key"]
    game.reset_exchange
    game.move_exchange(0, 1) # second row of the pack

    game.move_exchange(1, 0)
    assert.equal! args.state.exchange_side, "hold", "right goes over to the hold"
    assert.equal! args.state.exchange_index, 0, "and lands on a row that's actually there"

    game.move_exchange(-1, 0)
    assert.equal! args.state.exchange_side, "pack", "left comes back to the pack"
  end

  def test_the_cursor_never_points_past_the_end(args, assert)
    game = at_the_boat(args)
    args.state.stash = ["key", "can"]
    game.reset_exchange
    game.move_exchange(1, 0)
    game.move_exchange(0, 1) # the second (last) stack

    game.transfer_selected # takes the last of that kind, so the row disappears

    assert.equal! game.hold_stacks.length, 1, "one stack left"
    assert.equal! args.state.exchange_index, 0, "and the cursor moved onto it"
  end

  def test_opening_the_menu_starts_the_cursor_on_the_pack(args, assert)
    game = at_the_boat(args)
    args.state.inventory = ["bottle", "key"]
    game.reset_exchange
    game.move_exchange(1, 0)
    game.move_exchange(0, 1)

    game.toggle_home_menu(true) # open the logbook fresh

    assert.equal! args.state.game_scene, "home_menu"
    assert.equal! args.state.exchange_side, "pack", "the cursor starts on what you carry"
    assert.equal! args.state.exchange_index, 0, "at the top row"
  end

  def test_a_new_round_empties_the_hold_and_resets_the_cursor(args, assert)
    game = at_the_boat(args)
    args.state.stash = ["key", "can"]
    game.move_exchange(1, 0)

    game.reset_game

    assert.equal! args.state.stash.length, 0, "a fresh round, a fresh hold"
    assert.equal! args.state.exchange_side, "pack", "and the cursor back where it starts"
  end

  def test_the_boat_menu_renders_the_exchange(args, assert)
    game = at_the_boat(args)
    args.state.inventory = ["bottle"]
    args.state.stash = ["can", "can", "key"]
    game.toggle_home_menu(true)
    game.move_exchange(1, 0)

    game.home_menu_tick

    assert.true! args.outputs.labels.length > 0, "the boat screen draws both sides"
  end
end

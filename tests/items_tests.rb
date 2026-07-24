class ItemsTests
  def build_game(args)
    game = Game.new
    game.args = args
    game
  end

  def test_a_round_scatters_hidden_items(args, assert)
    game = build_game(args)
    game.initialize_game(0)

    assert.equal! args.state.world_items.length, Game::ITEM_COUNT, "the sea is seeded with treasures"
    assert.equal! args.state.inventory.length, 0, "the pack starts empty"
    assert.equal! args.state.stash.length, 0, "and so does the stash"
  end

  def test_items_sit_on_the_open_sea_floor(args, assert)
    game = build_game(args)
    game.initialize_game(0)

    args.state.world_items.each do |item|
      sector = item[:x].idiv(SCREEN_WIDTH)
      assert.false! sector.zero?, "never on the home sector (#{item[:x]})"
      assert.false! game.island_sector?(sector), "never buried in an island (#{sector})"
      assert.true! Game::ITEM_KINDS.include?(item[:kind]), "a known kind (#{item[:kind]})"
      assert.equal! item[:y], WorldGenerator.floor_y_at(item[:x]) + Game::ITEM_LIFT,
                    "resting on the sand at #{item[:x]}"
      assert.false! item[:collected], "and still there to find"
    end
  end

  def test_items_do_not_stack_on_one_another(args, assert)
    game = build_game(args)
    game.initialize_game(0)

    xs = args.state.world_items.map { |item| item[:x] }
    assert.equal! xs.uniq.length, xs.length, "no two items share a spot"
  end

  def test_reach_finds_a_nearby_item_only(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    item = args.state.world_items.first

    args.state.diver_global_x = item[:x]
    args.state.depth_y = item[:y]
    assert.equal! game.item_in_reach, item, "the item under the diver is in reach"

    args.state.diver_global_x = item[:x] + Game::ITEM_REACH + 40
    assert.equal! game.item_in_reach, nil, "and out of reach once he swims off"
  end

  def test_a_collected_item_is_no_longer_in_reach(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    item = args.state.world_items.first
    args.state.diver_global_x = item[:x]
    args.state.depth_y = item[:y]

    item[:collected] = true

    assert.equal! game.item_in_reach, nil, "picked-up items don't linger"
  end

  def test_grabbing_an_item_moves_it_into_the_pack(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    item = args.state.world_items.first
    args.state.diver_global_x = item[:x]
    args.state.depth_y = item[:y]

    game.grab_item

    assert.true! item[:collected], "the item is taken off the sea floor"
    assert.equal! args.state.inventory, [item[:kind]], "and is now in the pack"
    assert.equal! game.item_in_reach, nil, "so it's no longer there to grab"
  end

  def test_the_pack_holds_no_more_than_three(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.inventory = ["shoe", "can", "jewel"] # already full
    item = args.state.world_items.first
    args.state.diver_global_x = item[:x]
    args.state.depth_y = item[:y]

    game.grab_item

    assert.false! item[:collected], "a full pack leaves the item where it lies"
    assert.equal! args.state.inventory.length, Game::INVENTORY_MAX, "still just three"
  end

  def test_grabbing_with_nothing_in_reach_does_nothing(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.diver_global_x = 50 # home sector, no items here
    args.state.depth_y = -300

    game.grab_item

    assert.equal! args.state.inventory.length, 0, "grabbing thin water yields nothing"
  end

  def test_storing_at_the_boat_empties_the_pack_into_the_hold(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.inventory = ["bottle", "jewel"]

    game.store_items

    assert.equal! args.state.inventory.length, 0, "the pack is empty again"
    assert.equal! args.state.stash, ["bottle", "jewel"], "and both are in the hold"

    args.state.inventory = ["can"]
    game.store_items
    assert.equal! args.state.stash, ["bottle", "jewel", "can"], "storing again adds to the hold"
  end

  def test_storing_an_empty_pack_does_nothing(args, assert)
    game = build_game(args)
    game.initialize_game(0)

    game.store_items

    assert.equal! args.state.stash.length, 0, "nothing to store, nothing stored"
  end

  def test_the_inventory_hud_renders(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.inventory = ["bottle", "key"] # two of three slots filled
    item = args.state.world_items.first
    args.state.diver_global_x = item[:x] # over an item, so the prompt path runs too
    args.state.depth_y = item[:y]

    game.render_inventory
    game.render_pickup_prompt

    assert.true! args.outputs.sprites.length > 0, "slots and the prompt draw without error"
  end

  def test_items_render_only_underwater(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    game.spawn_at_surface # head out at the surface

    assert.false! game.submerged_visible?, "at the surface the sea floor is hidden ..."
    before = args.outputs.sprites.length
    game.render_world_items
    assert.equal! args.outputs.sprites.length, before, "... so no items are drawn"

    args.state.depth_y = -400 # dived under
    args.state.diver_global_x = args.state.world_items.first[:x]
    game.center_camera
    game.render_world_items
    assert.true! args.outputs.sprites.length > before, "under water they show"
  end
end

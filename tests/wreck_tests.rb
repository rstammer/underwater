# The wreck at a hundred and fifty metres.
#
# The first hand-built world in the game. Everything else is a function of where
# you are — swim back and the same sea is computed again — which is what makes
# the sea endless and also what stops any of it from being a landmark. This one
# segment is *placed*, and that is the whole point of it.
class WreckTests
  def build_game(args)
    game = Game.new
    game.args = args
    game
  end

  def wreck(args, game)
    game.initialize_game(0)
    game.world_at(WreckWorld::SECTOR)
  end

  # --- where it is -----------------------------------------------------------

  def test_the_wreck_overrides_generation_at_its_sector(args, assert)
    game = build_game(args)
    world = wreck(args, game)

    assert.equal! world.biome.name, "Wrack", "the segment is the wreck's, not the generator's"
    assert.false! world.roof.nil?, "and it has a hull on it"
  end

  # It is out of reach on the suit you start with, which is the reason it is
  # this deep. A wreck at seventy metres is scenery; this one is a purchase.
  def test_it_lies_below_the_starting_suit(args, assert)
    depth = (WATERLINE_Y - WreckWorld.floor_y).idiv(PIXELS_PER_METRE)

    assert.true! depth > SUIT_DEPTH_LIMIT,
                 "at #{depth} m it is inside what the first suit is rated for"
    assert.true! depth >= 140, "and it is properly deep (#{depth} m)"
  end

  # The second suit has to actually reach it, or it is a wall rather than a goal.
  def test_the_next_suit_reaches_it(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.gear = { suit: 1 }
    depth = (WATERLINE_Y - WreckWorld.floor_y).idiv(PIXELS_PER_METRE)

    assert.true! game.suit_limit > depth,
                 "the second suit is rated for #{game.suit_limit} m and the wreck is at #{depth} m"
  end

  # --- the ship itself -------------------------------------------------------

  def test_the_hull_is_solid_and_the_sea_around_it_is_not(args, assert)
    game = build_game(args)
    world = wreck(args, game)

    mid = ((WreckWorld::BOW + WreckWorld::BREAK_FROM) / 2) * World::COLUMN_WIDTH
    deck_y = world.floor_y_at(mid) + WreckWorld::HOLD_H + WreckWorld::DECK_H / 2
    assert.true! world.solid_at?(mid, deck_y), "the deck is over the hold"
    assert.false! world.solid_at?(mid, world.floor_y_at(mid) + WreckWorld::HOLD_H / 2),
                  "and the hold under it is water"

    open_sea = 4 * World::COLUMN_WIDTH
    assert.false! world.solid_at?(open_sea, world.floor_y_at(open_sea) + 60),
                  "and the water beside the ship is open"
  end

  # A hold you can swim through: water between the mud and the underside of the
  # deck, the whole length of the ship.
  def test_there_is_a_hold_inside_it(args, assert)
    game = build_game(args)
    world = wreck(args, game)

    inside = (WreckWorld::BOW + 12...WreckWorld::BREAK_FROM).select do |col|
      x = col * World::COLUMN_WIDTH
      slabs = world.slabs_at(x)
      next false if slabs.empty?

      slabs.first[:ceiling] - world.floor_y_at(x) >= 24 # room to swim
    end

    assert.true! inside.length > 20, "only #{inside.length} columns of hold"
  end

  # And exactly one way in. A hull you can swim through anywhere is a fence.
  def test_the_only_way_in_is_the_break(args, assert)
    game = build_game(args)
    world = wreck(args, game)

    open = (WreckWorld::BOW..WreckWorld::STERN).select do |col|
      world.slabs_at(col * World::COLUMN_WIDTH).empty?
    end

    assert.false! open.empty?, "there is a way in"
    # The gash, plus the tapered columns at bow and stern where the deck comes
    # down to the mud — those are ends, not doors.
    gash = (WreckWorld::BREAK_FROM..WreckWorld::BREAK_TO).to_a
    assert.true! gash.all? { |col| open.include?(col) }, "the gash is open"
  end

  # Air under the highest part of the deck: somewhere to put your head up, a
  # hundred and fifty metres down. It is the reason to go *in* rather than to
  # photograph it from outside.
  def test_there_is_air_trapped_under_the_deck(args, assert)
    game = build_game(args)
    world = wreck(args, game)

    assert.false! world.air_pockets.empty?, "there is a pocket"
    pocket = world.air_pockets.first
    x = pocket[:x] + pocket[:w] / 2
    assert.false! world.air_line_at(x).nil?, "and it has a surface to break"
    # The deck is what traps it: solid rock directly over the pocket.
    assert.true! world.solid_at?(x, world.floor_y_at(x) + WreckWorld::HOLD_H + 4),
                 "with the deck over it"
    assert.true! pocket[:y] + pocket[:h] <= world.floor_y_at(x) + WreckWorld::HOLD_H,
                 "and the air stops where the deck starts"
  end

  # --- that it reads as a ship -----------------------------------------------

  # The stem is the tell. A hull that stops flush at the deck is a barge, and the
  # first attempt ran the stem and the taper on the same columns, which came out
  # as a notch — a spike, a dip, then the deck.
  def test_the_bow_stands_up_and_falls_away_aft(args, assert)
    game = build_game(args)
    world = wreck(args, game)

    tops = (0...WreckWorld::NOSE).map do |i|
      col = WreckWorld::BOW + i
      world.slabs_at(col * World::COLUMN_WIDTH).map { |s| s[:crown] }.max
    end

    assert.equal! tops.max, tops.first, "the very bow is the highest thing forward"
    # ... and from there it only ever comes down, with no dip in between.
    tops.each_cons(2) do |a, b|
      assert.true! b <= a + 1, "the sheer rises again behind the stem"
    end
  end

  def test_the_mast_is_snapped_off(args, assert)
    game = build_game(args)
    world = wreck(args, game)

    stump = world.slabs_at(WreckWorld::MAST_COL * World::COLUMN_WIDTH)
    deck_top = world.floor_y_at(WreckWorld::MAST_COL * World::COLUMN_WIDTH) +
               WreckWorld::HOLD_H + WreckWorld::DECK_H
    standing = stump.select { |s| s[:crown] > deck_top + 20 }

    assert.false! standing.empty?, "there is a stump still standing"
    assert.true! standing.first[:crown] - deck_top < 200,
                 "and it is a stump, not a mast"

    # The length that came off it lies forward of the stump, sloping down.
    lying = [WreckWorld::FALLEN_FROM + 2, WreckWorld::FALLEN_TO - 2].map do |col|
      world.slabs_at(col * World::COLUMN_WIDTH).map { |s| s[:crown] }.max
    end
    assert.true! lying.first < lying.last, "the fallen spar slopes down towards the bow"
  end

  def test_there_is_a_gun_on_the_deck(args, assert)
    game = build_game(args)
    world = wreck(args, game)

    gun = world.decorations.find { |d| d[:kind] == "cannon" }
    assert.false! gun.nil?, "there is a gun"
    assert.false! Game::DECOR_SPRITES["cannon"].nil?, "and the renderer can draw it"

    deck_top = world.floor_y_at(gun[:x]) + WreckWorld::HOLD_H + WreckWorld::DECK_H
    assert.equal! gun[:y], deck_top, "it is lying on the deck, not in the mud"
  end

  # It is a place, so it has to look like one: its own water, not the deep sea's.
  def test_it_has_its_own_water(args, assert)
    game = build_game(args)
    world = wreck(args, game)

    assert.false! world.biome.shark, "what is down there is the ship"
    assert.false! world.biome.name == Biome::DEEP.name, "and it is not just the deep"
  end

  # The sea around it is still the sea: fish, crabs, and things growing on the
  # hull. A wreck in empty water is a model, not a place.
  def test_the_wreck_is_populated(args, assert)
    game = build_game(args)
    world = wreck(args, game)

    assert.true! world.biome.fish_count > 0, "there are fish round it"
    assert.false! world.decorations.empty?, "and something has grown on it"

    game.spawn_fauna(world)
    assert.false! args.state.fish.empty?, "the swarm actually spawns down here"
  end
end

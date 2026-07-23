class IslandTests
  def build_game(args)
    game = Game.new
    game.args = args
    game
  end

  # Each island is built from its own segment, so tests have to ask for the one
  # in the sector they're standing in.
  def island_for(sector)
    IslandWorld.new(WorldGenerator.generate(sector))
  end

  def island
    island_for(4)
  end

  def test_the_island_breaks_the_surface(args, assert)
    built = island.build
    crowns = (island.first_column...island.last_column).map { |col| built.roof[col][:crown] }

    assert.true! crowns.max > WATERLINE_Y + 100, "the summit rises well out of the sea"
    assert.true! crowns.min > WATERLINE_Y, "and even the shore stands clear of the water"
  end

  # A plain dome would be boring: the skyline steps in plateaus and has more than
  # one shoulder to it.
  def test_the_skyline_is_not_a_smooth_dome(args, assert)
    built = island.build
    crowns = (island.first_column...island.last_column).map { |col| built.roof[col][:crown] }

    plateaus = (1...crowns.length).count { |i| crowns[i] == crowns[i - 1] }
    assert.true! plateaus > crowns.length / 3, "the crown should sit in flat steps (#{plateaus})"

    rises = (1...crowns.length).count { |i| crowns[i] > crowns[i - 1] }
    falls = (1...crowns.length).count { |i| crowns[i] < crowns[i - 1] }
    assert.true! rises > 3 && falls > 3, "and go up and down more than once (#{rises}/#{falls})"
  end

  # Islands are rolled from their own index, so no two are the same lump of rock.
  def test_islands_differ_from_one_another(args, assert)
    a = island_for(3)
    b = island_for(-7)
    shape = lambda do |isle|
      world = isle.build
      (isle.first_column...isle.last_column).map { |col| world.roof[col][:crown] }
    end

    assert.true! [a.span, a.peak] != [b.span, b.peak] || shape.call(a) != shape.call(b),
                 "two islands should not share a silhouette"
  end

  # The segment borders must stay exactly as generated, or the island tears a
  # seam into its neighbours.
  def test_the_island_leaves_the_segment_borders_alone(args, assert)
    plain = WorldGenerator.generate(4)
    built = island.build

    assert.equal! built.floor.first, plain.floor.first
    assert.equal! built.floor.last, plain.floor.last
    assert.equal! built.roof.first, nil, "open water at the border"
    assert.equal! built.roof.last, nil
  end

  # A corridor runs the whole way through, wide enough to swim in.
  def test_a_tunnel_runs_through_the_island(args, assert)
    built = island.build

    (island.first_column...island.last_column).each do |col|
      rock = built.roof[col]
      assert.false! rock.nil?, "column #{col} should be part of the island"
      gap = rock[:ceiling] - built.floor[col]
      assert.true! gap >= Diver::HEIGHT * 2, "the tunnel must stay swimmable (gap #{gap} at #{col})"
      assert.true! rock[:crown] > rock[:ceiling], "and the rock above it has thickness"
    end
  end

  # The tunnel meets the sea floor flush at both mouths, so there is no step to
  # climb on the way in or out.
  def test_the_tunnel_mouths_meet_the_sea_floor(args, assert)
    plain = WorldGenerator.generate(4)
    built = island.build

    assert.equal! built.floor[island.first_column], plain.floor[island.first_column],
                  "flush at the left mouth"
    last = island.last_column - 1
    assert.true! (built.floor[last] - plain.floor[last]).abs <= WorldGenerator::FLOOR_STEP,
                 "and flush at the right mouth"
  end

  def test_plants_stand_on_the_island_and_gulls_over_the_water(args, assert)
    built = island.build

    built.decorations.each do |d|
      col = d[:x].idiv(World::COLUMN_WIDTH)
      next unless island.island_column?(col)
      next if d[:kind] == "gull" # those fly

      if d[:y] > WATERLINE_Y
        assert.equal! d[:y], built.roof[col][:crown], "#{d[:kind]} stands on the crown"
      else
        assert.equal! d[:y], built.floor[col], "#{d[:kind]} grows on the tunnel floor"
      end
    end

    in_cave = built.decorations.select { |d| island.island_column?(d[:x].idiv(World::COLUMN_WIDTH)) && d[:y] < WATERLINE_Y }
    assert.true! in_cave.length > 0, "the cave isn't barren either"

    kinds = built.decorations.map { |d| d[:kind] }
    assert.true! kinds.include?("palm") || kinds.include?("bush"), "the island is not bare rock"

    gulls = built.decorations.select { |d| d[:kind] == "gull" }
    assert.true! gulls.length >= 2, "gulls hang around the coast"
    off_shore = gulls.map do |gull|
      col = gull[:x].idiv(World::COLUMN_WIDTH)
      col < island.first_column ? island.first_column - col : col - island.last_column
    end
    assert.true! off_shore.max * World::COLUMN_WIDTH > 400,
                 "some range far enough out to give the island away early (#{off_shore.max} columns)"
    assert.true! off_shore.min >= 0, "and none of them sit over the rock"
    gulls.each do |gull|
      assert.true! gull[:y] > WATERLINE_Y, "a gull flies above the water (#{gull[:y]})"
      assert.true! gull[:y] < WATERLINE_Y + 300, "and low enough to be in frame (#{gull[:y]})"
    end
  end

  # Where the islands land is rolled per round: never on the home sector, never
  # twice on the same one, and always one of them close enough to stumble into.
  def test_the_islands_land_near_home_but_not_on_it(args, assert)
    game = build_game(args)

    10.times do
      sectors = game.roll_island_sectors
      assert.equal! sectors.length, ISLAND_COUNT
      assert.equal! sectors.uniq.length, ISLAND_COUNT, "each island gets its own sector"
      sectors.each do |sector|
        assert.false! sector.zero?, "never on top of the boat"
        assert.true! sector.abs <= ISLAND_MAX_SECTOR, "still within reach (#{sector})"
      end
      near = sectors.select { |sector| sector.abs <= ISLAND_NEAR_SECTOR }
      assert.true! near.length >= 1, "one island is always close to home (#{sectors.inspect})"
    end
  end

  def test_islands_are_stamped_onto_their_sectors_only(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.island_sectors = [3, -5]

    assert.false! game.world_for(3).roof.nil?, "an island sector has rock overhead"
    assert.false! game.world_for(-5).roof.nil?, "so does the other one"
    assert.equal! game.world_for(4).roof, nil, "their neighbours are open sea"
  end

  # World x of the middle of the air chamber of the island in `sector`.
  def chamber_x(sector)
    isle = island_for(sector)
    col = (isle.chamber_first + isle.chamber_last).idiv(2)
    sector * SCREEN_WIDTH + col * World::COLUMN_WIDTH
  end

  def test_the_chamber_traps_air_under_its_roof(args, assert)
    built = island.build

    # Columns are array indices: in DragonRuby `Integer / Integer` is a Float,
    # and a fractional column silently reads the wrong one.
    assert.equal! island.chamber_first, island.chamber_first.to_i, "columns stay whole numbers"
    air = built.air_pockets.first
    ceiling = built.roof[island.chamber_first][:ceiling]

    assert.true! built.air_at?(air[:x] + 10, ceiling - 10), "air right under the dome"
    assert.false! built.air_at?(air[:x] + 10, air[:y] - 10), "water below its surface"
    assert.false! built.air_at?(air[:x] - 200, ceiling - 10), "and none out in the tunnel"
  end

  # Every island's corridor runs differently: it dips or humps on its way through,
  # squeezes in places and opens out in others — but it always stays swimmable.
  def test_tunnels_differ_but_stay_swimmable(args, assert)
    profiles = []

    [2, -4, 7, -9].each do |sector|
      isle = island_for(sector)
      world = isle.build
      cols = (isle.first_column...isle.last_column)
      gaps = cols.map { |col| world.roof[col][:ceiling] - world.floor[col] }

      assert.true! gaps.min >= IslandWorld::MIN_GAP,
                   "sector #{sector} has a gap of #{gaps.min} — the diver is #{Diver::HEIGHT * 2} tall"
      assert.true! gaps.max - gaps.min > 60, "sector #{sector}'s corridor should vary in height"
      profiles << cols.map { |col| world.floor[col] }
    end

    assert.equal! profiles.uniq.length, profiles.length, "no two tunnels run the same"
  end

  # Wherever a chamber lifts the roof, the air under it is really under rock.
  def test_every_chamber_holds_its_air_under_the_roof(args, assert)
    [2, -4, 7, -9].each do |sector|
      isle = island_for(sector)
      world = isle.build

      world.air_pockets.each do |air|
        first = air[:x].idiv(World::COLUMN_WIDTH)
        last = (air[:x] + air[:w]).idiv(World::COLUMN_WIDTH)
        (first...last).each do |col|
          assert.equal! world.roof[col][:ceiling], air[:y] + air[:h],
                        "sector #{sector}: the air reaches exactly up to the rock at column #{col}"
          assert.true! world.floor[col] < air[:y], "and floats above the corridor floor"
        end
      end
    end
  end

  # The whole point of the chamber: half way through the cave you can surface and
  # fill your lungs, so the far side is reachable.
  def test_the_diver_breathes_in_the_chamber(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.island_sectors = [1]
    args.state.diver_global_x = chamber_x(1)
    args.state.depth_y = 99_999 # float up as far as the rock allows
    game.update_depth_and_camera

    assert.true! game.breathing?, "his head is in the trapped air"
    assert.false! game.at_open_surface?, "but he is nowhere near daylight"

    args.state.oxygen = 20
    game.update_oxygen
    assert.true! args.state.oxygen > 20, "so his air refills down here"
  end

  # Deeper in the water of the tunnel there is nothing to breathe.
  def test_the_tunnel_itself_has_no_air(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.island_sectors = [1]
    args.state.diver_global_x = SCREEN_WIDTH + island_for(1).first_column * World::COLUMN_WIDTH + 40
    args.state.depth_y = -99_999 # down on the tunnel floor
    game.update_depth_and_camera

    assert.false! game.breathing?, "the tunnel is flooded"
  end

  # The island is solid to everything, not just to the diver.
  def test_the_shark_turns_around_at_the_island(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.island_sectors = [1]
    args.state.diver_global_x = SCREEN_WIDTH + 100 # the diver is in the island's sector
    rock_starts = island_for(1).first_column * World::COLUMN_WIDTH
    # ... at a depth where the island is solid rock but the open sea is not
    args.state.dark_shark = { x: rock_starts - 120, y: WATERLINE_Y - 100, dir: 1 }

    60.times { game.update_shark(0) }

    shark_x = SCREEN_WIDTH + args.state.dark_shark.x
    assert.false! game.solid_at?(shark_x, args.state.dark_shark.y),
                  "the shark never ends up inside the island"
    assert.equal! args.state.dark_shark.dir, -1, "it turned around at the rock"
    assert.true! args.state.dark_shark.x < rock_starts, "and stayed on its side of it"
  end

  # Fish belong to the water they were spawned in. Left to drift they used to
  # swim straight into the island — through solid rock.
  def test_fish_never_swim_into_the_rock(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.island_sectors = [1]
    args.state.diver_global_x = SCREEN_WIDTH + 100
    world = game.world_for(1)

    game.spawn_fauna(world)
    900.times { args.state.fish.each { |fish| fish.tick(args, 0) } }

    args.state.fish.each do |fish|
      spot = fish.to_h
      assert.false! world.solid_at?(spot[:x], spot[:y]),
                    "a fish ended up inside the rock at #{spot[:x].to_i},#{spot[:y].to_i}"
    end
  end

  def test_renders_the_island_without_error(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.island_sectors = [1]
    args.state.diver_global_x = SCREEN_WIDTH + 60 # in the water beside the island
    args.state.depth_y = WATERLINE_Y
    game.center_camera
    args.state.game_scene = "area2"

    game.area2_tick

    assert.true! true, "a frame with the island renders"
  end
end

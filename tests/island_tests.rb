class IslandTests
  def build_game(args)
    game = Game.new
    game.args = args
    game
  end

  def island
    IslandWorld.build(WorldGenerator.generate(4))
  end

  def island_columns
    (IslandWorld.first_column...IslandWorld.last_column)
  end

  def test_the_island_breaks_the_surface(args, assert)
    crowns = island_columns.map { |col| island.roof[col][:crown] }

    assert.true! crowns.max > WATERLINE_Y + 100, "the summit rises well out of the sea"
    assert.true! crowns.min > WATERLINE_Y, "and even the shore stands clear of the water"
  end

  # The segment borders must stay exactly as generated, or the island tears a
  # seam into its neighbours.
  def test_the_island_leaves_the_segment_borders_alone(args, assert)
    plain = WorldGenerator.generate(4)
    built = island

    assert.equal! built.floor.first, plain.floor.first
    assert.equal! built.floor.last, plain.floor.last
    assert.equal! built.roof.first, nil, "open water at the border"
    assert.equal! built.roof.last, nil
  end

  # A corridor runs the whole way through, wide enough to swim in.
  def test_a_tunnel_runs_through_the_island(args, assert)
    built = island

    island_columns.each do |col|
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
    built = island
    first = IslandWorld.first_column
    last = IslandWorld.last_column

    assert.equal! built.floor[first], plain.floor[first], "flush at the left mouth"
    assert.true! (built.floor[last - 1] - plain.floor[last - 1]).abs <= WorldGenerator::FLOOR_STEP,
                 "and flush at the right mouth"
  end

  def test_decorations_do_not_sit_inside_the_rock(args, assert)
    built = island

    built.decorations.each do |d|
      col = d[:x].idiv(World::COLUMN_WIDTH)
      next unless island_columns.include?(col)

      assert.equal! d[:y], built.roof[col][:crown], "only summit rocks stand on the island (#{d[:kind]})"
    end
  end

  # Where the island lands is rolled per round: far enough from home to be a
  # find, close enough to reach.
  def test_the_island_lands_near_home_but_not_on_it(args, assert)
    game = build_game(args)

    20.times do
      sector = game.roll_island_sector
      assert.true! sector.abs >= ISLAND_MIN_SECTOR, "not right next to the boat (#{sector})"
      assert.true! sector.abs <= ISLAND_MAX_SECTOR, "still within reach (#{sector})"
    end
  end

  def test_the_island_is_stamped_onto_its_sector_only(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.island_sector = 3

    assert.false! game.world_for(3).roof.nil?, "the island sector has rock overhead"
    assert.equal! game.world_for(4).roof, nil, "its neighbour is open sea"
  end

  # World x of the middle of the air chamber, for an island in sector `sector`.
  def chamber_x(sector)
    col = (IslandWorld.chamber_first + IslandWorld.chamber_last) / 2
    sector * SCREEN_WIDTH + col * World::COLUMN_WIDTH
  end

  def test_the_chamber_traps_air_under_its_roof(args, assert)
    built = island
    air = built.air_pockets.first
    ceiling = built.roof[IslandWorld.chamber_first][:ceiling]

    assert.true! built.air_at?(air[:x] + 10, ceiling - 10), "air right under the dome"
    assert.false! built.air_at?(air[:x] + 10, air[:y] - 10), "water below its surface"
    assert.false! built.air_at?(air[:x] - 200, ceiling - 10), "and none out in the tunnel"
  end

  # The whole point of the chamber: half way through the cave you can surface and
  # fill your lungs, so the far side is reachable.
  def test_the_diver_breathes_in_the_chamber(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.island_sector = 1
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
    args.state.island_sector = 1
    args.state.diver_global_x = 1280 + IslandWorld.first_column * World::COLUMN_WIDTH + 40
    args.state.depth_y = -99_999 # down on the tunnel floor
    game.update_depth_and_camera

    assert.false! game.breathing?, "the tunnel is flooded"
  end

  def test_renders_the_island_without_error(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.island_sector = 1
    args.state.diver_global_x = SCREEN_WIDTH + SCREEN_WIDTH / 2 # in front of the island
    args.state.depth_y = 300
    game.center_camera
    args.state.game_scene = "area2"

    game.area2_tick

    assert.true! true, "a frame with the island renders"
  end
end

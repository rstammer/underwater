class IslandTests
  def build_game(args)
    game = Game.new
    game.args = args
    game
  end

  # An island is wider than a segment, so it is rolled from its home sector and
  # stamped onto every segment it reaches into.
  def island_for(sector)
    IslandWorld.new(WorldGenerator.generate(sector), sector)
  end

  def island
    island_for(4)
  end

  # Build every segment the island touches, so a test can ask about it in world
  # coordinates instead of chasing it across per-segment columns.
  def slices_of(isle)
    slices = {}
    from = (isle.first_x - IslandWorld::REACH).idiv(SCREEN_WIDTH)
    to = (isle.last_x + IslandWorld::REACH - 1).idiv(SCREEN_WIDTH)
    (from..to).each do |index|
      slices[index] = IslandWorld.build(WorldGenerator.generate(index), isle.sector)
    end
    slices
  end

  def floor_at(slices, world_x)
    slices[world_x.idiv(SCREEN_WIDTH)].floor_y_at(world_x % SCREEN_WIDTH)
  end

  def slabs_at(slices, world_x)
    slices[world_x.idiv(SCREEN_WIDTH)].slabs_at(world_x % SCREEN_WIDTH)
  end

  # Column by column from one world x to another (mruby has no Range#step).
  def xs_between(from, to)
    xs = []
    x = from
    while x < to
      xs << x
      x += World::COLUMN_WIDTH
    end
    xs
  end

  # Every world x the island covers, stepping a column at a time.
  def island_xs(isle)
    xs_between(isle.first_x, isle.last_x)
  end

  def test_an_island_is_wider_than_a_segment(args, assert)
    [4, -6, 9].each do |sector|
      isle = island_for(sector)
      assert.true! isle.span > SCREEN_WIDTH,
                   "sector #{sector}: #{isle.span} px of island against a #{SCREEN_WIDTH} px segment"
      assert.true! slices_of(isle).length >= 2, "so it lands on more than one segment"
    end
  end

  def test_the_island_breaks_the_surface(args, assert)
    isle = island
    slices = slices_of(isle)
    crowns = island_xs(isle).map { |x| slabs_at(slices, x).map { |s| s[:crown] }.max }

    assert.true! crowns.max > WATERLINE_Y + 100, "the summit rises well out of the sea"
    assert.true! crowns.min > WATERLINE_Y, "and even the shore stands clear of the water"
  end

  # The whole point of building it in world coordinates: two segments that each
  # carry a piece of the same island have to agree at the border, or there is a
  # visible seam and a wall the diver bumps into mid-tunnel.
  def test_the_slices_line_up_across_a_segment_border(args, assert)
    isle = island
    slices = slices_of(isle)
    borders = slices.keys.sort[1..-1] # every border inside the island

    assert.true! borders.length >= 1, "the island really does cross a border"
    borders.each do |index|
      border = index * SCREEN_WIDTH
      # The columns either side of the border are built by *different* segments.
      # Each has to come out as the island's own shape function says, or the two
      # halves disagree and the seam is a wall in the middle of the tunnel.
      [border - World::COLUMN_WIDTH, border].each do |x|
        assert.equal! floor_at(slices, x), isle.tunnel_floor_y_at(x),
                      "the tunnel floor at #{x} is the island's, whichever segment built it"
        assert.equal! slabs_at(slices, x).map { |s| s[:crown] }.max, isle.crown_y_at(x),
                      "and so is the skyline at #{x}"
      end
    end
  end

  # Off the shores, rugged rocks break the surface: their top stands clear of the
  # water, their base is rooted below it, and none of them sits on the island.
  def test_skerries_break_the_surface_off_the_shore(args, assert)
    found = 0
    slices_of(island).each_value do |world|
      isle = IslandWorld.new(world, island.sector)
      isle.skerry_columns.each do |col, rock|
        found += 1
        assert.false! isle.island_column?(col), "a skerry stands apart from the island (#{col})"
        assert.true! rock[:crown] > WATERLINE_Y, "its top breaks the surface (#{rock[:crown]})"
        assert.true! rock[:crown] < WATERLINE_Y + IslandWorld::SHORE_HEIGHT,
                     "but stays low, no summit (#{rock[:crown]})"
        assert.true! rock[:ceiling] < WATERLINE_Y, "its base is under the water (#{rock[:ceiling]})"
        assert.equal! world.roof[col], [rock], "and it is really in the world's rock"
      end
    end
    assert.true! found >= 4, "there are rocks out in the water off both shores (#{found})"
  end

  # The skerry is a real wall at the surface — you can't swim straight through it —
  # but there is open water beneath to dive under and pass.
  def test_a_surface_swimmer_is_stopped_by_a_skerry(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.island_sectors = [1]
    args.state.world_cache = {} # initialize_game already cached segments for the rolled sectors
    isle = island_for(1)
    world_x = skerry_x(isle)
    args.state.diver_global_x = world_x

    args.state.depth_y = WATERLINE_Y - SURFACE_FLOAT_DEPTH # up at the surface
    assert.true! game.blocked?(world_x), "the rock blocks him at the surface"

    args.state.depth_y = WATERLINE_Y - IslandWorld::SKERRY_DEPTH - Diver::HEIGHT * 3 # dived under it
    assert.false! game.blocked?(world_x), "but there's open water to slip under"
  end

  # World x of a skerry that really made it into a built segment.
  def skerry_x(isle)
    found = nil
    slices_of(isle).each do |index, world|
      next if found

      col = IslandWorld.new(world, isle.sector).skerry_columns.keys.first
      found = index * SCREEN_WIDTH + col * World::COLUMN_WIDTH if col
    end
    found
  end

  # A plain dome would be boring: the skyline steps in plateaus and has more than
  # one shoulder to it.
  def test_the_skyline_is_not_a_smooth_dome(args, assert)
    isle = island
    slices = slices_of(isle)
    crowns = island_xs(isle).map { |x| slabs_at(slices, x).map { |s| s[:crown] }.max }

    plateaus = (1...crowns.length).count { |i| crowns[i] == crowns[i - 1] }
    assert.true! plateaus > crowns.length / 3, "the crown should sit in flat steps (#{plateaus})"

    rises = (1...crowns.length).count { |i| crowns[i] > crowns[i - 1] }
    falls = (1...crowns.length).count { |i| crowns[i] < crowns[i - 1] }
    assert.true! rises > 3 && falls > 3, "and go up and down more than once (#{rises}/#{falls})"
  end

  # Islands are rolled from their own home sector, so no two are the same rock.
  def test_islands_differ_from_one_another(args, assert)
    a = island_for(3)
    b = island_for(-7)
    shape = ->(isle) { island_xs(isle).map { |x| isle.crown_y_at(x) } }

    assert.true! [a.span, a.peak] != [b.span, b.peak] || shape.call(a) != shape.call(b),
                 "two islands should not share a silhouette"
  end

  # A corridor runs the whole way through, wide enough to swim in.
  def test_a_tunnel_runs_through_the_island(args, assert)
    isle = island
    slices = slices_of(isle)

    island_xs(isle).each do |x|
      slabs = slabs_at(slices, x)
      assert.false! slabs.empty?, "world x #{x} should be part of the island"
      rock = slabs.first
      gap = rock[:ceiling] - floor_at(slices, x)
      assert.true! gap >= Diver::HEIGHT * 2, "the tunnel must stay swimmable (gap #{gap} at #{x})"
      assert.true! rock[:crown] > rock[:ceiling], "and the rock above it has thickness"
    end
  end

  # The tunnel meets the sea floor flush at both mouths, so there is no step to
  # climb on the way in or out — even though the mouths now lie in segments of
  # their own, far from the island's home.
  def test_the_tunnel_mouths_meet_the_sea_floor(args, assert)
    isle = island
    slices = slices_of(isle)

    [isle.first_x, isle.last_x - World::COLUMN_WIDTH].each do |x|
      sand = WorldGenerator.floor_y_at(x)
      assert.true! (floor_at(slices, x) - sand).abs <= WorldGenerator::FLOOR_STEP,
                   "flush with the sea floor at the mouth (#{floor_at(slices, x)} against #{sand})"
    end
  end

  def test_plants_stand_on_the_island_and_gulls_over_the_water(args, assert)
    isle = island
    slices = slices_of(isle)
    decor = []
    slices.each do |index, world|
      world.decorations.each { |d| decor << d.merge(wx: index * SCREEN_WIDTH + d[:x]) }
    end

    decor.each do |d|
      next unless d[:wx] >= isle.first_x && d[:wx] < isle.last_x
      next if d[:kind] == "gull" # those fly

      if d[:y] > WATERLINE_Y
        assert.equal! d[:y], slabs_at(slices, d[:wx]).map { |s| s[:crown] }.max,
                      "#{d[:kind]} stands on the crown"
      else
        assert.equal! d[:y], floor_at(slices, d[:wx]), "#{d[:kind]} grows on the tunnel floor"
      end
    end

    in_cave = decor.select { |d| d[:wx] >= isle.first_x && d[:wx] < isle.last_x && d[:y] < WATERLINE_Y }
    assert.true! in_cave.length > 0, "the cave isn't barren either"

    kinds = decor.map { |d| d[:kind] }
    assert.true! kinds.include?("palm") || kinds.include?("bush"), "the island is not bare rock"
    assert.equal! kinds.count { |k| k == "flag" } <= 1, true, "at most one flag on the whole island"

    gulls = decor.select { |d| d[:kind] == "gull" }
    assert.true! gulls.length >= 2, "gulls hang around the coast"
    off_shore = gulls.map do |gull|
      gull[:wx] < isle.first_x ? isle.first_x - gull[:wx] : gull[:wx] - isle.last_x
    end
    assert.true! off_shore.max > 400, "some range far enough out to give the island away early"
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
        assert.false! IslandWorld.covers?(sector, 0), "and never reaching into home (#{sector})"
      end
      near = sectors.select { |sector| sector.abs <= ISLAND_NEAR_SECTOR }
      assert.true! near.length >= 1, "one island is always close to home (#{sectors.inspect})"
    end
  end

  # An island reaches into its neighbours now — that's the point — but the open
  # sea further out stays open sea.
  def test_an_island_reaches_into_its_neighbours_but_no_further(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.island_sectors = [3, -5]
    args.state.world_cache = {} # initialize_game already cached segments for the rolled sectors

    assert.false! game.world_for(3).roof.nil?, "an island sector has rock overhead"
    assert.true! game.island_here?(2) || game.island_here?(4), "and it spills into a neighbour"
    far = (-20..20).find { |i| !game.island_here?(i) }
    assert.equal! game.world_for(far).roof, nil, "far enough out it is open sea again (#{far})"
  end

  # World x of the middle of an island's first air chamber.
  def chamber_x(sector)
    chamber = island_for(sector).chambers.first
    (chamber[:from] + chamber[:to]).idiv(2)
  end

  def test_the_chamber_traps_air_under_its_roof(args, assert)
    isle = island
    slices = slices_of(isle)
    chamber = isle.chambers.first
    mid = (chamber[:from] + chamber[:to]).idiv(2)
    world = slices[mid.idiv(SCREEN_WIDTH)]
    local = mid % SCREEN_WIDTH

    assert.true! world.air_at?(local, chamber[:ceiling] - 10), "air right under the dome"
    assert.false! world.air_at?(local, chamber[:ceiling] - IslandWorld::AIR_DEPTH - 10),
                  "water below its surface"
    outside = chamber[:from] - 300
    assert.false! slices[outside.idiv(SCREEN_WIDTH)].air_at?(outside % SCREEN_WIDTH, chamber[:ceiling] - 10),
                  "and none out in the tunnel"
  end

  # Every island's corridor runs differently: it dips or humps on its way through,
  # squeezes in places and opens out in others — but it always stays swimmable.
  def test_tunnels_differ_but_stay_swimmable(args, assert)
    profiles = []

    [2, -4, 7, -9].each do |sector|
      isle = island_for(sector)
      slices = slices_of(isle)
      xs = island_xs(isle)
      gaps = xs.map { |x| slabs_at(slices, x).first[:ceiling] - floor_at(slices, x) }

      assert.true! gaps.min >= IslandWorld::MIN_GAP,
                   "sector #{sector} has a gap of #{gaps.min} — the diver is #{Diver::HEIGHT * 2} tall"
      assert.true! gaps.max - gaps.min > 60, "sector #{sector}'s corridor should vary in height"
      profiles << xs.map { |x| floor_at(slices, x) }
    end

    assert.equal! profiles.uniq.length, profiles.length, "no two tunnels run the same"
  end

  # Wherever a chamber lifts the roof, the air under it is really under rock.
  def test_every_chamber_holds_its_air_under_the_roof(args, assert)
    [2, -4, 7, -9].each do |sector|
      isle = island_for(sector)
      slices = slices_of(isle)

      slices.each do |index, world|
        world.air_pockets.each do |air|
          first = index * SCREEN_WIDTH + air[:x]
          xs_between(first, first + air[:w]).each do |x|
            ceiling = slabs_at(slices, x).first[:ceiling]
            assert.equal! ceiling, air[:y] + air[:h],
                          "sector #{sector}: the air reaches exactly up to the rock at #{x}"
            assert.true! floor_at(slices, x) < air[:y], "and floats above the corridor floor"
          end
        end
      end
    end
  end

  # The whole point of the chamber: part way through the cave you can surface and
  # fill your lungs, so the far side is reachable.
  def test_the_diver_breathes_in_the_chamber(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.island_sectors = [1]
    args.state.world_cache = {} # initialize_game already cached segments for the rolled sectors
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
    args.state.world_cache = {} # initialize_game already cached segments for the rolled sectors
    args.state.diver_global_x = island_for(1).first_x + 40
    args.state.depth_y = -99_999 # down on the tunnel floor
    game.update_depth_and_camera

    assert.false! game.breathing?, "the tunnel is flooded"
  end

  # The island is solid to everything, not just to the diver.
  def test_the_shark_turns_around_at_the_island(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.island_sectors = [1]
    args.state.world_cache = {} # initialize_game already cached segments for the rolled sectors
    isle = island_for(1)
    y = WATERLINE_Y - 100
    body = DarkShark::WIDTH * DarkShark::SCALE_FACTOR

    # The first rock on the way in from the left, skerries included.
    rock_x = isle.first_x - 24 * World::COLUMN_WIDTH
    rock_x += World::COLUMN_WIDTH until game.solid_at?(rock_x, y)

    # Spawn it a clear body-length short of that, in open water, swimming at it.
    spawn = rock_x - body - 40
    segment = spawn.idiv(SCREEN_WIDTH)
    args.state.diver_global_x = segment * SCREEN_WIDTH + 100 # the shark lives in the diver's segment
    args.state.dark_shark = { x: spawn - segment * SCREEN_WIDTH, y: y, dir: 1 }
    assert.false! game.solid_at?(spawn, y), "the shark starts in open water (#{spawn})"

    turned = false
    200.times do
      game.update_shark(0)
      turned = true if args.state.dark_shark.dir == -1
      sx = segment * SCREEN_WIDTH + args.state.dark_shark.x
      # Never, on any tick, is any part of the shark inside solid rock.
      assert.false! game.solid_at?(sx, args.state.dark_shark.y) ||
                    game.solid_at?(sx + body, args.state.dark_shark.y),
                    "the shark ended up inside the rock at #{args.state.dark_shark.x.to_i},#{args.state.dark_shark.y.to_i}"
    end

    assert.true! turned, "and it turned away from the rock instead of ploughing on"
  end

  # Fish belong to the water they were spawned in. Left to drift they used to
  # swim straight into the island — through solid rock.
  def test_fish_never_swim_into_the_rock(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.island_sectors = [1]
    args.state.world_cache = {} # initialize_game already cached segments for the rolled sectors
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
    args.state.world_cache = {} # initialize_game already cached segments for the rolled sectors
    args.state.diver_global_x = SCREEN_WIDTH + 60 # in the water beside the island
    args.state.depth_y = WATERLINE_Y
    game.center_camera
    args.state.game_scene = "area2"

    game.area2_tick

    assert.true! true, "a frame with the island renders"
  end
end

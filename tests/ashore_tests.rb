# Walking out of the sea. Some islands meet the water with a beach instead of a
# rock face, and a beach is something you can wade up: the diver leaves the water
# and walks the island's terraces until rock stands in his way.
#
# The measurement that shaped all of this: an island's skyline already steps in
# 16 px terraces and never jumps more than 32 — well inside the 48 px ledge the
# diver takes in his stride. The only thing that ever stopped him was the very
# first step, from floating (his feet at WATERLINE_Y - 52) up onto rock standing
# SHORE_LIP above the water. That gap is exactly what a rock coast *is*, and a
# beach is a shore that starts below the waterline instead.
class AshoreTests
  def build_game(args)
    game = Game.new
    game.args = args
    game
  end

  # A diver in the water at a world x, at the surface with his head out.
  def afloat_at(args, game, world_x)
    args.state.game_scene = "area1"
    args.state.diver_global_x = world_x
    args.state.depth_y = WATERLINE_Y - SURFACE_FLOAT_DEPTH
    game.center_camera
    game
  end

  # --- standing on rock ------------------------------------------------------

  # How far up he can reach from floating is what decides whether a shore can be
  # waded at all: his feet hang SURFACE_FLOAT_DEPTH + HEIGHT under the waterline,
  # so the outermost rock he can stand on is a stride above that — which lands
  # *below* the water. A beach's first step is therefore a submerged one.
  WADEABLE = WATERLINE_Y - SURFACE_FLOAT_DEPTH - Diver::HEIGHT + SOLID_STEP_UP

  def test_he_rests_on_rock_that_lifts_him_out_of_the_water(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.island_sectors = []
    args.state.world_cache = {}
    crown = WADEABLE - 12 # a shelf just under the surface, within wading reach
    game.define_singleton_method(:slabs_at) { |_x| [{ ceiling: -800, crown: crown }] }
    afloat_at(args, game, 640)

    game.clamp_depth

    assert.equal! args.state.depth_y, crown + Diver::HEIGHT,
                  "he stands on it rather than being held down at the surface"
    assert.true! args.state.depth_y + Diver::HEIGHT > WATERLINE_Y,
                 "and that puts his head out of the water"
  end

  # Lifted off his footing somehow, gravity settles him back onto it. (That he
  # cannot lift himself in the first place is
  # test_there_is_no_swimming_up_a_mountain, which goes through the movement.)
  def test_gravity_settles_him_back_onto_his_footing(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    crown = WATERLINE_Y + 120
    game.define_singleton_method(:slabs_at) { |_x| [{ ceiling: -800, crown: crown }] }
    afloat_at(args, game, 640)
    args.state.depth_y = crown + Diver::HEIGHT + 200 # up in the air over it

    60.times { game.clamp_depth }

    assert.equal! args.state.depth_y, crown + Diver::HEIGHT, "he comes back down to the ground"
  end

  # Wading is a staircase, not one big step: each terrace has to be within a
  # stride of the one before it, and the first one within a stride of floating.
  def test_he_wades_up_a_staircase_of_terraces_onto_dry_land(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    steps = [WADEABLE - 12, WATERLINE_Y, WATERLINE_Y + 16, WATERLINE_Y + 32, WATERLINE_Y + 48]
    game.define_singleton_method(:slabs_at) do |x|
      i = (x - 600).idiv(64)
      i = 0 if i < 0
      i = steps.length - 1 if i >= steps.length
      [{ ceiling: -800, crown: steps[i] }]
    end
    afloat_at(args, game, 600)

    600.times do
      game.swim_sideways(2)
      game.clamp_depth
    end

    assert.true! args.state.diver_global_x > 600 + 64 * 4,
                 "he got all the way up the beach (#{args.state.diver_global_x})"
    assert.equal! args.state.depth_y, steps.last + Diver::HEIGHT,
                  "and he is standing on the top terrace, out of the water"
  end

  def test_out_in_open_water_he_still_cannot_leave_the_sea(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.island_sectors = []
    args.state.world_cache = {}
    afloat_at(args, game, 640)

    20.times do
      args.state.depth_y += 4
      game.clamp_depth
    end

    assert.equal! args.state.depth_y, WATERLINE_Y - SURFACE_FLOAT_DEPTH,
                  "with nothing under him he floats at the surface as before"
  end

  # The ledge tolerance has always been documented for sand; rock needs it too,
  # or an island's terraces are a staircase he can see and never climb.
  def test_he_steps_up_onto_a_ledge_within_his_stride(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    step = SOLID_STEP_UP - 8
    crown = WATERLINE_Y - 100
    game.define_singleton_method(:slabs_at) do |x|
      x > 640 ? [{ ceiling: -400, crown: crown + step }] : [{ ceiling: -400, crown: crown }]
    end
    afloat_at(args, game, 600)
    args.state.depth_y = crown + Diver::HEIGHT
    game.clamp_depth

    assert.false! game.blocked?(660), "a knee-high ledge is a step, not a wall"
  end

  # --- the three kinds of shore ---------------------------------------------
  #
  # Checked by walking, not by reading the numbers off the shape: whether you can
  # get out of the sea onto a particular island is the sort of thing the geometry
  # can quietly stop being true about, and only a diver actually swimming at it
  # finds that out.

  def sector_with_shore(kind)
    (1..60).find { |s| IslandWorld.shape_for(s)[:shore] == kind }
  end

  # Swim in at the surface from one side and see where the island lets him get to.
  def walk_in(game, args, sector, from_left)
    isle = IslandWorld.new(args.state.world_cache[sector] || game.world_at(sector), sector)
    args.state.island_sectors = [sector]
    args.state.world_cache = {}
    args.state.diver_global_x = from_left ? isle.first_x - 400 : isle.last_x + 400
    args.state.depth_y = WATERLINE_Y - SURFACE_FLOAT_DEPTH
    game.center_camera

    highest = args.state.depth_y
    4000.times do
      game.swim_sideways(from_left ? 2 : -2)
      game.clamp_depth
      highest = args.state.depth_y if args.state.depth_y > highest
    end
    { isle: isle, x: args.state.diver_global_x, highest: highest,
      ashore: highest - Diver::HEIGHT > WATERLINE_Y }
  end

  def diving(args)
    game = build_game(args)
    game.initialize_game(0)
    game
  end

  def test_the_sea_holds_all_three_kinds_of_shore(args, assert)
    kinds = (1..60).map { |s| IslandWorld.shape_for(s)[:shore] }
    IslandWorld::SHORES.each do |kind|
      assert.true! kinds.count(kind) >= 8,
                   "#{kind} shores turn up (#{kinds.count(kind)} in 60 sectors)"
    end
  end

  def test_a_rock_coast_cannot_be_climbed_from_either_side(args, assert)
    game = diving(args)
    sector = sector_with_shore(:rock)

    [true, false].each do |from_left|
      walk = walk_in(game, args, sector, from_left)
      assert.false! walk[:ashore],
                    "a rock face is a wall from the #{from_left ? 'left' : 'right'} " \
                    "(got to #{walk[:highest] - WATERLINE_Y} above the water)"
    end
  end

  def test_a_beach_island_can_be_walked_clean_across(args, assert)
    game = diving(args)
    sector = sector_with_shore(:through)

    walk = walk_in(game, args, sector, true)

    assert.true! walk[:ashore], "he waded out of the sea (#{walk[:highest] - WATERLINE_Y} up)"
    assert.true! walk[:x] > walk[:isle].last_x,
                 "and walked the whole way over to the far shore (#{walk[:x]} past #{walk[:isle].last_x})"
  end

  def test_the_blocked_island_lets_him_ashore_and_then_stops_him(args, assert)
    game = diving(args)
    sector = sector_with_shore(:blocked)
    sand_side_is_left = IslandWorld.shape_for(sector)[:beach_left]

    from_sand = walk_in(game, args, sector, sand_side_is_left)
    isle = from_sand[:isle]
    got = (from_sand[:x] - isle.first_x) / isle.span.to_f

    assert.true! from_sand[:ashore], "the sand side lets him out of the water"
    assert.true! got > 0.05 && got < 0.95,
                 "and then a wall stops him part way over (#{(got * 100).to_i}%)"
  end

  def test_the_blocked_island_cannot_be_climbed_from_its_rock_side(args, assert)
    game = diving(args)
    sector = sector_with_shore(:blocked)

    walk = walk_in(game, args, sector, !IslandWorld.shape_for(sector)[:beach_left])

    assert.false! walk[:ashore], "the other shore is still a rock face"
  end

  # --- how he moves and looks up there --------------------------------------

  # Put him on a slab of dry rock, standing.
  def standing_on(args, game, crown)
    game.define_singleton_method(:slabs_at) { |_x| [{ ceiling: -800, crown: crown }] }
    afloat_at(args, game, 640)
    args.state.depth_y = crown + Diver::HEIGHT
    game.clamp_depth
    game
  end

  def test_on_land_he_is_drawn_from_the_land_sheet_and_not_tilted(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    standing_on(args, game, WATERLINE_Y + 80)
    args.state.angle = 30 # left over from swimming in

    sprite = args.state.diver.to_h

    assert.equal! sprite[:path], Diver::LAND_PATH, "he walks in the on-land sheet"
    assert.equal! sprite[:angle], 0, "and stands upright rather than leaning"
  end

  def test_in_the_water_he_is_still_the_swimmer(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.island_sectors = []
    args.state.world_cache = {}
    afloat_at(args, game, 640)
    args.state.depth_y = -400
    game.clamp_depth
    args.state.angle = 30

    sprite = args.state.diver.to_h

    assert.equal! sprite[:path], Diver::PATH, "under water nothing has changed"
    assert.equal! sprite[:angle], 30, "including the lean"
  end

  def test_walking_is_slower_than_swimming(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.island_sectors = []
    args.state.world_cache = {}
    afloat_at(args, game, 640)
    args.state.depth_y = -400
    game.clamp_depth
    game.update_sprint
    swimming = args.state.speed

    standing_on(args, game, WATERLINE_Y + 80)
    game.update_sprint

    assert.true! args.state.speed < swimming,
                 "flippers on rock are a waddle (#{args.state.speed} against #{swimming})"
    assert.true! args.state.speed > 0, "but he does get about"
  end

  def test_there_is_no_swimming_up_a_mountain(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    crown = WATERLINE_Y + 80
    standing_on(args, game, crown)
    game.define_singleton_method(:will_up?) { true }

    60.times do
      game.basic_movements_per_tick
      game.clamp_depth
    end

    assert.equal! args.state.depth_y, crown + Diver::HEIGHT, "holding up does nothing on land"
  end

  # Stepping off a terrace used to snap him to the ground below in a single
  # frame. On land he is heavy, not buoyant: he drops, gathering speed.
  def test_stepping_off_a_ledge_is_a_fall_rather_than_a_snap(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    high = WATERLINE_Y + 300
    low = WATERLINE_Y + 40
    game.define_singleton_method(:slabs_at) do |x|
      [{ ceiling: -800, crown: x < 640 ? high : low }]
    end
    afloat_at(args, game, 600)
    args.state.depth_y = high + Diver::HEIGHT
    game.clamp_depth

    args.state.diver_global_x = 700 # off the edge
    ticks = 0
    biggest = 0
    120.times do
      before = args.state.depth_y
      game.basic_movements_per_tick
      game.clamp_depth
      drop = before - args.state.depth_y
      biggest = drop if drop > biggest
      ticks += 1
      break if args.state.depth_y == low + Diver::HEIGHT
    end

    assert.equal! args.state.depth_y, low + Diver::HEIGHT, "he lands on the lower terrace"
    assert.true! ticks > 5, "and took a moment getting there (#{ticks} ticks)"
    assert.true! biggest < high - low, "never covering the whole drop in one frame (#{biggest})"
  end

  # The island must never be a trap. Walking up a beach costs no air, but the
  # suit and the round are still out there, and being unable to get back down to
  # the water would end a dive with nothing to show for it.
  def test_he_can_always_walk_back_down_into_the_sea(args, assert)
    game = diving(args)
    sector = sector_with_shore(:blocked)
    sand_left = IslandWorld.shape_for(sector)[:beach_left]
    walk = walk_in(game, args, sector, sand_left)
    assert.true! walk[:ashore], "he is up on the island to begin with"

    4000.times do
      game.swim_sideways(sand_left ? -2 : 2) # turn round and head back
      game.clamp_depth
    end

    assert.false! game.at_open_surface? && args.state.depth_y > WATERLINE_Y,
                  "he is off the rock and back in the water (#{args.state.depth_y})"
    assert.true! sand_left ? args.state.diver_global_x < walk[:isle].first_x
                           : args.state.diver_global_x > walk[:isle].last_x,
                 "and clear of the island (#{args.state.diver_global_x})"
  end

  # Stacks say "the rock reaches out here" — in front of sand they would say the
  # opposite, and (measured) they fence off the wade completely, because a skerry
  # is a wall at exactly the depth you walk ashore at.
  def test_sand_shores_have_no_stacks_off_them(args, assert)
    through = IslandWorld.new(WorldGenerator.generate(0), sector_with_shore(:through))
    rocky = IslandWorld.new(WorldGenerator.generate(0), sector_with_shore(:rock))

    assert.equal! through.skerry_clusters.length, 0, "a beach island has none"
    assert.equal! rocky.skerry_clusters.length, 2, "a rock coast has them off both shores"
  end

  # Standing on an island is being in the air, with everything that follows.
  # Walked in properly and left standing where the wall stopped him, rather than
  # dropped onto the island from above — from a point inside the mountain the
  # clamp quite correctly keeps him under the rock, which is a different test.
  def test_up_on_the_island_he_is_in_the_open_air(args, assert)
    game = diving(args)
    sector = sector_with_shore(:blocked)
    walk_in(game, args, sector, IslandWorld.shape_for(sector)[:beach_left])

    assert.true! game.at_open_surface?, "he is out in the daylight"
    assert.true! game.breathing?, "and breathing"
    args.state.oxygen = 20
    game.update_oxygen
    assert.true! args.state.oxygen > 20, "so his air comes back up on the beach"
  end

  def test_a_wall_higher_than_his_stride_still_stops_him(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    crown = WATERLINE_Y - 100
    game.define_singleton_method(:slabs_at) do |x|
      x > 640 ? [{ ceiling: -400, crown: crown + SOLID_STEP_UP + 32 }] : [{ ceiling: -400, crown: crown }]
    end
    afloat_at(args, game, 600)
    args.state.depth_y = crown + Diver::HEIGHT
    game.clamp_depth

    assert.true! game.blocked?(660), "rock over his head is a wall"
  end
end

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

  # Ask the island, not the roll: a blocked island too low to carry both a dry
  # shelf and a wall over it is fitted down to a walkable one, so the roll and
  # what is actually out there are not the same thing.
  def sector_with_shore(kind)
    (1..60).find { |s| IslandWorld.new(WorldGenerator.generate(s), s).shore == kind }
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

  # Counted on the islands themselves rather than on the rolls: the fitting takes
  # blocked islands away when they are too low to carry a wall, so this is the
  # test that would notice if it took nearly all of them.
  # --- the hills behind an island ---------------------------------------------

  # Land you can see and never reach is a promise the game cannot keep, so the
  # range only stands where its island does. It used to follow you across open
  # water: the parallax divided the distance from the island rather than lagging
  # behind it, which shrank how far away everything was and kept the mountain at
  # full height a sector and a half out.
  def test_the_hills_only_stand_where_their_island_does(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.island_sectors = [3]
    args.state.world_cache = {}
    args.state.game_scene = "area1"

    seen = (0..6).map do |sector|
      args.state.diver_global_x = sector * SCREEN_WIDTH + 640
      args.state.depth_y = WATERLINE_Y - SURFACE_FLOAT_DEPTH
      game.center_camera
      game.visible_islands
    end

    assert.equal! seen[0], [], "nothing over open water three sectors away"
    assert.equal! seen[6], [], "nor three the other side"
    assert.equal! seen[3], [3], "and the island's own water has them"
  end

  # The framing screens park the camera at the boat *for* a clean horizon, and
  # the island next door is near enough that its hills came along and spoiled it.
  def test_no_hills_behind_the_boat_on_a_menu_screen(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.game_scene = "title"

    game.render_backdrop

    assert.equal! args.outputs.sprites.flatten.length, 0, "the horizon stays clean"
  end

  # --- the island next door --------------------------------------------------
  #
  # One walkable island always lies just off home, so a round never starts with a
  # hunt for somewhere to come ashore.

  def test_every_round_has_a_walkable_island_next_to_home(args, assert)
    game = build_game(args)

    6.times do
      game.initialize_game(0)
      assert.true! args.state.island_sectors.include?(IslandWorld::HOME_SECTOR),
                   "there is one off home (#{args.state.island_sectors.inspect})"
    end

    isle = IslandWorld.new(WorldGenerator.generate(IslandWorld::HOME_SECTOR),
                           IslandWorld::HOME_SECTOR)
    assert.false! isle.shore == :rock, "and it is one you can get out of the water onto"
  end

  # It must not swallow the boat. An island is up to 2800 px across and centred on
  # its sector, so the one at -1 reaches x 676 — right over the boat at x 120,
  # which leaves the diver spawning under rock with no way to log, develop or
  # patch his suit. -2 is the nearest sector that clears it.
  def test_the_island_next_door_leaves_the_boat_alone(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    isle = IslandWorld.new(WorldGenerator.generate(IslandWorld::HOME_SECTOR),
                           IslandWorld::HOME_SECTOR)

    assert.true! isle.last_x + IslandWorld::REACH < SURFACE_BOAT_X - BOAT_REACH,
                 "it stops well short of the boat (ends #{isle.last_x})"

    game.spawn_at_surface
    assert.true! game.at_the_boat?, "so a round still starts at the boat"
    assert.false! game.on_land?, "floating, not standing on an island"
  end

  def test_you_can_wade_ashore_on_the_island_next_door(args, assert)
    game = diving(args)

    walk = walk_in(game, args, IslandWorld::HOME_SECTOR, true)

    assert.true! walk[:ashore],
                 "the island off home lets you out of the water (#{walk[:highest] - WATERLINE_Y})"
  end

  def test_the_sea_holds_all_three_kinds_of_shore(args, assert)
    kinds = (1..60).map { |s| IslandWorld.new(WorldGenerator.generate(s), s).shore }
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

  # He used to waddle: slower on land than in the water, which made an island —
  # a place you cross to get somewhere — the slowest part of the game. He walks
  # a little quicker than an easy swim now, and still nowhere near a sprint,
  # because sprinting is the thing you buy fins for.
  def test_walking_is_brisker_than_an_easy_swim(args, assert)
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

    walking = args.state.speed
    assert.true! walking > swimming,
                 "he gets on with it on land (#{walking} against #{swimming})"
    assert.true! walking < swimming * SPRINT_MULTIPLIER,
                 "but a walk is not a sprint (#{walking})"
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

  # Feet that cycle on a timer slide along the ground at every speed but one, and
  # that is exactly what "he shoves himself along" looks like. On land the walk is
  # driven by how far he has actually gone.
  def test_the_walk_is_driven_by_the_ground_not_by_the_clock(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    standing_on(args, game, WATERLINE_Y + 80)
    args.state.swim_pose = true # he is walking

    frames = []
    12.times do
      args.state.diver_global_x += Diver::LAND_STRIDE
      frames << args.state.diver.to_h[:source_x]
    end

    assert.true! frames.uniq.length >= 4, "the legs really move (#{frames.uniq.length} poses)"
    assert.true! frames.uniq.length <= Diver::SPRITES_PER_ROW, "and it is a cycle, not a drift"
  end

  # Through the keyboard and whole ticks, at the speed he really walks. The test
  # above steps the position by a whole stride at a time, so it can never see the
  # thing that was actually wrong: the cycle advancing so slowly, over poses half
  # of which were feet-together, that holding a key looked like standing still
  # and the only visible movement was the snap to standing when you let go.
  def test_the_legs_visibly_move_while_he_walks(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    standing_on(args, game, WATERLINE_Y + 120)
    args.state.game_scene = "area1"

    args.inputs.keyboard.key_held.right = true
    frames = 40.times.map do
      game.tick
      args.state.diver.to_h[:source_x]
    end

    assert.true! frames.uniq.length >= 3,
                 "the legs go over 40 ticks of walking (#{frames.uniq.length} poses)"
  end

  # The pixels the game actually draws, not the frame number it picked. Every
  # test here was green while pressing a key showed the standing pose and letting
  # go showed the walk: the frame number was right and the *row* of the sheet it
  # came from was not, which no amount of checking source_x could see.
  def land_frame_pixels(args, frame)
    sheet = args.gtk.get_pixels(Diver::LAND_PATH)
    Diver::HEIGHT.times.flat_map do |row|
      Diver::WIDTH.times.map do |col|
        sheet.pixels[row * sheet.w + frame * Diver::WIDTH + col]
      end
    end
  end

  def test_the_pose_he_walks_in_is_not_the_pose_he_stands_in(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    standing_on(args, game, WATERLINE_Y + 120)

    args.state.swim_pose = false
    still = args.state.diver.to_h
    args.state.swim_pose = true
    walking = Diver::LAND_WALK_FRAMES.times.map do |i|
      args.state.diver_global_x = i * Diver::LAND_STRIDE
      args.state.diver.to_h
    end

    assert.equal! still[:source_y], 0, "one row, so there is nothing to get backwards"
    still_px = land_frame_pixels(args, still[:source_x] / Diver::WIDTH)
    poses = walking.map { |s| land_frame_pixels(args, s[:source_x] / Diver::WIDTH) }

    poses.each_with_index do |px, i|
      assert.false! px == still_px, "walk frame #{i} is not him standing there"
    end
    assert.true! poses.uniq.length >= 2, "and the walk frames differ from each other"
  end

  def test_standing_still_the_legs_stand_still(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    standing_on(args, game, WATERLINE_Y + 80)
    args.state.swim_pose = true

    frames = 30.times.map { args.state.diver.to_h[:source_x] } # never moved

    assert.equal! frames.uniq.length, 1, "no marching on the spot"
  end

  def test_walking_is_brisk(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    standing_on(args, game, WATERLINE_Y + 80)

    game.update_sprint

    assert.true! args.state.speed >= Diver::SPEED * 0.8,
                 "he gets along at a decent clip (#{args.state.speed} of #{Diver::SPEED})"
  end

  # --- hopping ---------------------------------------------------------------

  def test_the_space_bar_is_a_hop_on_land(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    crown = WATERLINE_Y + 120
    standing_on(args, game, crown)
    ground = args.state.depth_y
    game.define_singleton_method(:wants_jump?) { true }

    game.basic_movements_per_tick
    game.clamp_depth
    highest = args.state.depth_y
    120.times do
      game.clamp_depth
      highest = args.state.depth_y if args.state.depth_y > highest
    end

    assert.true! highest > ground, "he leaves the ground (#{highest - ground} px)"
    assert.true! highest - ground < Diver::HEIGHT * 2,
                 "but it is a hop, not a leap (#{highest - ground} px)"
    assert.equal! args.state.depth_y, ground, "and he comes back down to it"
  end

  def test_there_is_no_hopping_off_thin_air(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    crown = WATERLINE_Y + 120
    standing_on(args, game, crown)
    ground = args.state.depth_y
    game.define_singleton_method(:wants_jump?) { true }

    # Hold the key down the whole way up: it must not wind him higher and higher.
    highest = ground
    120.times do
      game.basic_movements_per_tick
      game.clamp_depth
      highest = args.state.depth_y if args.state.depth_y > highest
    end

    assert.true! highest - ground < Diver::HEIGHT * 2,
                 "one hop's worth of height, however long you hold it (#{highest - ground} px)"
  end

  def test_in_the_water_the_space_bar_is_still_the_sprint(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.island_sectors = []
    args.state.world_cache = {}
    afloat_at(args, game, 640)
    args.state.depth_y = -400
    game.clamp_depth
    game.define_singleton_method(:will_sprint?) { true }
    game.define_singleton_method(:moving?) { true }

    game.update_sprint

    assert.true! args.state.sprinting, "down here it still makes him go faster"
  end

  def test_on_land_the_space_bar_is_not_a_sprint(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    standing_on(args, game, WATERLINE_Y + 120)
    game.define_singleton_method(:will_sprint?) { true }
    game.define_singleton_method(:moving?) { true }

    game.update_sprint

    assert.false! args.state.sprinting, "up here the same key is a hop"
  end

  # The promise the blocked island makes. A hop raises how high he can reach, so
  # the wall has to be built past stride *and* hop — this walks at it doing
  # nothing but jumping, for as long as it takes.
  def test_no_amount_of_hopping_gets_him_over_the_wall(args, assert)
    game = diving(args)
    sector = sector_with_shore(:blocked)
    sand_left = IslandWorld.shape_for(sector)[:beach_left]
    walk = walk_in(game, args, sector, sand_left)
    assert.true! walk[:ashore], "he is up on the shelf to begin with"
    isle = walk[:isle]
    stopped = args.state.diver_global_x

    game.define_singleton_method(:wants_jump?) { true }
    4000.times do
      game.basic_movements_per_tick
      game.clamp_depth
      game.swim_sideways(sand_left ? 2 : -2)
      game.clamp_depth
    end

    got = args.state.diver_global_x
    assert.true! (sand_left ? got - stopped : stopped - got) < 64,
                 "the wall is still a wall (#{stopped} -> #{got})"
    assert.true! got > isle.first_x && got < isle.last_x, "and he is still on the island"
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

  # A beach has to look like one. The island tags the slabs whose top is low
  # ground on a sand shore, and the renderer lays sand on those instead of the
  # sun-bleached stone the rest of an island wears.
  def dry_slabs(game, args, sector)
    args.state.island_sectors = [sector]
    args.state.world_cache = {}
    first = IslandWorld.new(WorldGenerator.generate(sector), sector).first_x.idiv(SCREEN_WIDTH)
    (first - 1..first + 3).flat_map do |index|
      world = game.world_at(index)
      world.roof ? world.roof.flatten.select { |s| s[:crown] > WATERLINE_Y } : []
    end
  end

  def test_a_sand_shore_is_drawn_as_sand(args, assert)
    game = diving(args)

    sandy = dry_slabs(game, args, sector_with_shore(:through)).select { |s| s[:sand] }

    assert.true! sandy.length > 20, "there is a beach to see (#{sandy.length} columns)"
    sandy.each do |slab|
      assert.true! slab[:crown] <= WATERLINE_Y + IslandWorld::BEACH_SAND_HEIGHT,
                   "sand is the low ground, not the summit (#{slab[:crown] - WATERLINE_Y})"
    end
  end

  def test_a_rock_coast_is_never_sand(args, assert)
    game = diving(args)

    slabs = dry_slabs(game, args, sector_with_shore(:rock))

    assert.true! slabs.length > 0, "the island is there at all"
    assert.equal! slabs.count { |s| s[:sand] }, 0, "and none of it is beach"
  end

  # Stacks say "the rock reaches out here, and you cannot swim straight in" —
  # which is exactly what needs saying off a beach too, because from the surface
  # the island's own flank is invisible (nothing under the waterline is drawn from
  # up in the air) and you swim into a wall you cannot see.
  def test_only_rock_shores_have_stacks_off_them(args, assert)
    through = IslandWorld.new(WorldGenerator.generate(0), sector_with_shore(:through))
    rocky = IslandWorld.new(WorldGenerator.generate(0), sector_with_shore(:rock))

    assert.equal! through.skerry_clusters.length, 0, "a beach island has none"
    assert.equal! rocky.skerry_clusters.length, 2, "a rock coast has them off both shores"
  end

  # ... and they must not shut the beach off. A skerry is a wall at the surface,
  # which is the depth you wade in at — but it only reaches SKERRY_DEPTH down, so
  # the way past is under it. This swims the way a player would: push toward the
  # island, duck when something is in the way, rise again when it isn't.
  def swim_in_ducking(game, args, sector, from_left)
    isle = IslandWorld.new(WorldGenerator.generate(sector), sector)
    args.state.island_sectors = [sector]
    args.state.world_cache = {}
    args.state.diver_global_x = from_left ? isle.first_x - 600 : isle.last_x + 600
    args.state.depth_y = WATERLINE_Y - SURFACE_FLOAT_DEPTH
    game.center_camera

    step = from_left ? 2 : -2
    highest = args.state.depth_y
    6000.times do
      if game.blocked?(args.state.diver_global_x + step)
        args.state.depth_y -= 3 # something in the way: go under it
      else
        game.swim_sideways(step)
        # Rise only when rising wouldn't put him back into the rock — staying
        # down until he is properly past is what a player does, and what the
        # earlier model failed to do.
        here = args.state.depth_y
        args.state.depth_y = here + 2
        args.state.depth_y = here if game.blocked?(args.state.diver_global_x + step)
      end
      game.clamp_depth
      highest = args.state.depth_y if args.state.depth_y > highest
    end
    { isle: isle, x: args.state.diver_global_x, highest: highest,
      ashore: highest - Diver::HEIGHT > WATERLINE_Y }
  end

  def test_the_stacks_do_not_shut_the_beach_off(args, assert)
    game = diving(args)

    walk = swim_in_ducking(game, args, IslandWorld::HOME_SECTOR, true)

    assert.true! walk[:ashore],
                 "ducking under the rocks still gets you onto the beach " \
                 "(got to #{walk[:highest] - WATERLINE_Y} above the water)"
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

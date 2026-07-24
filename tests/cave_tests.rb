# A heightmap can only say "sand up to here" — it cannot describe a cave, which
# needs rock above *and* below with water in between. Worlds can therefore carry
# a second solid span per column (the roof); these tests pin down what it means.
class CaveTests
  ROOF_FROM = 20 # first column with rock overhead
  ROOF_TO = 60   # first column past it
  CEILING = 200  # world y of the rock's underside
  CROWN = 800    # world y of its top

  def build_game(args)
    game = Game.new
    game.args = args
    game
  end

  # A flat world with a slab of rock hanging over its middle: open water, then a
  # tunnel between floor and ceiling, then open water again.
  def tunnel_world(index)
    columns = WorldGenerator.columns
    floor = Array.new(columns) { 0 }
    roof = Array.new(columns) { [] }
    (ROOF_FROM...ROOF_TO).each { |c| roof[c] = [{ ceiling: CEILING, crown: CROWN }] }
    World.new(index: index, biome: Biome::SANDBANK, floor: floor, decorations: [], roof: roof)
  end

  # Put that world where the diver is, bypassing generation.
  def with_tunnel(game, args)
    args.state.world_cache = { 0 => tunnel_world(0) }
    args.state.active_world_index = nil # force a re-read of the current segment
  end

  def x_under_roof
    (ROOF_FROM + 5) * World::COLUMN_WIDTH
  end

  def x_in_open_water
    (ROOF_TO + 20) * World::COLUMN_WIDTH
  end

  def test_a_world_without_a_roof_is_open_water(args, assert)
    world = WorldGenerator.generate(2)

    assert.equal! world.slabs_at(640), [], "the open sea has no rock overhead"
  end

  def test_roof_reports_the_rock_overhead(args, assert)
    slabs = tunnel_world(0).slabs_at(x_under_roof)

    assert.equal! slabs.length, 1, "one slab hangs over this column"
    assert.equal! slabs[0][:ceiling], CEILING, "the underside he bumps his head on"
    assert.equal! slabs[0][:crown], CROWN, "and the top of the slab"
  end

  # Two slabs over one column: a passage running above another, with rock between
  # them. Which one bounds the diver depends on where in the column he is.
  def test_stacked_slabs_make_two_separate_passages(args, assert)
    columns = WorldGenerator.columns
    floor = Array.new(columns) { 0 }
    roof = Array.new(columns) { [] }
    lower = { ceiling: 200, crown: 300 }  # rock between the two passages
    upper = { ceiling: 500, crown: 620 }  # the roof over the upper one
    (ROOF_FROM...ROOF_TO).each { |c| roof[c] = [lower, upper] }
    world = World.new(index: 0, biome: Biome::SANDBANK, floor: floor, decorations: [], roof: roof)
    x = x_under_roof

    assert.false! world.solid_at?(x, 100), "the lower passage is open water"
    assert.true! world.solid_at?(x, 250), "the rock between them is solid"
    assert.false! world.solid_at?(x, 400), "so is the upper passage"
    assert.true! world.solid_at?(x, 550), "and the roof over the whole thing"
  end

  def test_the_diver_cannot_swim_up_through_the_cave_roof(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    with_tunnel(game, args)
    args.state.diver_global_x = x_under_roof
    args.state.depth_y = 99_999 # try to float up to the surface

    game.update_depth_and_camera

    assert.equal! args.state.depth_y, CEILING - Diver::HEIGHT, "his head stops at the rock"
    assert.false! game.breathing?, "and he is not breathing under a cave roof"
  end

  # Beside the slab he can still surface as usual.
  def test_open_water_beside_the_cave_still_reaches_the_surface(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    with_tunnel(game, args)
    args.state.diver_global_x = x_in_open_water
    args.state.depth_y = 99_999

    game.update_depth_and_camera

    assert.equal! args.state.depth_y, WATERLINE_Y - SURFACE_FLOAT_DEPTH
    assert.true! game.breathing?
  end

  # A flat sea floor that steps up by `height` at column 40 — a ledge or a wall,
  # depending on how high.
  def step_world(index, height)
    columns = WorldGenerator.columns
    floor = (0...columns).map { |c| c < 40 ? 0 : height }
    World.new(index: index, biome: Biome::SANDBANK, floor: floor, decorations: [])
  end

  def with_world(game, args, world)
    args.state.world_cache = { 0 => world }
    args.state.active_world_index = nil
  end

  def test_a_wall_blocks_swimming_into_it(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    with_world(game, args, step_world(0, 400))
    args.state.diver_global_x = 300 # a footprint away from the wall at column 40
    args.state.depth_y = 32         # resting on the sand

    game.swim_sideways(2)

    assert.equal! args.state.diver_global_x, 300, "rock is solid — he doesn't swim into it"
  end

  # Terrain is ragged; he shouldn't snag on every notch of it.
  def test_small_ledges_are_slipped_over(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    with_world(game, args, step_world(0, 24))
    args.state.diver_global_x = 300
    args.state.depth_y = 32

    game.swim_sideways(2)
    game.update_depth_and_camera

    assert.equal! args.state.diver_global_x, 302, "a low ledge is no obstacle"
    assert.equal! args.state.depth_y, 24 + Diver::HEIGHT, "and he is lifted onto it"
  end

  def test_a_cave_roof_in_his_face_blocks_him(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    with_tunnel(game, args)
    args.state.diver_global_x = x_under_roof - 40 # approaching the tunnel mouth
    args.state.depth_y = 400 # swimming too high to fit in

    game.swim_sideways(2)

    assert.equal! args.state.diver_global_x, x_under_roof - 40, "he can't swim into the rock"
  end

  def test_the_tunnel_can_be_swum_through_at_the_right_depth(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    with_tunnel(game, args)
    args.state.diver_global_x = x_under_roof - 40
    args.state.depth_y = 100 # low enough to fit under the roof

    game.swim_sideways(2)

    assert.equal! args.state.diver_global_x, x_under_roof - 38, "he swims into the cave"
  end

  def test_renders_a_cave_without_error(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    with_tunnel(game, args)
    args.state.diver_global_x = x_under_roof
    args.state.depth_y = 100
    game.update_depth_and_camera
    args.state.game_scene = "area1"

    game.area1_tick

    assert.true! true, "a frame with rock overhead renders"
  end
end

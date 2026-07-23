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
    roof = Array.new(columns) { nil }
    (ROOF_FROM...ROOF_TO).each { |c| roof[c] = { ceiling: CEILING, crown: CROWN } }
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

    assert.equal! world.roof_at(640), nil, "the open sea has no rock overhead"
  end

  def test_roof_reports_the_rock_overhead(args, assert)
    rock = tunnel_world(0).roof_at(x_under_roof)

    assert.equal! rock[:ceiling], CEILING, "the underside he bumps his head on"
    assert.equal! rock[:crown], CROWN, "and the top of the slab"
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

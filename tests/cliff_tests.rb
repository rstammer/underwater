# Walking off a cliff into the sea.
#
# Stepping between two land heights was made a proper fall a while back, because
# snapping to the rock below read as a teleport. Stepping off rock into *water*
# was left out of that: the clamp asked whether the ground he was heading for was
# land, and open sea is not, so he jumped the whole drop in one frame. It hardly
# showed while beaches sloped gently into the water — but an island with a
# blocked shore has a wall, and off the top of one it is a hundred pixels.
class CliffTests
  PLATEAU_TO = 40                  # first column past the rock
  CROWN = WATERLINE_Y + 200        # a plateau standing well clear of the sea
  SURFACE = WATERLINE_Y - SURFACE_FLOAT_DEPTH

  def build_game(args)
    game = Game.new
    game.args = args
    game
  end

  # Flat sand, a plateau of rock over the left half of it standing 200 px above
  # the waterline, open sea to the right of it.
  def cliff_world(index)
    columns = WorldGenerator.columns
    roof = Array.new(columns) { [] }
    (0...PLATEAU_TO).each { |c| roof[c] = [{ ceiling: 0, crown: CROWN }] }
    World.new(index: index, biome: Biome::SANDBANK,
              floor: Array.new(columns) { 0 }, decorations: [], roof: roof)
  end

  def x_on_the_plateau
    (PLATEAU_TO - 10) * World::COLUMN_WIDTH
  end

  def x_over_the_sea
    (PLATEAU_TO + 12) * World::COLUMN_WIDTH
  end

  # Standing on top of the rock, having got there the way he would in the game.
  def on_the_plateau(args)
    game = build_game(args)
    game.initialize_game(0)
    args.state.island_sectors = []
    args.state.world_cache = { 0 => cliff_world(0) }
    args.state.active_world_index = nil
    args.state.game_scene = "area1"
    args.state.diver_global_x = x_on_the_plateau
    args.state.depth_y = CROWN + Diver::HEIGHT
    game.clamp_depth
    game
  end

  def test_he_is_standing_on_the_cliff_to_begin_with(args, assert)
    game = on_the_plateau(args)

    assert.true! game.on_land?, "the rock holds him above the sea"
    assert.true! args.state.depth_y > WATERLINE_Y, "and he is out of the water"
  end

  # The bug, in one number: one tick used to cover the whole drop.
  def test_stepping_off_it_is_a_fall_not_a_teleport(args, assert)
    game = on_the_plateau(args)
    was_at = args.state.depth_y
    args.state.diver_global_x = x_over_the_sea

    game.clamp_depth

    dropped = was_at - args.state.depth_y
    assert.true! dropped <= LAND_FALL_MAX + 1,
                 "he falls at falling speed, not all at once (#{dropped.round} px in one tick)"
    assert.true! args.state.depth_y > SURFACE, "still in the air over the water"
    assert.true! args.state.airborne, "and off the ground"
  end

  def test_the_water_still_catches_him(args, assert)
    game = on_the_plateau(args)
    args.state.diver_global_x = x_over_the_sea

    120.times { game.clamp_depth }

    assert.equal! args.state.depth_y, SURFACE, "he ends up floating at the surface"
    assert.false! args.state.airborne, "the water caught him"
    assert.false! game.on_land?
  end

  # It has to gather speed like any other fall, or it is just a slow teleport.
  def test_the_fall_speeds_up(args, assert)
    game = on_the_plateau(args)
    args.state.diver_global_x = x_over_the_sea

    game.clamp_depth
    first = args.state.depth_y
    game.clamp_depth
    second = args.state.depth_y
    game.clamp_depth
    third = args.state.depth_y

    assert.true! (second - third) > (first - second), "gravity is working on him"
  end

  # The regression this must not cause: under the surface the clamp is buoyancy,
  # not gravity. A diver swimming up must be held at the waterline every tick,
  # not treated as falling and given an accelerating arc.
  def test_swimming_up_at_the_surface_is_still_a_snap(args, assert)
    game = on_the_plateau(args)
    args.state.diver_global_x = x_over_the_sea
    args.state.depth_y = SURFACE
    args.state.airborne = false
    game.clamp_depth # settle him there, out of the water's way

    args.state.depth_y = SURFACE + 40 # a stroke upwards
    game.clamp_depth

    assert.equal! args.state.depth_y, SURFACE, "held at the surface in one tick"
    assert.false! args.state.airborne
  end
end

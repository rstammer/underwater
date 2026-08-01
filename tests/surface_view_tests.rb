# What the sea gives away from above.
#
# The rule is in Game#submerged_visible?: floating at the surface you do not see
# through the water. An island is a wall of sand ending at the waterline, and the
# skerries standing out in front of it are the only warning that there is more of
# it underneath. Everything drawn from the roof has to keep that rule.
class SurfaceViewTests
  def build_game(args)
    game = Game.new
    game.args = args
    game
  end

  # Floating in the open water beside an island, head up, as you are the moment
  # before a dive.
  def afloat_beside_an_island(args)
    game = build_game(args)
    game.initialize_game(0)
    sector = args.state.island_sectors.first
    args.state.game_scene = "area1"
    args.state.diver_global_x = IslandWorld.centre_x(sector)
    args.state.on_land = false
    game.current_world
    game.center_camera
    # Last, and after the camera: settling the view clamps the depth, which put
    # him back under before anybody could look at anything.
    args.state.depth_y = WATERLINE_Y
    game
  end

  # Every tile the roof draws, over the island and both its neighbours, so a
  # slab that reaches out of the segment is covered too.
  def roof_tiles(game, args)
    sector = args.state.island_sectors.first
    tiles = []
    (-1..1).each do |offset|
      world = game.world_at(sector + offset)
      tiles.concat(game.world_roof(world, offset * SCREEN_WIDTH))
    end
    tiles
  end

  def test_the_diver_is_actually_at_the_surface(args, assert)
    game = afloat_beside_an_island(args)

    assert.true! game.at_open_surface?, "he is floating with his head out"
    assert.false! game.submerged_visible?, "so the water keeps what is under it"
  end

  # The bug this file was written for: the body of a slab is clipped at the
  # surface, but the lit rim under it was drawn at the slab's own ceiling
  # whatever depth that was. A skerry's ceiling is 160 px down, so every island
  # trailed a four-pixel brown line across the open water in front of it —
  # rock with no rock attached to it.
  def test_no_rock_is_drawn_below_the_surface(args, assert)
    game = afloat_beside_an_island(args)
    cut = game.surface_clip_y - args.state.camera_y

    roof_tiles(game, args).each do |tile|
      next if tile[:h] <= 0

      assert.true! tile[:y] + tile[:h] > cut,
                   "a #{tile[:w]}x#{tile[:h]} piece of rock is drawn " \
                   "#{(cut - (tile[:y] + tile[:h])).round} px under the surface"
    end
  end

  # And the rule only applies looking in from the air: under water the same rock
  # has to be there, rim and all, or diving down to an island would show nothing.
  def test_under_water_the_rock_is_all_there(args, assert)
    game = afloat_beside_an_island(args)
    args.state.depth_y = WATERLINE_Y - 300
    game.center_camera

    assert.true! game.submerged_visible?, "his head is under"
    deep = roof_tiles(game, args).select do |tile|
      tile[:h] > 0 && tile[:y] + tile[:h] <= game.surface_clip_y - args.state.camera_y
    end
    assert.false! deep.empty?, "there is rock down here to see"

    # And the rim itself is still on it. The fix drops the rim wherever the
    # underside is not in view, so this is the other half of it: down here the
    # underside *is* the view, and a cave roof without its lit edge is a hole.
    assert.false! deep.select { |tile| tile[:h] == 4 }.empty?,
                  "the underside of the rock is lit"
  end
end

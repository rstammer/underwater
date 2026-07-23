class CameraTests
  def build_game(args)
    game = Game.new
    game.args = args
    game
  end

  # Settle the camera as if a few seconds had passed (it eases toward its target).
  def settle(game, ticks = 90)
    ticks.times { game.update_depth_and_camera }
  end

  # Resting on the sand the camera comes to rest just below the floor, so the
  # diver has ground under him and room above — a dead zone at the bottom.
  def test_camera_rests_below_the_sea_floor(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.depth_y = -99_999 # sink onto the sand
    settle(game)

    assert.equal! args.state.depth_y, game.sea_floor_y, "clamped to rest on the floor"
    assert.true! (args.state.camera_y - (game.sea_floor_y - FLOOR_VIEW_MARGIN)).abs < 1,
                 "the camera settles a margin below the floor"
    assert.true! args.state.player_y > 0 && args.state.player_y < SCREEN_HEIGHT,
                 "and the diver stays on screen (#{args.state.player_y})"
  end

  # Well above the floor the camera follows the diver and he sits at the anchor.
  def test_camera_follows_the_diver_in_open_water(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.depth_y = game.sea_floor_y + 400
    settle(game)

    assert.true! (args.state.camera_y - (args.state.depth_y - CAMERA_ANCHOR)).abs < 1,
                 "camera scrolls to keep the diver anchored"
    assert.true! (args.state.player_y - CAMERA_ANCHOR).abs < 1,
                 "the diver sits at the anchor on screen"
  end

  # The camera eases toward its target instead of snapping, so rough terrain
  # under the diver doesn't make the view jitter.
  def test_camera_eases_toward_its_target(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    game.center_camera
    before = args.state.camera_y
    args.state.depth_y -= 600 # a sudden plunge

    game.update_depth_and_camera
    moved = before - args.state.camera_y

    assert.true! moved > 0, "the camera starts moving after the diver"
    assert.true! moved < 600, "but does not snap there in one tick (#{moved})"
  end

  # The diver can float up to head-out at the waterline, but no higher.
  def test_depth_is_clamped_at_the_float_ceiling(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.depth_y = 99_999 # try to fly out of the water

    game.update_depth_and_camera

    assert.equal! args.state.depth_y, WATERLINE_Y - SURFACE_FLOAT_DEPTH
    assert.true! game.breathing?, "clamped at the surface, head out, breathing"
  end

  # Over a trench there is real depth to explore, far below the shallow banks.
  def test_a_trench_can_be_dived_far_below_the_shelf(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.diver_global_x = deep_world_x
    args.state.depth_y = -99_999 # dive all the way down
    settle(game)

    assert.true! args.state.depth_y < -800, "a trench goes deep (#{args.state.depth_y})"
    assert.true! game.current_depth > 150, "and the depth readout shows it (#{game.current_depth} m)"
  end

  # Sky only shows once the camera has scrolled up enough to reveal the waterline.
  def test_sky_shows_only_once_the_waterline_is_in_view(args, assert)
    game = build_game(args)
    game.initialize_game(0)

    args.state.camera_y = 0
    assert.equal! game.sky_fill, [], "no sky while the camera rests deep"

    args.state.camera_y = 300 # scrolled up toward the surface
    assert.false! game.sky_fill == [], "sky appears as the waterline comes into view"
  end

  # Horizontally the camera centres on the diver; the world scrolls sideways.
  def test_camera_centers_on_the_diver_horizontally(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.diver_global_x = 2000

    game.update_depth_and_camera

    assert.equal! args.state.camera_x, 2000 - CAMERA_ANCHOR_X, "camera scrolls to keep the diver centred"
    assert.equal! args.state.player_x, CAMERA_ANCHOR_X, "the diver sits at the horizontal anchor"
  end

  # At a chunk boundary the diver's segment and its neighbour are both on screen,
  # so the terrain scrolls across continuously instead of flipping.
  def test_two_segments_are_visible_at_a_boundary(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.diver_global_x = SCREEN_WIDTH # right at the segment 0/1 boundary

    game.update_depth_and_camera
    indices = game.visible_world_indices

    assert.true! indices.length >= 2, "more than one segment is on screen at a boundary"
    assert.true! indices.include?(game.world_index), "the diver's own segment is visible"
  end

  # At the surface you see only the water surface — the fish below are hidden.
  def test_fauna_hidden_at_the_surface(args, assert)
    game = build_game(args)
    game.initialize_game(0)

    args.state.depth_y = WATERLINE_Y # head out, at the surface
    assert.false! game.fauna_visible?, "no fish while at the surface"

    args.state.depth_y = -200 # dived under
    assert.true! game.fauna_visible?, "fish are visible underwater"
  end

  # Smoke test: a full underwater render at the surface and deep in a shark biome
  # must not blow up (boat, hint, camera-shifted fauna, sky, floor all exercised).
  def test_renders_without_error_at_surface_and_deep(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    game.spawn_at_surface # at home, breathing -> boat + hint + sky
    args.state.game_scene = "area1"
    game.area1_tick

    args.state.diver_global_x = 1500 # Tiefsee: a shark prowls
    args.state.depth_y = -99_999     # down on the trench floor
    settle(game)
    game.area2_tick

    assert.true! true, "rendered both frames without raising"
  end

  # A world x whose sea floor lies deep — used to test diving into a trench.
  def deep_world_x
    (0..400).map { |i| i * 256 }.min_by { |x| WorldGenerator.floor_y_at(x) }
  end
end

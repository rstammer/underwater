class CameraTests
  def build_game(args)
    game = Game.new
    game.args = args
    game
  end

  # Near the floor the camera rests at 0, showing the classic world 0..height
  # view, and the diver moves freely on screen (a dead zone at the bottom).
  def test_camera_rests_at_zero_in_the_dead_zone(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.depth_y = 200 # above the floor, below the camera anchor

    game.update_depth_and_camera

    assert.equal! args.state.depth_y, 200, "depth is untouched in the dead zone"
    assert.equal! args.state.camera_y, 0, "camera stays put near the floor"
    assert.equal! args.state.player_y, 200, "on-screen y equals depth when camera is 0"
  end

  # Above the dead zone the camera follows and the diver stays around centre.
  def test_camera_follows_the_diver_when_deep_up(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.depth_y = 500

    game.update_depth_and_camera

    assert.equal! args.state.camera_y, 500 - CAMERA_ANCHOR, "camera scrolls to keep the diver anchored"
    assert.equal! args.state.player_y, CAMERA_ANCHOR, "the diver sits at the anchor on screen"
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

  # He rests on the sand instead of sinking through the sea floor.
  def test_depth_is_clamped_at_the_sea_floor(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.depth_y = -500 # try to sink through the floor

    game.update_depth_and_camera

    assert.equal! args.state.depth_y, game.sea_floor_y, "clamped to rest on the floor"
    assert.true! args.state.player_y >= 0, "and stays on screen"
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

    args.state.depth_y = 200 # dived under
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
    args.state.depth_y = 200
    game.update_depth_and_camera
    game.area2_tick

    assert.true! true, "rendered both frames without raising"
  end
end

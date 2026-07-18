class PanelTests
  # With DEBUG off, the panel renders exactly one label: the scene title.
  # The diver is unused in that path, so nil is fine.
  def test_renders_known_scene_title(args, assert)
    args.state.game_scene = "area1"
    items = Panel.new(args, nil).to_a

    assert.equal! items.length, 1
    assert.equal! items.first[:text], Panel::SCENE_TITLES["area1"]
  end

  def test_area2_has_its_own_title(args, assert)
    args.state.game_scene = "area2"
    items = Panel.new(args, nil).to_a

    assert.equal! items.first[:text], Panel::SCENE_TITLES["area2"]
    assert.not_equal! Panel::SCENE_TITLES["area1"], Panel::SCENE_TITLES["area2"]
  end

  def test_unknown_scene_has_no_title(args, assert)
    args.state.game_scene = "title"
    items = Panel.new(args, nil).to_a

    assert.true! items.first[:text].nil?, "expected nil title for a scene without an entry"
  end
end

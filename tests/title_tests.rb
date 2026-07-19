class TitleTests
  def build_game(args)
    game = Game.new
    game.args = args
    game
  end

  def test_title_shows_the_game_name(args, assert)
    game = build_game(args)
    game.initialize_game(0)

    texts = game.title_labels.map { |l| l[:text] }

    assert.true! texts.include?("Underwater"), "title should show the game name"
  end

  def test_title_has_decorative_fish(args, assert)
    game = build_game(args)
    game.initialize_game(0)

    fish = game.title_fish

    assert.equal! fish.length, Game::TITLE_FISH.length
    assert.true! fish.all? { |f| f[:path].include?("animals") }, "fish reuse the animal sprites"
  end

  def test_title_bubbles_use_the_generated_sprite(args, assert)
    game = build_game(args)
    game.initialize_game(0)

    bubbles = game.title_bubbles

    assert.true! bubbles.length > 0, "there should be bubbles"
    assert.true! bubbles.all? { |b| b[:path].include?("decor/bubble") }, "bubbles use the generated sprite"
  end

  def test_title_background_bands_span_the_width(args, assert)
    game = build_game(args)
    game.initialize_game(0)

    bg = game.title_background

    assert.true! bg.length > 1, "the background is a gradient of several bands"
    assert.true! bg.all? { |b| b[:w] == args.grid.w }, "each band spans the full width"
  end
end

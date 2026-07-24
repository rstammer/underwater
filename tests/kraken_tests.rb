# The kraken: a lure, not a hunter. It shows only in the deep, tempts the camera,
# never lets a photo land, and draws whoever chases it further down.
class KrakenTests
  def build_game(args)
    game = Game.new
    game.args = args
    game
  end

  # Deep underwater, where the legend lives — hovering in a genuine trench, so the
  # sea floor is really below him (being "160 m down" over the shallow home sector
  # would put him under the sand, which can't happen in play).
  def deep(args, metres: 160)
    game = build_game(args)
    game.initialize_game(0)
    args.state.island_sectors = []
    args.state.world_cache = {}
    args.state.game_scene = "area1"
    args.state.diver_global_x = deep_spot(metres)
    args.state.depth_y = WATERLINE_Y - metres * PIXELS_PER_METRE
    game
  end

  # A world x whose sea floor lies deeper than `metres` (plus headroom), so a
  # diver hovering at `metres` is in open water with the floor below him.
  def deep_spot(metres)
    want = WATERLINE_Y - (metres + 60) * PIXELS_PER_METRE
    x = 2 * SCREEN_WIDTH
    x += 40 while WorldGenerator.floor_y_at(x) > want && x < 80 * SCREEN_WIDTH
    x
  end

  def test_it_only_lurks_in_the_deep(args, assert)
    game = deep(args, metres: 160)
    game.update_kraken
    assert.true! game.kraken_present?, "past the trigger depth it appears"

    # Climb back up toward safety and it dissolves.
    args.state.depth_y = WATERLINE_Y - 100 * PIXELS_PER_METRE
    game.update_kraken
    assert.false! game.kraken_present?, "back above the fade depth it's gone"
  end

  def test_it_is_not_there_in_the_shallows(args, assert)
    game = deep(args, metres: 40)
    game.update_kraken
    assert.false! game.kraken_present?, "no legend in the shallows"
  end

  def test_it_is_gone_at_the_surface(args, assert)
    game = deep(args, metres: 160)
    game.update_kraken
    assert.true! game.kraken_present?

    game.spawn_at_surface # head out of the water
    game.update_kraken
    assert.false! game.kraken_present?, "there is nothing to see up in the daylight"
  end

  # The pull is always downward and ahead — that's the trap.
  def test_it_hangs_below_and_ahead(args, assert)
    game = deep(args, metres: 170)
    args.state.direction = :right
    game.update_kraken
    k = args.state.kraken

    assert.true! game.kraken_target_y(k.side) < args.state.depth_y, "it keeps below you (deeper)"
    assert.true! game.kraken_target_x(k.side) > args.state.diver_global_x, "and ahead of the way you face"
  end

  # Chasing it deeper makes it retreat deeper still — the mark keeps receding.
  def test_chasing_it_draws_you_down(args, assert)
    game = deep(args, metres: 160)
    game.update_kraken
    first = game.kraken_target_y(args.state.kraken.side)

    args.state.depth_y -= 200 # the diver follows it down
    deeper = game.kraken_target_y(args.state.kraken.side)

    assert.true! deeper < first, "the deeper you go, the deeper its mark"
  end

  # --- the photo that never lands -------------------------------------------

  def kraken_in_front(game, args)
    args.state.direction = :right
    args.state.fish = []
    args.state.kraken = { x: args.state.diver_global_x + 200, y: args.state.depth_y - 100, side: 1 }
  end

  def test_the_camera_reads_it_as_a_subject(args, assert)
    game = deep(args, metres: 160)
    kraken_in_front(game, args)

    subject = game.photo_subject

    assert.false! subject.nil?, "the prompt lights up — you believe you can take it"
    assert.equal! subject[:species].key, "kraken"
  end

  def test_the_shot_never_lands_and_costs_no_film(args, assert)
    game = deep(args, metres: 160)
    kraken_in_front(game, args)
    film_before = args.state.film_left

    game.take_photo

    assert.equal! args.state.film_left, film_before, "no frame is spent, so you keep trying"
    assert.equal! args.state.film_roll.length, 0, "and nothing lands on the roll"
    assert.false! args.state.shot_note.nil?, "just an empty, eerie note"
    assert.equal! args.state.shot_note[:quality], nil, "no grade — there's nothing there"
  end

  def test_it_never_enters_the_artenbuch(args, assert)
    game = deep(args, metres: 160)

    keys = game.artenbuch_rows.map { |row| row[:species].key }
    assert.false! keys.include?("kraken"), "the legend is never a page in the book"
    assert.equal! Species["kraken"], nil, "it isn't even in the roster"
  end

  # If you actually corner it — dive right onto it — it takes you.
  def test_cornered_it_seizes_you(args, assert)
    game = deep(args, metres: 200)
    args.state.kraken = { x: args.state.diver_global_x + 10, y: args.state.depth_y + 10, side: 1 }

    game.seize_diver_if_cornered

    assert.equal! args.state.game_scene, "game_over"
    assert.equal! args.state.death_cause, :taken
    assert.true! game.death_message.include?("Dunkelheit"), "dragged down into the dark"
  end

  # But at its usual lure distance it never grabs you — the deep does the killing.
  def test_at_its_lure_distance_it_does_not_grab(args, assert)
    game = deep(args, metres: 170)
    game.update_kraken

    game.seize_diver_if_cornered

    assert.equal! args.state.game_scene, "area1", "it keeps its distance; you're not seized"
  end

  def test_it_renders_without_error(args, assert)
    game = deep(args, metres: 170)
    game.update_kraken
    game.center_camera

    game.render_kraken

    assert.true! args.outputs.sprites.length > 0, "the murk, the tentacles and the eye draw"
  end
end

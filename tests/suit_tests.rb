# The suit is the second thing that can kill you: it is rated for a depth, and
# below that the pressure starts working on it. Air limits how *long* you stay
# down, the suit limits how *deep* you go.
class SuitTests
  def build_game(args)
    game = Game.new
    game.args = args
    game
  end

  # Put the diver at a depth in metres, out at sea (away from the boat).
  def dive_to(args, metres)
    args.state.diver_global_x = 4 * SCREEN_WIDTH
    args.state.depth_y = WATERLINE_Y - metres * PIXELS_PER_METRE
  end

  def test_the_suit_is_fine_within_its_rated_depth(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    dive_to(args, SUIT_DEPTH_LIMIT - 10)

    100.times { game.update_suit }

    assert.equal! args.state.suit, SUIT_MAX, "no damage above the rated depth"
    assert.false! game.too_deep?
  end

  def test_below_its_rated_depth_the_suit_takes_damage(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    dive_to(args, SUIT_DEPTH_LIMIT + 40)

    assert.true! game.too_deep?
    100.times { game.update_suit }

    assert.true! args.state.suit < SUIT_MAX, "the pressure works on it"
    assert.true! args.state.suit > 0, "but 40 m past the limit is survivable for a while"
  end

  # Twice as far past the limit should hurt twice as fast — that gradient is what
  # makes the deep tempting rather than a wall.
  def test_the_deeper_you_go_the_faster_it_gives(args, assert)
    game = build_game(args)
    game.initialize_game(0)

    dive_to(args, SUIT_DEPTH_LIMIT + 50)
    args.state.suit = SUIT_MAX
    60.times { game.update_suit }
    shallow_loss = SUIT_MAX - args.state.suit

    dive_to(args, SUIT_DEPTH_LIMIT + 100)
    args.state.suit = SUIT_MAX
    60.times { game.update_suit }
    deep_loss = SUIT_MAX - args.state.suit

    assert.true! deep_loss > shallow_loss * 1.5,
                 "deeper must cost more (#{shallow_loss} vs #{deep_loss})"
  end

  def test_a_failed_suit_ends_the_dive(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.game_scene = "area1"
    dive_to(args, SUIT_DEPTH_LIMIT + 150)
    args.state.suit = 1

    20.times { game.update_suit }

    assert.equal! args.state.suit, 0
    assert.equal! args.state.game_scene, "game_over"
    assert.equal! args.state.death_cause, :crushed
    assert.true! game.death_message.downcase.include?("druck"), "the message names the pressure"
  end

  # The boat is where you patch the suit up — that's what makes it worth coming
  # home to, rather than just bobbing at the nearest bit of surface.
  def test_the_suit_is_patched_up_at_the_boat(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    game.spawn_at_surface
    args.state.suit = 40

    assert.true! game.at_the_boat?
    50.times { game.update_suit }

    assert.true! args.state.suit > 40, "back at the boat you can repair it"
  end

  def test_no_repairs_out_at_sea(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.diver_global_x = 5 * SCREEN_WIDTH # far from home, at the surface
    args.state.depth_y = WATERLINE_Y
    args.state.suit = 40

    assert.false! game.at_the_boat?
    50.times { game.update_suit }

    assert.equal! args.state.suit, 40, "surfacing anywhere doesn't mend a suit"
  end

  def test_a_new_round_starts_with_a_whole_suit(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.suit = 3

    game.reset_game

    assert.equal! args.state.suit, SUIT_MAX
  end
end

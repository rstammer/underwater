# Getting back. Generated ground may be hard to cross, and an island is allowed
# to say no — a rock coast is a wall from the water, and a blocked island keeps
# a wall inland on purpose. What none of it may do is let the diver *down* a
# step he cannot climb back up, because the sea on the far side is not always
# shallower than his suit is rated for. Then he is stranded, and waiting to
# drown costs him the whole roll of film.
#
# The first one of these was found by a playtester on the shop island, walking
# east past Andreas' market and finding no way home (issue #16).
class StrandTests
  # What he can get back up: his stride. Jumping adds about 33 px of height,
  # which is *less* than the stride, so it doesn't widen this at all.
  CLIMBABLE = Game::SOLID_STEP_UP

  def island_for(sector)
    IslandWorld.new(WorldGenerator.generate(sector), sector)
  end

  # The worst downward step anywhere along an island's skyline, and where.
  # Sampled at 8 px, the narrowest a terrace ever is.
  def worst_step(island, sector)
    first = IslandWorld.first_x_for(sector)
    worst = [0, nil]
    previous = nil
    x = first - 64
    while x < first + island.span + 64
      crown = island.crown_y_at(x)
      if previous && crown
        step = (previous - crown).abs
        worst = [step, x] if step > worst[0]
      end
      previous = crown
      x += 8
    end
    worst
  end

  # An island you walk over has to be walkable in both directions. This is the
  # invariant the shop island broke: its market terrace was stamped in at a fixed
  # height with nothing joining it to the rock either side, so its eastern edge
  # was a 78 px drop — a step up you cannot make.
  def test_a_crossable_island_never_drops_further_than_a_stride(args, assert)
    crossable = (-20..40).select { |sector| island_for(sector).crossable? }
    assert.true! crossable.length >= 5,
                 "expected a few crossable islands to check, found #{crossable.length}"

    crossable.each do |sector|
      step, x = worst_step(island_for(sector), sector)
      assert.true! step <= CLIMBABLE,
                   "island #{sector} drops #{step.round} px at x=#{x} — " \
                   "he can only climb #{CLIMBABLE}"
    end
  end

  # And the same thing as the diver meets it: walk east off the shop island, turn
  # round, and come home.
  def test_walking_east_over_the_shop_island_is_reversible(args, assert)
    game = Game.new
    game.args = args
    game.initialize_game(0)

    sector = IslandWorld::SHOP_SECTOR
    island = island_for(sector)
    start = IslandWorld.first_x_for(sector) + island.span / 2

    args.state.game_scene = "area1"
    args.state.diver_global_x = start
    args.state.depth_y = WATERLINE_Y + 400
    game.clamp_depth
    30.times { game.update_depth_and_camera } # let him settle onto the rock

    walk(game, args, Game::LAND_SPEED)
    east = args.state.diver_global_x
    assert.true! east > start + 1000,
                 "he should get well east of the market, got #{(east - start).round} px"

    walk(game, args, -Game::LAND_SPEED)
    assert.true! args.state.diver_global_x <= start,
                 "walked east to #{east.round} and only got back to " \
                 "#{args.state.diver_global_x.round} — stranded east of #{start}"
  end

  def walk(game, args, step)
    2000.times do
      game.swim_sideways(step)
      game.update_depth_and_camera
    end
  end
end

# What grows on the islands, and what stands behind them.
#
# The islands used to be sand with palms on: five kinds of plant, one of them a
# palm, one a smaller palm. From a distance that reads as an atoll, which is a
# fine thing to be but a thin one — and the range behind was a smooth ridge,
# which reads as bare rock however green you paint it.
class VegetationTests
  def build_game(args)
    game = Game.new
    game.args = args
    game
  end

  def island_for(sector)
    IslandWorld.new(WorldGenerator.generate(sector), sector)
  end

  # Everything growing on a stretch of islands, as kind => how often. Only what
  # is out of the water: the sea floor's own weed and coral come through the same
  # list, and they are not what any of this is about.
  def growth_census(sectors)
    census = Hash.new(0)
    sectors.each do |sector|
      island_for(sector).build.decorations.each do |item|
        census[item[:kind]] += 1 if item[:y] > WATERLINE_Y
      end
    end
    census
  end

  # --- what the island grows -------------------------------------------------

  # The tool prints a table of sizes and app/world/world_renderer.rb types it
  # out; a stale w or h there draws the plant squashed rather than failing, so
  # it is held against the pictures themselves. Same guard the camp has.
  def test_the_decor_table_matches_the_pictures(args, assert)
    Game::DECOR_SPRITES.each do |key, sprite|
      png = args.gtk.get_pixels(sprite[:path])

      assert.equal! png.w, sprite[:w], "#{key} is #{png.w} px wide, not #{sprite[:w]}"
      assert.equal! png.h, sprite[:h], "#{key} is #{png.h} px tall, not #{sprite[:h]}"
    end
  end

  # A plant the island can grow but the renderer cannot draw is a crash waiting
  # for the right roll, and one without a scale draws at its raw pixel size.
  def test_everything_that_grows_can_be_drawn(args, assert)
    growth_census((1..24).to_a).each_key do |kind|
      assert.false! Game::DECOR_SPRITES[kind].nil?, "#{kind} has a picture"
      assert.false! IslandWorld::SCALES[kind].nil?, "#{kind} has a scale"
    end
  end

  # The point of the whole exercise: a run of islands has to come out as woodland
  # rather than as the same two palms over and over. Counted over the census
  # rather than off the roster, because a kind that is listed but never rolled is
  # not growing anywhere.
  def test_an_island_chain_grows_a_mixed_wood(args, assert)
    census = growth_census((1..24).to_a)
    plants = census.keys.reject { |kind| ["gull", "flag", "rock", "driftwood"].include?(kind) }

    assert.true! plants.length >= 8,
                 "only #{plants.length} kinds of plant grow out there: #{plants.sort.join(", ")}"
  end

  # And no single one of them may be most of the wood. Palms were 'the' island
  # plant, and a chain where four in five plants are the same tree is a
  # plantation.
  def test_no_one_plant_takes_over(args, assert)
    census = growth_census((1..24).to_a)
    plants = census.reject { |kind, _| ["gull", "flag", "rock", "driftwood"].include?(kind) }
    total = plants.values.sum
    top, count = plants.max_by { |_, n| n }

    assert.true! count < total * 0.4,
                 "#{top} is #{(count * 100.0 / total).round} % of everything growing"
  end

  # --- what stands behind it -------------------------------------------------

  def backdrop_game(args)
    game = build_game(args)
    game.initialize_game(0)
    game
  end

  # The heights the far range is drawn at, sampled along its own source grid.
  # Written as a plain loop: this runs in mruby, where the tidier chain of
  # map/reject over a negative Range is not worth finding the edge of.
  def tree_line(game, sector, samples)
    isle = game.backdrop_island(sector)
    centre = IslandWorld.centre_x(sector)
    line = []
    (0...samples).each do |i|
      lift = game.backdrop_lift(isle, centre + (i - samples / 2) * Game::BACKDROP_SAMPLE, 2.3, 0)
      line << lift if lift > 0
    end
    line
  end

  # A wood seen from far off has a broken top edge: crowns, not a ridge. The
  # island's own crown steps in wide terraces, so a silhouette taken straight
  # off it changes height only a handful of times across a whole island — that
  # is the smooth ridge this is meant to stop being.
  def test_the_far_range_has_a_broken_canopy(args, assert)
    game = backdrop_game(args)
    sector = args.state.island_sectors.first
    line = tree_line(game, sector, 80)

    assert.true! line.length > 20, "the range is actually there (#{line.length} columns)"

    steps = 0
    (0...line.length - 1).each { |i| steps += 1 if line[i] != line[i + 1] }
    assert.true! steps > line.length / 2,
                 "only #{steps} of #{line.length - 1} columns break — that is a ridge, not a wood"
  end

  # It may break up, but it may not turn into noise: a canopy is a band of
  # heights around the land's own shape, not a random one.
  def test_the_canopy_still_follows_the_land(args, assert)
    game = backdrop_game(args)
    sector = args.state.island_sectors.first
    isle = game.backdrop_island(sector)
    centre = IslandWorld.centre_x(sector)

    (-20..20).each do |i|
      x = centre + i * Game::BACKDROP_SAMPLE
      bare = (isle.crown_y_at(x) - WATERLINE_Y) * 2.3
      next if bare <= 0

      # The ceiling is every roll that can add height, plus the rounding step: an
      # emergent is allowed to stand clear of the canopy, it is just not allowed
      # to leave the hill.
      ceiling = bare + Game::CANOPY_RISE + Game::CANOPY_RAGGED +
                Game::CANOPY_EMERGENT_RISE + Game::BACKDROP_STEP
      lift = game.backdrop_lift(isle, x, 2.3, 0)
      assert.true! lift >= bare - Game::BACKDROP_STEP,
                   "the wood at #{i} sinks below its own hill"
      assert.true! lift <= ceiling,
                   "the wood at #{i} stands #{(lift - bare).round} px over its hill"
    end
  end

  # The whole reason the silhouette samples a fixed world grid is that the same
  # place has to come back the same answer however the camera is standing — the
  # earlier versions shimmered because they asked about the screen. A canopy
  # built on the tick count or on camera_x would bring that straight back.
  def test_the_canopy_holds_still(args, assert)
    game = backdrop_game(args)
    sector = args.state.island_sectors.first
    isle = game.backdrop_island(sector)
    x = IslandWorld.centre_x(sector)

    first = game.backdrop_lift(isle, x, 2.3, 0)
    args.state.camera_x += 137
    Kernel.tick_count += 1 if Kernel.respond_to?(:tick_count=)
    second = game.backdrop_lift(isle, x, 2.3, 0)

    assert.equal! second, first, "the same place has to keep the same crown"
  end

  # --- and how it is kept ----------------------------------------------------
  #
  # Because it holds still, it is worked out once per place and remembered
  # (Game#backdrop_lift). That is worth its own guard in both directions: a
  # cache that answers too readily draws one island's hills behind another, and
  # a cache that outlives its islands draws last round's.

  def test_the_kept_crowns_are_told_apart(args, assert)
    game = backdrop_game(args)
    sector = args.state.island_sectors.first
    isle = game.backdrop_island(sector)
    centre = IslandWorld.centre_x(sector)

    assert.equal! game.backdrop_lift(isle, centre, 2.3, 0),
                  game.backdrop_lift(isle, centre, 2.3, 0),
                  "asking twice has to give the same answer"

    # Two neighbouring places may honestly share a height, and so may the two
    # ranks at one place — both round to BACKDROP_STEP. What cannot happen is a
    # whole ridge coming back as another ridge, so they are compared as lines.
    near = tree_line(game, sector, 60)
    far = []
    (0...60).each do |i|
      lift = game.backdrop_lift(isle, centre + (i - 30) * Game::BACKDROP_SAMPLE, 1.75, 1)
      far << lift if lift > 0
    end

    assert.true! near.length > 20, "the near rank is actually there"
    assert.true! far.length > 20, "the far rank is actually there"
    assert.true! near != far, "the two ranks came back as one ridge"
  end

  # A new career rolls a new seed, so the islands are new land: different
  # sectors, different shapes. Everything read off them has to go with them —
  # the silhouettes themselves and the crowns kept off them alike. The far hills
  # used to survive a reset (state.backdrop_isles was never cleared), so a new
  # round opened with the previous round's range standing behind its islands.
  def test_a_new_round_forgets_the_old_islands(args, assert)
    game = backdrop_game(args)
    sector = args.state.island_sectors.first
    before = game.backdrop_island(sector)
    game.backdrop_lift(before, IslandWorld.centre_x(sector), 2.3, 0)

    args.state.world_seed = args.state.world_seed + 1
    game.reset_game

    after = game.backdrop_island(sector)

    assert.true! !after.equal?(before),
                 "the range behind an island outlived the island it came off"
  end
end

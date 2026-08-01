# The reef, and the five corals growing on it.
#
# Corals are the first thing in the book that does not move. Everything else has
# to be chased, waited out or crept up on; a coral holds still and lets you
# frame it exactly, which is what makes the reef the place a diver can learn
# what a good frame is before the subject swims off.
class ReefTests
  def build_game(args)
    game = Game.new
    game.args = args
    game
  end

  def reef_world(args, game)
    game.initialize_game(0)
    # A stretch of sea that actually rolled the reef biome — the corals only
    # grow where the water is.
    index = (0..80).find { |i| game.world_at(i).biome.name == "Riff" }
    [index, index && game.world_at(index)]
  end

  # --- the roster ------------------------------------------------------------

  def test_there_are_five_corals_to_find(args, assert)
    corals = Species.sessile_species

    reef = corals.select { |s| s.biomes == ["Riff"] }
    assert.equal! reef.length, 5, "five kinds of coral"
    assert.true! corals.all? { |s| s.fee > 0 }, "and every one of them worth a page"
  end

  # They are pages, so they have to look like pages: a name, a latin name, a
  # size and something to say before you have identified them.
  def test_every_coral_is_a_proper_page(args, assert)
    Species.sessile_species.each do |coral|
      assert.false! coral.name.strip.empty?, "#{coral.key} has a name"
      assert.false! coral.latin.strip.empty?, "#{coral.key} has a latin name"
      assert.false! coral.tease.strip.empty?, "#{coral.key} says what it looks like"
      assert.true! coral.size_cm > 0, "#{coral.key} has a size"
    end
  end

  # One of them has to start below where the others stop, or the whole reef is a
  # single afternoon's work.
  def test_one_of_them_is_deeper_than_the_rest(args, assert)
    corals = Species.sessile_species
    deepest_start = corals.map(&:shallowest).max

    assert.true! deepest_start >= 40,
                 "every coral starts in the top #{deepest_start} m — nothing left to come back for"
  end

  # The sprite table has to match the pictures the tool wrote, the same guard
  # the decor and the camp have.
  def test_the_coral_sprites_are_the_size_the_roster_says(args, assert)
    Species.sessile_species.each do |coral|
      png = args.gtk.get_pixels(coral.sheet)

      assert.equal! png.w, coral.frame_w, "#{coral.key} is #{png.w} px wide, not #{coral.frame_w}"
      assert.equal! png.h, coral.frame_h, "#{coral.key} is #{png.h} px tall, not #{coral.frame_h}"
    end
  end

  # --- growing in the sea ----------------------------------------------------

  def test_the_reef_grows_corals(args, assert)
    game = build_game(args)
    index, world = reef_world(args, game)

    assert.false! index.nil?, "there is a reef out there somewhere"
    assert.true! world.biome.anchored_count > 0, "and it is meant to carry colonies"

    game.spawn_corals(world)
    assert.false! args.state.corals.empty?, "something grew on it"
    assert.true! args.state.corals.all? { |c| c.species.habitat == :sessile },
                 "and all of it is coral"
  end

  # A sandbank is not a reef. Corals only belong where they belong, or the one
  # biome that is *about* them stops being special.
  def test_nothing_grows_off_the_reef(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    plain = (0..80).find { |i| game.world_at(i).biome.name == "Sandbank" }
    return if plain.nil?

    game.spawn_corals(game.world_at(plain))
    assert.true! args.state.corals.empty?, "a sandbank stays a sandbank"
  end

  # Two colonies on the same column are one colony drawn twice — and a
  # photograph is a crop now, so they want to be side by side.
  def test_colonies_stand_apart(args, assert)
    game = build_game(args)
    _index, world = reef_world(args, game)
    game.spawn_corals(world)

    xs = args.state.corals.map(&:x).sort
    xs.each_cons(2) do |a, b|
      assert.true! (b - a) >= Game::CORAL_SPACING * World::COLUMN_WIDTH,
                   "two colonies #{(b - a).round} px apart"
    end
  end

  # It sits on the sand, like a crab does, rather than hanging in the water.
  def test_a_colony_sits_on_the_floor(args, assert)
    game = build_game(args)
    _index, world = reef_world(args, game)
    game.spawn_corals(world)
    coral = args.state.corals.first
    return if coral.nil?

    assert.equal! coral.y, world.floor_y_at(coral.x), "it is standing on the sand"
  end

  # It does not move, and being asked to run away does not make it.
  def test_a_coral_stays_exactly_where_it_is(args, assert)
    game = build_game(args)
    _index, world = reef_world(args, game)
    game.spawn_corals(world)
    coral = args.state.corals.first
    return if coral.nil?

    was = coral.x
    120.times { coral.tick(args, 0) }
    coral.bolt_from(was - 10)
    coral.tick(args, 0)

    assert.equal! coral.x, was, "it is still there"
  end

  # --- the seahorse ----------------------------------------------------------

  # It is anchored like a coral, because that is what a seahorse does — but it
  # lives in the kelp, not on the reef, and it is an animal rather than a rock.
  def test_the_seahorse_holds_on_in_the_kelp(args, assert)
    horse = Species["seepferdchen"]

    assert.false! horse.nil?, "there is a seahorse"
    assert.equal! horse.habitat, :sessile, "it holds on rather than swims"
    assert.equal! horse.biomes, ["Kelpwald"], "and it holds on to kelp"
    assert.equal! horse.rarity, :rare, "meeting one is a find"
  end

  def test_the_kelp_grows_seahorses_and_no_coral(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    kelp = (0..80).find { |i| game.world_at(i).biome.name == "Kelpwald" }
    return if kelp.nil?

    world = game.world_at(kelp)
    assert.true! world.biome.anchored_count > 0, "something holds on in the kelp"

    found = []
    12.times do
      game.spawn_corals(world)
      found.concat(args.state.corals.map { |c| c.species.key })
    end
    return if found.empty?

    assert.true! found.uniq == ["seepferdchen"],
                 "the kelp holds seahorses, not coral (#{found.uniq.join(", ")})"
  end

  # And it is a photographable creature like any other: in the list the camera
  # and the eye read from.
  def test_a_coral_can_be_seen_and_photographed(args, assert)
    game = build_game(args)
    index, world = reef_world(args, game)
    game.spawn_corals(world)
    return if args.state.corals.empty?

    args.state.game_scene = "area1"
    args.state.diver_global_x = index * SCREEN_WIDTH + args.state.corals.first.x
    args.state.depth_y = world.floor_y_at(args.state.corals.first.x) + 40

    assert.true! game.sea_creatures.any? { |c| c.species.habitat == :sessile },
                 "the reef is in what the camera looks at"
  end
end

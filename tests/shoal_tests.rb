# Fish that swim together. You cannot photograph a shoal that is not there, and
# until now the sea had none: every fish was rolled on its own column, so two of
# a kind close enough to share a frame was luck rather than something you could
# go and look for.
class ShoalTests
  def build_game(args)
    game = Game.new
    game.args = args
    game
  end

  def sea_of(args, game, index)
    args.state.island_sectors = [IslandWorld::HOME_SECTOR]
    args.state.world_cache = {}
    game.world_for(index)
  end

  def spread(fish)
    return [0, 0] if fish.empty?

    [fish.map(&:x).max - fish.map(&:x).min, fish.map(&:y).max - fish.map(&:y).min]
  end

  # --- the roster says who shoals ---------------------------------------------

  def test_shoaling_is_a_property_of_the_species(args, assert)
    assert.true! Species["hornhering"].shoal > 1, "a herring is a school fish"
    assert.equal! Species["laternentraeger"].shoal, 1, "the rare ones are met alone"
    assert.equal! Species["schattenhai"].shoal, 1, "and so is the shark"
  end

  # --- one school ---------------------------------------------------------------

  def school(args, game, species: Species["hornhering"], count: 4)
    game.shoal_of(species, 2, count, x: 600, y: -400,
                  from_x: 0, to_x: SCREEN_WIDTH, low: -520, high: -280)
  end

  def test_a_school_is_one_species_at_one_size(args, assert)
    game = build_game(args)
    game.initialize_game(0)

    fish = school(args, game)

    assert.equal! fish.length, 4
    assert.equal! fish.map { |one| one.species.key }.uniq, ["hornhering"]
    assert.equal! fish.map(&:size).uniq, [2], "a school is animals of a size"
  end

  # Close enough that a frame can hold them. This is the whole point of the
  # thing: a school spread over half a screen is a scattering with a name.
  def test_a_school_starts_inside_one_frame(args, assert)
    game = build_game(args)
    game.initialize_game(0)

    wide, tall = spread(school(args, game))

    assert.true! wide < Game::FRAME_WIDE, "it fits across a wide frame (#{wide.to_i} px)"
    assert.true! tall < Game::FRAME_WIDE * Game::FRAME_ASPECT, "and down it (#{tall.to_i} px)"
  end

  # And it has to *stay* a school. They share one pace on purpose — a school
  # whose members each rolled their own speed comes apart in ten seconds, and
  # then the picture is only ever there by accident.
  def test_a_school_keeps_formation(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    fish = school(args, game)
    before, = spread(fish)

    900.times { fish.each { |one| one.tick(args, 0) } }
    after, = spread(fish)

    assert.true! after <= before + 8, "still together after fifteen seconds (#{after.to_i} px)"
  end

  def test_a_loner_is_spawned_alone(args, assert)
    game = build_game(args)
    game.initialize_game(0)

    fish = school(args, game, species: Species["laternentraeger"], count: 6)

    assert.equal! fish.length, 1, "shoal 1 means one, whatever the swarm asked for"
  end

  # --- and in the sea ------------------------------------------------------------

  # Clustering must not quietly multiply the population: the biome says how many
  # fish a segment holds, and it still does — they are simply grouped now.
  def test_a_segment_still_holds_its_biome_count(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    caught = []

    (-14..14).each do |index|
      world = sea_of(args, game, index)
      game.spawn_swarm(world)
      if args.state.fish.length > world.biome.fish_count
        caught << "#{index}: #{args.state.fish.length} > #{world.biome.fish_count}"
      end
    end

    assert.equal! caught.length, 0, "never more than the biome asked for (#{caught.first(3).inspect})"
  end

  # The measurement that matters: swimming about, do you actually come across
  # two of a kind close enough to photograph together?
  def test_schools_turn_up_in_the_open_sea(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    segments = 0

    (-20..20).each do |index|
      world = sea_of(args, game, index)
      game.spawn_swarm(world)
      by_species = {}
      args.state.fish.each do |one|
        (by_species[one.species.key] ||= []) << one
      end
      segments += 1 if by_species.any? { |_, group| group.length > 1 && spread(group)[0] < Game::FRAME_WIDE }
    end

    assert.true! segments > 20, "most stretches of sea hold one (#{segments} of 41)"
  end
end

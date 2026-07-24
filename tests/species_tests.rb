# The roster of things that live out there, and how the sea picks which of them
# turns up where.
class SpeciesTests
  def build_game(args)
    game = Game.new
    game.args = args
    game
  end

  def test_every_species_is_properly_described(args, assert)
    assert.true! Species::ALL.length >= 8, "there is a roster worth filling (#{Species::ALL.length})"

    Species::ALL.each do |species|
      assert.false! species.name.empty?, "#{species.key} has a name"
      assert.false! species.latin.empty?, "#{species.key} has a latin name"
      assert.true! species.points > 0, "#{species.name} is worth something"
      assert.true! Species::RARITIES.key?(species.rarity), "#{species.name}: #{species.rarity}?"
      assert.true! species.deepest > species.shallowest,
                   "#{species.name} lives in a band of water, not a line"
      assert.false! species.biomes.empty?, "#{species.name} lives somewhere"
    end
  end

  def test_keys_and_names_are_unique(args, assert)
    keys = Species::ALL.map { |s| s.key }
    names = Species::ALL.map { |s| s.name }

    assert.equal! keys.uniq.length, keys.length, "no two species share a key"
    assert.equal! names.uniq.length, names.length, "nor a name"
  end

  def test_lookup_by_key(args, assert)
    species = Species::ALL.first

    assert.equal! Species[species.key], species, "a species can be found by its key"
    assert.equal! Species["no_such_fish"], nil, "and an unknown key finds nothing"
  end

  # Every biome has something common living in it, or a whole stretch of sea
  # comes out empty.
  def test_every_biome_has_something_common_in_it(args, assert)
    Biome::ALL.each do |biome|
      common = Species::ALL.select { |s| s.biomes.include?(biome.name) && s.rarity == :common }
      assert.true! common.length >= 1, "#{biome.name} has a common resident (#{common.length})"
    end
  end

  # Depth is what makes the deep worth the risk: the rarest things live below
  # what the suit is rated for.
  def test_the_rarest_live_deep(args, assert)
    rare = Species::ALL.select { |s| s.rarity == :rare }

    assert.true! rare.length >= 2, "there are rarities to chase (#{rare.length})"
    assert.true! rare.any? { |s| s.shallowest >= SUIT_DEPTH_LIMIT - 20 },
                 "and at least one of them lives about as deep as the suit allows"
  end

  def test_picking_respects_biome_and_depth(args, assert)
    100.times do
      species = Species.pick(Biome::SANDBANK, 10)
      next unless species

      assert.true! species.biomes.include?("Sandbank"), "#{species.name} belongs on the sandbank"
      assert.true! species.shallowest <= 10 && species.deepest >= 10,
                   "#{species.name} lives at 10 m"
    end
  end

  def test_picking_always_finds_something_for_a_biome(args, assert)
    Biome::ALL.each do |biome|
      found = 40.times.map { Species.pick(biome, 30) }.compact
      assert.true! found.length > 0, "#{biome.name} is never empty at 30 m"
    end
  end

  # Common things are common. Without that the sea would be all rarities and
  # nothing would feel like a find.
  def test_common_species_turn_up_far_more_often_than_rare_ones(args, assert)
    picks = 400.times.map { Species.pick(Biome::REEF, 30) }.compact
    common = picks.count { |s| s.rarity == :common }
    rare = picks.count { |s| s.rarity == :rare }

    assert.true! common > rare * 2, "common #{common} against rare #{rare}"
  end

  # The fish in the water carry their species with them — that is what a photo
  # is a photo *of*.
  def test_spawned_fish_carry_a_species(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    world = game.world_for(3)

    game.spawn_fauna(world)

    assert.true! args.state.fish.length > 0, "the segment has fish in it"
    args.state.fish.each do |fish|
      assert.false! fish.species.nil?, "every fish knows what it is"
      assert.true! fish.species.biomes.include?(world.biome.name),
                   "#{fish.species.name} belongs in the #{world.biome.name}"
    end
  end

  def test_a_fish_draws_from_its_species_sheet(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    game.spawn_fauna(game.world_for(3))
    fish = args.state.fish.first

    sprite = fish.to_h

    assert.equal! sprite[:path], fish.species.sheet, "it draws from its own sheet"
    assert.equal! sprite[:source_w], fish.species.frame_w
    assert.equal! sprite[:source_h], fish.species.frame_h
  end
end

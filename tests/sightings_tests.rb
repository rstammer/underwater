# Sighting a species — laying eyes on it in the water — is what puts it in the
# Artenbuch. The book fills in as you explore.
class SightingsTests
  def build_game(args)
    game = Game.new
    game.args = args
    game
  end

  def diving(args)
    game = build_game(args)
    game.initialize_game(0)
    args.state.game_scene = "area1"
    args.state.diver_global_x = 600
    args.state.depth_y = -400 # under water, so fauna is visible
    args.state.fish = []
    game
  end

  def fish_at(args, key, world_x, y)
    Creature.new(args, 0, species: Species[key], x: world_x, y: y)
  end

  def test_a_nearby_fish_gets_sighted(args, assert)
    game = diving(args)
    args.state.fish = [fish_at(args, "burgunder", 640, -400)] # right next to him

    game.update_sightings

    assert.true! game.species_known?("burgunder"), "a fish in front of him is seen"
  end

  def test_a_distant_fish_is_not_yet_sighted(args, assert)
    game = diving(args)
    args.state.fish = [fish_at(args, "burgunder", 600 + Game::SIGHT_RANGE + 200, -400)]

    game.update_sightings

    assert.false! game.species_known?("burgunder"), "too far off in the murk to count"
  end

  def test_nothing_is_sighted_at_the_surface(args, assert)
    game = diving(args)
    game.spawn_at_surface # head out; fauna hidden
    args.state.fish = [fish_at(args, "burgunder", args.state.diver_global_x, args.state.depth_y)]

    game.update_sightings

    assert.false! game.species_known?("burgunder"), "you see only water and sky up here"
  end

  def test_photographing_implies_the_species_is_known(args, assert)
    game = diving(args)
    args.state.album = { "prunkflosser" => :gut } # documented, even if never in a sighting tick

    assert.true! game.species_known?("prunkflosser"), "a photo means you saw it"
  end

  # Knowledge survives a death, like the album — a new round doesn't hide what you
  # already discovered.
  def test_sightings_survive_a_retry(args, assert)
    game = diving(args)
    args.state.fish = [fish_at(args, "hornhering", 620, -400)]
    game.update_sightings
    assert.true! game.species_known?("hornhering")

    game.reset_game

    assert.true! game.species_known?("hornhering"), "what you've seen stays seen"
  end

  def test_the_kraken_is_never_sighted_into_the_book(args, assert)
    game = diving(args)
    args.state.kraken = { x: 620, y: -400, side: 1 } # right there

    game.update_sightings

    keys = game.artenbuch_rows.map { |row| row[:species].key }
    assert.false! keys.include?("kraken"), "the legend never becomes a page"
  end
end

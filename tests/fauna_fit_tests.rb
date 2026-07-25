# A fish is not a point. It is drawn from its x/y out to the right and upwards,
# up to 64 by 32 px of it — so checking that its anchor is in open water says
# nothing about where its body is. That is how they ended up half inside cliffs
# and poking out through the surface.
class FaunaFitTests
  def build_game(args)
    game = Game.new
    game.args = args
    game
  end

  # Every corner of the animal, not the one point it happens to be drawn from.
  def body_in_rock?(world, fish)
    [[0, 0], [fish.w, 0], [0, fish.h], [fish.w, fish.h], [fish.w / 2, fish.h / 2]].any? do |dx, dy|
      world.solid_at?(fish.x + dx, fish.y + dy)
    end
  end

  def sea_of(args, game, index)
    args.state.island_sectors = [IslandWorld::HOME_SECTOR, index]
    args.state.world_cache = {}
    game.world_for(index)
  end

  def test_no_fish_is_spawned_inside_rock(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    caught = []

    (-14..14).each do |index|
      world = sea_of(args, game, index)
      game.spawn_swarm(world)
      args.state.fish.each do |fish|
        caught << "#{fish.species.name} at #{fish.x.to_i}/#{fish.y.to_i} in #{index}" if body_in_rock?(world, fish)
      end
    end

    assert.equal! caught.length, 0, "nobody starts in a wall (#{caught.first(4).inspect})"
  end

  def test_no_fish_swims_into_rock(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    caught = []

    (-14..14).each do |index|
      world = sea_of(args, game, index)
      game.spawn_swarm(world)
      900.times { args.state.fish.each { |fish| fish.tick(args, 0) } }
      args.state.fish.each do |fish|
        caught << "#{fish.species.name} at #{fish.x.to_i}/#{fish.y.to_i} in #{index}" if body_in_rock?(world, fish)
      end
    end

    assert.equal! caught.length, 0, "and nobody swims into one (#{caught.first(4).inspect})"
  end

  # The other half of the same mistake: a fish whose anchor is under the water
  # but whose back is above it.
  def test_no_fish_breaks_the_surface(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    caught = []

    (-14..14).each do |index|
      world = sea_of(args, game, index)
      game.spawn_swarm(world)
      900.times { args.state.fish.each { |fish| fish.tick(args, 0) } }
      args.state.fish.each do |fish|
        caught << "#{fish.species.name} top at #{(fish.y + fish.h).to_i}" if fish.y + fish.h > WATERLINE_Y
      end
    end

    assert.equal! caught.length, 0, "they stay under (#{caught.first(4).inspect})"
  end

  # Being frightened must not be a way through a wall either.
  def test_a_bolting_fish_stays_in_the_water_it_has(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    world = sea_of(args, game, 4)
    game.spawn_swarm(world)
    args.state.crawlers = []
    args.state.shore_life = []
    args.state.game_scene = "area1"
    game.define_singleton_method(:moving?) { true }

    900.times do
      args.state.fish.each { |fish| fish.bolt_from(fish.x - 20) } # driven right at speed
      args.state.fish.each { |fish| fish.tick(args, 0) }
    end

    caught = args.state.fish.select { |fish| body_in_rock?(world, fish) }
    assert.equal! caught.length, 0, "a startled fish does not bolt through rock"
  end

  # A cave with trapped air has a water surface of its own, well below the rock.
  # Reading only the ceiling let fish rise straight out of the water into it —
  # the same mistake as the sea surface, one level down.
  def test_no_fish_surfaces_into_a_chamber(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    caught = []

    (-14..14).each do |index|
      world = sea_of(args, game, index)
      next if world.air_pockets.empty?

      game.spawn_swarm(world)
      900.times { args.state.fish.each { |fish| fish.tick(args, 0) } }
      args.state.fish.each do |fish|
        air = world.air_line_at(fish.x)
        caught << "#{fish.species.name} at #{fish.y.to_i}, air at #{air}" if air && fish.y + fish.h > air
      end
    end

    assert.equal! caught.length, 0, "they stay under the water in there too (#{caught.first(4).inspect})"
  end
end

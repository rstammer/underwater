# The things that walk on the sea floor instead of swimming over it. They are
# species like any other — the point of them is that they are photographable —
# but where they live is the sand itself, so they belong to the terrain in a way
# a fish never is.
class CrustaceanTests
  def build_game(args)
    game = Game.new
    game.args = args
    game
  end

  def test_the_roster_has_crustaceans_on_the_floor(args, assert)
    crawlers = Species::ALL.select { |s| s.habitat == :floor }

    assert.true! crawlers.length >= 5, "there is a spread of them (#{crawlers.length})"
    crawlers.each do |species|
      assert.false! species.name.empty?, "#{species.key} has a name"
      assert.true! species.points > 0, "#{species.name} is worth something"
    end
  end

  # A fish is a fish and a crab is a crab: what swims in the water column must
  # never be rolled for the sand, or crabs would spawn floating in mid-water.
  def test_the_swimming_roll_never_returns_a_bottom_dweller(args, assert)
    200.times do
      species = Species.pick(Biome::REEF, 30)
      next unless species

      assert.equal! species.habitat, :water, "#{species.name} swims"
    end
  end

  def test_the_floor_roll_only_returns_bottom_dwellers(args, assert)
    200.times do
      species = Species.pick_floor(Biome::REEF, 30)
      next unless species

      assert.equal! species.habitat, :floor, "#{species.name} walks"
      assert.true! species.biomes.include?("Riff"), "#{species.name} belongs on the reef"
      assert.true! species.shallowest <= 30 && species.deepest >= 30,
                   "#{species.name} lives at 30 m"
    end
  end

  # Unlike the swimming roll, this one does *not* fall back to "anything from
  # this biome". The deep crab staying deep is the whole point of it: a shallow
  # stretch of deep-sea floor comes out bare rather than handing you the rarity.
  def test_a_crab_out_of_its_depth_simply_is_not_there(args, assert)
    assert.equal! Species.pick_floor(Biome::DEEP, 5), nil,
                  "nothing walks the deep sea's floor up at 5 m"
    assert.false! Species.pick_floor(Biome::DEEP, 150).nil?,
                  "but something does down at 150 m"
  end

  def test_a_crustacean_walks_along_the_sand(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    world = game.world_for(3)
    crab = Crustacean.new(args, 0, species: Species["taschenkrebs"], world: world,
                          x: 400, from_x: 320, to_x: 480)

    moved = false
    600.times do |i|
      before = crab.x
      crab.tick(args, i % 8)
      moved = true if crab.x != before
      assert.equal! crab.y, world.floor_y_at(crab.x),
                    "it stays on the sand at x #{crab.x}"
    end

    assert.true! moved, "and it does get about"
  end

  def test_it_turns_around_at_the_ends_of_its_stretch(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    world = game.world_for(3)
    crab = Crustacean.new(args, 0, species: Species["taschenkrebs"], world: world,
                          x: 400, from_x: 380, to_x: 420)

    2000.times { |i| crab.tick(args, i % 8) }

    assert.true! crab.x >= 380 && crab.x <= 420, "it kept to its stretch (#{crab.x})"
  end

  # It rests on the sand and scuttles in bursts, rather than sliding along at a
  # constant crawl — that is what reads as a crab rather than a slow fish.
  def test_it_scuttles_in_bursts_rather_than_sliding(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    world = game.world_for(3)
    crab = Crustacean.new(args, 0, species: Species["taschenkrebs"], world: world,
                          x: 400, from_x: 200, to_x: 600)

    still = 0
    600.times do |i|
      before = crab.x
      crab.tick(args, i % 8)
      still += 1 if crab.x == before
    end

    assert.true! still > 60, "it stands still a fair bit (#{still} of 600 ticks)"
    assert.true! still < 540, "but not the whole time (#{still} of 600 ticks)"
  end

  def test_a_segment_gets_its_own_crawlers_resting_on_the_floor(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.island_sectors = [] # plain sea floor, no island stamped over it
    args.state.world_cache = {}
    world = game.world_for(3)

    game.spawn_fauna(world)

    assert.true! args.state.crawlers.length > 0, "the sand is inhabited"
    args.state.crawlers.each do |crab|
      assert.equal! crab.species.habitat, :floor, "#{crab.species.name} belongs on the floor"
      assert.true! crab.species.biomes.include?(world.biome.name),
                   "#{crab.species.name} belongs in the #{world.biome.name}"
      assert.equal! crab.y, world.floor_y_at(crab.x), "it rests on the sand"
    end
  end

  # Rock is as solid for a crab as it is for the diver: it must not walk into an
  # island's flank, and must not end up inside one either.
  def test_crawlers_keep_out_of_the_rock(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.island_sectors = [4]
    args.state.world_cache = {}
    world = game.world_for(4)

    game.spawn_fauna(world)
    900.times { |i| args.state.crawlers.each { |crab| crab.tick(args, i % 8) } }

    args.state.crawlers.each do |crab|
      assert.false! world.solid_at?(crab.x, crab.y + 8),
                    "#{crab.species.name} is not inside rock at #{crab.x}/#{crab.y}"
    end
  end

  # --- the beach -----------------------------------------------------------
  #
  # Above the waterline, on an island's shore. The rule that falls out of it is
  # a nice one: under water you photograph the sea, up in the air you photograph
  # the land — so surfacing beside an island is worth something beyond breathing.

  def test_the_roster_has_something_living_on_the_beach(args, assert)
    shore = Species::ALL.select { |s| s.habitat == :shore }

    assert.true! shore.length >= 1, "there is life above the waterline"
    shore.each { |s| assert.true! s.points > 0, "#{s.name} is worth something" }
  end

  def test_neither_sea_roll_ever_returns_a_beach_dweller(args, assert)
    200.times do
      swimmer = Species.pick(Biome::SANDBANK, 20)
      crawler = Species.pick_floor(Biome::SANDBANK, 20)

      assert.false! swimmer && swimmer.habitat == :shore, "the swarm has no beach crabs"
      assert.false! crawler && crawler.habitat == :shore, "nor does the sea floor"
    end
  end

  # An island's home sector holds its high middle — measured, that stretch stands
  # 160..304 px out of the water, which is cliff, not beach. The shores are out on
  # the flanks, in the neighbouring segments. So: stamp the island, then find the
  # segment that actually has a beach on it and dive there.
  def beach_segment(args, game)
    args.state.island_sectors = [4]
    args.state.world_cache = {}
    (2..6).each do |index|
      world = game.world_for(index)
      game.spawn_fauna(world)
      return { index: index, world: world } unless args.state.shore_life.empty?
    end
    nil
  end

  def test_an_island_segment_gets_crabs_on_its_beach(args, assert)
    game = build_game(args)
    game.initialize_game(0)

    beach = beach_segment(args, game)

    assert.false! beach.nil?, "an island has a shore somewhere along it"
    assert.true! args.state.shore_life.length > 0, "the beach is inhabited"
    args.state.shore_life.each do |crab|
      assert.equal! crab.species.habitat, :shore, "#{crab.species.name} lives up here"
      assert.true! crab.y > WATERLINE_Y, "it is out of the water (#{crab.y})"
    end
  end

  def test_open_sea_has_no_beach_to_put_a_crab_on(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.island_sectors = []
    args.state.world_cache = {}

    game.spawn_fauna(game.world_for(3))

    assert.equal! args.state.shore_life.length, 0, "no island, no beach, no crabs"
  end

  def test_a_beach_crab_keeps_its_feet_dry(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    beach_segment(args, game)

    1200.times { |i| args.state.shore_life.each { |crab| crab.tick(args, i % 8) } }

    args.state.shore_life.each do |crab|
      assert.true! crab.y > WATERLINE_Y, "#{crab.species.name} never walked into the sea (#{crab.y})"
    end
  end

  # The two halves of the rule, checked from both sides.
  def test_from_the_surface_the_beach_is_what_you_can_shoot(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    beach = beach_segment(args, game)
    crab = args.state.shore_life.first
    args.state.game_scene = "area1"
    args.state.fish = []
    args.state.crawlers = []
    args.state.direction = :right
    args.state.diver_global_x = beach[:index] * SCREEN_WIDTH + crab.x - 60 # in the water just off it
    args.state.depth_y = WATERLINE_Y - SURFACE_FLOAT_DEPTH # head out, looking at the shore

    subject = game.photo_subject

    assert.false! subject.nil?, "there is something on the beach to photograph"
    assert.equal! subject[:species].habitat, :shore
  end

  def test_under_water_the_beach_is_out_of_the_picture(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    beach = beach_segment(args, game)
    crab = args.state.shore_life.first
    args.state.game_scene = "area1"
    args.state.fish = []
    args.state.crawlers = []
    args.state.direction = :right
    args.state.diver_global_x = beach[:index] * SCREEN_WIDTH + crab.x - 60
    args.state.depth_y = WATERLINE_Y - 200 # ducked under: the shore is above the surface

    assert.equal! game.photo_subject, nil, "from down here you don't shoot the beach"
  end

  def test_beach_crabs_reach_the_screen_on_a_real_tick(args, assert)
    game = build_game(args)
    game.tick # boots the game on the title screen
    beach = beach_segment(args, game)
    crab = args.state.shore_life.first
    args.state.game_scene = "area1"
    args.state.diver_global_x = beach[:index] * SCREEN_WIDTH + crab.x
    args.state.depth_y = WATERLINE_Y - SURFACE_FLOAT_DEPTH
    game.tick # floating off the beach; the tick loads the segment and stocks it

    args.outputs.sprites.clear
    game.tick

    drawn = args.outputs.sprites.flatten.map { |s| s[:path] }
    assert.true! drawn.include?(Species["strandkrabbe"].sheet), "the beach crab is drawn"
  end

  def test_a_beach_crab_gets_noticed_from_the_surface(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    beach = beach_segment(args, game)
    crab = args.state.shore_life.first
    args.state.game_scene = "area1"
    args.state.fish = []
    args.state.crawlers = []
    args.state.sighted = {}
    args.state.diver_global_x = beach[:index] * SCREEN_WIDTH + crab.x - 60
    args.state.depth_y = WATERLINE_Y - SURFACE_FLOAT_DEPTH

    game.update_sightings

    assert.true! args.state.sighted[crab.species.key], "you have seen it scuttling about"
  end

  def test_a_crustacean_draws_from_its_species_sheet(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    world = game.world_for(3)
    crab = Crustacean.new(args, 3, species: Species["hummer"], world: world, x: 400)

    sprite = crab.tick(args, 3) && crab.to_h

    assert.equal! sprite[:path], Species["hummer"].sheet, "it draws from its own sheet"
    assert.equal! sprite[:source_w], Species["hummer"].frame_w
    assert.equal! sprite[:source_h], Species["hummer"].frame_h
  end

  # The whole reason they exist: they go in the Artenbuch like anything else.
  def test_a_crab_can_be_photographed(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.game_scene = "area1"
    args.state.diver_global_x = 400
    args.state.direction = :right
    args.state.fish = []
    world = game.world_at(0)
    crab = Crustacean.new(args, 0, species: Species["taschenkrebs"], world: world, x: 430)
    args.state.crawlers = [crab]
    args.state.depth_y = crab.y + 40 # hanging just over the sand it sits on

    subject = game.photo_subject

    assert.false! subject.nil?, "the crab is a subject"
    assert.equal! subject[:species].key, "taschenkrebs"
  end

  # Everything above pokes at the pieces directly. This one goes the whole way
  # round through game.tick and the real outputs, because that is the only thing
  # that proves a crab actually reaches the screen — a missing require or a bad
  # sprite hash would leave every other test in this file happily green.
  def test_crabs_reach_the_screen_on_a_real_tick(args, assert)
    game = build_game(args)
    game.tick # boots the game on the title screen
    args.state.game_scene = "area1"
    args.state.island_sectors = []
    args.state.world_cache = {}
    args.state.active_world_index = nil
    args.state.diver_global_x = 640
    args.state.depth_y = WorldGenerator.floor_y_at(640) + 60 # down by the sand
    game.tick # loads the segment, which stocks its floor
    args.state.crawlers = [Crustacean.new(args, 0, species: Species["taschenkrebs"],
                                          world: game.current_world, x: 640)]

    args.outputs.sprites.clear
    game.tick

    drawn = args.outputs.sprites.flatten.map { |s| s[:path] }
    assert.true! drawn.include?(Species["taschenkrebs"].sheet),
                 "the crab is drawn from its own sheet"
  end

  def test_a_crab_gets_noticed_like_anything_else(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.game_scene = "area1"
    args.state.diver_global_x = 400
    args.state.fish = []
    args.state.sighted = {}
    world = game.world_at(0)
    crab = Crustacean.new(args, 0, species: Species["hummer"], world: world, x: 430)
    args.state.crawlers = [crab]
    args.state.depth_y = crab.y + 40

    game.update_sightings

    assert.true! args.state.sighted["hummer"], "you have laid eyes on a lobster"
  end
end

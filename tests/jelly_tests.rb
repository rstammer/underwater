# Jellyfish, and the field they come in.
#
# The thing being pinned down here is that a field is *terrain*: something you
# decide whether to swim through. Rolled one at a time across a segment they
# would be a fish that happens to be a jellyfish, and the whole idea would be
# gone — so most of these are about the field being a field.
class JellyTests
  def build_game(args)
    game = Game.new
    game.args = args
    game
  end

  def a_jelly_field(args)
    game = build_game(args)
    game.initialize_game(0)
    args.state.island_sectors = []
    args.state.world_cache = {}
    args.state.active_world_index = nil
    sector = (0..120).find { |i| game.world_for(i).biome.name == "Quallenfeld" }
    args.state.game_scene = "area1"
    args.state.diver_global_x = sector * SCREEN_WIDTH + 640
    game.spawn_fauna(game.world_for(sector))
    game
  end

  # --- a field, not a scattering ---------------------------------------------

  # Every time, not most times. A biome that sometimes has no field is a bug you
  # only ever meet as a flaky test.
  def test_the_jelly_water_always_has_a_field_in_it(args, assert)
    game = a_jelly_field(args)
    20.times do
      game.spawn_fauna(game.current_world)
      assert.true! args.state.jellies.length > 4, "a field, every time"
    end

    assert.true! args.state.jellies.length > 4, "a crowd, not a specimen"
    assert.true! args.state.jellies.all? { |j| j.species.habitat == :drift }
  end

  # All in one place. Spread evenly over the segment they would be scenery you
  # swim past; packed into a patch they are something you swim around.
  def test_they_are_packed_into_one_patch(args, assert)
    game = a_jelly_field(args)
    xs = args.state.jellies.map(&:x)

    assert.true! (xs.max - xs.min) < SCREEN_WIDTH / 3,
                 "the field is a patch (#{(xs.max - xs.min).round} px across)"
  end

  # One species per field: a field is a bloom, and a bloom is one animal.
  def test_a_field_is_all_one_animal(args, assert)
    game = a_jelly_field(args)

    assert.equal! args.state.jellies.map { |j| j.species.key }.uniq.length, 1
  end

  # Where the biome has no jellyfish there is no field. pick_drift has no
  # fallback for the same reason the sea floor's roll has none: a thing that
  # turns up everywhere is not worth finding.
  def test_water_without_jellyfish_has_no_field(args, assert)
    game = build_game(args)
    game.initialize_game(0)

    assert.equal! Species.pick_drift(Biome::SANDBANK, 30), nil, "not on a sandbank"
    assert.equal! Species.pick_drift(Biome::REEF, 40), nil, "nor on a reef"
  end

  # They must never be rolled into the ordinary swarm or onto the sand.
  def test_they_are_their_own_population(args, assert)
    assert.false! Species.swimmers.any? { |s| s.habitat == :drift }, "not in the swarm"
    assert.equal! Species.pick_floor(Biome::JELLY, 120)&.habitat != :drift, true
  end

  # --- alive, and out of step ------------------------------------------------

  # A field pulsing in unison is a screensaver. Every animal carries its own
  # phase so the crowd breathes rather than claps.
  def test_they_are_not_all_in_time_with_each_other(args, assert)
    game = a_jelly_field(args)
    args.state.jellies.each { |j| j.tick(args, 0) }

    frames = args.state.jellies.map { |j| j.to_h[:source_x] }

    assert.true! frames.uniq.length > 2, "the field is out of step with itself"
  end

  def test_they_drift_without_going_anywhere(args, assert)
    game = a_jelly_field(args)
    jelly = args.state.jellies.first
    home_x = jelly.x
    home_y = jelly.y

    moved = false
    2000.times do |i|
      jelly.tick(args, i % 8)
      moved = true if (jelly.y - home_y).abs > 8
      assert.true! (jelly.x - home_x).abs <= Jelly::SWAY + 1, "it stays in its patch"
      assert.true! (jelly.y - home_y).abs <= Jelly::DRIFT + 1, "and at its depth"
    end

    assert.true! moved, "but it does move"
  end

  # --- the sting -------------------------------------------------------------

  # Right on top of one. A jelly's x is local to its segment, so his world x is
  # that segment's origin plus the animal's own.
  def swimming_into_one(args)
    game = a_jelly_field(args)
    jelly = args.state.jellies.first
    sector = args.state.diver_global_x.idiv(SCREEN_WIDTH)
    args.state.diver_global_x = sector * SCREEN_WIDTH + jelly.x
    # The bell's own middle. BELL_H is in sprite pixels and the animal is drawn
    # at SIZE, so leaving the scale out put him half a bell off — near enough to
    # touch on some spawns and not others, which is a flaky test rather than a
    # wrong one.
    args.state.depth_y = jelly.y + jelly.h / 2 - Jelly::BELL_H * Jelly::SIZE / 2
    args.state.oxygen = OXYGEN_MAX
    args.state.stung_at = nil
    game
  end

  def test_touching_one_costs_air(args, assert)
    game = swimming_into_one(args)

    game.update_sting

    assert.true! args.state.oxygen < OXYGEN_MAX, "it cost him a breath"
    assert.equal! args.state.oxygen, OXYGEN_MAX - Game::STING_COST
  end

  # Air, never the suit. The suit is the depth clock and is mended only at the
  # boat, so a field between you and home would be a sentence rather than a
  # decision.
  def test_it_never_touches_the_suit(args, assert)
    game = swimming_into_one(args)
    args.state.suit = SUIT_MAX

    game.update_sting

    assert.equal! args.state.suit, SUIT_MAX
  end

  # Without a grace period, holding still in a field is not an obstacle but a
  # wall of instant death.
  def test_it_cannot_sting_you_every_tick(args, assert)
    game = swimming_into_one(args)

    game.update_sting
    after_one = args.state.oxygen
    20.times { game.update_sting }

    assert.equal! args.state.oxygen, after_one, "one sting per brush, not one per frame"
  end

  def test_open_water_never_stings(args, assert)
    game = a_jelly_field(args)
    args.state.jellies = []
    args.state.oxygen = OXYGEN_MAX

    game.update_sting

    assert.equal! args.state.oxygen, OXYGEN_MAX
  end

  # The bell, not the sprite box: most of the frame is trailing thread and clear
  # water, and being stung by water you can see through feels like a cheat.
  def test_the_sting_is_the_bell_and_not_the_empty_water(args, assert)
    game = a_jelly_field(args)
    jelly = args.state.jellies.first
    bell = jelly.bell

    assert.true! bell[:w] < jelly.w, "narrower than the frame"
    assert.true! bell[:h] < jelly.h, "and shorter than it, threads and all"
  end
end

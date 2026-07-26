# The shark against rock.
#
# Reported from a screenshot: the shark sitting motionless *inside* the dark rock
# above the diver. Two things were wrong and they fed each other — it could get
# into rock, and once in it could never get out.
class SharkTests
  ROOF_FROM = 20 # first column with rock overhead
  ROOF_TO = 60   # first column past it
  CEILING = 200  # world y of the rock's underside
  CROWN = 800    # ... and the top of it

  def build_game(args)
    game = Game.new
    game.args = args
    game
  end

  # Flat sand with a thick slab hanging over its middle: water underneath it,
  # rock from 200 to 800, open water either side. An island, in miniature.
  def walled_world(index)
    columns = WorldGenerator.columns
    floor = Array.new(columns) { 0 }
    roof = Array.new(columns) { [] }
    (ROOF_FROM...ROOF_TO).each { |c| roof[c] = [{ ceiling: CEILING, crown: CROWN }] }
    World.new(index: index, biome: Biome::SANDBANK, floor: floor, decorations: [], roof: roof)
  end

  def x_under_roof
    (ROOF_FROM + 10) * World::COLUMN_WIDTH
  end

  def x_in_open_water
    (ROOF_TO + 20) * World::COLUMN_WIDTH
  end

  # The diver hangs in the open water *below* the slab, so there is somewhere
  # free for the shark to be — otherwise "it must not come in inside rock" is
  # a demand nothing could meet.
  def under_the_slab(args)
    game = build_game(args)
    game.initialize_game(0)
    args.state.island_sectors = []
    args.state.world_cache = { 0 => walled_world(0) }
    args.state.active_world_index = nil # force a re-read of the segment
    args.state.game_scene = "area1"
    args.state.diver_global_x = x_in_open_water
    args.state.depth_y = 100 # under the slab, above the sand
    game.current_world
    game
  end

  # --- where it feels for rock ----------------------------------------------

  # Its position is the bottom-left of its sprite square and the animal sits
  # HITBOX_Y up from there. Probing y, y - HEIGHT and y + HEIGHT sampled two
  # points below the fish and never touched its back.
  def test_it_feels_for_rock_where_its_body_actually_is(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    bottom = 500 + DarkShark::HITBOX_Y
    top = bottom + DarkShark::HITBOX_H

    probes = game.shark_body_ys(500)

    assert.true! probes.all? { |y| y >= bottom && y <= top },
                 "every probe is on the animal: #{probes.inspect} against #{bottom}..#{top}"
    assert.true! probes.include?(top), "including its back — that is what a ceiling meets first"
  end

  def test_a_ceiling_over_its_back_is_rock(args, assert)
    game = under_the_slab(args)
    # Sitting so its belly is clear of the slab but its back is four pixels in.
    y = CEILING - DarkShark::HITBOX_Y - DarkShark::HITBOX_H + 4

    assert.true! game.shark_span_solid?(x_under_roof, y),
                 "its back is in the rock, so the rock is in its way"
  end

  # --- how it comes back in --------------------------------------------------

  # It used to be clamped against the sand and the waterline only, which are the
  # two things an island is not. That is how it got in. The contract now: a
  # depth it fits at, or nil for "this water is walled off" — never rock.
  def test_a_patrol_depth_is_never_rock(args, assert)
    game = under_the_slab(args)
    args.state.dark_shark = { x: x_under_roof, y: 0, dir: 1 }
    nose = game.shark_nose_x(args.state.dark_shark)

    30.times do
      y = game.shark_patrol_y
      next if y.nil? # no way in here, which is an answer

      assert.false! game.shark_span_solid?(nose, y),
                    "a patrol depth of #{y} puts it in the slab (#{CEILING}..#{CROWN})"
    end
  end

  def test_open_water_always_has_a_depth_to_come_in_at(args, assert)
    game = under_the_slab(args)
    args.state.dark_shark = { x: x_in_open_water, y: 0, dir: 1 }

    assert.false! game.shark_patrol_y.nil?, "nothing in the way out here"
  end

  # --- and how it gets out ---------------------------------------------------

  # The symptom in the screenshot: in rock, shark_blocked? turns it round every
  # single tick, so it shivers on the spot for the rest of the round.
  def test_a_shark_in_the_rock_leaves_instead_of_shivering(args, assert)
    game = under_the_slab(args)
    args.state.dark_shark = { x: x_under_roof, y: 400, dir: 1 } # squarely in the slab
    was_at = args.state.dark_shark.x

    game.update_shark(0)

    shark = args.state.dark_shark
    assert.false! game.shark_span_solid?(game.shark_nose_x(shark), shark.y),
                  "it is out of the rock"
    assert.not_equal! shark.x, was_at, "and not still stuck where it was"
  end

  def test_turning_on_the_spot_forever_counts_as_stuck(args, assert)
    game = under_the_slab(args)
    args.state.dark_shark = { x: x_in_open_water, y: 60, dir: 1,
                              turns: Game::SHARK_STUCK_TURNS }

    game.update_shark(0)

    shark = args.state.dark_shark
    assert.true! [-300, SCREEN_WIDTH].include?(shark.x), "it came round again (#{shark.x})"
    assert.equal! shark.turns, 0, "with a clean slate"
  end

  # The one the screenshot was actually of: at the diver's own segment edge the
  # world can be solid island from the sand to above the waterline. Both ways in
  # walled off means waiting outside — never entering the rock.
  def walled_in(args)
    game = build_game(args)
    game.initialize_game(0)
    args.state.island_sectors = []
    solid = solid_world(0)
    args.state.world_cache = { -1 => solid_world(-1), 0 => solid, 1 => solid_world(1) }
    args.state.active_world_index = nil
    args.state.game_scene = "area1"
    args.state.diver_global_x = 640
    args.state.depth_y = 400
    game.current_world
    game
  end

  # Rock from under the sand to well over the waterline, right across.
  def solid_world(index)
    columns = WorldGenerator.columns
    World.new(index: index, biome: Biome::SANDBANK,
              floor: Array.new(columns) { 0 }, decorations: [],
              roof: Array.new(columns) { [{ ceiling: -400, crown: WATERLINE_Y + 400 }] })
  end

  def test_a_walled_approach_makes_it_wait_outside(args, assert)
    game = walled_in(args)
    args.state.dark_shark = { x: 400, y: 400, dir: 1 }

    game.update_shark(0)

    shark = args.state.dark_shark
    assert.true! game.shark_off_segment?(shark),
                 "it waits out of the way rather than in the wall (x #{shark.x})"
  end

  # Swimming freely must not look like being stuck, or it would keep resetting
  # itself off the edge of the world.
  def test_open_water_never_counts_as_stuck(args, assert)
    game = under_the_slab(args)
    args.state.dark_shark = { x: x_in_open_water, y: 60, dir: 1 }

    20.times { game.update_shark(0) }

    assert.equal! args.state.dark_shark.turns.to_i, 0, "nothing in its way, nothing to count"
  end
end

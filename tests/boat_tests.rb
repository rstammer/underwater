# The boat as a thing that *moves*. It used to be a constant — one mooring at
# world x 120, the same every round for ever — and everything that says "home"
# read that constant. Now it is a position you can change, so a diver who has
# worked a stretch of sea out can pick the boat up and take it somewhere else.
#
# This file is the foundation: the boat has a place, and everything that talks
# about home agrees on where that is. Steering it there is the next thing.
class BoatTests
  def build_game(args)
    game = Game.new
    game.args = args
    game
  end

  def afloat(args)
    game = build_game(args)
    game.initialize_game(0)
    args.state.game_scene = "area1"
    game.current_world
    game
  end

  # --- the boat has a position ------------------------------------------------

  def test_a_new_round_moors_the_boat_at_the_home_mooring(args, assert)
    game = afloat(args)

    assert.equal! args.state.boat_x, Game::SURFACE_BOAT_X,
                  "a first round starts where the boat has always been"
  end

  def test_the_diver_spawns_beside_the_boat_wherever_it_is(args, assert)
    game = afloat(args)
    args.state.boat_x = Game::SURFACE_BOAT_X + 12 * SCREEN_WIDTH

    game.spawn_at_surface

    assert.true! (args.state.diver_global_x - args.state.boat_x).abs < Game::BOAT_REACH,
                 "he wakes up next to his own boat, not where it used to be"
    assert.true! game.at_the_boat?, "and close enough to use it"
  end

  # The one that catches the whole class of bug this change invites: a place
  # that still measures home against the old constant keeps working perfectly at
  # sector 0 and silently stops working the moment the boat moves.
  def test_being_at_the_boat_follows_the_boat(args, assert)
    game = afloat(args)
    args.state.boat_x = 9 * SCREEN_WIDTH
    args.state.diver_global_x = 9 * SCREEN_WIDTH + 40
    args.state.depth_y = WATERLINE_Y - Diver::HEIGHT

    assert.true! game.at_the_boat?, "beside it out there counts as being home"

    args.state.diver_global_x = Game::SURFACE_BOAT_X
    assert.false! game.at_the_boat?, "and the old mooring does not"
  end

  def test_the_boat_shows_wherever_it_is_moored(args, assert)
    game = afloat(args)
    args.state.boat_x = 9 * SCREEN_WIDTH
    args.state.diver_global_x = 9 * SCREEN_WIDTH
    game.center_camera

    assert.true! game.home_visible?, "you can see it when you are next to it"

    args.state.diver_global_x = 0
    game.center_camera
    assert.false! game.home_visible?, "and not back where it used to be"
  end

  # Every screen outside the water is built on a view of the real sea parked
  # beside the boat. Anchored to the old constant it would show empty water at
  # sector 0 while the boat sat five sectors away.
  def test_the_menu_horizon_looks_at_the_boat(args, assert)
    game = afloat(args)
    args.state.boat_x = 6 * SCREEN_WIDTH

    game.render_boat_horizon

    assert.true! (args.state.camera_x - args.state.boat_x).abs < SCREEN_WIDTH,
                 "the horizon behind the menus is this boat's horizon"
  end

  # --- it stays where you left it ---------------------------------------------

  # Where you moored is a fact about your career, like the Artenbuch and the
  # hold: sailing two days east and having the boat snap back overnight would
  # make the whole business pointless.
  def test_where_it_is_moored_survives_the_round_trip(args, assert)
    back = SaveFile.decode(SaveFile.encode(name: "Kins", album: {}, sighted: {},
                                           boat_x: 7 * SCREEN_WIDTH))

    assert.equal! back[:boat_x], 7 * SCREEN_WIDTH
  end

  # Westward sectors are negative, and the counter lines in the save file only
  # ever wrote values above zero — so a boat taken out to the left would have
  # come back moored at the origin.
  def test_a_mooring_to_the_west_survives_too(args, assert)
    back = SaveFile.decode(SaveFile.encode(name: "Kins", album: {}, sighted: {},
                                           boat_x: -4 * SCREEN_WIDTH))

    assert.equal! back[:boat_x], -4 * SCREEN_WIDTH
  end

  def test_a_book_from_before_boats_moved_moors_at_the_old_place(args, assert)
    back = SaveFile.decode("name Kins\nalbum burgunder perfekt\n")

    assert.equal! back[:boat_x], Game::SURFACE_BOAT_X,
                  "an old save is a boat that never left home"
  end

  # --- how far it may go ------------------------------------------------------
  #
  # One sector past the furthest you have *swum*, each way. So the sea opens up
  # a boat-length at a time and the far islands stay something you work towards,
  # rather than a place you motor to on the first morning.

  def test_swimming_charts_the_sector_you_are_in(args, assert)
    game = afloat(args)
    args.state.diver_global_x = 3 * SCREEN_WIDTH + 100
    args.state.depth_y = WATERLINE_Y - 400
    game.current_world

    game.track_log

    assert.equal! args.state.charted_east, 3, "he has been out to sector three"
  end

  def test_the_chart_remembers_the_furthest_each_way(args, assert)
    game = afloat(args)
    args.state.depth_y = WATERLINE_Y - 400

    [5, -4, 2, -1].each do |sector|
      args.state.diver_global_x = sector * SCREEN_WIDTH + 100
      game.current_world
      game.track_log
    end

    assert.equal! args.state.charted_east, 5, "the furthest east he ever got"
    assert.equal! args.state.charted_west, -4, "and the furthest west"
  end

  def test_the_boat_may_go_one_sector_past_the_chart(args, assert)
    game = afloat(args)
    args.state.charted_west = -2
    args.state.charted_east = 4

    assert.equal! game.boat_range, [-3, 5], "one sector further than he has swum, each way"
  end

  # The rule only means anything if motoring about does not itself count as
  # exploring. Without this you could inch out for ever: sail to the edge, let
  # the sailing chart it, sail one further, and the sea has no end.
  def test_sailing_does_not_chart_the_water_you_sail_over(args, assert)
    game = afloat(args)
    args.state.charted_east = 1
    args.state.aboard = true
    args.state.diver_global_x = 4 * SCREEN_WIDTH
    args.state.boat_x = 4 * SCREEN_WIDTH
    game.current_world

    game.track_log

    assert.equal! args.state.charted_east, 1, "riding over water is not knowing it"
  end

  def test_the_chart_survives_the_round_trip(args, assert)
    back = SaveFile.decode(SaveFile.encode(name: "Kins", album: {}, sighted: {},
                                           charted_west: -6, charted_east: 9))

    assert.equal! back[:charted_west], -6
    assert.equal! back[:charted_east], 9
  end

  # A fresh diver is not stuck in a puddle. The chart opens wide enough that the
  # island next door and the Späti are both somewhere the boat can go — the
  # first of those exists precisely so a round never opens with a hunt for a
  # beach, and it sits at sector −2, which a chart starting at nothing put out
  # of reach for ever.
  def test_a_new_chart_already_covers_the_islands_the_game_hands_you(args, assert)
    game = afloat(args)
    west, east = game.boat_range

    assert.true! west <= IslandWorld::HOME_SECTOR,
                 "the island next door is somewhere she can go from the first morning"
    assert.true! east >= IslandWorld::SHOP_SECTOR, "and so is the Späti"
    assert.true! west > IslandWorld::BEACH_SECTOR,
                 "but the beach at #{IslandWorld::BEACH_SECTOR} still has to be found"
  end

  def test_a_book_from_before_charts_gets_the_same_opening(args, assert)
    back = SaveFile.decode("name Kins\n")

    assert.equal! back[:charted_west], -Game::CHART_START
    assert.equal! back[:charted_east], Game::CHART_START
  end

  # Carrying on a book written while the chart was narrower must not leave that
  # diver worse off than somebody starting today — his own five days of
  # exploring were never written down anywhere, so there is nothing to
  # reconstruct them from.
  def test_carrying_on_an_old_book_widens_a_narrow_chart(args, assert)
    game = afloat(args)
    args.state.saved_book = SaveFile.decode("name Kins\ncharted 0 6\n")

    game.continue_round(1)

    assert.true! args.state.charted_west <= -Game::CHART_START,
                 "the side he never charted opens to what a beginner gets"
    assert.equal! args.state.charted_east, 6,
                  "and the side he did reach further on is left alone"
  end

  def test_carrying_on_never_shrinks_a_chart_he_earned(args, assert)
    game = afloat(args)
    args.state.saved_book = SaveFile.decode("name Kins\ncharted -9 11\n")

    game.continue_round(1)

    assert.equal! args.state.charted_west, -9, "hard-won water stays his"
    assert.equal! args.state.charted_east, 11
  end

  # --- sailing it -------------------------------------------------------------

  def alongside(args)
    game = afloat(args)
    args.state.depth_y = WATERLINE_Y - Diver::HEIGHT
    args.state.diver_global_x = args.state.boat_x + 40
    game.current_world
    game
  end

  # Empty water: the rolled islands land where they land, and a test about what
  # a crossing costs must not fail because one of them was in the way.
  def open_sea(args)
    game = alongside(args)
    args.state.island_sectors = []
    args.state.world_cache = {}
    args.state.charted_east = 8
    args.state.beach_band = nil
    game.current_world
    game
  end

  def test_you_can_climb_aboard_beside_the_boat(args, assert)
    game = alongside(args)

    game.board_boat

    assert.true! args.state.aboard, "he is in his boat"
  end

  def test_you_cannot_climb_aboard_from_out_at_sea(args, assert)
    game = alongside(args)
    args.state.diver_global_x = args.state.boat_x + 4 * SCREEN_WIDTH

    game.board_boat

    assert.false! args.state.aboard, "a boat a mile off is not a boat you get into"
  end

  def test_sailing_moves_the_boat_and_takes_him_with_it(args, assert)
    game = alongside(args)
    game.board_boat
    was = args.state.boat_x

    20.times { game.sail(1) }

    assert.true! args.state.boat_x > was, "the boat has made way"
    assert.true! (args.state.diver_global_x - args.state.boat_x).abs < Game::BOAT_REACH,
                 "and he is still in it"
    assert.true! args.state.depth_y >= WATERLINE_Y - SURFACE_FLOAT_DEPTH - 1,
                 "riding on the surface, not being dragged under"
  end

  # The rule has to be felt as a wall, not as a number in a menu.
  def test_it_stops_one_sector_past_the_chart(args, assert)
    game = alongside(args)
    args.state.charted_east = 1
    game.board_boat

    2000.times { game.sail(1) }

    assert.true! args.state.boat_x < 3 * SCREEN_WIDTH,
                 "sector two is as far as it goes, and it is #{args.state.boat_x / SCREEN_WIDTH}"
    assert.true! game.boat_blocked?, "and it says why it has stopped"
  end

  def test_it_stops_going_west_too(args, assert)
    game = alongside(args)
    args.state.charted_west = -1
    game.board_boat

    4000.times { game.sail(-1) }

    assert.true! args.state.boat_x >= -2 * SCREEN_WIDTH,
                 "it is #{args.state.boat_x / SCREEN_WIDTH} sectors out"
  end

  # He says it himself rather than a rule appearing on screen — the boat has
  # stopped because the man steering it does not know what is ahead.
  def test_the_diver_says_why_he_has_stopped(args, assert)
    game = alongside(args)
    args.state.charted_east = 0
    game.board_boat
    2000.times { game.sail(1) }

    assert.true! game.boat_block_line.include?("Erkundungstour"),
                 "he says he has to go and look first"
  end

  # The running message boxes are one fixed width, so a line that is a few
  # pixels too long simply runs out through the side of its own box on screen
  # while every character count is perfectly happy. Measured, not counted.
  def test_what_he_says_fits_the_box_it_is_said_in(args, assert)
    game = alongside(args)
    width = args.gtk.calcstringbox(game.boat_block_line, 0)[0]
    room = Game::MESSAGE_W - 40

    assert.true! width <= room,
                 "\"#{game.boat_block_line}\" is #{width.round} px in a #{room} px box"
  end

  def test_the_message_fades_once_he_turns_back(args, assert)
    game = alongside(args)
    args.state.charted_east = 0
    game.board_boat
    2000.times { game.sail(1) }
    args.state.blocked_at -= Game::BOAT_BLOCK_TICKS + 1

    assert.false! game.boat_blocked?, "it does not hang there for the rest of the day"
  end

  # --- what you see of it -----------------------------------------------------

  # He is *in* the boat. Drawn as well, he floated alongside his own hull like a
  # man being towed, which is the one reading the whole thing must not have.
  def test_he_is_not_drawn_while_he_is_aboard(args, assert)
    game = alongside(args)
    game.board_boat
    game.center_camera

    game.render_diver

    assert.true! args.outputs.sprites.empty?, "nobody is swimming out here"
  end

  def test_he_is_drawn_again_once_he_is_back_in_the_water(args, assert)
    game = alongside(args)
    game.board_boat
    game.anchor_boat
    game.center_camera

    game.render_diver

    assert.false! args.outputs.sprites.empty?, "he is back over the side"
  end

  # A boat that changes position without anything happening at the waterline
  # reads as a sprite being moved, not as a boat going somewhere.
  def test_a_moving_boat_throws_spray(args, assert)
    game = alongside(args)
    args.state.charted_east = 4
    game.board_boat
    game.sail(1)
    game.center_camera

    game.render_wake

    assert.false! args.outputs.sprites.empty?, "there is water coming off her"
  end

  def test_a_boat_at_rest_throws_none(args, assert)
    game = alongside(args)
    game.board_boat
    game.center_camera

    game.render_wake

    assert.true! args.outputs.sprites.empty?, "moored, she sits still"
  end

  # It has to stop when he stops, not trail off over the next few seconds.
  def test_the_spray_dies_away_when_he_stops_steering(args, assert)
    game = alongside(args)
    args.state.charted_east = 4
    game.board_boat
    game.sail(1)
    args.state.wake_at -= Game::WAKE_TICKS + 1
    game.center_camera

    game.render_wake

    assert.true! args.outputs.sprites.empty?, "she settles as soon as he eases off"
  end

  # --- islands ----------------------------------------------------------------
  #
  # She goes *behind* them. There is no navigating round an island in a game
  # with one axis to steer on, so rather than make it a wall she passes astern
  # of it — the rock is nearer to you than she is, and that is all it takes.

  # Floating just off the beach island: near enough that its rock is inside the
  # anchor's clearance, but still in water — moored *on* the island the diver
  # gets clamped onto it by center_camera and is not at the surface at all,
  # which is a different thing being tested.
  def at_the_beach_island(args)
    game = alongside(args)
    args.state.charted_west = -9
    # The islands are pinned rather than left to the roll. One of the four is
    # rolled from the world seed, which is fresh every game, and when it lands
    # alongside the beach it stamps its crown across part of it — so the shore
    # this hunts for moves, and any offset measured from it is a different place
    # in a different sea. Both of these tests failed about one run in three
    # before it was nailed down.
    args.state.island_sectors = [IslandWorld::HOME_SECTOR, IslandWorld::SHOP_SECTOR,
                                 IslandWorld::BEACH_SECTOR]
    # Memoised per round, so they must go with it or they answer for the world
    # that was stamped before.
    args.state.beach_band = nil
    args.state.world_cache = {}
    game.current_world
    first = IslandWorld.first_x_for(IslandWorld::BEACH_SECTOR)
    shore = (0..40).map { |i| first + i * 40 }
                   .find { |x| (game.crown_at_world_x(x) || 0) > WATERLINE_Y }
    args.state.boat_x = shore - Game::ANCHOR_CLEARANCE / 2
    args.state.diver_global_x = args.state.boat_x
    game.current_world
    game.center_camera
    game
  end

  # There was a test here pinning the draw order — the boat painted before the
  # rock, so an island covered her. It has been taken out rather than mended,
  # because it now contradicts the thing that replaced it: she is hidden outright
  # while an island is across her, so at an island there is no boat on screen for
  # the rock to be painted over. It failed about one run in eight, which is the
  # worst way for a stale test to go.
  #
  # The order still matters and is still there. What is checked now is what you
  # can actually see: gone behind an island, drawn in open water.

  # --- which way she is pointing ----------------------------------------------

  def test_she_turns_round_when_he_turns_round(args, assert)
    game = open_sea(args)
    game.board_boat

    game.sail(1)
    east = game.home_boat[:flip_horizontally]
    game.sail(-1)
    west = game.home_boat[:flip_horizontally]

    assert.false! east, "heading east she is drawn as she is drawn"
    assert.true! west, "heading west she is turned about"
  end

  def test_she_keeps_pointing_the_way_he_left_her(args, assert)
    game = open_sea(args)
    game.board_boat
    40.times { game.sail(-1) }

    game.anchor_boat

    assert.true! game.home_boat[:flip_horizontally],
                 "moored, she still lies the way she came in"
  end

  # The motor is at her stern, so the wash has to come off the same end — foam
  # boiling off the bow is a boat going backwards.
  def test_the_wash_comes_off_the_stern(args, assert)
    game = open_sea(args)
    game.board_boat
    game.sail(1)
    game.center_camera
    game.render_wake
    astern_of_east = args.outputs.sprites.map { |s| s[:x] }.min

    args.outputs.sprites.clear
    game.sail(-1)
    game.center_camera
    game.render_wake
    astern_of_west = args.outputs.sprites.map { |s| s[:x] }.max

    middle = game.home_boat[:x]
    assert.true! astern_of_east < middle, "making east, the wash is behind her"
    assert.true! astern_of_west > middle, "making west, it is behind her the other way"
  end

  # A ladder trailing in the water at seven pixels a tick is a ladder that is
  # about to be somebody else's problem. It comes in when he casts off.
  def test_the_ladder_is_hauled_in_under_way(args, assert)
    game = open_sea(args)
    game.board_boat

    assert.equal! game.home_boat[:path], Game::BOAT_UNDERWAY_SPRITE[:path]
  end

  def test_it_goes_back_over_the_side_once_she_is_moored(args, assert)
    game = open_sea(args)
    game.board_boat
    game.anchor_boat

    assert.equal! game.home_boat[:path], Game::BOAT_SPRITE[:path],
                  "moored, it is how he gets aboard"
  end

  # Where he moored has to reach the disk, and dropping the anchor is the only
  # moment it can. The book is written when what it holds changes — a species
  # developed, a name typed, a day ended — and a voyage is none of those. It
  # used to end the day, which saved it as a side effect; when the day cost went
  # (it was an interruption, not a cost) the only thing that ever wrote the
  # mooring went with it, silently. Sail three sectors, quit, come back at the
  # old berth.
  def test_anchoring_writes_the_mooring_to_the_book(args, assert)
    game = open_sea(args)
    game.board_boat
    400.times { game.sail(1) }
    moored = args.state.boat_x

    game.anchor_boat

    back = SaveFile.decode($gtk.read_file(SaveFile::TEST_PATH))
    assert.equal! back[:boat_x], moored, "the book knows where she is"
  end

  # The chart widens while he swims, and that has to survive the session too —
  # it is what his range is measured against.
  def test_anchoring_writes_the_chart_as_well(args, assert)
    game = open_sea(args)
    args.state.charted_east = 9
    game.board_boat
    400.times { game.sail(1) }

    game.anchor_boat

    back = SaveFile.decode($gtk.read_file(SaveFile::TEST_PATH))
    assert.equal! back[:charted_east], 9
  end

  # --- the seam at the shore --------------------------------------------------

  # From the surface the sea hides the rock beneath it, which is why an island
  # is a solid wall of sand ending at the waterline. That left nothing to cover
  # the part of the boat that is *under* the water, so her hull and her ladder
  # showed straight through the island she was passing.
  def test_rock_is_cut_off_at_the_waterline_when_you_are_swimming(args, assert)
    game = alongside(args)

    assert.equal! game.surface_clip_y, WATERLINE_Y,
                  "from the water you cannot see the rock under it"
  end

  def test_it_reaches_below_the_waterline_while_he_is_aboard(args, assert)
    game = open_sea(args)
    game.board_boat

    assert.true! game.surface_clip_y < WATERLINE_Y - Game::BOAT_DRAUGHT + 1,
                 "far enough down to cover her keel"
  end

  # --- where she may be left --------------------------------------------------

  def test_you_cannot_anchor_up_against_an_island(args, assert)
    game = at_the_beach_island(args)
    game.board_boat
    game.sail(1)

    assert.false! game.anchorage?, "she would be on the rocks by morning"
  end

  def test_open_water_is_a_fine_place_to_leave_her(args, assert)
    game = alongside(args)
    args.state.boat_x = 30 * SCREEN_WIDTH

    assert.true! game.anchorage?, "nothing out here to go aground on"
  end

  def test_anchoring_against_an_island_does_not_take_and_costs_nothing(args, assert)
    game = at_the_beach_island(args)
    args.state.credits = 500
    game.board_boat
    was = args.state.boat_x

    game.anchor_boat

    assert.true! args.state.aboard, "he is still at the tiller"
    assert.equal! args.state.boat_x, was, "she has not moved herself"
    assert.equal! args.state.credits, 500, "and nothing has been charged for a stop that did not happen"
  end

  def test_he_says_why_he_will_not_anchor_there(args, assert)
    game = at_the_beach_island(args)
    game.board_boat
    game.sail(1)
    game.anchor_boat

    assert.true! game.boat_blocked?, "the refusal is on screen"
    assert.true! game.boat_block_line.length > 0
  end

  def test_that_line_fits_its_box_too(args, assert)
    game = at_the_beach_island(args)
    game.board_boat
    game.sail(1)
    game.anchor_boat
    width = args.gtk.calcstringbox(game.boat_block_line, 0)[0]

    assert.true! width <= Game::MESSAGE_W - 40,
                 "\"#{game.boat_block_line}\" is #{width.round} px"
  end

  # --- the view from the boat -------------------------------------------------
  #
  # Steering, you are looking at the sea from a boat: sky above, waterline
  # across, and that framing holds whatever is underneath. The camera used to be
  # the diver's, which meant passing an island threw the view underwater — the
  # man in the boat was being clamped onto the rock beneath him and the camera
  # dutifully went with him.

  def test_passing_an_island_does_not_drop_the_view_underwater(args, assert)
    game = at_the_beach_island(args)
    game.board_boat
    before = args.state.depth_y

    120.times { game.sail(1) }

    assert.equal! args.state.depth_y.round, before.round,
                  "she is on the water, not climbing the beach"
    assert.true! game.at_open_surface?, "the view stays above the waterline"
    assert.false! args.state.on_land, "a boat does not come ashore"
  end

  def test_the_horizon_holds_steady_while_he_steers(args, assert)
    game = at_the_beach_island(args)
    game.board_boat
    game.sail(1)
    first = args.state.camera_y

    200.times { game.sail(1) }

    assert.equal! args.state.camera_y.round, first.round,
                  "the waterline sits still while the world goes past"
  end

  # --- what the crossing costs ------------------------------------------------

  # It used to end the day, on the reasoning that a crossing is a day's work.
  # In the hand that is just an interruption — move the boat and the game takes
  # the afternoon off — so it costs fuel and the time it takes to steer, and
  # nothing else.
  def test_anchoring_does_not_take_the_rest_of_the_day(args, assert)
    game = open_sea(args)
    game.board_boat
    600.times { game.sail(1) }

    game.anchor_boat

    assert.false! args.state.aboard, "he is back in the water beside it"
    assert.false! args.state.game_scene == "night", "the afternoon is still his"
  end

  def test_a_crossing_burns_fuel_by_the_sector(args, assert)
    game = open_sea(args)
    args.state.credits = 500
    game.board_boat
    sectors = 3
    (sectors * SCREEN_WIDTH / Game::BOAT_SPEED).to_i.times { game.sail(1) }

    game.anchor_boat

    assert.true! args.state.credits < 500, "fuel is not free"
    assert.equal! args.state.credits, 500 - sectors * Game::BOAT_FUEL,
                  "charged by how far it went, not by the trip"
  end

  # Getting in, thinking better of it and getting out again is not a voyage.
  def test_climbing_back_out_where_you_started_costs_nothing(args, assert)
    game = open_sea(args)
    args.state.credits = 500
    game.board_boat

    game.anchor_boat

    assert.equal! args.state.credits, 500, "he never left the mooring"
    assert.false! args.state.game_scene == "night", "and it is still the same day"
  end

  # Dying is losing the round, not losing the boat.
  def test_drowning_does_not_sail_the_boat_home(args, assert)
    game = afloat(args)
    args.state.boat_x = 5 * SCREEN_WIDTH

    game.reset_game

    assert.equal! args.state.boat_x, 5 * SCREEN_WIDTH,
                  "it is still where you left it"
  end
end

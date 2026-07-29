# The people on the beach — the island in sector -5, and the seven who spend
# their day on it. They are the game's second piece of signposting after the
# shop, and the only one that talks about the deep.
class IslanderTests
  def build_game(args)
    game = Game.new
    game.args = args
    game
  end

  # Ashore on the beach island, on foot, where you would be after wading up.
  def ashore(args)
    game = build_game(args)
    game.initialize_game(0)
    args.state.game_scene = "area1"
    args.state.diver_global_x = IslandWorld.centre_x(IslandWorld::BEACH_SECTOR)
    args.state.on_land = true
    game.current_world
    game
  end

  # --- where they are --------------------------------------------------------

  # Fixed, like the shop's: people you can go back to have to be somewhere you
  # can go back to.
  def test_there_is_always_an_island_at_the_beach_sector(args, assert)
    game = build_game(args)
    10.times do
      game.initialize_game(0)
      assert.true! args.state.island_sectors.include?(IslandWorld::BEACH_SECTOR),
                   "the beach island is there every round"
    end
  end

  # You have to be able to walk up it, or there is nobody to talk to.
  def test_the_beach_island_can_be_walked_up(args, assert)
    assert.equal! IslandWorld.shape_for(IslandWorld::BEACH_SECTOR)[:shore], :through
  end

  # It is its own island, not the shop's: Andi keeps his stall to himself.
  def test_it_is_not_the_shop_island(args, assert)
    assert.false! IslandWorld::BEACH_SECTOR == IslandWorld::SHOP_SECTOR,
                  "the shop and the bathers are two different places"
    assert.false! IslandWorld::BEACH_SECTOR == IslandWorld::HOME_SECTOR,
                  "and neither is the island next door"
  end

  # --- who they are ----------------------------------------------------------

  def test_everybody_has_a_name_and_something_to_say(args, assert)
    Islander::ALL.each do |person|
      assert.false! person.name.strip.empty?, "everybody is somebody"
      assert.false! person.lines.empty?, "#{person.name} has something to say"
    end
  end

  def test_the_cast_is_who_it_should_be(args, assert)
    names = Islander::ALL.map(&:name)
    ["Flori", "Falko", "Hendrik", "Tall Pete", "Sebastián", "George", "Mike"].each do |name|
      assert.true! names.include?(name), "#{name} is on the island"
    end
  end

  # He is Sebastián, accent and all — and George says his name out loud, so the
  # spelling has to hold in the lines as well as on the roster. A name spelled
  # two ways is two people.
  def test_sebastian_is_spelled_the_same_wherever_he_is_named(args, assert)
    sebastian = Islander["sebastian"]
    naming = Islander::ALL.flat_map(&:all_lines).select { |line| line.include?("ebasti") }

    assert.equal! sebastian.name, "Sebastián"
    assert.false! naming.empty?, "somebody says his name"
    naming.each do |line|
      assert.true! line.include?("Sebastián"), "\"#{line}\" spells it his way"
    end
  end

  # Nobody stands on top of anybody else — they are spread along the island.
  # Only the campers: the keeper is on the other island and the warden stands at
  # reception, so neither of their spots is a position on this run.
  def test_they_stand_apart(args, assert)
    spots = Islander::ALL.reject { |person| [:keeper, :warden].include?(person.kind) }
                         .map(&:spot).sort
    spots.each_cons(2) do |a, b|
      assert.true! (b - a) > 0.04, "there is room between #{a} and #{b}"
    end
  end

  # --- what they say ---------------------------------------------------------

  # Everybody but Mike deals in rumour: they are people on the surface talking
  # about a place none of them has been.
  def test_the_rumours_never_say_where(args, assert)
    Islander::ALL.reject { |person| person.name == "Mike" }.each do |person|
      person.all_lines.each do |line|
        assert.false! line.include?("Meter"), "#{person.name} does not measure anything"
      end
    end
  end

  # Mike is the exception and the reason is that he runs the place: he has
  # watched this water for years, so his is the line you can act on.
  def test_mike_gives_something_you_can_act_on(args, assert)
    mike = Islander::ALL.find { |person| person.name == "Mike" }

    assert.true! mike.useful, "Mike's hint is the one that is worth having"
  end

  # He runs the place, so he has to be *at* the place he runs. He used to sit on
  # the island's high point and this asked how far up he was; that whole idea
  # went when he became the warden.
  def test_mike_stands_at_reception(args, assert)
    game = ashore(args)
    mike = game.islanders.find { |person| person.name == "Mike" }
    reception = game.camp_pieces.find { |piece| piece[:key] == "reception" }

    assert.false! reception.nil?, "there is a reception to stand at"
    assert.false! mike.nil?, "and a warden standing at it"
    assert.true! (mike.x - reception[:x]).abs < 300,
                 "Mike is #{(mike.x - reception[:x]).abs} px from the desk he works at"
  end

  # Close enough together to be a group, far enough apart that walking up to one
  # is walking up to *one*. If two ever came within a reach of each other you
  # could never choose which of them you were talking to.
  def test_nobody_stands_within_reach_of_anybody_else(args, assert)
    game = ashore(args)
    xs = game.islanders.map(&:x).sort

    xs.each_cons(2) do |left, right|
      assert.true! (right - left) > Game::ISLANDER_REACH,
                   "#{right - left} px apart is further than one reach"
    end
  end

  # The line follows the diver: before the deep it is hearsay, afterwards it is
  # something the two of you share.
  def test_what_they_say_follows_how_deep_you_have_been(args, assert)
    game = ashore(args)
    person = Islander::ALL.first

    args.state.log_best = 0
    args.state.kraken_met = 0
    green = game.islander_line(person)

    args.state.kraken_met = 1
    met = game.islander_line(person)

    assert.false! green.strip.empty?, "a fresh diver still gets a line"
    assert.false! green == met, "somebody who has seen it is spoken to differently"
  end

  # A person with only one thing to say must not break when the diver is further
  # along than that line — everybody has to answer at every stage.
  def test_everybody_answers_at_every_stage(args, assert)
    game = ashore(args)
    [[0, 0], [90, 0], [190, 1]].each do |best, met|
      args.state.log_best = best
      args.state.kraken_met = met
      Islander::ALL.each do |person|
        line = game.islander_line(person)
        assert.false! line.nil?, "#{person.name} answers at best=#{best} met=#{met}"
        assert.false! line.strip.empty?, "#{person.name} says something real"
      end
    end
  end

  # --- standing on the beach -------------------------------------------------

  def test_they_stand_on_the_island_and_not_in_the_air(args, assert)
    game = ashore(args)

    game.islanders.each do |person|
      assert.true! person.y > WATERLINE_Y, "#{person.name} is out of the water"
    end
    assert.false! game.islanders.empty?, "the beach is populated"
  end

  # No island, nobody: swimming past open water must not conjure a crowd.
  def test_there_is_nobody_out_at_sea(args, assert)
    game = ashore(args)
    args.state.diver_global_x = 40 * SCREEN_WIDTH
    game.current_world

    assert.true! game.islanders.empty?, "nobody stands in the open sea"
  end

  # --- the campsite ----------------------------------------------------------

  def test_the_camp_stands_on_the_island_and_not_in_the_air(args, assert)
    game = ashore(args)
    pieces = game.camp_pieces

    assert.false! pieces.empty?, "the camp is pitched"
    pieces.each do |piece|
      assert.true! piece[:y] > WATERLINE_Y, "#{piece[:key]} is out of the water"
    end
  end

  def test_the_camp_has_tents_a_reception_and_a_fire(args, assert)
    keys = ashore(args).camp_pieces.map { |piece| piece[:key] }

    assert.true! keys.any? { |key| key.start_with?("tent") }, "tents"
    assert.true! keys.include?("reception"), "a reception"
    assert.true! keys.include?("fire"), "and a fire to sit at"
  end

  # Nothing gets pitched out at sea, the same as nobody stands there.
  def test_there_is_no_camp_out_at_sea(args, assert)
    game = ashore(args)
    args.state.diver_global_x = 40 * SCREEN_WIDTH
    game.current_world

    assert.true! game.camp_pieces.empty?, "no tents in the open sea"
  end

  # A tent pitched on somebody is a tent pitched on somebody. The two lists are
  # spaced by hand against each other, so this is what catches a spot being
  # nudged in one file without the other.
  def test_nothing_is_pitched_on_top_of_anybody(args, assert)
    game = ashore(args)
    people = game.islanders

    game.camp_pieces.each do |piece|
      next if piece[:key] == "reception" || piece[:key] == "fire" # both are meant to be stood at

      people.each do |person|
        assert.true! (piece[:x] - person.x).abs > 120,
                     "#{piece[:key]} is #{(piece[:x] - person.x).abs} px from #{person.name}"
      end
    end
  end

  # The musicians are sitting round it, so it has to be between them.
  def test_the_fire_is_between_the_two_musicians(args, assert)
    game = ashore(args)
    fire = game.camp_pieces.find { |piece| piece[:key] == "fire" }
    players = game.islanders.select { |person| person.kind == :musician }.sort_by(&:x)

    assert.equal! players.length, 2
    assert.true! players.first.x < fire[:x], "Sebastián sits on one side"
    assert.true! players.last.x > fire[:x], "and George on the other"
  end

  # --- what the camp is drawn as ---------------------------------------------

  # The table in app/world/camp.rb is typed out from what the tool printed, and
  # a stale w or h there draws the sprite squashed rather than failing — which
  # is exactly the kind of thing that survives a green suite. So it is held
  # against the pictures themselves.
  def test_the_sprite_table_matches_the_pictures(args, assert)
    Game::CAMP_SPRITES.each do |key, sprite|
      png = args.gtk.get_pixels(sprite[:path])

      assert.equal! png.w, sprite[:w], "#{key} is #{png.w} px wide, not #{sprite[:w]}"
      assert.equal! png.h, sprite[:h], "#{key} is #{png.h} px tall, not #{sprite[:h]}"
    end
  end

  # Rows carrying more than the board's two colours — that is, rows with
  # lettering on them. Counted as runs so a line of text reads as one thing.
  def lettered_runs(png)
    runs = []
    run = 0
    png.h.times do |row|
      inks = png.w.times.map { |col| png.pixels[row * png.w + col] }.uniq.length
      if inks > 2
        run += 1
      else
        runs << run if run > 0
        run = 0
      end
    end
    runs << run if run > 0
    runs
  end

  # The sign used to be five blocks of colour that meant nothing — a sign in the
  # sense that a rectangle is a sign. It says CAMPING / REZEPTION now, and that
  # only counts if the letters are really drawn: two runs of five rows at the
  # top of the picture, which is a five-pixel-tall line of type twice over.
  def test_the_reception_sign_says_what_the_place_is(args, assert)
    png = args.gtk.get_pixels(Game::CAMP_SPRITES["reception"][:path])
    runs = lettered_runs(png)

    assert.true! runs.length >= 2, "there is lettering on the board"
    assert.equal! runs[0], 5, "CAMPING is five rows of type"
    assert.equal! runs[1], 5, "and so is REZEPTION"
  end

  # Big enough to read from where you stand. Three pixels of glyph at this scale
  # is nine on screen, and the widest line is nine letters — under that the sign
  # is decoration again, which is what it was.
  def test_the_sign_is_big_enough_to_read(args, assert)
    on_screen = Game::CAMP_SPRITES["reception"][:w] * Game::CAMP_SCALE

    assert.true! on_screen >= 140, "the board is #{on_screen} px across on screen"
  end

  # A square with a stripe on it is a square with a stripe on it, however red.
  # Read off the picture rather than off the drawing: empty corners, full middle,
  # and rows that widen and narrow again — which is what makes it a disc.
  def test_the_ball_is_round(args, assert)
    png = args.gtk.get_pixels(Game::CAMP_SPRITES["ball"][:path])
    widths = png.h.times.map do |row|
      png.w.times.count { |col| png.pixels[row * png.w + col] != 0 }
    end

    assert.equal! png.w, png.h, "as wide as it is tall"
    assert.equal! png.pixels[0], 0, "its corner is empty"
    assert.equal! widths.max, png.w, "it is full across its middle"
    assert.true! widths.first < widths[png.h / 2], "it widens towards the middle"
    assert.true! widths.last < widths[png.h / 2], "and narrows again"
  end

  def test_the_ball_is_drawn_where_it_flies(args, assert)
    game = ashore(args)
    game.center_camera
    game.render_ball
    ball = game.ball_between
    drawn = args.outputs.sprites.last

    assert.false! drawn.nil?, "the ball is drawn"
    assert.equal! drawn[:path], Game::CAMP_SPRITES["ball"][:path], "as the disc, not a solid"
    assert.true! (drawn[:x] + drawn[:w] / 2 - (ball[:x] - args.state.camera_x)).abs <= 1,
                 "centred on where it is"
  end

  # --- Andi, over at the Späti -----------------------------------------------

  def at_the_spaeti(args)
    game = build_game(args)
    game.initialize_game(0)
    args.state.game_scene = "area2"
    args.state.diver_global_x = game.shop_x
    args.state.on_land = true
    game.current_world
    game
  end

  def test_the_keeper_can_be_spoken_to_at_his_counter(args, assert)
    game = at_the_spaeti(args)
    person = game.islander_in_reach

    assert.false! person.nil?, "Andi is somebody you can say hello to"
    assert.equal! person.name, "Andi"
  end

  def test_the_keeper_is_not_at_the_campsite(args, assert)
    game = ashore(args)

    assert.false! game.islanders.map(&:name).include?("Andi"),
                  "he is behind his own counter, on the other island"
  end

  # The campers are not at the Späti either — the two islands are two places.
  def test_the_campers_are_not_at_the_spaeti(args, assert)
    game = at_the_spaeti(args)

    assert.equal! game.islanders.map(&:name), ["Andi"]
  end

  # Talking to him must not open the shop, and the shop key must not talk.
  def test_talking_to_him_is_not_shopping(args, assert)
    game = at_the_spaeti(args)

    game.talk_to_islander

    assert.false! args.state.game_scene == "shop", "E says hello, it does not open the shelf"
    assert.false! args.state.islander_said.nil?
  end

  # He is drawn into the stall's own picture, so he must not also be drawn as a
  # figure standing in front of it.
  def test_the_keeper_has_no_sprite_of_his_own(args, assert)
    assert.true! Game::ISLANDER_SPRITES["andi"].nil?,
                 "the stall already has him behind the counter"
  end

  # --- what a documented species changes -------------------------------------

  # Falko asks whether you have ever photographed a shark. Once you have, he has
  # to stop asking — a question that survives its own answer is furniture.
  def test_falko_stops_asking_once_you_have_the_shark(args, assert)
    game = ashore(args)
    falko = Islander["falko"]
    args.state.log_best = 0
    args.state.kraken_met = 0

    args.state.album = {}
    asking = game.islander_pool(falko)

    args.state.album = { "schattenhai" => :gut }
    answered = game.islander_pool(falko)

    assert.true! asking.any? { |line| line.include?("Schattenhai") }, "he asks"
    assert.false! asking == answered, "and then he does not ask any more"
  end

  # Nobody else is tied to a species, so nobody else changes when one lands.
  def test_a_documented_species_only_moves_who_asked(args, assert)
    game = ashore(args)
    args.state.log_best = 0
    args.state.kraken_met = 0
    peter = Islander["tall_pete"]

    args.state.album = {}
    before = game.islander_pool(peter)
    args.state.album = { "schattenhai" => :gut }

    assert.equal! game.islander_pool(peter), before
  end

  # --- the ball --------------------------------------------------------------

  def test_the_boys_have_a_ball_between_them(args, assert)
    game = ashore(args)
    boys = game.islanders.select { |person| person.kind == :boy }.sort_by(&:x)
    ball = game.ball_between

    assert.equal! boys.length, 2
    assert.false! ball.nil?, "there is a ball in the air"
    assert.true! ball[:x] >= boys.first.x - 1, "it stays between them"
    assert.true! ball[:x] <= boys.last.x + 1
    assert.true! ball[:y] > [boys.first.y, boys.last.y].max, "and above their feet"
  end

  # It is a function of the clock, so it has to actually move as the clock runs
  # — and come back, rather than sailing off in one direction.
  def test_the_ball_flies_there_and_back(args, assert)
    game = ashore(args)
    seen = [0, 40, 96, 140, 192].map { |tick| game.ball_between(tick)[:x] }

    assert.true! seen.uniq.length > 1, "it moves"
    assert.true! (seen.first - seen.last).abs < 40, "and it comes back to where it started"
  end

  # --- talking to them -------------------------------------------------------

  def test_you_have_to_be_ashore_to_talk(args, assert)
    game = ashore(args)
    person = game.islanders.first
    args.state.diver_global_x = person.x
    args.state.on_land = false

    assert.true! game.islander_in_reach.nil?, "you cannot chat while treading water"
  end

  # Past the last of them, not simply "a long way from the first" — they are
  # spread along the island, so walking away from one walks you up to the next.
  def test_you_have_to_be_next_to_somebody(args, assert)
    game = ashore(args)
    args.state.diver_global_x = game.islanders.map(&:x).max + 600

    assert.true! game.islander_in_reach.nil?, "nobody is within earshot"
  end

  def test_standing_beside_somebody_you_can_talk_to_them(args, assert)
    game = ashore(args)
    person = game.islanders.first
    args.state.diver_global_x = person.x

    assert.false! game.islander_in_reach.nil?, "there is somebody to talk to"
    assert.equal! game.islander_in_reach.name, person.name
  end

  # The nearest one, not simply the first in the list — two of them stand close
  # enough together that it matters which one you are actually beside.
  def test_it_is_the_nearest_one_who_answers(args, assert)
    game = ashore(args)
    people = game.islanders.sort_by(&:x)
    args.state.diver_global_x = people.last.x

    assert.equal! game.islander_in_reach.name, people.last.name
  end

  def test_talking_puts_up_what_they_said(args, assert)
    game = ashore(args)
    person = game.islanders.first
    args.state.diver_global_x = person.x

    game.talk_to_islander

    assert.false! args.state.islander_said.nil?, "a line goes up"
    assert.equal! args.state.islander_said[:name], person.name
    assert.false! args.state.islander_said[:text].strip.empty?
  end

  # It is a speech bubble, not a screen: the game keeps running while somebody
  # talks to you, and the line fades on its own.
  def test_what_they_said_fades_on_its_own(args, assert)
    game = ashore(args)
    person = game.islanders.first
    args.state.diver_global_x = person.x
    game.talk_to_islander

    args.state.islander_said[:at] -= Game::ISLANDER_SAY_TICKS + 1

    assert.false! game.islander_speaking?, "the bubble does not hang about"
  end

  def test_the_game_is_not_paused_while_they_talk(args, assert)
    game = ashore(args)
    person = game.islanders.first
    args.state.diver_global_x = person.x

    game.talk_to_islander

    assert.equal! args.state.game_scene, "area1", "nobody takes over the screen"
  end

  # Talking again gets you the next thing they have to say rather than the same
  # sentence twice — the people who repeat themselves are vending machines.
  def test_talking_again_moves_them_on(args, assert)
    game = ashore(args)
    person = game.islanders.find { |goer| goer.islander.lines.length > 1 }
    args.state.diver_global_x = person.x

    game.talk_to_islander
    first = args.state.islander_said[:text]
    game.talk_to_islander
    second = args.state.islander_said[:text]

    assert.false! first == second, "#{person.name} has more than one thing to say"
  end

  # Every line anybody can say, put through the wrapper. The suite passed while
  # the engine threw on the first spoken word — render_islander_speech had
  # bailed out before it got that far — so the wrapping is exercised directly
  # rather than only through a render that may or may not reach it.
  def test_every_line_wraps(args, assert)
    game = ashore(args)

    Islander::ALL.each do |person|
      person.all_lines.each do |text|
        lines = game.wrap_speech(text)
        assert.false! lines.empty?, "#{person.name}: #{text}"
        assert.equal! lines.join(" "), text, "wrapping loses nothing"
        lines.each do |line|
          assert.true! line.length <= Game::SPEECH_CHARS,
                       "#{person.name}: \"#{line}\" fits the bubble"
        end
      end
    end
  end

  # Measured in pixels, not counted in characters. A character count is a guess
  # about the font: the first line of Mike's ran out through the right-hand edge
  # of its own box on screen while every count-based check was happy.
  def test_every_line_fits_the_bubble_on_screen(args, assert)
    game = ashore(args)
    room = Game::SPEECH_W - Game::SPEECH_PAD * 2

    Islander::ALL.each do |person|
      person.all_lines.each do |text|
        game.wrap_speech(text).each do |line|
          width = args.gtk.calcstringbox(line, 1)[0]
          assert.true! width <= room,
                       "#{person.name}: \"#{line}\" is #{width.round} px in a #{room} px box"
        end
      end
    end
  end

  def test_it_renders_without_error(args, assert)
    game = ashore(args)
    person = game.islanders.first
    args.state.diver_global_x = person.x
    game.center_camera
    game.talk_to_islander

    game.render_islanders
    game.render_islander_speech

    assert.true! args.outputs.sprites.length > 0, "the people and the bubble draw"
  end
end

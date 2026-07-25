# The camera: finding a subject, what makes a good shot, and the film roll that
# only becomes an Artenbuch entry once you get it home and develop it.
class PhotographyTests
  def build_game(args)
    game = Game.new
    game.args = args
    game
  end

  # Down in the water at a known spot, with one fish right in front of him.
  def diving_with_a_fish(args, species_key: "burgunder", away: 60, facing: :right)
    game = build_game(args)
    game.initialize_game(0)
    args.state.game_scene = "area1"
    args.state.diver_global_x = 600
    args.state.depth_y = -400 # well under the surface, so the fauna is out
    args.state.direction = facing
    game.current_world # load the segment *first* — loading it stocks it with life
    args.state.fish = [Creature.new(args, 0, species: Species[species_key],
                                    x: 600 + away, y: -400)]
    args.state.crawlers = [] # ... and the crabs it stocked the floor with go too,
    game                     #     so the one fish is the only subject in the water
  end

  def test_nothing_to_photograph_at_the_surface(args, assert)
    game = diving_with_a_fish(args)
    args.state.depth_y = WATERLINE_Y - SURFACE_FLOAT_DEPTH # head out, fauna hidden

    assert.equal! game.photo_subject, nil, "up here you see water and sky, nothing else"
  end

  def test_a_fish_in_front_of_him_is_the_subject(args, assert)
    game = diving_with_a_fish(args, species_key: "hornhering", away: 80)

    subject = game.photo_subject

    assert.false! subject.nil?, "there is something to photograph"
    assert.equal! subject[:species].key, "hornhering"
  end

  # You have to turn towards it. Swimming away from a fish and shooting over your
  # shoulder is not photography.
  def test_a_fish_behind_him_is_not(args, assert)
    game = diving_with_a_fish(args, away: 200, facing: :left)

    assert.equal! game.photo_subject, nil, "it's behind him"

    args.state.direction = :right
    assert.false! game.photo_subject.nil?, "and in front of him once he turns"
  end

  def test_a_fish_too_far_off_is_not(args, assert)
    game = diving_with_a_fish(args, away: Game::PHOTO_REACH + 60)

    assert.equal! game.photo_subject, nil, "out of range"
  end

  def test_quality_comes_from_how_close_you_got(args, assert)
    game = build_game(args)
    game.initialize_game(0)

    assert.equal! game.photo_quality(20), :perfekt
    assert.equal! game.photo_quality(Game::PHOTO_MID - 10), :gut
    assert.equal! game.photo_quality(Game::PHOTO_MID + 10), :unscharf
  end

  # Thrashing along at full speed blurs the shot.
  def test_sprinting_costs_a_grade(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.sprinting = true

    assert.equal! game.photo_quality(20), :gut, "a perfect frame comes out merely good"
    assert.equal! game.photo_quality(Game::PHOTO_MID + 10), :unscharf, "and a poor one can't get worse"
  end

  def test_taking_a_photo_spends_film_and_fills_the_roll(args, assert)
    game = diving_with_a_fish(args, species_key: "scalarus", away: 40)
    before = args.state.film_left

    game.take_photo

    assert.equal! args.state.film_left, before - 1, "one frame gone"
    assert.equal! args.state.film_roll.length, 1
    assert.equal! args.state.film_roll[0][:key], "scalarus"
    assert.equal! args.state.film_roll[0][:quality], :perfekt, "he was right on top of it"
    assert.equal! args.state.album.length, 0, "and it is not in the book until it's developed"
  end

  def test_an_empty_camera_takes_nothing(args, assert)
    game = diving_with_a_fish(args)
    args.state.film_left = 0

    game.take_photo

    assert.equal! args.state.film_roll.length, 0, "no film, no photo"
  end

  # Standing in front of the same fish must not be a way to fill the roll.
  def test_the_same_shot_twice_costs_no_film(args, assert)
    game = diving_with_a_fish(args, away: 40)
    game.take_photo
    before = args.state.film_left

    game.take_photo

    assert.equal! args.state.film_left, before, "nothing spent on a shot he already has"
    assert.equal! args.state.film_roll.length, 1
  end

  # A better shot of the same fish does replace the one on the roll.
  def test_a_better_shot_replaces_the_one_on_the_roll(args, assert)
    game = diving_with_a_fish(args, away: Game::PHOTO_MID + 20) # far off: blurry
    game.take_photo
    assert.equal! args.state.film_roll[0][:quality], :unscharf

    args.state.fish[0] = Creature.new(args, 0, species: Species["burgunder"], x: 640, y: -400)
    game.take_photo

    assert.equal! args.state.film_roll.length, 1, "still one photo of that fish"
    assert.equal! args.state.film_roll[0][:quality], :perfekt, "the good one"
  end

  def test_developing_at_the_boat_fills_the_book_and_reloads(args, assert)
    game = diving_with_a_fish(args, away: 40)
    game.take_photo
    game.spawn_at_surface # home to the boat
    assert.true! game.at_the_boat?

    game.develop_film

    assert.equal! args.state.album["burgunder"], :perfekt, "the fish is in the book"
    assert.equal! args.state.film_roll.length, 0, "the roll is spent"
    assert.equal! args.state.film_left, Game::FILM_MAX, "and a fresh film is in"
  end

  def test_developing_never_downgrades_what_is_already_in_the_book(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.album = { "burgunder" => :perfekt }
    args.state.film_roll = [{ key: "burgunder", quality: :unscharf }]

    game.develop_film

    assert.equal! args.state.album["burgunder"], :perfekt, "a worse photo doesn't replace a good one"
  end

  def test_the_score_is_the_sum_of_the_book(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    assert.equal! game.album_score, 0, "an empty book scores nothing"

    args.state.album = { "burgunder" => :gut }
    good = game.album_score
    assert.equal! good, Species["burgunder"].fee, "a good photo is worth the species"

    args.state.album = { "burgunder" => :perfekt }
    assert.true! game.album_score > good, "a perfect one is worth more"

    args.state.album = { "burgunder" => :unscharf }
    assert.true! game.album_score < good, "a blurry one less"
  end

  # The whole point of the hard rule: what you have not brought home, you lose.
  def test_dying_costs_the_roll_but_never_the_book(args, assert)
    game = diving_with_a_fish(args, away: 40)
    game.take_photo
    args.state.album = { "hornhering" => :gut }

    game.reset_game

    assert.equal! args.state.film_roll.length, 0, "the undeveloped film is gone"
    assert.equal! args.state.film_left, Game::FILM_MAX, "a fresh one is loaded"
    assert.equal! args.state.album["hornhering"], :gut, "but the book survives"
  end

  # F is the shutter under water and the darkroom at the boat — the same key,
  # because at the surface beside the boat there is never a fish to shoot.
  def test_f_shoots_below_and_develops_at_the_boat(args, assert)
    game = diving_with_a_fish(args, away: 40)

    args.inputs.keyboard.key_down.f = true
    game.update_camera
    assert.equal! args.state.film_roll.length, 1, "under water it takes the picture"

    game.spawn_at_surface
    args.inputs.keyboard.key_down.f = true
    game.update_camera
    assert.equal! args.state.film_roll.length, 0, "at the boat it develops the roll"
    assert.equal! args.state.album.length, 1
  end

  # --- the Artenbuch, page by page ------------------------------------------
  #
  # The roster outgrew the screen: fourteen species already ran the last rows
  # down through the footer and over each other. It turns pages now.

  def at_the_boat_with_everything_sighted(args)
    game = build_game(args)
    game.initialize_game(0)
    game.spawn_at_surface
    args.state.game_scene = "area1"
    args.state.sighted = Species::ALL.each_with_object({}) { |s, h| h[s.key] = true }
    game.toggle_home_menu(true)
    args.state.boat_page = :book
    game
  end

  def test_the_book_turns_pages_when_the_roster_outgrows_one(args, assert)
    game = at_the_boat_with_everything_sighted(args)

    assert.true! game.artenbuch_rows.length > Game::BOOK_PER_PAGE,
                 "there is more here than fits (#{game.artenbuch_rows.length})"
    assert.true! game.artenbuch_pages > 1, "so there is more than one page"
    assert.true! game.artenbuch_page_rows.length <= Game::BOOK_PER_PAGE,
                 "and a page holds no more than it can show"
  end

  # Turning through must show every species exactly once — a book that drops one
  # is worse than a book that scrolls badly.
  def test_every_species_is_on_exactly_one_page(args, assert)
    game = at_the_boat_with_everything_sighted(args)

    seen = []
    game.artenbuch_pages.times do |i|
      args.state.artenbuch_page = i
      seen.concat(game.artenbuch_page_rows.map { |row| row[:species].key })
    end

    assert.equal! seen.length, game.artenbuch_rows.length, "nothing is shown twice or lost"
    assert.equal! seen.uniq.length, seen.length, "and nothing repeats"
  end

  def test_paging_wraps_and_is_a_plain_state_change(args, assert)
    game = at_the_boat_with_everything_sighted(args)
    last = game.artenbuch_pages - 1

    game.turn_artenbuch_page(1)
    assert.equal! args.state.artenbuch_page, 1, "forward a page"

    args.state.artenbuch_page = last
    game.turn_artenbuch_page(1)
    assert.equal! args.state.artenbuch_page, 0, "and round to the front from the back"

    game.turn_artenbuch_page(-1)
    assert.equal! args.state.artenbuch_page, last, "and back again"
  end

  # The bug you could see: rows ran down through the footer and printed over it.
  def test_no_row_of_the_book_falls_through_the_footer(args, assert)
    game = at_the_boat_with_everything_sighted(args)

    game.home_menu_tick

    below = args.outputs.labels.flatten.select { |l| l[:y] < game.body_bottom - 2 }
    assert.equal! below.length, 1,
                  "only the footer hint sits down there (#{below.map { |l| l[:text] }.inspect})"
  end

  # The Artenbuch lists only what you've seen — sighted or documented — so it
  # fills in as you explore instead of spoiling the sea from the first dive.
  def test_the_book_lists_only_what_you_have_seen(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    args.state.sighted = { "hornhering" => true } # seen, not yet photographed
    args.state.album = { "burgunder" => :gut }    # documented (which implies seen)

    rows = game.artenbuch_rows
    keys = rows.map { |row| row[:species].key }

    assert.equal! rows.length, 2, "only the two he's encountered"
    assert.true! keys.include?("burgunder") && keys.include?("hornhering")
    assert.false! keys.include?("laternentraeger"), "one never seen isn't in the book at all"

    documented = rows.find { |row| row[:species].key == "burgunder" }
    assert.equal! documented[:quality], :gut
    seen = rows.find { |row| row[:species].key == "hornhering" }
    assert.equal! seen[:quality], nil, "seen but not yet photographed: a row with no grade"
  end

  def test_the_book_is_empty_until_you_have_seen_anything(args, assert)
    game = build_game(args)
    game.initialize_game(0)

    assert.equal! game.artenbuch_rows.length, 0, "nothing seen, nothing listed"
  end

  def test_tab_turns_to_the_book_and_back(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    game.spawn_at_surface
    args.state.game_scene = "area1"
    game.toggle_home_menu(true)
    assert.false! game.book_page?, "it opens on what you just brought up"

    args.inputs.keyboard.key_down.tab = true
    game.update_boat_page
    assert.true! game.book_page?, "Tab turns to the Artenbuch"

    game.update_boat_page
    assert.false! game.book_page?, "and back again"
  end

  # On the book page the arrows must not be quietly shuffling the hold about
  # behind it.
  def test_the_book_page_has_no_exchange_cursor(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    game.spawn_at_surface
    args.state.game_scene = "area1"
    args.state.inventory = ["shoe", "can"]
    game.toggle_home_menu(true)
    args.state.boat_page = :book

    args.inputs.keyboard.key_down.e = true
    game.update_exchange

    assert.equal! args.state.inventory.length, 2, "nothing moved"
    assert.equal! args.state.stash.length, 0
  end

  def test_the_book_page_renders(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    game.spawn_at_surface
    args.state.game_scene = "area1"
    args.state.album = { "burgunder" => :perfekt, "hornhering" => :unscharf }
    args.state.sighted = { "burgunder" => true, "hornhering" => true }
    game.toggle_home_menu(true)
    args.state.boat_page = :book

    game.home_menu_tick
    text = args.outputs.labels.map { |label| label[:text] }.join(" ")

    assert.true! text.include?("Artenbuch"), "the page names itself"
    assert.true! text.include?("Blauer Burgunder"), "and lists what he has seen"
    assert.false! text.include?("Lucerna abyssi"), "but not a species he has never laid eyes on"
    assert.true! text.include?("ungesichtet"), "just a hint that more is out there"
  end

  # The right-hand column's grade and fee are right-aligned on a column width
  # that used to be a constant. The panel grew; the constant didn't; the fees
  # printed past the edge of the box onto the bare screen. Nothing on this page
  # may leave the box it is drawn in.
  def test_the_book_stays_inside_its_box(args, assert)
    game = build_game(args)
    game.initialize_game(0)
    game.spawn_at_surface
    args.state.game_scene = "area1"
    args.state.album = {}
    args.state.sighted = {}
    Species::ALL.each { |species| args.state.sighted[species.key] = true }
    args.state.album[Species::ALL.first.key] = :perfekt
    game.toggle_home_menu(true)
    args.state.boat_page = :book

    game.home_menu_tick

    left = game.menu_left + Game::MENU_PAD
    right = left + game.menu_width - Game::MENU_PAD * 2
    args.outputs.labels.flatten.each do |label|
      next if label[:x].nil?

      assert.true! label[:x] >= left && label[:x] <= right,
                   "\"#{label[:text]}\" is inside the box (x #{label[:x]}, box #{left}..#{right})"
    end
  end

  def test_the_hud_draws_the_camera_without_error(args, assert)
    game = diving_with_a_fish(args, away: 40)
    game.take_photo

    game.render_film_gauge
    game.render_flash
    game.render_messages

    text = args.outputs.labels.map { |label| label[:text] }.join(" ")
    assert.true! args.outputs.labels.length > 0, "film counter and prompt draw"
    # Nothing is in the book in this round, so it can't name it yet — it says
    # only that there is something new on the film.
    assert.true! text.include?(Species["burgunder"].tease), "and reports what he just caught"
    assert.true! text.include?("Neues"), "as something worth bringing home"
  end

  # They used to be strewn across the middle of the screen — over the diver, and
  # over the water you are actually looking at. Everything the game says to you
  # in passing lives along the bottom edge now.
  def test_the_running_messages_sit_along_the_bottom_edge(args, assert)
    game = diving_with_a_fish(args, away: 40)
    game.take_photo # so the shot note is up as well as the lens prompt

    game.render_messages

    ys = args.outputs.labels.map { |label| label[:y] }
    assert.true! ys.length >= 2, "there is more than one thing being said at once"
    assert.true! ys.max < grid_height(args) / 3,
                 "and none of it is up in the picture (highest #{ys.max})"
  end

  def grid_height(args)
    args.grid.h
  end

  # --- what the lens tells you ----------------------------------------------
  #
  # A species gives its name only once it is in the book, so "has it got a name?"
  # *is* the answer to "have I got this one?". No second thing to read.

  def test_a_species_you_have_never_developed_has_no_name_down_here(args, assert)
    game = diving_with_a_fish(args, species_key: "burgunder", away: 40)
    args.state.album = {}

    line = game.photo_message

    assert.false! line[:text].include?("Blauer Burgunder"), "it doesn't give itself away"
    assert.true! line[:text].include?(Species["burgunder"].tease),
                 "it is what you could tell by looking at it"
    assert.equal! line[:color], Game::NEW_INK, "and it is worth the film"
  end

  def test_once_it_is_in_the_book_it_has_a_name(args, assert)
    game = diving_with_a_fish(args, species_key: "burgunder", away: 40)
    args.state.album = { "burgunder" => :unscharf }

    line = game.photo_message

    assert.true! line[:text].include?("Blauer Burgunder"), "now you know what it is"
  end

  # The three states are three colours, so the answer is there before you read.
  def test_the_colour_says_what_the_shot_is_worth(args, assert)
    fresh = diving_with_a_fish(args, species_key: "burgunder", away: 40)
    args.state.album = {}
    assert.equal! fresh.photo_message[:color], Game::NEW_INK, "never had it"

    args.state.album = { "burgunder" => :unscharf } # a poor one is in the book
    assert.equal! fresh.photo_message[:color], Game::BETTER_INK, "this would be better"

    args.state.album = { "burgunder" => :perfekt } # nothing left to gain
    assert.equal! fresh.photo_message[:color], Game::ENOUGH_INK, "no need to spend film"
  end

  def test_the_shot_note_keeps_its_secret_too(args, assert)
    game = diving_with_a_fish(args, species_key: "burgunder", away: 40)
    args.state.album = {}

    game.take_photo

    assert.true! args.state.shot_note[:name].include?(Species["burgunder"].tease),
                 "exposed film, not a discovery"
    assert.true! args.state.shot_note[:fresh], "but it does say it is something new"
  end

  # Boxes that fit themselves to their text resize every time another fish comes
  # into the lens, and a panel changing shape under your eyes reads as movement.
  # One width for all of them — measured here against the longest line any of
  # them can hold, since nothing wraps.
  def test_every_running_message_fits_the_box(args, assert)
    longest = [
      "Kein Film mehr — am Boot entwickeln",
      "Inventar voll — am Boot einlagern",
      "[ E ]  Flaschenpost aufheben",
      "Etwas Neues! Am Boot entwickeln",
      "[ F ]  Schwarzer Schattenhai  (unscharf)",
      "Purpurner Prunkflosser — schon besser im Kasten",
    ]
    room = Game::MESSAGE_W - 24 # a little air at each end

    longest.each do |text|
      w, _h = args.gtk.calcstringbox(text, 2)
      assert.true! w <= room, "\"#{text}\" fits (#{w.to_i} of #{room})"
    end
    # The note line is drawn a size larger.
    w, _h = args.gtk.calcstringbox("Schwarzer Schattenhai  —  unscharf", 3)
    assert.true! w <= room, "and so does the shot note (#{w.to_i} of #{room})"
  end
end

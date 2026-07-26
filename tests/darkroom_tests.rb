# The darkroom: what comes out of the developing tank, read at leisure.
#
# Developing used to be a keypress that silently moved numbers — the film went,
# the balance moved, and the one moment the whole game is *for* (a species nobody
# had, now on paper) went past without a word. Now the tank hands you the prints.
class DarkroomTests
  def build_game(args)
    game = Game.new
    game.args = args
    game
  end

  def at_the_boat_with_a_roll(args, roll)
    game = build_game(args)
    game.initialize_game(0)
    game.spawn_at_surface # home, beside the boat
    args.state.game_scene = "area1"
    args.state.day = 2
    args.state.film_roll = roll
    game
  end

  def one_fish(quality = :gut, day = 2)
    [{ key: "burgunder", quality: quality, day: day }]
  end

  # --- what developing produces ---------------------------------------------

  def test_developing_hands_you_the_prints(args, assert)
    game = at_the_boat_with_a_roll(args, one_fish(:perfekt))

    game.develop_film

    prints = args.state.developed_roll
    assert.equal! prints.length, 1, "one photo in, one print out"
    assert.equal! prints[0][:species].key, "burgunder"
    assert.equal! prints[0][:quality], :perfekt
    assert.equal! prints[0][:day], 2, "the day it was taken"
    assert.true! prints[0][:fee] > 0, "and what the magazine paid for it"
    assert.true! prints[0][:fresh], "nobody had this one before"
  end

  # A better picture of something already in the book is worth having, but it is
  # not a discovery — and the screen must not claim it is.
  def test_a_better_photo_of_a_known_species_is_not_a_discovery(args, assert)
    game = at_the_boat_with_a_roll(args, one_fish(:perfekt))
    args.state.album = { "burgunder" => :unscharf }

    game.develop_film

    assert.false! args.state.developed_roll[0][:fresh], "he had it, only worse"
  end

  # The photo carries the day it was taken, not the day it was developed —
  # sleeping on an exposed roll must not re-date it.
  def test_a_print_keeps_the_day_the_shot_was_taken(args, assert)
    game = at_the_boat_with_a_roll(args, one_fish(:gut, 2))
    args.state.day = 5 # developed three days later

    game.develop_film

    assert.equal! args.state.developed_roll[0][:day], 2
  end

  # A roll from before prints carried a date at all still develops.
  def test_a_shot_without_a_day_falls_back_to_today(args, assert)
    game = at_the_boat_with_a_roll(args, [{ key: "burgunder", quality: :gut }])
    args.state.day = 4

    game.develop_film

    assert.equal! args.state.developed_roll[0][:day], 4
  end

  # --- the screen it opens ---------------------------------------------------

  def test_developing_at_the_boat_opens_the_darkroom(args, assert)
    game = at_the_boat_with_a_roll(args, one_fish)

    args.inputs.keyboard.key_down.f = true
    game.update_camera

    assert.equal! args.state.game_scene, "darkroom", "F at the boat opens the tank"
  end

  def test_an_empty_roll_leaves_you_where_you_were(args, assert)
    game = at_the_boat_with_a_roll(args, [])

    args.inputs.keyboard.key_down.f = true
    game.update_camera

    assert.equal! args.state.game_scene, "area1", "nothing to look at"
  end

  def test_the_print_says_what_it_is_when_it_was_and_how_big(args, assert)
    game = at_the_boat_with_a_roll(args, one_fish(:perfekt))
    game.develop_film

    game.darkroom_tick
    text = args.outputs.labels.flatten.map { |label| label[:text] }.join("  ")

    assert.true! text.include?(Species["burgunder"].name), "its name: #{text}"
    assert.true! text.include?(Species["burgunder"].size_label), "how big it is"
    assert.true! text.include?("Tag 2"), "and when it was taken"
  end

  def test_the_animal_itself_is_on_the_print(args, assert)
    game = at_the_boat_with_a_roll(args, one_fish)
    game.develop_film

    game.darkroom_tick
    paths = args.outputs.sprites.flatten.map { |sprite| sprite[:path] }

    assert.true! paths.include?(Species["burgunder"].sheet), "the fish is in the picture"
  end

  # --- reading it at leisure -------------------------------------------------

  # The tap that developed the roll must not also be read as "seen it, thanks" —
  # the same mistake the pause menu made with ESC.
  def test_the_press_that_opened_it_does_not_close_it(args, assert)
    game = at_the_boat_with_a_roll(args, one_fish)
    args.state.touch_tapped = [:photo] # a thumb on the shutter button
    args.state.touch_began = true

    game.update_camera
    game.darkroom_tick

    assert.equal! args.state.game_scene, "darkroom", "it stays up to be read"
  end

  def test_pressing_on_goes_back_to_the_water(args, assert)
    game = at_the_boat_with_a_roll(args, one_fish)
    game.develop_film
    game.open_darkroom

    args.state.developed_at = nil # not the opening tick any more
    args.inputs.keyboard.key_down.space = true
    game.darkroom_tick

    assert.equal! args.state.game_scene, "area1", "back beside the boat"
  end

  # A full roll is more prints than fit on one wall.
  def test_a_long_roll_turns_pages(args, assert)
    game = at_the_boat_with_a_roll(args, [])
    args.state.developed_roll = Array.new(Game::DARKROOM_PER_PAGE + 2) do
      { species: Species["burgunder"], quality: :gut, fee: 5, day: 1, fresh: false }
    end

    assert.equal! game.darkroom_pages, 2
    assert.equal! game.darkroom_page_prints.length, Game::DARKROOM_PER_PAGE

    game.turn_darkroom_page(1)
    assert.equal! game.darkroom_page_prints.length, 2, "the rest on the second wall"
  end
end

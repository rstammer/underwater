# What a group photograph is worth, and where the book keeps it.
#
# The Artenbuch had one thing to say about a species: the best single picture of
# it. A school is a different photograph of the same animal — harder to find,
# harder to compose — so it gets its own line rather than overwriting the
# portrait or being folded into it.
class FlockTests
  def build_game(args)
    game = Game.new
    game.args = args
    game
  end

  def at_the_boat(args)
    game = build_game(args)
    game.initialize_game(0)
    args.state.game_scene = "area1"
    args.state.album = {}
    args.state.flocks = {}
    game
  end

  def roll(game, args, key, quality, flock)
    args.state.film_roll << { key: key, quality: quality, flock: flock, day: 1 }
    game
  end

  # --- the fee -------------------------------------------------------------------

  def test_a_lone_animal_is_worth_no_group_fee(args, assert)
    game = at_the_boat(args)

    assert.equal! game.flock_fee(Species["hornhering"], 1), 0
    assert.equal! game.flock_fee(Species["hornhering"], 0), 0
  end

  def test_a_bigger_school_is_worth_more(args, assert)
    game = at_the_boat(args)
    species = Species["hornhering"]

    assert.true! game.flock_fee(species, 6) > game.flock_fee(species, 3)
    assert.true! game.flock_fee(species, 3) > game.flock_fee(species, 2)
  end

  # --- developing ------------------------------------------------------------------

  def test_a_school_is_paid_for_and_written_down(args, assert)
    game = at_the_boat(args)
    roll(game, args, "hornhering", :perfekt, 4)

    game.develop_film

    assert.equal! args.state.flocks["hornhering"], 4, "the book remembers the school"
    assert.equal! args.state.album["hornhering"], :perfekt, "and the species with it"
    assert.equal! args.state.credits,
                  game.photo_fee(Species["hornhering"], :perfekt) +
                  game.flock_fee(Species["hornhering"], 4)
  end

  # The same rule the quality ladder already keeps: a better picture of something
  # you have been paid for earns the difference, not the fee over again.
  def test_a_bigger_school_later_pays_only_the_difference(args, assert)
    game = at_the_boat(args)
    species = Species["hornhering"]
    roll(game, args, "hornhering", :perfekt, 3)
    game.develop_film
    before = args.state.credits

    roll(game, args, "hornhering", :perfekt, 6)
    game.develop_film

    assert.equal! args.state.flocks["hornhering"], 6
    assert.equal! args.state.credits - before,
                  game.flock_fee(species, 6) - game.flock_fee(species, 3)
  end

  def test_a_smaller_school_later_is_worth_nothing(args, assert)
    game = at_the_boat(args)
    roll(game, args, "hornhering", :perfekt, 5)
    game.develop_film
    before = args.state.credits

    roll(game, args, "hornhering", :perfekt, 2)
    game.develop_film

    assert.equal! args.state.flocks["hornhering"], 5, "the record stands"
    assert.equal! args.state.credits, before
  end

  # A blurred group is a blurred photograph. Without this the wide-open frame is
  # a free record: press, release, and the biggest school you happened to be
  # near is in the book with no composing done at all.
  def test_a_blurred_school_records_nothing(args, assert)
    game = at_the_boat(args)
    roll(game, args, "hornhering", :unscharf, 6)

    game.develop_film

    assert.equal! args.state.flocks["hornhering"], nil
  end

  # The invariant that keeps the balance honest: what photography has earned you
  # is exactly what the book is worth, groups included.
  def test_the_book_is_worth_what_it_paid(args, assert)
    game = at_the_boat(args)
    roll(game, args, "hornhering", :gut, 4)
    roll(game, args, "burgunder", :perfekt, 1)
    game.develop_film
    roll(game, args, "hornhering", :perfekt, 6)
    game.develop_film

    assert.equal! game.album_score, args.state.credits
  end

  # --- what is worth the film ----------------------------------------------------

  def test_a_bigger_school_is_worth_the_film(args, assert)
    game = at_the_boat(args)
    args.state.album["hornhering"] = :perfekt
    args.state.flocks["hornhering"] = 2

    assert.true! game.improves?("hornhering", :perfekt, 4),
                 "same grade, more fish — a picture you have not got"
    assert.false! game.improves?("hornhering", :perfekt, 2),
                  "and no better than the one you have"
  end

  def test_a_blurred_school_is_not_worth_the_film(args, assert)
    game = at_the_boat(args)
    args.state.album["hornhering"] = :perfekt
    args.state.flocks["hornhering"] = 2

    assert.false! game.improves?("hornhering", :unscharf, 9)
  end

  # --- and it survives being closed ------------------------------------------------

  def test_the_school_is_written_to_the_book_file(args, assert)
    text = SaveFile.encode(name: "Kins", album: { "hornhering" => :gut },
                           sighted: {}, flocks: { "hornhering" => 4 })
    book = SaveFile.decode(text)

    assert.equal! book[:flocks]["hornhering"], 4
  end

  # A book written before schools existed simply hasn't got the line, and that
  # is not an error — it is a diver who has never photographed one.
  def test_an_older_book_reads_back_without_schools(args, assert)
    book = SaveFile.decode("name Kins\nalbum hornhering perfekt")

    assert.equal! book[:flocks], {}
  end

  def test_a_school_of_one_is_never_written(args, assert)
    text = SaveFile.encode(name: "Kins", album: {}, sighted: {},
                           flocks: { "hornhering" => 1 })

    assert.false! text.include?("flock"), "one fish is not a school"
  end
end

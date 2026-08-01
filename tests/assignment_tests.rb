# The day's assignment: one job a magazine wants, good for the day it is set.
#
# It is the piece that turns "photograph whatever swims past" into work. The
# Artenbuch is collecting — every animal once, for ever. An assignment is the
# other half: a thing somebody asked for, today, which may well be an animal you
# already have a page for.
class AssignmentTests
  def build_game(args)
    game = Game.new
    game.args = args
    game
  end

  def at_sea(args, day: 3)
    game = build_game(args)
    game.initialize_game(0)
    args.state.day = day
    args.state.game_scene = "area1"
    game.current_world
    game
  end

  # Everything is a candidate once he has laid eyes on it.
  def sight_everything(args)
    args.state.sighted = {}
    Species::ALL.each { |s| args.state.sighted[s.key] = true }
  end

  # --- where it comes from ---------------------------------------------------

  # Rolled from the seed and the day, so it costs nothing in the save file: the
  # day *is* the assignment. Same book, same morning, same job.
  def test_the_same_day_always_sets_the_same_job(args, assert)
    game = at_sea(args, day: 7)
    sight_everything(args)

    first = game.todays_assignment
    args.state.assignment = nil # nothing cached
    second = game.todays_assignment

    assert.false! first.nil?, "there is a job"
    assert.equal! second.key, first.key, "and it is the same one on the same day"
  end

  def test_different_days_set_different_jobs(args, assert)
    game = at_sea(args)
    sight_everything(args)

    keys = (1..14).map do |day|
      args.state.day = day
      args.state.assignment = nil
      game.todays_assignment.key
    end

    assert.true! keys.uniq.length > 4,
                 "a fortnight brought only #{keys.uniq.length} different jobs"
  end

  # It may only ask for animals he has actually met. "Photograph the blue whale"
  # on the first morning is not a job, it is a wall.
  def test_it_only_asks_for_animals_he_has_seen(args, assert)
    game = at_sea(args)
    seen = Species::ALL.first
    args.state.sighted = { seen.key => true }

    (1..30).each do |day|
      args.state.day = day
      args.state.assignment = nil
      job = game.todays_assignment
      next if job.nil? || job.species_key.nil?

      assert.equal! job.species_key, seen.key,
                    "day #{day} asks for #{job.species_key}, which he has never seen"
    end
  end

  # A diver who has seen nothing at all still gets something to do — the sea is
  # full of shore crabs and sectors.
  def test_a_beginner_still_gets_a_job(args, assert)
    game = at_sea(args, day: 1)
    args.state.sighted = {}

    assert.false! game.todays_assignment.nil?, "there is something he can be asked for"
  end

  # --- what it pays ----------------------------------------------------------

  def test_it_pays_something_worth_the_detour(args, assert)
    game = at_sea(args)
    sight_everything(args)

    (1..20).each do |day|
      args.state.day = day
      args.state.assignment = nil
      fee = game.todays_assignment.fee
      assert.true! fee >= 40, "day #{day} pays #{fee}, which is not worth a dive"
      assert.true! fee <= 260, "day #{day} pays #{fee}, which beats a day's photography"
    end
  end

  # --- what satisfies it -----------------------------------------------------

  def roll_with(args, key, quality: :perfekt, flock: 1, sector: 0)
    args.state.film_roll = [{ key: key, quality: quality, flock: flock,
                              day: args.state.day, sector: sector }]
  end

  def job_of_kind(game, args, kind)
    (1..80).each do |day|
      args.state.day = day
      args.state.assignment = nil
      job = game.todays_assignment
      return job if job && job.kind == kind
    end
    nil
  end

  def test_a_species_job_wants_that_species(args, assert)
    game = at_sea(args)
    sight_everything(args)
    job = job_of_kind(game, args, :species)
    assert.false! job.nil?, "there is a plain species job in there somewhere"

    roll_with(args, job.species_key)
    assert.true! game.assignment_done?(job), "the animal it asked for is on the roll"

    other = Species::ALL.find { |s| s.key != job.species_key }
    roll_with(args, other.key)
    assert.false! game.assignment_done?(job), "something else is not that animal"
  end

  def test_a_flock_job_counts_the_group(args, assert)
    game = at_sea(args)
    sight_everything(args)
    job = job_of_kind(game, args, :flock)
    assert.false! job.nil?, "there is a group job in there somewhere"

    roll_with(args, job.species_key, flock: job.count - 1)
    assert.false! game.assignment_done?(job), "one short is not enough"
    roll_with(args, job.species_key, flock: job.count)
    assert.true! game.assignment_done?(job), "the full group counts"
  end

  def test_a_shore_job_wants_something_off_the_beach(args, assert)
    game = at_sea(args)
    sight_everything(args)
    job = job_of_kind(game, args, :shore)
    assert.false! job.nil?, "there is a beach job in there somewhere"

    shore = Species::ALL.find { |s| s.habitat == :shore }
    deep = Species::ALL.find { |s| s.habitat == :water }
    roll_with(args, deep.key)
    assert.false! game.assignment_done?(job), "a fish out in the water is not the beach"
    roll_with(args, shore.key)
    assert.true! game.assignment_done?(job), "a shore animal is"
  end

  def test_a_sector_job_wants_a_picture_taken_there(args, assert)
    game = at_sea(args)
    sight_everything(args)
    job = job_of_kind(game, args, :sector)
    assert.false! job.nil?, "there is a sector job in there somewhere"

    roll_with(args, Species::ALL.first.key, sector: job.sector + 1)
    assert.false! game.assignment_done?(job), "the wrong sector does not count"
    roll_with(args, Species::ALL.first.key, sector: job.sector)
    assert.true! game.assignment_done?(job), "a picture taken there does"
  end

  # A blurred frame is not a delivery. The magazine is buying a photograph.
  def test_a_blurred_frame_does_not_fill_an_assignment(args, assert)
    game = at_sea(args)
    sight_everything(args)
    job = job_of_kind(game, args, :species)

    roll_with(args, job.species_key, quality: :unscharf)
    assert.false! game.assignment_done?(job), "out of focus is not a delivery"
  end

  # --- handing it in ---------------------------------------------------------

  # At the boat, with the rest of the money. It is the tank that turns exposed
  # film into work delivered, so it is the tank that pays for the job.
  def test_developing_the_roll_pays_the_assignment(args, assert)
    game = at_sea(args)
    sight_everything(args)
    job = job_of_kind(game, args, :species)
    args.state.album = {}
    args.state.credits = 0
    roll_with(args, job.species_key)

    game.develop_film

    assert.true! args.state.credits >= job.fee,
                 "the job paid (#{args.state.credits} Cr against a #{job.fee} Cr fee)"
    assert.true! game.assignment_paid?, "and is marked as handed in"
  end

  def test_an_unfilled_assignment_pays_nothing(args, assert)
    game = at_sea(args)
    sight_everything(args)
    job = job_of_kind(game, args, :species)
    other = Species::ALL.find { |s| s.key != job.species_key && s.fee > 0 }
    args.state.album = { other.key => :perfekt } # so the photo itself earns nothing either
    args.state.credits = 0
    roll_with(args, other.key, quality: :gut)

    game.develop_film

    assert.equal! args.state.credits, 0, "nothing was owed"
    assert.false! game.assignment_paid?, "and nothing was handed in"
  end

  # Twice in a day is once too often: develop, go out, photograph the same fish
  # again, develop again.
  def test_an_assignment_is_only_paid_once_a_day(args, assert)
    game = at_sea(args)
    sight_everything(args)
    job = job_of_kind(game, args, :species)
    args.state.album = {}
    args.state.credits = 0

    roll_with(args, job.species_key)
    game.develop_film
    after_first = args.state.credits

    roll_with(args, job.species_key)
    game.develop_film

    assert.equal! args.state.credits - after_first, 0, "the second delivery paid nothing"
  end

  # And tomorrow is a fresh job, whether or not today's was done.
  def test_sleeping_brings_a_new_job(args, assert)
    game = at_sea(args, day: 4)
    sight_everything(args)
    before = game.todays_assignment.key
    args.state.assignment_paid_day = 4

    game.wake_up

    assert.false! game.assignment_paid?, "the new day is not handed in yet"
    assert.true! args.state.day == 5, "and it is a new day"
    fresh = game.todays_assignment
    assert.false! fresh.nil?, "with a job on it"
    assert.false! fresh.key == before && args.state.assignment_day != 5,
                  "rolled for the new day"
  end

  # --- what it says on screen ------------------------------------------------

  # Two rows in the same slot is one row nobody can read.
  def test_the_assignment_row_does_not_collide_with_the_boat_row(args, assert)
    game = at_sea(args)
    sight_everything(args)
    args.state.aboard = true

    slots = game.running_messages.map { |row| row[:slot] }
    assert.equal! slots.length, slots.uniq.length, "two messages want the same row"
  end

  def test_the_row_is_gone_once_the_job_is_handed_in(args, assert)
    game = at_sea(args)
    sight_everything(args)
    args.state.assignment_paid_day = args.state.day

    texts = game.running_messages.map { |row| row[:text] }
    assert.false! texts.any? { |t| t.include?("Auftrag") }, "nothing left to nag about"
  end

  # The star means "this counts", and it may only appear when it does.
  def test_the_viewfinder_marks_a_subject_that_counts(args, assert)
    game = at_sea(args)
    sight_everything(args)
    job = job_of_kind(game, args, :species)
    args.state.film_roll = []

    wanted = Species[job.species_key]
    other = Species::ALL.find { |s| s.key != job.species_key && s.fee > 0 }

    assert.equal! game.assignment_mark(wanted, 1, :perfekt), Game::ASSIGNMENT_MARK,
                  "the animal it asked for is marked"
    assert.equal! game.assignment_mark(other, 1, :perfekt), "",
                  "something else is not"
    assert.equal! game.assignment_mark(wanted, 1, :unscharf), "",
                  "and a blurred one would not count either"
  end

  # It has to survive a reload, or closing the game after handing in a job and
  # opening it again is a second fee for the same photograph.
  def test_a_handed_in_job_survives_a_reload(args, assert)
    game = at_sea(args, day: 6)
    sight_everything(args)
    args.state.assignment_paid_day = 6

    book = SaveFile.decode(game.encode_book)

    assert.equal! book[:assignment_paid_day], 6, "the save file remembers it"
  end

  # --- where the sector on a shot comes from ---------------------------------

  # store_shot merges by species, so the sector has to travel with the shot it
  # belongs to — otherwise "a picture from sector -5" is unanswerable the moment
  # you photograph the same fish twice.
  def test_a_shot_remembers_where_it_was_taken(args, assert)
    game = at_sea(args)
    args.state.film_roll = []
    args.state.diver_global_x = IslandWorld.centre_x(-5)

    game.store_shot(Species::ALL.first.key, :gut, 1)

    assert.equal! args.state.film_roll.first[:sector], -5, "it knows where he stood"
  end
end

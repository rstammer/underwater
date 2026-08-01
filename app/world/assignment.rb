# One job, of the kind a magazine rings up with. Not a quest log — a single
# thing somebody wants today, and tomorrow they want something else.
#
# It exists because the Artenbuch can only ask one question, and it asks it
# once: have you got this animal yet. That is collecting, and collecting runs
# out — the pages you have are the pages you have, and the ones you have not are
# the ones you cannot reach yet. An assignment asks a different question, one
# that is worth answering again on a day when the book has nothing left to give:
# not "have you got it" but "can you get it today".
#
# The kinds are deliberately answerable from things the game already knows about
# a photograph. Nothing here needed a new property on a species or a new number
# on the roll except the sector, which a shot ought to have remembered anyway.
class Assignment
  attr_reader :kind, :species_key, :count, :sector, :fee

  def initialize(kind:, fee:, species_key: nil, count: 1, sector: 0)
    @kind = kind
    @fee = fee
    @species_key = species_key
    @count = count
    @sector = sector
  end

  # Identity for a test and for the save file's sake — two assignments with the
  # same key are the same job.
  def key
    "#{@kind}:#{@species_key}:#{@count}:#{@sector}"
  end

  def species
    @species_key && Species[@species_key]
  end
end

class Game
  # What the day's job pays. The scale is set against the shop rather than
  # against a photograph: the cheapest thing on Andi's shelf is 150 Cr, so a good
  # assignment is a decent step towards a bottle and a poor one is pocket money.
  # It is not meant to out-earn a dive's worth of new pages — the book is still
  # the living, this is the overtime.
  ASSIGNMENT_BASE = 60
  ASSIGNMENT_SEED = 5150
  # A group asked for is a group that has to exist: the roster's schooling sizes
  # run 6/5/4/3/2, so asking for more than a species goes about in would be a job
  # nobody can do (Species#shoal).
  ASSIGNMENT_FLOCK_MIN = 2

  # Today's job. Rolled from the world seed and the day number, so it costs the
  # save file nothing at all — the day *is* the assignment, and a book reloaded
  # on the same morning gets the same call.
  #
  # Memoised per day rather than per session: the roll walks the roster, and this
  # is asked once a frame by the HUD.
  def todays_assignment
    if state.assignment && state.assignment_day == state.day
      return state.assignment
    end

    state.assignment_day = state.day
    state.assignment = roll_assignment
  end

  # The pool is filtered by what he has actually met, so the job is always one he
  # could go and do. Shore and sector jobs need nothing from the roster at all,
  # which is what a diver on his first morning is left with.
  def roll_assignment
    rng = world_rng(ASSIGNMENT_SEED + state.day.to_i * 31)
    pool = assignment_pool(rng)
    pool[(rng.float * pool.length).to_i] || pool.first
  end

  def assignment_pool(rng)
    known = assignable_species
    pool = [shore_assignment(rng), sector_assignment(rng)]
    unless known.empty?
      pick = known[(rng.float * known.length).to_i]
      pool << Assignment.new(kind: :species, species_key: pick.key,
                             fee: species_assignment_fee(pick))
      schooling = known.select { |s| s.shoal >= ASSIGNMENT_FLOCK_MIN }
      unless schooling.empty?
        shoaler = schooling[(rng.float * schooling.length).to_i]
        count = ASSIGNMENT_FLOCK_MIN + (rng.float * (shoaler.shoal - ASSIGNMENT_FLOCK_MIN + 1)).to_i
        count = shoaler.shoal if count > shoaler.shoal
        pool << Assignment.new(kind: :flock, species_key: shoaler.key, count: count,
                               fee: flock_assignment_fee(shoaler, count))
      end
    end
    pool.compact
  end

  # Seen it, and it is a thing a photograph can be of — the kraken is a rumour
  # that never lands on film, so nobody may be sent after it.
  def assignable_species
    seen = state.sighted || {}
    Species::ALL.select { |s| seen[s.key] && s.fee > 0 }
  end

  def species_assignment_fee(species)
    cap(ASSIGNMENT_BASE + species.fee)
  end

  def flock_assignment_fee(species, count)
    cap(ASSIGNMENT_BASE + species.fee + count * 18)
  end

  def shore_assignment(_rng)
    Assignment.new(kind: :shore, fee: cap(ASSIGNMENT_BASE + 30))
  end

  # Somewhere he has already been, or one step past the edge of the chart — the
  # same reach the boat has, so a sector job is never a place he cannot get to.
  def sector_assignment(rng)
    west = (state.charted_west || -CHART_START).to_i
    east = (state.charted_east || CHART_START).to_i
    span = east - west
    pick = west + (rng.float * (span + 1)).to_i
    Assignment.new(kind: :sector, sector: pick, fee: cap(ASSIGNMENT_BASE + 40))
  end

  def cap(fee)
    return 40 if fee < 40
    return 260 if fee > 260

    fee
  end

  # Is it on the roll? Asked of the exposed film rather than of the Artenbuch,
  # which is what makes drowning cost the assignment as well as the pictures —
  # the magazine is buying a photograph, and a photograph you did not bring home
  # is not one.
  def assignment_done?(job = todays_assignment)
    return false unless job

    (state.film_roll || []).any? { |shot| shot_satisfies?(job, shot) }
  end

  # A blurred frame is never a delivery, whatever it is of.
  def shot_satisfies?(job, shot)
    return false if shot[:quality] == :unscharf

    case job.kind
    when :species then shot[:key] == job.species_key
    when :flock   then shot[:key] == job.species_key && (shot[:flock] || 1) >= job.count
    when :shore   then Species[shot[:key]]&.habitat == :shore
    when :sector  then shot[:sector] == job.sector
    else false
    end
  end

  # Handed in already today? Kept as the day it was paid rather than as a flag,
  # so it clears itself at the turn of the day and needs nothing in wake_up.
  def assignment_paid?
    state.assignment_paid_day == state.day
  end

  # Called by the tank. Pays once: develop, swim out, photograph the same fish
  # again and develop a second time, and the magazine does not pay twice for the
  # one job it asked for.
  def settle_assignment
    return 0 if assignment_paid?

    job = todays_assignment
    return 0 unless job && assignment_done?(job)

    state.assignment_paid_day = state.day
    state.assignment_earned = job.fee
    job.fee
  end

  # What the job says out loud. German, like everything the game says.
  def assignment_text(job = todays_assignment)
    return "" unless job

    case job.kind
    when :species then "Ein Bild von: #{job.species.name}"
    when :flock   then "#{job.count} × #{job.species.name} auf einem Bild"
    when :shore   then "Etwas vom Strand — was oben an Land lebt"
    when :sector  then "Eine Aufnahme aus Sektor #{job.sector}"
    else ""
    end
  end

  # The short form, for the line that has to share the screen with the sea.
  def assignment_short(job = todays_assignment)
    return "" unless job

    case job.kind
    when :species then job.species.name
    when :flock   then "#{job.count} × #{job.species.name}"
    when :shore   then "etwas vom Strand"
    when :sector  then "Sektor #{job.sector}"
    else ""
    end
  end
end

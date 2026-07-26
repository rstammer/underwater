# The underwater camera. Documenting the sea's species is what the diving is
# *for*; this is the part that turns swimming past a fish into a page in the
# Artenbuch.
#
# The rule is deliberately hard: a photo is exposed film, not a record. Film is
# limited per dive, and the roll only becomes book entries when it is developed
# at the boat. Drown out there and the roll goes with you — the book, which is
# the work of many dives, does not.
#
# Note the naming: nothing here is called `camera`. That word already means the
# view (state.camera_x / camera_y), and a second meaning would be a trap.
class Game
  FILM_MAX = 12       # frames on a roll; a fresh one comes with every developing
  PHOTO_REACH = 320   # px within which a creature is close enough to shoot at all
  PHOTO_CLOSE = 90    # ... and this close for a perfect frame
  PHOTO_MID = 190     # ... this close for a good one
  PHOTO_BEHIND = 40   # slack behind him — a fish right at his shoulder still counts
  QUALITY_RANK = { unscharf: 1, gut: 2, perfekt: 3 }
  QUALITY_FACTOR = { unscharf: 0.5, gut: 1.0, perfekt: 1.6 }
  SHUTTER_TICKS = 8   # how long the flash hangs on the screen
  NOTE_TICKS = 150    # ... and the line naming what he just caught

  # A fresh film and an empty roll. The album is *not* here: it survives dying,
  # which is the whole point of having to bring the film home.
  def reset_film
    state.film_left = film_capacity
    state.film_roll = []
    state.shot_at = nil
    state.shot_note = nil
  end

  # F: the shutter down in the water, the darkroom up at the boat. One key for
  # both because beside the boat you are at the surface, where there is never a
  # fish to photograph.
  # At the boat F is the darkroom, a single press. Down in the water it is the
  # shutter, and the shutter is *held* — see app/world/framing.rb.
  def update_camera
    if at_the_boat?
      cancel_framing if framing?
      return develop_at_the_boat if inputs.keyboard.key_down.f || tapped?(:photo)

      return
    end

    update_framing
  end

  # Developing is a moment, so it stops the game and shows what came out. The
  # decision to *show* lives here rather than in develop_film: developing is a
  # change to the book, opening a screen is not, and a test that develops a roll
  # should not find itself in another scene.
  def develop_at_the_boat
    develop_film
    open_darkroom
  end

  # What the lens is on: the nearest creature in front of him and within reach.
  # Which creatures those are depends on which side of the surface his head is
  # on (see creatures_in_view) — out in open water with his head up there is
  # nothing but sky, but beside an island there is a beach.
  # Reach is per animal, not per camera. Thirty metres of whale cannot be judged
  # by the distances that suit a hand-sized fish: at the range where a burgunder
  # is "perfekt" you are looking at one flank. photo_span scales the whole
  # ladder, so the rule stands — near is sharp — and only what counts as near
  # changes, which is a fact about the animal rather than about the lens.
  def photo_reach(species)
    PHOTO_REACH * species.photo_span
  end

  def photo_subject
    best = nil
    photo_candidates.each do |species, world_x, y|
      next unless in_front?(world_x)

      distance = photo_distance(world_x, y)
      next if distance > photo_reach(species)
      # Compared as a *fraction* of each animal's own reach, or the whale two
      # screens off would always beat the fish in front of your mask.
      score = distance / photo_span_of(species)
      next if best && best[:score] <= score

      best = { species: species, distance: distance, score: score }
    end
    best
  end

  def photo_span_of(species)
    span = species.photo_span
    span < 1 ? 1.0 : span.to_f
  end

  # Everything photographable right now, in world coordinates: whatever is on
  # this side of the surface, plus the shark if it is about. Fish and crabs alike
  # carry a local chunk x.
  # It lives in world coordinates already, so it is asked about directly rather
  # than through the bodies list — it has no sprite rect worth speaking of.
  def kraken_in_frame?
    return false unless kraken_present?

    rect = frame_rect
    x = state.kraken.x
    y = state.kraken.y
    x >= rect[:x] && x <= rect[:x] + rect[:w] && y >= rect[:y] && y <= rect[:y] + rect[:h]
  end

  def photo_candidates
    list = creatures_in_view.map do |creature|
      [creature.species, world_index * SCREEN_WIDTH + creature.x, creature.y]
    end
    if shark_present?
      list << [Species["schattenhai"],
               world_index * SCREEN_WIDTH + state.dark_shark.x, state.dark_shark.y]
    end
    # The kraken reads as a subject too — that's the whole lure. It already lives
    # in world coordinates.
    list << [Species::KRAKEN, state.kraken.x, state.kraken.y] if kraken_present?
    # ... and so does the whale, which lives out there as well.
    list << [whale_species, state.whale.x, state.whale.y] if whale_present? && whale_species
    list
  end

  def photo_distance(world_x, y)
    dx = world_x - state.diver_global_x
    dy = y - state.depth_y
    Math.sqrt(dx * dx + dy * dy)
  end

  # He has to be turned towards it — swimming away and shooting over his
  # shoulder is not photography.
  def in_front?(world_x)
    ahead = world_x - state.diver_global_x
    state.direction == :left ? ahead <= PHOTO_BEHIND : ahead >= -PHOTO_BEHIND
  end

  # Close is sharp; thrashing along at sprint speed blurs whatever you got.
  # Scaled by the animal, the same way the reach is: three hundred px from a
  # whale is close, and three hundred px from a crab is a speck.
  def photo_quality(distance, species = nil)
    span = species ? photo_span_of(species) : 1.0
    quality =
      if distance <= PHOTO_CLOSE * span then :perfekt
      elsif distance <= PHOTO_MID * span then :gut
      else :unscharf
      end
    state.sprinting ? blurred(quality) : quality
  end

  # One rung down the ladder. It has two callers that mean different things —
  # a shot taken at sprint speed is blurred, a group with a stray in it is
  # merely a worse picture — so the movement has its own name and the blur keeps
  # the one that says what happened.
  def demote(quality)
    return :gut if quality == :perfekt

    :unscharf
  end

  def blurred(quality)
    demote(quality)
  end

  # Take the picture, if there is film, something to shoot, and the shot would
  # actually be worth anything. Standing in front of the same fish must not be a
  # way to burn the roll — a shot no better than one he already has costs
  # nothing and does nothing.
  # Whatever was inside the frame when you let go. The kraken is still the shot
  # that never lands — it reads as a subject and comes back empty, which is the
  # whole of the lure.
  def take_photo
    return if state.film_left <= 0
    return attempt_kraken_photo if kraken_in_frame?

    report = frame_report
    return unless report

    species = report[:species]
    quality = frame_quality(report)
    flock = report[:flock]
    return unless improves?(species.key, quality, flock)

    state.film_left -= 1
    store_shot(species.key, quality, flock)
    note_shot(species, quality)
    dismiss_dive_hint # he has got it; the card can go
  end

  # Better than what is on the roll *and* better than what is in the book — and
  # there are two ways for a picture to be better now. A school of six at the
  # same grade as the single you already have is not the same photograph, so it
  # is worth the frame; the same school out of focus is not, or the wide-open
  # frame would be a free record of whatever you happened to be swimming past.
  # Compared at what it would *pay*, not at what is in the frame: otherwise the
  # cap would be worse than the hole it closes — the lens would keep offering a
  # bigger field as worth a frame, and the tank would keep developing nothing.
  def improves?(key, quality, flock = 1)
    rank = QUALITY_RANK[quality]
    on_roll = state.film_roll.find { |shot| shot[:key] == key }
    if quality != :unscharf &&
       payable_flock(Species[key], flock) > best_flock(key, on_roll)
      return true
    end
    return false if on_roll && QUALITY_RANK[on_roll[:quality]] >= rank
    return false if state.album[key] && QUALITY_RANK[state.album[key]] >= rank

    true
  end

  # The biggest school of this one you have anywhere — brought home, or on the
  # film you are still carrying.
  def best_flock(key, on_roll = nil)
    on_roll ||= state.film_roll.find { |shot| shot[:key] == key }
    booked = payable_flock(Species[key], flock_record(key))
    rolled = payable_flock(Species[key], on_roll ? on_roll[:flock] : 1)
    rolled > booked ? rolled : booked
  end

  def flock_record(key)
    ((state.flocks || {})[key] || 1)
  end

  # The frame carries the day it was taken. Not the day it is developed: you can
  # sleep on an exposed roll, and a print dated the morning it was pulled out of
  # the tank would be a lie about where you were.
  # One frame per species on the roll, holding the best of each thing it can be
  # best at. The grade and the size of the school are kept separately because
  # they can come off different exposures — a tight portrait in the morning and a
  # loose school in the afternoon are two facts about the same animal, and
  # neither should quietly wipe the other.
  def store_shot(key, quality, flock = 1)
    existing = state.film_roll.find { |shot| shot[:key] == key }
    unless existing
      return state.film_roll << { key: key, quality: quality, flock: flock, day: state.day }
    end

    existing[:quality] = quality if QUALITY_RANK[quality] > QUALITY_RANK[existing[:quality]]
    existing[:flock] = flock if quality != :unscharf && flock > (existing[:flock] || 1)
    existing[:day] = state.day
  end

  # What he just caught, as far as he can tell down here — which for something
  # not yet in the book is not much (see Game#species_label). Both fields are
  # settled now, and neither can change while the note is up: the album only
  # moves at the boat.
  def note_shot(species, quality)
    state.shot_at = Kernel.tick_count
    state.shot_note = { name: species_label(species), quality: quality,
                        fresh: !state.album[species.key] }
  end

  # At the boat: everything on the roll that beats what is in the book goes into
  # it, the magazine pays for it, and a fresh film goes in the camera.
  #
  # A better picture of something you have already been paid for earns the
  # *difference*, not the fee over again — otherwise photographing the same fish
  # badly and then well would pay twice for one animal. It also keeps a tidy
  # invariant: what the photography has earned you is exactly album_score.
  def develop_film
    earned = 0
    prints = []
    state.film_roll.each do |shot|
      species = Species[shot[:key]]
      next unless species # a species retired from the roster since the shot

      known = state.album[shot[:key]]
      better = known.nil? || QUALITY_RANK[shot[:quality]] > QUALITY_RANK[known]
      # The two halves of a page move independently: a school you had not got is
      # worth developing even if the picture is no sharper than the one on file.
      flock = payable_flock(species, shot[:flock] || 1)
      recorded = payable_flock(species, flock_record(shot[:key]))
      bigger = shot[:quality] != :unscharf && flock > recorded
      next unless better || bigger

      fee = 0
      if better
        fee += photo_fee(species, shot[:quality]) - (known ? photo_fee(species, known) : 0)
        state.day_species += 1 unless known # a page nobody had before today
        state.album[shot[:key]] = shot[:quality]
      end
      if bigger
        fee += flock_fee(species, flock) - flock_fee(species, recorded)
        state.flocks[shot[:key]] = flock
      end
      earned += fee
      # A print, not a row of numbers. This is the one moment in the game where a
      # shape in the murk becomes a name, a size and a date — so the tank hands
      # over something to look at, and the darkroom screen shows it.
      prints << { species: species, quality: state.album[shot[:key]], fee: fee,
                  flock: bigger ? flock : 0,
                  day: shot[:day] || state.day, fresh: known.nil? }
    end
    state.developed_roll = prints
    state.credits += earned
    state.log_earned += earned
    state.day_earned += earned
    developed = state.film_roll.length
    state.film_roll = []
    state.film_left = film_capacity
    save_book # the book has changed, so the book on disk changes with it
    developed
  end

  # What the whole book has earned. Read off the book rather than tallied up as
  # you go — then it can never drift out of step with what is actually
  # documented, and it is the photography half of the credit balance.
  def album_score
    booked = state.album.reduce(0) do |sum, (key, quality)|
      sum + photo_fee(Species[key], quality)
    end
    (state.flocks || {}).reduce(booked) do |sum, (key, flock)|
      sum + flock_fee(Species[key], flock)
    end
  end

  def photo_fee(species, quality)
    return 0 unless species

    (species.fee * QUALITY_FACTOR[quality]).round
  end

  # What a school is worth over and above the single animal, per extra fish in
  # the frame. A separate fee rather than a multiplier on the portrait, so the
  # two stay independent — the tidy invariant is that album_score is exactly what
  # the photography has paid you, and that only holds if each thing the book
  # records has its own price.
  #
  # A perfect single herring fetches 8; six of them fetch 22 on top of that. The
  # ratio is meant to make a school the reason to keep diving somewhere you have
  # already documented, without making the portraits pointless.
  FLOCK_FACTOR = 0.9

  def flock_fee(species, flock)
    return 0 unless species

    counted = payable_flock(species, flock)
    return 0 if counted < 2

    (species.fee * FLOCK_FACTOR * (counted - 1)).round
  end

  # You are paid for a group of the size this kind actually goes about in, not
  # for however many happened to be in front of you.
  #
  # Without this the fee is linear in whatever drifted into the crop, and a
  # jellyfield breaks it wide open: eighteen animals of one species hanging
  # still in a patch two hundred pixels across, so the frame held every one of
  # them, whole and centred, *before it had closed at all*. Measured, 405 Cr on
  # the first tick of the shutter against 31 for a six-herring school composed
  # properly — the best money in the game for a tap.
  #
  # The cap is the roster's own number rather than a rule about jellyfish,
  # because the question it answers is a question about the animal: how many of
  # these are a group? Six herring are a school; the eighteenth jellyfish in a
  # field is not news. It also means a species that shoals in numbers is worth
  # photographing in numbers, which is the thing worth keeping.
  #
  # Deliberately *not* applied in frame_report. That stays an honest count of
  # what is in the picture — an assignment asking for three at once must be able
  # to see three, whatever they are worth.
  def payable_flock(species, flock)
    return 1 if species.nil? || flock.nil?

    flock < species.shoal ? flock : species.shoal
  end

  def album_found
    state.album.length
  end
end

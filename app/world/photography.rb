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
    state.film_left = FILM_MAX
    state.film_roll = []
    state.shot_at = nil
    state.shot_note = nil
  end

  # F: the shutter down in the water, the darkroom up at the boat. One key for
  # both because beside the boat you are at the surface, where there is never a
  # fish to photograph.
  def update_camera
    return unless inputs.keyboard.key_down.f || tapped?(:photo)

    at_the_boat? ? develop_film : take_photo
  end

  # What the lens is on: the nearest creature in front of him and within reach.
  # Which creatures those are depends on which side of the surface his head is
  # on (see creatures_in_view) — out in open water with his head up there is
  # nothing but sky, but beside an island there is a beach.
  def photo_subject
    best = nil
    photo_candidates.each do |species, world_x, y|
      next unless in_front?(world_x)

      distance = photo_distance(world_x, y)
      next if distance > PHOTO_REACH
      next if best && best[:distance] <= distance

      best = { species: species, distance: distance }
    end
    best
  end

  # Everything photographable right now, in world coordinates: whatever is on
  # this side of the surface, plus the shark if it is about. Fish and crabs alike
  # carry a local chunk x.
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
  def photo_quality(distance)
    quality =
      if distance <= PHOTO_CLOSE then :perfekt
      elsif distance <= PHOTO_MID then :gut
      else :unscharf
      end
    state.sprinting ? blurred(quality) : quality
  end

  def blurred(quality)
    return :gut if quality == :perfekt
    return :unscharf if quality == :gut

    :unscharf
  end

  # Take the picture, if there is film, something to shoot, and the shot would
  # actually be worth anything. Standing in front of the same fish must not be a
  # way to burn the roll — a shot no better than one he already has costs
  # nothing and does nothing.
  def take_photo
    return if state.film_left <= 0

    subject = photo_subject
    return unless subject

    species = subject[:species]
    return attempt_kraken_photo if species.key == "kraken" # the shot that never lands
    quality = photo_quality(subject[:distance])
    return unless improves?(species.key, quality)

    state.film_left -= 1
    store_shot(species.key, quality)
    note_shot(species, quality)
    dismiss_dive_hint # he has got it; the card can go
  end

  # Better than what is on the roll *and* better than what is in the book.
  def improves?(key, quality)
    rank = QUALITY_RANK[quality]
    on_roll = state.film_roll.find { |shot| shot[:key] == key }
    return false if on_roll && QUALITY_RANK[on_roll[:quality]] >= rank
    return false if state.album[key] && QUALITY_RANK[state.album[key]] >= rank

    true
  end

  def store_shot(key, quality)
    existing = state.film_roll.find { |shot| shot[:key] == key }
    return existing[:quality] = quality if existing

    state.film_roll << { key: key, quality: quality }
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
    state.film_roll.each do |shot|
      known = state.album[shot[:key]]
      next if known && QUALITY_RANK[known] >= QUALITY_RANK[shot[:quality]]

      species = Species[shot[:key]]
      earned += photo_fee(species, shot[:quality]) - (known ? photo_fee(species, known) : 0)
      state.album[shot[:key]] = shot[:quality]
    end
    state.credits += earned
    state.last_payment = earned # so the boat can say what the magazine paid
    developed = state.film_roll.length
    state.film_roll = []
    state.film_left = FILM_MAX
    save_book # the book has changed, so the book on disk changes with it
    developed
  end

  # What the whole book has earned. Read off the book rather than tallied up as
  # you go — then it can never drift out of step with what is actually
  # documented, and it is the photography half of the credit balance.
  def album_score
    state.album.reduce(0) do |sum, (key, quality)|
      sum + photo_fee(Species[key], quality)
    end
  end

  def photo_fee(species, quality)
    return 0 unless species

    (species.fee * QUALITY_FACTOR[quality]).round
  end

  def album_found
    state.album.length
  end
end

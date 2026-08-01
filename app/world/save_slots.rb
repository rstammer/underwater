# Where the books live, and which one is open. Reopens Game.
#
# There used to be exactly one file. "Neu anfangen" blanked the state, the name
# screen confirmed it, and save_book wrote the new diver straight over the old
# one — the comment on it even said so. One stray keypress at the title cost a
# career, with no warning and no copy. That is how a save got lost.
#
# So: a fixed number of slots at fixed filenames. Fixed matters more than it
# looks. In the browser build the files live in the IndexedDB behind DragonRuby's
# virtual filesystem, and listing a directory there is not something to lean on;
# an index file that says which slots exist is one more thing that can drift out
# of step with the truth. Five known names can simply be read, and a slot that
# comes back empty *is* an empty slot. Nothing to enumerate, nothing to migrate
# when it breaks.
class Game
  SAVE_SLOTS = 5

  # Nothing is written unless a slot is actually open. Before, any first sighting
  # wrote the current state to the one file whatever was going on; now a game
  # that has not been told which book it is keeping simply does not write one.
  def book_path(runtime = $gtk)
    return SaveFile::TEST_PATH if under_test?(runtime)

    state.book_slot ? slot_path(state.book_slot) : nil
  end

  # argv is a development thing and this runs on every save, including in the
  # browser where there is no command line at all. Ask before reaching for it: a
  # missing method here would take the game down the first time anyone swam past
  # a fish.
  def under_test?(runtime = $gtk)
    runtime.respond_to?(:argv) && runtime.argv.to_s.include?("--test")
  end

  # Every slot goes somewhere disposable while the suite runs. The single book
  # already did this; the slots did not, so running the tests quietly wrote five
  # real files — including copying somebody's actual career into slot one.
  def slot_path(slot)
    under_test? ? "tmp/test_book_#{slot}.txt" : SaveFile.path_for(slot)
  end

  def read_book_file(path = book_path)
    return nil unless path

    $gtk.read_file(path)
  end

  # One generation of history, kept for nothing. A save that goes wrong — a
  # blanked state, a crash mid-write, a career overwritten by accident — leaves
  # the previous one on disk beside it. It is the cheapest possible answer to
  # "my book is gone", and the reason it exists is that the answer used to be
  # "then it is gone".
  def save_book(path = book_path)
    return unless path

    previous = $gtk.read_file(path)
    $gtk.write_file("#{path}.bak", previous) if previous && !previous.strip.empty?
    $gtk.write_file(path, encode_book)
  end

  def encode_book
    SaveFile.encode(name: state.player_name,
                    album: state.album, sighted: state.sighted,
                    flocks: state.flocks,
                    seed: state.world_seed, stash: state.stash,
                    boat_x: state.boat_x,
                    charted_west: state.charted_west,
                    charted_east: state.charted_east,
                    credits: state.credits,
                    dives: state.log_dives, best: state.log_best,
                    sold: state.log_sold, earned: state.log_earned,
                    day: state.day, energy: state.energy.round,
                    day_earned: state.day_earned,
                    day_species: state.day_species,
                    day_deepest: state.day_deepest,
                    day_sold: state.day_sold,
                    assignment_paid_day: state.assignment_paid_day.to_i,
                    assignment_log: assignment_log,
                    gear_film: gear_level(:film),
                    gear_air: gear_level(:air),
                    gear_suit: gear_level(:suit),
                    gear_mask: gear_level(:mask),
                    gear_fins: gear_level(:fins),
                    shop_met: state.shop_met.to_i,
                    kraken_met: state.kraken_met.to_i)
  end

  # --- what is on the shelf ---------------------------------------------------

  # Read once at boot and kept in state: five small files, and the title reads
  # the result rather than the disk.
  def load_slots
    state.slots = (1..SAVE_SLOTS).map { |slot| read_slot(slot) }
    adopt_legacy_book
    state.slots
  end

  def read_slot(slot)
    text = $gtk.read_file(slot_path(slot))
    return nil if text.nil? || text.strip.empty?

    book = SaveFile.decode(text)
    SaveFile.empty?(book) && book[:name].to_s.empty? ? nil : book
  end

  # The one file everybody had before this existed becomes slot one — and the
  # old file is *left where it is*. Deleting it would make the fix that stops
  # books being lost the occasion of one more book being lost.
  def adopt_legacy_book
    # Never while the suite runs. It would pull whoever's real career is sitting
    # in artenbuch.txt onto the test shelf, and then every test that asks "what
    # happens with no saves?" is quietly answering a different question.
    return if under_test?
    return unless state.slots.compact.empty?

    text = $gtk.read_file(SaveFile::PATH)
    return if text.nil? || text.strip.empty?

    $gtk.write_file(slot_path(1), text)
    state.slots[0] = SaveFile.decode(text)
  end

  # A single book handed in with no shelf behind it *is* slot one. That is the
  # shape a test sets up — one career, then press on at the title — and it is
  # what the game itself looked like before there were five of them. In a real
  # run the shelf is always loaded and state.saved_book is nil, so this never
  # fires; it exists so "one book" stays a sentence the game understands.
  def slot_book(slot)
    slots = state.slots || []
    if slot == 1 && slots.compact.empty? &&
       state.saved_book && !SaveFile.empty?(state.saved_book)
      return state.saved_book
    end

    slots[slot - 1]
  end

  def slot_used?(slot)
    !slot_book(slot).nil?
  end

  # Through slot_book, like everything else — asking state.slots directly walked
  # straight past the "a lone book is slot one" rule and answered no to a shelf
  # that plainly had a career on it.
  def any_slot_used?
    (1..SAVE_SLOTS).any? { |slot| !slot_book(slot).nil? }
  end

  # What a row on the title says about itself. A plain method returning plain
  # data, so what the shelf claims can be tested without drawing it.
  def slot_summary(slot)
    book = slot_book(slot)
    return nil unless book

    name = book[:name].to_s.strip
    { name: name.empty? ? DIVER_NAME : name,
      day: book[:day] || 1,
      documented: book[:album].length,
      sighted: book[:sighted].length,
      credits: book[:credits] || 0 }
  end

  # --- opening and closing one ------------------------------------------------

  def open_slot(slot)
    state.book_slot = slot
  end

  # Deliberate, and only ever the slot you pointed at. The backup is left alone:
  # if the deletion was a mistake, the last save is still sitting next to it.
  def delete_slot(slot)
    $gtk.write_file(slot_path(slot), "")
    state.slots[slot - 1] = nil
    state.book_slot = nil if state.book_slot == slot
  end
end

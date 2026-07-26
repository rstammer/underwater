# The whale: the other end of the sea from the kraken. Reopens Game.
#
# The kraken is a threat that hides. This is the opposite in every respect —
# it is not dangerous, it does not hide, and it does not care that you are
# there. It simply crosses the open blue, and the only thing it asks of you is
# that you keep up.
#
# Three things make it read as enormous, and none of them is the sprite alone:
#
#   * It is drawn at WHALE_SCALE, which puts thirty metres of animal on the
#     screen against a diver of two. Scale is only believable next to something
#     you already know the size of, and the diver is that.
#   * It is *slow*. WHALE_SPEED is under a third of a diver's, and the body
#     wave in the sheet is slower still — one beat every few seconds. Nothing
#     that big should look busy.
#   * It ignores you. No shyness, no flight, no reaction of any kind. A fish
#     that flees is your size in its own estimation; an animal that does not
#     look up is not.
#
# It lives in world coordinates rather than in a chunk, because it is longer
# than a third of the screen and would visibly jump at a segment boundary — the
# one animal where the sea's chunk-local fauna would not do.
class Game
  WHALE_SPEED = 0.45      # px/tick. A diver does 2; this is meant to be caught up with
  WHALE_SCALE = 4         # 112 px of sheet becomes 448 px of animal — about 32 m
  WHALE_ENTER = 1100      # px beyond the screen edge where one appears ...
  WHALE_GONE = 2400       # ... and how far past you it gets before it is gone
  WHALE_RISE = 46         # px of the long slow rise and fall of its track
  WHALE_PERIOD = 900.0    # ticks for one of those — fifteen seconds, barely a drift
  WHALE_SPREAD = 260      # px above or below you it comes through at
  WHALE_CLEARANCE = 120   # water it keeps between itself and the sand
  WHALE_EASE = 0.02       # how softly it settles onto its line — see move_whale
  WHALE_CHANCE = 900      # one tick in this many, in its own water, brings one along
  WHALE_NOTE_TICKS = 220

  def whale_present?
    !state.whale.nil?
  end

  # The species this water holds, if it holds one at all. Blauwasser is the only
  # place with an entry, so everywhere else this is nil and the whole thing is
  # off — which is what makes the open blue worth finding.
  def whale_species
    Species.giant_for(current_world.biome)
  end

  def update_whale
    if whale_present?
      move_whale
    elsif whale_water?
      state.whale = new_whale if rand(WHALE_CHANCE).zero?
    end
  end

  # Its own water, and only while you are actually in it. Surfacing does not
  # end a pass — it is still out there — but one will not *begin* while your
  # head is in the air, or the first you would know of it is a tail leaving.
  def whale_water?
    return false if at_open_surface?

    !whale_species.nil?
  end

  # Well off one side, at roughly your depth: near enough that you meet it,
  # never so near that it arrives on top of you.
  def new_whale
    dir = rand(2).zero? ? 1 : -1
    x = state.diver_global_x - dir * WHALE_ENTER
    # home_y is the line it holds; y is where the long rise and fall has it at
    # this moment. Two numbers, because a track that drifted from wherever it
    # happened to be last tick would wander instead of undulating.
    #
    # It starts *on* its line, not at the diver's depth: the rise is zero at
    # birth, so anything else would be a jump on the whale's very first tick —
    # the one moment it must not look like it is in a hurry.
    home = whale_track_y(x, state.depth_y + rand(2 * WHALE_SPREAD) - WHALE_SPREAD)
    { x: x,
      dir: dir,
      home_y: home,
      y: home,
      born: Kernel.tick_count,
      noted: false }
  end

  # It holds its line and rises and falls on a very long period. No steering, no
  # reacting: the track is a fact about the whale, not about the diver.
  def move_whale
    whale = state.whale
    whale.x += WHALE_SPEED * whale.dir
    swim = Math.sin((Kernel.tick_count - whale.born) / WHALE_PERIOD * 2 * Math::PI)
    target = whale_track_y(whale.x, whale.home_y + swim * WHALE_RISE)
    # Eased onto the line rather than set to it. The clamp reads the sea floor,
    # and the sea floor is a terraced thing that steps a pixel or two per tick as
    # it passes underneath — followed exactly, that put a visible judder into the
    # one animal that must never look hurried (measured: 2 px in a single tick,
    # four times its own swimming speed). Through the ease, a step in the ground
    # becomes a hundredth of a pixel.
    whale.y += (target - whale.y) * WHALE_EASE

    note_the_whale(whale)
    state.whale = nil if (whale.x - state.diver_global_x).abs > WHALE_GONE
  end

  # Keep it in open water: off the sand, under the surface. Read at the whale's
  # own x, not the diver's — they can be a screen and a half apart, and a floor
  # measured where *he* is standing means nothing about where it is swimming.
  # The sea floor is a long way down in its water, so this rarely bites; but a
  # whale ploughing through a trench wall would undo the whole illusion.
  def whale_track_y(x, y)
    low = WorldGenerator.smooth_floor_y_at(x) + WHALE_CLEARANCE + whale_height / 2
    high = WATERLINE_Y - whale_height
    return low if high < low
    return low if y < low
    return high if y > high

    y
  end

  def whale_width
    (whale_species || Species["blauwal"]).frame_w * WHALE_SCALE
  end

  def whale_height
    (whale_species || Species["blauwal"]).frame_h * WHALE_SCALE
  end

  # Said once per animal, on the running-messages line. It is the only warning
  # you get, and it is not a warning — nothing is going to happen to you.
  def note_the_whale(whale)
    return if whale.noted
    return if (whale.x - state.diver_global_x).abs > SCREEN_WIDTH

    whale.noted = true
    state.whale_note_at = Kernel.tick_count
  end

  def whale_note_visible?
    state.whale_note_at && Kernel.tick_count - state.whale_note_at < WHALE_NOTE_TICKS
  end

  # Its body as a rect in world coordinates, for the camera to find it by.
  def whale_rect
    whale = state.whale
    { x: whale.x - whale_width / 2, y: whale.y - whale_height / 2,
      w: whale_width, h: whale_height }
  end

  # Drawn in world space and camera-offset, like everything else out here — and
  # *before* the fog, so the dark takes its ends. At this size the fog is not
  # hiding it; it is what stops you seeing all of it at once, which is most of
  # why it feels big.
  def render_whale
    return unless whale_present? && fauna_visible?

    whale = state.whale
    species = whale_species || Species["blauwal"]
    frame = Kernel.tick_count.idiv(WHALE_FRAME_HOLD) % species.frames_per_row
    outputs.sprites << {
      x: whale.x - state.camera_x - whale_width / 2,
      y: whale.y - state.camera_y - whale_height / 2,
      w: whale_width, h: whale_height,
      path: species.sheet,
      source_x: species.frame_w * frame, source_y: 0,
      source_w: species.frame_w, source_h: species.frame_h,
      flip_horizontally: whale.dir < 0,
    }
  end

  # Slower than the shared sprite clock: everything else in the sea animates off
  # the game's 8-frame, 16-tick cycle, and a whale beating its tail at fish
  # tempo would be a very large minnow.
  WHALE_FRAME_HOLD = 22
end

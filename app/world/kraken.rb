# The kraken: a legend of the deep. Reopens Game.
#
# It is real, and it is deadly — but not the way the shark is. It never lunges at
# you across open water; it *lures*. It hangs at the edge of the fog, deeper than
# you and a little ahead, close enough that the camera reads it as a subject —
# "[ F ] ? ? ?" — so you believe you can photograph it. You can't. Every shot
# comes back empty. And every time you swim closer for a better one, it drifts
# deeper, drawing you past what the suit can take. The only escape is the way you
# never want to go while chasing a photograph: up.
#
# So the killer is the depth, not the kraken — exactly how the legend would be
# told. It only seizes you outright if you actually corner it (against a trench
# wall), which the retreat almost never lets you do.
#
# It appears only when you are already deep enough to be in trouble, which the
# rated suit forbids — so meeting it at all means you have gone too far.
class Game
  KRAKEN_DEPTH = 150      # m: it shows once you are this deep ...
  KRAKEN_FADE = 120       # ... and sinks away once you climb back above this
  KRAKEN_GAP = 230        # px it keeps ahead — inside the camera's reach, so it tempts
  KRAKEN_DROP = 130       # px it keeps below you — the pull is always downward
  KRAKEN_EASE = 0.05      # how slowly it glides to its mark: an eerie drift
  KRAKEN_GRAB = 64        # px: this close and it takes you (only if you corner it)
  KRAKEN_FLOOR_MARGIN = 40 # it hovers this far off the sand, never inside it
  KRAKEN_FAIL_NOTES = [
    "Nichts auf dem Film …",
    "Zu dunkel — nur Schatten.",
    "Der Sucher blieb leer.",
    "Weg. War da überhaupt etwas?",
  ]

  def kraken_present?
    !state.kraken.nil?
  end

  # Runs each diving tick. It lurks while you are deep, and dissolves into the
  # dark the moment you climb back toward safety.
  def update_kraken
    unless kraken_should_lurk?
      state.kraken = nil
      return
    end

    state.kraken ||= new_kraken
    move_kraken
    seize_diver_if_cornered
  end

  # Present only underwater and only below the trigger depth, with hysteresis so
  # it doesn't flicker on and off right at the boundary.
  def kraken_should_lurk?
    return false unless submerged_visible?

    current_depth >= (state.kraken ? KRAKEN_FADE : KRAKEN_DEPTH)
  end

  # It appears on the side you're facing, and keeps that side — so turning to flee
  # leaves it trailing behind rather than crossing through you.
  def new_kraken
    { x: kraken_target_x(kraken_facing), y: kraken_target_y(kraken_facing), side: kraken_facing }
  end

  def move_kraken
    k = state.kraken
    k.x += (kraken_target_x(k.side) - k.x) * KRAKEN_EASE
    k.y += (kraken_target_y(k.side) - k.y) * KRAKEN_EASE
  end

  def kraken_facing
    state.direction == :left ? -1 : 1
  end

  def kraken_target_x(side)
    state.diver_global_x + side * KRAKEN_GAP
  end

  # Below the diver — always — but never sunk into the sand: at a trench bottom it
  # can retreat no deeper, and there the chase ends with the pressure, not the
  # kraken.
  def kraken_target_y(side)
    below = state.depth_y - KRAKEN_DROP
    floor = floor_top_at(kraken_target_x(side)) + KRAKEN_FLOOR_MARGIN
    below > floor ? below : floor
  end

  def seize_diver_if_cornered
    return unless photo_distance(state.kraken.x, state.kraken.y) < KRAKEN_GRAB

    state.game_scene = "game_over"
    state.death_cause = :taken
  end

  # The shutter fires and the flash goes off — and the film comes back empty. No
  # frame spent, so nothing stops you trying again, closer, deeper.
  def attempt_kraken_photo
    state.shot_at = Kernel.tick_count
    state.shot_note = { name: KRAKEN_FAIL_NOTES[rand(KRAKEN_FAIL_NOTES.length)], quality: nil, fresh: false }
  end

  # It must never quite resolve. Rather than one coherent bulk, it is a handful of
  # near-black patches and tentacle-hints that each flicker on their own phase, so
  # at any instant only some of it is there — the eye never sees the whole thing.
  # Over it all a slow "presence" that keeps sinking almost back into the dark.
  # Drawn before the fog, so the fog eats its edges too.
  KRAKEN_MURK = [8, 12, 20]     # near-black, a touch of cold blue
  KRAKEN_MURK_ALPHA = 44        # the mantle patches, at full presence
  KRAKEN_TENTACLE_ALPHA = 30
  KRAKEN_EYE_DIM = 16           # the eye almost always just smoulders ...
  KRAKEN_EYE_GLINT = 92         # ... and only rarely, briefly, catches the light
  # Patch offsets from the centre: [dx, dy, w, h].
  KRAKEN_PATCHES = [[-70, -30, 150, 130], [-30, 60, 120, 80], [10, -70, 90, 90]]

  def render_kraken
    return unless kraken_present? && submerged_visible?

    k = state.kraken
    sx = k.x - state.camera_x
    sy = k.y - state.camera_y
    return if sx < -320 || sx > grid.w + 320

    presence = kraken_presence(k.x)
    render_kraken_tentacles(sx, sy, presence)
    render_kraken_patches(sx, sy, presence)
    render_kraken_eye(sx, sy, presence)
  end

  # A slow swell that dips almost to nothing — the thing fading in and out of the
  # deep. Never near full: it tops out well under one.
  def kraken_presence(x)
    0.08 + 0.42 * (0.5 + 0.5 * Math.sin((Kernel.tick_count + x) / 58.0))
  end

  # Each patch has its own flicker, so they don't all show at once — the shape
  # never assembles.
  def render_kraken_patches(sx, sy, presence)
    KRAKEN_PATCHES.each_with_index do |(dx, dy, w, h), i|
      flick = 0.35 + 0.65 * (0.5 + 0.5 * Math.sin((Kernel.tick_count + i * 300) / (44.0 + i * 11)))
      drift = Math.sin((Kernel.tick_count + i * 120) / 50.0) * 10
      alpha = (KRAKEN_MURK_ALPHA * presence * flick).to_i
      outputs.sprites << { x: sx + dx + drift, y: sy + dy, w: w, h: h,
                           r: KRAKEN_MURK[0], g: KRAKEN_MURK[1], b: KRAKEN_MURK[2],
                           a: alpha, path: :solid }
    end
  end

  def render_kraken_tentacles(sx, sy, presence)
    4.times do |i|
      lean = (i - 1.5) * 30
      wave = Math.sin((Kernel.tick_count + i * 130) / 24.0) * 18
      flick = 0.3 + 0.7 * (0.5 + 0.5 * Math.sin((Kernel.tick_count + i * 210) / 37.0))
      alpha = (KRAKEN_TENTACLE_ALPHA * presence * flick).to_i
      outputs.sprites << { x: sx + lean + wave - 4, y: sy - 190, w: 8, h: 190,
                           r: KRAKEN_MURK[0], g: KRAKEN_MURK[1], b: KRAKEN_MURK[2],
                           a: alpha, path: :solid }
    end
  end

  # The one thing you ever nearly make out: a cold eye that mostly smoulders and,
  # rarely and briefly, gleams. Even the gleam is tied to presence, so it too can
  # sink away.
  def render_kraken_eye(sx, sy, presence)
    gleam = (Kernel.tick_count % 320) < 12 ? 1.0 : 0.0
    base = KRAKEN_EYE_DIM + (KRAKEN_EYE_GLINT - KRAKEN_EYE_DIM) * gleam
    alpha = (base * (0.4 + 0.6 * presence)).to_i
    outputs.sprites << { x: sx - 30, y: sy + 30, w: 18, h: 18,
                         r: 120, g: 150, b: 128, a: alpha, path: :solid }
  end
end

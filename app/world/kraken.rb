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

  # Drawn with the fauna, before the fog — so the fog eats its edges and it stays
  # a suggestion: a dark mantle, tentacles trailing below, and one cold eye that
  # blinks in the murk.
  def render_kraken
    return unless kraken_present? && submerged_visible?

    k = state.kraken
    sx = k.x - state.camera_x
    sy = k.y - state.camera_y
    return if sx < -320 || sx > grid.w + 320

    sway = Math.sin((Kernel.tick_count + k.x) / 40.0) * 12
    render_kraken_tentacles(sx + sway, sy)
    # the mantle: a big, near-black bulk, low enough alpha that the dark hides it
    outputs.sprites << { x: sx - 90 + sway, y: sy - 40, w: 180, h: 150,
                         r: 10, g: 14, b: 22, a: 96, path: :solid }
    outputs.sprites << { x: sx - 60 + sway, y: sy + 70, w: 120, h: 60,
                         r: 12, g: 16, b: 26, a: 80, path: :solid }
    render_kraken_eye(sx + sway, sy)
  end

  def render_kraken_tentacles(sx, sy)
    5.times do |i|
      lean = (i - 2) * 26
      wave = Math.sin((Kernel.tick_count + i * 90) / 26.0) * 16
      outputs.sprites << { x: sx + lean + wave - 5, y: sy - 200, w: 10, h: 200,
                           r: 8, g: 12, b: 20, a: 70, path: :solid }
    end
  end

  # The one thing you ever really see: a pale eye that mostly smoulders and, every
  # so often, catches the light.
  def render_kraken_eye(sx, sy)
    phase = (Kernel.tick_count % 200)
    glint = phase < 24 ? 1.0 : 0.35 # a slow, occasional gleam
    outputs.sprites << { x: sx - 34, y: sy + 34, w: 22, h: 22,
                         r: 150, g: 176, b: 150, a: (70 + 150 * glint).to_i, path: :solid }
  end
end

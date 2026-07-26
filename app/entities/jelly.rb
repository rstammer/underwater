# A jellyfish. Not a fish: it does not swim anywhere and it does not care that
# you exist. It hangs in the water, pulses, and drifts.
#
# That is the whole point of it. Everything else alive out here either patrols a
# stretch of water (Creature), walks a floor (Crustacean), hunts you (DarkShark)
# or crosses the sea on business of its own (the whale). A jellyfish is the first
# thing in the game that is simply *in the way* — which is what makes a field of
# them a piece of terrain rather than a piece of fauna.
#
# Two details do most of the work of making a field read as alive:
#
#   * every animal has its **own phase**. A field pulsing in unison is a
#     screensaver; a field pulsing out of step is a crowd.
#   * every animal has its **own slow drift**, up and down on a long period, so
#     the field breathes instead of hanging there like wallpaper.
#
# Like the swarm, its x is local to its segment and its y is a world y.
class Jelly
  PULSE_HOLD = 9        # ticks per frame of the bell — slower than a fish's fins
  DRIFT = 44            # px it wanders above and below where it hatched
  DRIFT_PERIOD = 420.0  # ticks for one of those; a long, sleepy breath
  SWAY = 16             # ... and how far it slides sideways over the same period
  SIZE = 2              # drawn at twice the sheet, so a 24 px bell is a 48 px animal

  attr_reader :species

  def initialize(current_args, sprite_index, species:, x:, y:, phase: 0)
    @current_args = current_args
    @sprite_index = sprite_index
    @species = species
    @home_x = x
    @home_y = y
    @x = x
    @y = y
    # Its own place in the cycle, given from outside so a field can be spread
    # across the beat rather than clapping in time.
    @phase = phase
    # Its own clock, wound on once per tick. Read off Kernel.tick_count instead
    # and the animal keeps drifting and pulsing behind the pause menu, which
    # draws the world precisely *because* it is frozen — and nothing that only
    # a global clock moves can be tested without a running game.
    @age = phase
  end

  def x
    @x
  end

  def y
    @y
  end

  def w
    species.frame_w * SIZE
  end

  def h
    species.frame_h * SIZE
  end

  # It drifts. There is no heading, no patrol and no destination — the position
  # is a function of the clock and where it started, which is why a field never
  # slowly migrates off somewhere over a long dive.
  def tick(current_args, _sprite_index)
    @current_args = current_args
    @age += 1
    t = @age / DRIFT_PERIOD * 2 * Math::PI
    @y = @home_y + Math.sin(t) * DRIFT
    @x = @home_x + Math.cos(t * 0.6) * SWAY
  end

  # A jellyfish has no idea you are there. Both are no-ops rather than absent,
  # because Game#update_shyness talks to everything alive in the water — and a
  # species with shy: 0 never gets here anyway.
  def bolt_from(_local_x); end

  def drawn_to(_local_x); end

  def bolting?
    false
  end

  # The bell, for the sting: the animal's own body rather than its sprite box,
  # which is mostly trailing threads and empty water.
  BELL_W = 20
  BELL_H = 16

  def bell
    { x: @x - BELL_W * SIZE / 2, y: @y + h / 2 - BELL_H * SIZE,
      w: BELL_W * SIZE, h: BELL_H * SIZE }
  end

  def to_h
    frame = @age.idiv(PULSE_HOLD) % species.frames_per_row
    {
      x: @x - w / 2,
      y: @y - h / 2,
      w: w,
      h: h,
      path: species.sheet,
      source_x: species.frame_w * frame,
      source_y: 0,
      source_w: species.frame_w,
      source_h: species.frame_h,
    }
  end
end

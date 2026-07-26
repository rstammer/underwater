# A fish in the water, of some species. It patrols the stretch of open water it
# was spawned in and drifts a little around its home depth; everything about how
# it *looks* comes from its species (see app/world/species.rb), so adding a fish
# to the sea is adding a row to that roster, not a class here.
class Creature
  SPEEDS = [0.25, 0.5, 0.75, 0.65, 0.35, 0.15]
  SIZES = [1, 1, 1, 2] # mostly small ones, now and then a bigger specimen
  DRIFT = 60 # how far it wanders from the depth it was spawned at
  BOLT_SPEED = 1.7  # how fast a startled one leaves — comfortably faster than a
                    # swimming diver, so chasing is hopeless by design
  BOLT_TICKS = 40   # and how long it keeps going after the last fright, so the
                    # flight reads as a startle rather than a switch

  attr_reader :species

  # from_x/to_x bound the stretch of open water this fish was spawned in — it
  # turns around at the ends rather than swimming on into rock. low/high do the
  # same for the water above and below it, and they matter for the same reason
  # the span does: a fish is up to 64 by 32 px of animal drawn out and up from
  # this x/y, so a point in open water is no promise that the *fish* is.
  #
  # size comes from outside now: the sea has to know how big the animal will be
  # before it can work out which water it fits in.
  #
  # speed likewise, and for a sharper reason: a school is only a school for as
  # long as it stays together. Left to roll their own out of SPEEDS, six herring
  # spawned side by side are strung out across the segment inside ten seconds and
  # the group photograph is gone. Handed one pace, they hold formation — and the
  # two behaviours that already override the patrol, bolting and coming to look,
  # both run at a fixed speed, so the whole school does those together too.
  def initialize(current_args, sprite_index, species:, x: 10, y: 200,
                 from_x: 0, to_x: SCREEN_WIDTH, low: nil, high: nil, size: nil,
                 speed: nil)
    @sprite_index = sprite_index
    @current_args = current_args
    @species = species
    @size = size || SIZES.sample
    @x = x
    @y = y
    @home_y = y # world y of its patch of water — it never strays far from this
    @from_x = from_x
    @to_x = to_x
    @low = low || y - DRIFT
    @high = high || y + DRIFT
    @heading = 1
    @speed = speed || SPEEDS.sample
    @bolting = 0
  end

  # Frightened off, away from a diver at this segment-local x. Called by the game
  # (Game#update_shyness), which is the only thing that knows where he is; the
  # fish just knows which way is away. Re-applied for as long as he keeps coming,
  # so standing still is what lets it settle.
  def bolt_from(local_x)
    @bolting = BOLT_TICKS
    @heading = local_x > @x ? -1 : 1
  end

  def bolting?
    @bolting > 0
  end

  # The other half of it: a diver who has stopped is not a threat but a curiosity,
  # and it comes to have a look. Without this, waiting only means *hoping* the
  # patrol wanders back — and then the promise the whole mechanic makes ("stop and
  # it will come to you") is a coin toss.
  #
  # It stops steering once it is right up close, so it drifts on past instead of
  # sticking to him like a magnet.
  CROWDING = 40
  # Coming to look is its own pace, not whatever patrol speed it happened to roll.
  # Otherwise the wait is a lottery: the slowest fish would take half a minute to
  # cross the same water the quickest crosses in eight seconds, and patience you
  # cannot estimate is just tedium.
  CURIOUS_SPEED = 0.6

  def drawn_to(local_x)
    return if bolting?

    gap = local_x - @x
    return if gap.abs < CROWDING

    @heading = gap > 0 ? 1 : -1
    @curious = true
  end

  def x
    @x
  end

  def y
    @y
  end

  # It patrols its stretch of water and turns at both ends; y drifts around its
  # home depth. Both are world coordinates, so a fish spawned in a trench keeps
  # swimming down there instead of being folded back into the top screen height.
  def tick(current_args, sprite_index)
    @sprite_index = sprite_index
    @current_args = current_args
    if bolting?
      @bolting -= 1
      @x += BOLT_SPEED * @heading
    else
      @x += (@curious ? CURIOUS_SPEED : @speed) * @heading
    end
    @curious = false # re-asked every frame by Game#update_shyness
    if @x >= @to_x
      @x = @to_x
      @heading = -1
    elsif @x <= @from_x
      @x = @from_x
      @heading = 1
    end

    if (sprite_index + rand(100)) % 180 == 0 # don't jump too often
      @y += (-1)**rand(10) * rand(5)
      @y = @home_y - DRIFT if @y < @home_y - DRIFT
      @y = @home_y + DRIFT if @y > @home_y + DRIFT
      # ... and never out of the water it was given, whatever the drift says.
      @y = @low if @y < @low
      @y = @high if @y > @high
    end
  end

  def size
    @size
  end

  def w
    species.frame_w * size
  end

  def h
    species.frame_h * size
  end

  def to_h
    {
      x: @x,
      y: @y,
      flip_horizontally: @heading < 0,
      w: w,
      h: h,
      path: species.sheet,
      source_x: species.frame_w * @sprite_index,
      source_y: species.frame_h * (@sprite_index / species.frames_per_row).floor,
      source_w: species.frame_w,
      source_h: species.frame_h,
    }
  end
end

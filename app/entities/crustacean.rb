# A crab, a lobster, a langoustine — something that walks on the sea floor
# rather than swimming over it. Sibling of Creature: same idea (it carries a
# species and everything about how it looks comes from there), but its vertical
# position is not its own. It rests on the sand, so its y is read from the
# terrain under it every tick, and it climbs whatever the floor does.
#
# It scuttles rather than crawls: short dashes with pauses in between, which is
# what makes a crab read as a crab and not as a slow fish. It also makes them
# far easier to photograph well — standing still is what you want from a subject
# you have to get close to.
class Crustacean
  SPEEDS = [0.2, 0.3, 0.45]
  DASH = [40, 70, 110]  # ticks of scuttling before it thinks better of it
  REST = [30, 60, 100]  # ... and ticks of sitting there afterwards

  attr_reader :species

  # from_x/to_x bound the stretch it can walk — worked out at spawn, so it never
  # wanders into an island's flank or off a beach into the sea. Both are
  # segment-local, like a fish.
  #
  # ground says which surface it belongs to: :sand is the sea floor, :crown the
  # top of the rock — a beach, which is the same animal walking on the other
  # side of the waterline.
  def initialize(current_args, sprite_index, species:, world:, x: 100,
                 from_x: nil, to_x: nil, ground: :sand)
    @sprite_index = sprite_index
    @current_args = current_args
    @species = species
    @world = world
    @ground = ground
    @x = x
    @from_x = from_x || x - 120
    @to_x = to_x || x + 120
    @heading = [1, -1].sample
    @speed = SPEEDS.sample
    @size = [2, 2, 3].sample
    @dash = DASH.sample
    @rest = 0
    @y = ground_y
  end

  # The surface under its feet. A beach crab falls back to the sand if it should
  # ever find itself over open water — it can't, given its span, but a nil here
  # would be a crash rather than a bug you can see.
  def ground_y
    return @world.floor_y_at(@x) if @ground == :sand

    @world.crown_y_at(@x) || @world.floor_y_at(@x)
  end

  def x
    @x
  end

  def y
    @y
  end

  def size
    @size
  end

  # Sit for a spell, then dash a little way, then sit again. Whatever the x ends
  # up as, the y is the sand under it — so it walks up over a terrace instead of
  # through it.
  def tick(current_args, sprite_index)
    @sprite_index = sprite_index
    @current_args = current_args

    if @rest > 0
      @rest -= 1
    else
      @x += @speed * @heading
      turn_at_the_ends
      @dash -= 1
      if @dash <= 0
        @dash = DASH.sample
        @rest = REST.sample
        @heading = -@heading if rand(2).zero? # as often as not, it goes back
      end
    end

    @y = ground_y
  end

  # A crab can be frightened too — none is, today (every crustacean's shy is 0),
  # but Game#update_shyness asks every creature it can see, and a shy species
  # added later shouldn't find the method missing. It scuttles off rather than
  # bolting: it has legs, not fins.
  def bolt_from(local_x)
    @heading = local_x > @x ? -1 : 1
    @rest = 0
    @dash = DASH.max
  end

  def turn_at_the_ends
    if @x >= @to_x
      @x = @to_x
      @heading = -1
    elsif @x <= @from_x
      @x = @from_x
      @heading = 1
    end
  end

  def w
    species.frame_w * size
  end

  def h
    species.frame_h * size
  end

  # Drawn resting *on* the sand: y is the floor, and a sprite's y is its bottom
  # edge, so it stands on the terrace rather than sinking into it.
  def to_h
    {
      x: @x - w / 2,
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

# A fish in the water, of some species. It patrols the stretch of open water it
# was spawned in and drifts a little around its home depth; everything about how
# it *looks* comes from its species (see app/world/species.rb), so adding a fish
# to the sea is adding a row to that roster, not a class here.
class Creature
  SPEEDS = [0.25, 0.5, 0.75, 0.65, 0.35, 0.15]
  DRIFT = 60 # how far it wanders from the depth it was spawned at

  attr_reader :species

  # from_x/to_x bound the stretch of open water this fish was spawned in — it
  # turns around at the ends rather than swimming on into rock.
  def initialize(current_args, sprite_index, species:, x: 10, y: 200,
                 from_x: 0, to_x: SCREEN_WIDTH)
    @sprite_index = sprite_index
    @current_args = current_args
    @species = species
    @x = x
    @y = y
    @home_y = y # world y of its patch of water — it never strays far from this
    @from_x = from_x
    @to_x = to_x
    @heading = 1
    @speed = SPEEDS.sample
    @size = [1, 1, 1, 2].sample
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
    @x += @speed * @heading
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

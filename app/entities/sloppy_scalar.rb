class SloppyScalar
  BASE_PATH = "sprites/animals/scalar_32_16/"
  WIDTH = 32
  HEIGHT = 16
  SPRITES_PER_ROW = 8
  COLORS = [:orange, :blue, :green, :purple]
  SPEEDS = [0.25, 0.5, 0.75, 0.65, 0.35, 0.15]
  DRIFT = 60 # how far the fish wanders from the depth it was spawned at

  # from_x/to_x bound the stretch of open water this fish was spawned in — it
  # turns around at the ends rather than swimming on into rock.
  def initialize(current_args, sprite_index, x: 10, y: 200, color: nil,
                 from_x: 0, to_x: SCREEN_WIDTH)
    @sprite_index = sprite_index
    @current_args = current_args
    @x = x
    @y = y
    @home_y = y # world y of its patch of water — it never strays far from this
    @from_x = from_x
    @to_x = to_x
    @heading = 1
    @color = color || COLORS.sample
    @speed = SPEEDS.sample
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

  def path
    BASE_PATH + @color.to_s + ".png"
  end

  def size
    @size ||= [1, 1, 1, 2].sample
  end

  def to_h
    {
      x: @x,
      y: @y,
      flip_horizontally: @heading < 0,
      w: WIDTH * size,
      h: HEIGHT * size,
      path: path,
      source_x: WIDTH * @sprite_index,
      source_y: HEIGHT * (@sprite_index / SPRITES_PER_ROW).floor,
      source_w: WIDTH,
      source_h: HEIGHT
    }
  end
end

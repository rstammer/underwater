class SloppyScalar
  BASE_PATH = "sprites/animals/scalar_32_16/"
  WIDTH = 32
  HEIGHT = 16
  SPRITES_PER_ROW = 8
  COLORS = [:orange, :blue, :green, :purple]

  def initialize(current_args, sprite_index, x: 10, y: 200, color: nil)
    @sprite_index = sprite_index
    @current_args = current_args
    @x = x
    @y = y
    @color = color || COLORS.sample
  end

  def tick(current_args, sprite_index)
    @sprite_index = sprite_index
    @current_args = current_args
  end

  def path
    BASE_PATH + @color.to_s + ".png"
  end

  def to_h
    {
      x: @x,
      y: @y,
      w: WIDTH * 2,
      h: HEIGHT * 2,
      flip_horizontally: @current_args.state.direction == :left,
      path: path,
      source_x: WIDTH * @sprite_index,
      source_y: HEIGHT * (@sprite_index / SPRITES_PER_ROW).floor,
      source_w: WIDTH,
      source_h: HEIGHT
    }
  end
end

class Weed
  PATH = "sprites/other/weed.png"
  WIDTH = 16
  HEIGHT = 24
  SPRITES_PER_ROW = 12

  def initialize(current_args, sprite_index, x: 0, y: 0, size: 2)
    @sprite_index = sprite_index
    @current_args = current_args
    @x = x
    @y = y
    @size = size
  end

  def tick(current_args, sprite_index)
    @sprite_index = sprite_index
    @current_args = current_args
  end

  def to_h
    {
      x: @x,
      y: @y,
      w: WIDTH * @size,
      h: HEIGHT * @size,
      path: PATH,
      source_x: WIDTH * @sprite_index,
      source_y: HEIGHT * (@sprite_index / SPRITES_PER_ROW).floor,
      source_w: WIDTH,
      source_h: HEIGHT
    }
  end
end


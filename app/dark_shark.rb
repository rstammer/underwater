class DarkShark
  PATH = "sprites/animals/dark_shark_32_32/shark.png"
  WIDTH = 32
  HEIGHT = 32
  SPRITES_PER_ROW = 8
  SCALE_FACTOR = 4

  def initialize(current_args, sprite_index)
    @sprite_index = sprite_index
    @current_args = current_args
  end

  def to_h
    {
      x: @current_args.state.dark_shark.x,
      y: @current_args.state.dark_shark.y,
      w: WIDTH * SCALE_FACTOR,
      h: HEIGHT * SCALE_FACTOR,
      angle: 0,
      path: PATH,
      source_x: WIDTH * @sprite_index,
      source_y: HEIGHT * (@sprite_index / SPRITES_PER_ROW).floor,
      source_w: WIDTH,
      source_h: HEIGHT
    }
  end
end


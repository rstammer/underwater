class Diver
  PATH = "sprites/diver.png"
  WIDTH = 32
  HEIGHT = 32
  SPRITES_PER_ROW = 12

  def initialize(current_args, sprite_index)
    @sprite_index = sprite_index
    @current_args = current_args
  end

  def tick(current_args, sprite_index)
    @sprite_index = sprite_index
    @current_args = current_args
  end

  def to_h
    {
      x: @current_args.state.player_x,
      y: @current_args.state.player_y,
      w: WIDTH * 2,
      h: HEIGHT * 2,
      flip_horizontally: @current_args.state.direction == :left,
      angle: @current_args.state.angle,
      anchor_x: 0.5,
      anchor_y: 0.5,
      path: PATH,
      source_x: WIDTH * @sprite_index,
      source_y: HEIGHT * (@sprite_index / SPRITES_PER_ROW).floor,
      source_w: WIDTH,
      source_h: HEIGHT
    }
  end
end


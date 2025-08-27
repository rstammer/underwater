class Diver
  PATH = "sprites/diver_v2.png"
  WIDTH = 32
  HEIGHT = 32
  SPRITES_PER_ROW = 12
  START_X = 600
  SPEED = 2

  attr_reader :global_position_x

  def initialize(current_args, sprite_index)
    @sprite_index = sprite_index
    @current_args = current_args
    @global_position_x = 600
  end

  def tick(current_args, sprite_index)
    @sprite_index = sprite_index
    @current_args = current_args
    
    if movement?
      if @current_args.state.direction == :right 
        @global_position_x += SPEED
      elsif @current_args.state.direction == :left
        @global_position_x -= SPEED
      end
    end
  end

  def movement?
    @current_args.inputs.left || @current_args.inputs.right || @current_args.inputs.down
  end

  def to_h
    {
      x: @current_args.state.player_x % 1280,
      y: @current_args.state.player_y,
      w: WIDTH * 2,
      h: HEIGHT * 2,
      flip_horizontally: @current_args.state.direction == :left,
      angle: @current_args.state.angle,
      anchor_x: 0.5,
      anchor_y: 0.5,
      path: PATH,
      source_x: WIDTH * @sprite_index,
      source_y: HEIGHT * (@sprite_index / SPRITES_PER_ROW).floor + (movement? ? 0 : HEIGHT),
      source_w: WIDTH,
      source_h: HEIGHT
    }
  end
end

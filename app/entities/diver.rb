class Diver
  PATH = "sprites/diver_v2.png"
  WIDTH = 32
  HEIGHT = 32
  SPRITES_PER_ROW = 12
  START_X = 600
  SPEED = 2

  def initialize(current_args, sprite_index)
    @sprite_index = sprite_index
    @current_args = current_args
  end

  # Single source of truth: the unbounded horizontal position lives in
  # args.state, so reset_game can restore it without touching this object.
  def global_position_x
    @current_args.state.diver_global_x
  end

  # Horizontal movement (both player_x and diver_global_x) is driven together in
  # Game#basic_movements_per_tick so the two stay perfectly in lockstep. This
  # object is now a pure renderer that reads position from state.
  def tick(current_args, sprite_index)
    @sprite_index = sprite_index
    @current_args = current_args
  end

  def movement?
    @current_args.inputs.left || @current_args.inputs.right || @current_args.inputs.down
  end

  def to_h
    {
      x: @current_args.state.player_x, # already the on-screen x (camera-projected)
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

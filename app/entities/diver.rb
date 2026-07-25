class Diver
  PATH = "sprites/diver_v2.png"
  # The same person out of the water: arms down, flippers folded flat and
  # forward. Derived from the sheet above rather than drawn fresh — see
  # tools/make_diver_land_sprites.rb. Same layout, so only the path changes.
  LAND_PATH = "sprites/diver_land.png"
  # px of ground covered per frame of the walk. Two of the four poses are steps,
  # so a stride is twice this — about half his own height, which is what a stride
  # looks like.
  LAND_STRIDE = 16
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

  # Whether to show the swimming pose rather than the idle one. Game sets
  # state.swim_pose each tick from will_* (keyboard OR the touch joystick), so the
  # animation follows both without this renderer knowing which drove it.
  def movement?
    @current_args.state.swim_pose
  end

  # Out of the water he walks in the land sheet, and he doesn't lean: the tilt is
  # a swimmer angling through water, and on a beach it just tips him over.
  def on_land?
    !!@current_args.state.on_land
  end

  # Which frame of the sheet to draw. Swimming runs on the clock, like everything
  # else in the water. Walking runs on the *ground*: the frame comes from how far
  # he has actually gone, so his feet keep step with the terrain instead of
  # cycling on a timer while he slides along underneath them.
  def frame
    return @sprite_index unless on_land? && movement?

    (@current_args.state.diver_global_x.idiv(LAND_STRIDE)) % SPRITES_PER_ROW
  end

  def to_h
    {
      x: @current_args.state.player_x, # already the on-screen x (camera-projected)
      y: @current_args.state.player_y,
      w: WIDTH * 2,
      h: HEIGHT * 2,
      flip_horizontally: @current_args.state.direction == :left,
      angle: on_land? ? 0 : @current_args.state.angle,
      anchor_x: 0.5,
      anchor_y: 0.5,
      path: on_land? ? LAND_PATH : PATH,
      source_x: WIDTH * frame,
      source_y: HEIGHT * (frame / SPRITES_PER_ROW).floor + (movement? ? 0 : HEIGHT),
      source_w: WIDTH,
      source_h: HEIGHT
    }
  end
end

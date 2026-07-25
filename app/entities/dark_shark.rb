class DarkShark
  PATH = "sprites/animals/dark_shark_32_32/shark.png"
  WIDTH = 32
  HEIGHT = 32
  SPRITES_PER_ROW = 8
  SCALE_FACTOR = 2
  SPEED = 3.5
  # The animal inside its frame. Measured off the sheet: it fills the full width
  # but only 19 of the 32 rows, sitting 8 rows up from the bottom — so a third of
  # the sprite square is water, and colliding with the square made it bite from
  # there. In drawn pixels (SCALE_FACTOR applied), kept a shade inside the art.
  HITBOX_W = 60
  HITBOX_H = 34
  HITBOX_Y = 18 # up from the sprite's bottom edge
  HITBOX_X = 2

  def initialize(current_args, sprite_index)
    @sprite_index = sprite_index
    @current_args = current_args
  end

  def tick(current_args, sprite_index)
    @sprite_index = sprite_index
    @current_args = current_args
  end

  # Its body as a rect in world coordinates. Its position is the bottom-left of
  # its sprite, the way it is drawn — not its middle, unlike the diver's.
  def hitbox(world_x, world_y)
    { x: world_x + HITBOX_X, y: world_y + HITBOX_Y, w: HITBOX_W, h: HITBOX_H }
  end

  def to_h
    {
      x: @current_args.state.dark_shark.x,
      y: @current_args.state.dark_shark.y,
      w: WIDTH * SCALE_FACTOR,
      h: HEIGHT * SCALE_FACTOR,
      angle: 0,
      flip_horizontally: @current_args.state.dark_shark.dir.to_i < 0,
      path: PATH,
      source_x: WIDTH * @sprite_index,
      source_y: HEIGHT * (@sprite_index / SPRITES_PER_ROW).floor,
      source_w: WIDTH,
      source_h: HEIGHT
    }
  end
end


ANIMATION_START_TICK = 0

class LittleBass
  def initialize(current_args, sprite_index)
    @sprite_index = sprite_index
    @current_args = current_args
  end

  def render
    {
      x: @current_args.state.player_x,
      y: @current_args.state.player_y,
      w: 32 * 2,
      h: 16 * 2,
      flip_horizontally: @current_args.inputs.left,
      angle: @current_args.state.angle,
      anchor_x: 0.5,
      anchor_y: 0.5,
      path: "sprites/fishes/bass1_32_16/Red.png",
      source_x: 32 * @sprite_index,
      source_y: 16 * (@sprite_index / 8).floor,
      source_w: 32,
      source_h: 16
    }
  end
end

def default_background(grid)
  {
    x: 0,
    y: 0,
    w: grid.w,
    h: grid.h,
    r: 48,
    g: 95,
    b: 177,
  }
end

def tick(args)
  args.state.player_x ||= 120
  args.state.player_y ||= 280

  start_animation_on_tick = 60

  sprite_index =
    start_animation_on_tick.frame_index(
      count: 8, # how many sprites?
      hold_for: 16, # how long to hold each sprite?
      repeat: true # should it repeat?
    )

  sprite_index ||= 0

  if args.inputs.left
    args.state.player_x -= 2
  elsif args.inputs.right
    args.state.player_x += 2
  end

  if args.inputs.up
    args.state.player_y += 2
  elsif args.inputs.down
    args.state.player_y -= 2
  end

  if !args.inputs.up && args.state.player_y >= 1
    args.state.player_y -= 0.15
  end

  if args.inputs.up
    args.state.angle += 0.5
  elsif args.inputs.down
    args.state.angle -= 0.5
  else
    args.state.angle = 0
  end

  args.outputs.sprites << LittleBass.new(args, sprite_index).render
  args.outputs.solids << default_background(args.grid)
end

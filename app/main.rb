ANIMATION_START_TICK = 0

class LittleBass
  def initialize(game_state, sprite_index)
    @sprite_index = sprite_index
    @game_state = game_state
  end

  def render
    {
      x: @game_state.player_x,
      y: @game_state.player_y,
      w: 32,
      h: 16,
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
    args.state.player_x -= 10
  elsif args.inputs.right
    args.state.player_x += 10
  end

  if args.inputs.up
    args.state.player_y += 10
  elsif args.inputs.down
    args.state.player_y -= 10
  end

  args.outputs.sprites << LittleBass.new(args.state, sprite_index).render
  args.outputs.solids << default_background(args.grid)
end

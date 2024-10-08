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
      flip_horizontally: @current_args.state.direction == :left,
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

class SandTile
  COLORS = [
    [242, 208, 169],
    [238, 200, 143],
    [225, 188, 109]
  ]
  def initialize(grid, x, y)
    @grid = grid
    @x = x
    @y = y
    @r, @g, @b = COLORS.sample
  end

  def to_h
    {
      x: @x,
      y: @y,
      w: 8,
      h: 12 + rand(4),
      r: @r + (-1)**rand(2) + rand(25),
      g: @g + (-1)**rand(2) + rand(25),
      b: @b + (-1)**rand(2) + rand(25),
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

def ground(args)
  @ground ||=
    (1..10_000).map do |n|
      SandTile.new(args.grid, 2*n % args.grid.w, -2 + rand(22)).to_h
    end
end

def deepness_factors
  @deepness_factors ||= (6..10).to_a.map{ |n| n / 10 }
end

def water(args, grid_size)
  if args.state.tick_count % 122 != 0
    @water
  else
    deepness_factor = deepness_factors.sample
    @water =
      (1..grid_size).map do |n|
        {
          x: 0,
          y: n*args.grid.h / grid_size,
          w: args.grid.w,
          h: args.grid.h / grid_size,
          r: 0 + rand(25),
          g: 0 + rand(25),
          b: 15 + deepness_factor * n*args.grid.h / grid_size
        }
      end
  end
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
    args.state.direction = :left
    args.state.player_x -= 2
  elsif args.inputs.right
    args.state.player_x += 2
    args.state.direction = :right
  else
    args.state.direction = :right
  end

  if args.inputs.up
    args.state.player_y += 2
  elsif args.inputs.down
    args.state.player_y -= 2
  end

  if !args.inputs.up && args.state.player_y >= 1
    args.state.player_y -= 0.15
  end

  if args.state.player_y <= 1
    args.state.player_y = 1
  end

  if args.state.direction == :right
    if args.inputs.up
      args.state.angle += 0.5
    elsif args.inputs.down
      args.state.angle -= 0.5
    else
      args.state.angle = 0
    end
  else
    if args.inputs.up
      args.state.angle -= 0.5
    elsif args.inputs.down
      args.state.angle += 0.5
    else
      args.state.angle = 0
    end
  end

  args.outputs.solids << default_background(args.grid)
  args.outputs.solids << water(args, 60)
  args.outputs.solids << ground(args)
  args.outputs.sprites << LittleBass.new(args, sprite_index).render
end

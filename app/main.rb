require "app/title.rb"
require "app/game_over.rb"
require "app/little_bass.rb"
require "app/dark_shark.rb"
require "app/sand_tile.rb"
require "app/water.rb"
require "app/weed.rb"
require "app/sloppy_scalar.rb"
require "app/diver.rb"

ANIMATION_START_TICK = 0
SCREEN_WIDTH = 1280
SCREEN_HEIGHT = 720

def initialize_game(args, sprite_index)
  args.state.angle = 0
  args.state.player_x = 600
  args.state.player_y = 710
  args.state.player_state = nil
  args.state.direction = :right
  args.state.dark_shark.x = -300
  args.state.dark_shark.y = 300
  args.state.player_state = :alive
  args.state.scene = "underwater-start"
  args.state.game_scene = "title"
  args.state.initialized = true

  @diver = Diver.new(args, sprite_index)
  @dark_shark = DarkShark.new(args, sprite_index)

  @scalars = (1..20).map do |n|
    x = rand(1280)
    y = 75 + rand(200)
    SloppyScalar.new(args, sprite_index, x: x, y: y)
  end

  @weeds = (1..150).map do |n|
    x = rand(65) + 10*n % SCREEN_WIDTH
    y = 10 + rand(20)
    size = 3 + rand(4)

    Weed.new(args, sprite_index, x: x, y: y, size: size)
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

def fog_square(x, y, w, h)
  {
    x: x,
    y: y,
    w: w,
    h: h,
    r: 8,
    g: 5,
    b: 77,
  }
end

def fog_of_war(args)
  (0..32).map do |x|
    (0..18).map do |y|
      if Math.sqrt((args.state.player_x - x*40)**2 + (args.state.player_y - y*40)**2) > 220
        fog_square(40*x, 40*y, 40, 40)
      end
    end
  end.flatten.compact.map(&:solid)
end

def fire_input?(args)
  args.inputs.keyboard.key_down.space ||
  args.inputs.keyboard.key_down.z ||
    args.inputs.keyboard.key_down.j ||
    args.inputs.controller_one.key_down.a
end

def reset_game(args)
  args.state.angle = 0
  args.state.player_x = 20
  args.state.player_y = 710
  args.state.player_state = nil
  args.state.direction = :right
  args.state.dark_shark.x = 300
  args.state.dark_shark.y = 300
  args.state.player_state = :alive
end

def active_tick(args)
  if args.inputs.keyboard.key_down.escape
    args.state.game_scene = "title"
    return
  end

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
    if args.inputs.up && (args.inputs.left || args.inputs.right)
      args.state.angle += 0.5
    elsif args.inputs.down && (args.inputs.left || args.inputs.right)
      args.state.angle -= 0.5
    else
      args.state.angle = 0
    end
  else
    if args.inputs.up && (args.inputs.left || args.inputs.right)
      args.state.angle -= 0.5
    elsif args.inputs.down && (args.inputs.left || args.inputs.right)
      args.state.angle += 0.5
    else
      args.state.angle = 0
    end
  end

  # Shark movement
  if args.state.dark_shark.x > SCREEN_WIDTH
    args.state.dark_shark.x = -300
    args.state.dark_shark.y = rand(SCREEN_HEIGHT)
  else
    args.state.dark_shark.x = (args.state.dark_shark.x + DarkShark::SPEED)
  end

  if args.tick_count % 30 == 0
    args.state.dark_shark.y = (args.state.dark_shark.y + ((-1)**rand(10) * rand(30))) % SCREEN_WIDTH
  end

  # Render screen
  args.outputs.solids << default_background(args.grid)
  args.outputs.solids << water(args, 60)
  args.outputs.solids << ground(args)
  args.outputs.sprites << @diver.to_h
  args.outputs.sprites << @dark_shark.to_h
  args.outputs.sprites << (@scalars.map(&:to_h) + @weeds.map(&:to_h)).flatten
  args.outputs.primitives << fog_of_war(args)
end

def update_characters(args, sprite_index)
  @dark_shark.tick(args, sprite_index)
  @diver.tick(args, sprite_index)

  @weeds.each do |weed|
    weed.tick(args, sprite_index)
  end

  @scalars.each do |scalar|
    scalar.tick(args, sprite_index)
  end

  if @diver.to_h.intersect_rect?(@dark_shark.to_h)
    args.state.game_scene = "game_over"
  end
end

def tick(args)
  sprite_index ||= 0
  initialize_game(args, sprite_index) unless args.state.initialized

  start_animation_on_tick = 60
  sprite_index =
    start_animation_on_tick.frame_index(
      count: 8, # how many sprites?
      hold_for: 16, # how long to hold each sprite?
      repeat: true # should it repeat?
    ) || 0

  update_characters(args, sprite_index)
  send("#{args.state.game_scene}_tick", args)
end

require 'title.rb'
require 'game_over.rb'
require 'little_bass.rb'
require 'dark_shark.rb'
require 'sand_tile.rb'
require 'water.rb'

ANIMATION_START_TICK = 0
SCREEN_WIDTH = 640
SCREEN_HEIGHT = 720

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

def fire_input?(args)
  args.inputs.keyboard.key_down.space ||
  args.inputs.keyboard.key_down.z ||
    args.inputs.keyboard.key_down.j ||
    args.inputs.controller_one.key_down.a
end

def initialize_game(args)
  args.state.angle = 0
  args.state.player_x = 120
  args.state.player_y = 280
  args.state.player_state = nil
  args.state.direction = :right
  args.state.dark_shark.x = 300
  args.state.dark_shark.y = 300
  args.state.player_state = :alive
  args.state.scene = "underwater-start"
  args.state.game_scene = "title"
  args.state.initialized = true
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

  # Shark movement
  args.state.dark_shark.x = (args.state.dark_shark.x + 0.5) % SCREEN_WIDTH
  args.state.dark_shark.y = args.state.dark_shark.y + ((-1)**rand(10) * rand(10)) if args.tick_count % 40 == 0

  # Render screen
  args.outputs.solids << default_background(args.grid)
  args.outputs.solids << water(args, 60)
  args.outputs.solids << ground(args)
  args.outputs.sprites << @little_bass.to_h
  args.outputs.sprites << @dark_shark.to_h
end

def tick(args)
  initialize_game(args) unless args.state.initialized

  # Make sprites animated
  start_animation_on_tick = 60
  sprite_index =
    start_animation_on_tick.frame_index(
      count: 8, # how many sprites?
      hold_for: 16, # how long to hold each sprite?
      repeat: true # should it repeat?
    )

  sprite_index ||= 0

  # Update characters
  @little_bass = LittleBass.new(args, sprite_index)
  @dark_shark = DarkShark.new(args, sprite_index)

  send("#{args.state.game_scene}_tick", args)
end

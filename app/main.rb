require "app/ux/panel.rb"

require "app/scenes/title.rb"
require "app/scenes/game_over.rb"
require "app/scenes/area1.rb"
require "app/scenes/area2.rb"

require "app/entities/dark_shark.rb"
require "app/entities/sloppy_scalar.rb"
require "app/entities/diver.rb"

require "app/world/sand_tile.rb"
require "app/world/water.rb"
require "app/world/weed.rb"
require "app/world/fog_of_war.rb"

ANIMATION_START_TICK = 0
SCREEN_WIDTH = 1280
SCREEN_HEIGHT = 720
FOG_OF_WAR = true
DEBUG = false

# The whole game lives in this class so we don't pollute the global object
# space. attr_dr gives us state/inputs/outputs/grid/args without threading
# args through every method. Scene ticks reopen this class in app/scenes/*.
class Game
  attr_dr

  def tick
    initialize_game(0) unless state.initialized

    sprite_index = 60.frame_index(
      count: 8,     # how many sprites?
      hold_for: 16, # how long to hold each sprite?
      repeat: true  # should it repeat?
    ) || 0

    update_scene
    update_characters(sprite_index)
    basic_movements_per_tick
    render_panel
    send("#{state.game_scene}_tick")
    render_diver unless game_paused?
  end

  def initialize_game(sprite_index)
    state.angle = 0
    state.player_x = Diver::START_X
    state.player_y = 710
    state.player_state = :alive
    state.direction = :right
    state.dark_shark = { x: -300, y: 300 }
    state.scene = "underwater-start"
    state.game_scene = "title"
    state.diver_global_x = Diver::START_X
    state.initialized = true

    state.diver = Diver.new(args, sprite_index)
    state.shark = DarkShark.new(args, sprite_index)

    state.scalars = (1..30).map do |n|
      SloppyScalar.new(args, sprite_index, x: rand(1280), y: 75 + rand(400))
    end

    state.weeds = (1..150).map do |n|
      Weed.new(args, sprite_index,
               x: rand(65) + 10 * n % SCREEN_WIDTH,
               y: 10 + rand(20),
               size: 3 + rand(4))
    end
  end

  def default_background
    {
      x: 0,
      y: 0,
      w: grid.w,
      h: grid.h,
      r: 48,
      g: 95,
      b: 177,
      path: :solid,
    }
  end

  def ground
    state.ground_tiles ||=
      (1..10_000).map do |n|
        SandTile.new(grid, 2 * n % grid.w, -2 + rand(22)).to_h
      end
  end

  def fire_input?
    inputs.keyboard.key_down.space ||
      inputs.keyboard.key_down.z ||
      inputs.keyboard.key_down.j ||
      inputs.controller_one.key_down.a
  end

  def reset_game
    state.angle = 0
    state.player_x = 20
    state.player_y = 710
    state.player_state = :alive
    state.direction = :right
    state.dark_shark = { x: 300, y: 300 }
    state.diver_global_x = Diver::START_X # otherwise restart stays in area2 with the shark
  end

  def update_characters(sprite_index)
    state.shark.tick(args, sprite_index)
    state.diver.tick(args, sprite_index)

    state.weeds.each { |weed| weed.tick(args, sprite_index) }
    state.scalars.each { |scalar| scalar.tick(args, sprite_index) }

    if state.diver.to_h.intersect_rect?(state.shark.to_h)
      state.game_scene = "game_over"
    end
  end

  def basic_movements_per_tick
    if inputs.keyboard.key_down.escape
      state.game_scene = "title"
      return
    end

    if inputs.left
      state.direction = :left
      state.player_x -= Diver::SPEED
    elsif inputs.right
      state.player_x += Diver::SPEED
      state.direction = :right
    end
    # no else: keep facing the last direction while idle

    if inputs.up
      state.player_y += Diver::SPEED
    elsif inputs.down
      state.player_y -= Diver::SPEED
    end

    if !inputs.up && state.player_y >= 1
      state.player_y -= 0.15
    end

    if state.player_y <= 1
      state.player_y = 1
    end

    if state.direction == :right
      if inputs.up && (inputs.left || inputs.right)
        state.angle += 0.5
      elsif inputs.down && (inputs.left || inputs.right)
        state.angle -= 0.5
      else
        state.angle = 0
      end
    else
      if inputs.up && (inputs.left || inputs.right)
        state.angle -= 0.5
      elsif inputs.down && (inputs.left || inputs.right)
        state.angle += 0.5
      else
        state.angle = 0
      end
    end
  end

  def update_scene
    return if game_paused?

    state.game_scene =
      if state.diver.global_position_x < 1281
        "area1"
      else
        "area2"
      end
  end

  def render_panel
    return if game_paused?

    Panel.new(args, state.diver).to_a.each do |item|
      outputs.labels << item
    end
  end

  def game_paused?
    ["title", "game_over"].include?(state.game_scene)
  end

  def render_diver
    outputs.sprites << state.diver.to_h
    if !!FOG_OF_WAR
      outputs.sprites << FogOfWar.new(state.diver).to_a
    end
  end
end

def boot(args)
  args.state = {} # opt out of args.state nil auto-initialization
end

def tick(args)
  $game ||= Game.new
  $game.args = args
  $game.tick
end

def reset(args)
  $game = nil
end

$game = nil

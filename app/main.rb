require "app/ux/panel.rb"

require "app/scenes/title.rb"
require "app/scenes/game_over.rb"
require "app/scenes/area1.rb"
require "app/scenes/area2.rb"
require "app/scenes/surface.rb"

require "app/entities/dark_shark.rb"
require "app/entities/sloppy_scalar.rb"
require "app/entities/diver.rb"

require "app/world/water.rb"
require "app/world/fog_of_war.rb"

require "app/world/rng.rb"
require "app/world/biome.rb"
require "app/world/world.rb"
require "app/world/world_generator.rb"
require "app/world/static_worlds.rb"
require "app/world/world_renderer.rb"

SCREEN_WIDTH = 1280
SCREEN_HEIGHT = 720
SURFACE_WATERLINE = 160 # y of the waterline in the surface scene; diver body stays below it
SURFACE_FLOAT_DEPTH = 20 # how far below the waterline the diver's center floats (only head/shoulders show)
SURFACE_BOAT_X = 120 # screen x of the diver's home boat in the surface scene
OXYGEN_MAX = 100
OXYGEN_DRAIN = 0.009 # per tick underwater (~3 min of air at 60 fps)
OXYGEN_REFILL = 1.0 # per tick while breathing at the surface (fast top-up)
SPRINT_MULTIPLIER = 2 # sprinting: this much faster, and this much thirstier for air
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
    update_sprint
    update_characters(sprite_index)
    basic_movements_per_tick
    apply_vertical_bounds
    update_oxygen unless game_paused?
    send("#{state.game_scene}_tick")
    render_diver unless game_paused?
    render_panel # HUD last so it draws on top of the scene and fog
  end

  def initialize_game(sprite_index)
    state.angle = 0
    state.player_x = Diver::START_X
    state.player_y = 710
    state.direction = :right
    state.dark_shark = { x: -300, y: 300 }
    state.game_scene = "title"
    state.diver_global_x = Diver::START_X
    state.surfaced = false
    state.oxygen = OXYGEN_MAX
    state.death_cause = nil
    state.sprinting = false
    state.speed = Diver::SPEED
    state.initialized = true

    state.diver = Diver.new(args, sprite_index)
    state.shark = DarkShark.new(args, sprite_index)
    state.fish = [] # a per-world swarm, (re)spawned when a world loads (spawn_fauna)
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

  def fire_input?
    inputs.keyboard.key_down.space ||
      inputs.keyboard.key_down.z ||
      inputs.keyboard.key_down.j ||
      inputs.controller_one.key_down.a
  end

  def reset_game
    state.angle = 0
    state.direction = :right
    state.dark_shark = { x: 300, y: 300 }
    state.oxygen = OXYGEN_MAX
    state.death_cause = nil
    state.sprinting = false
    state.speed = Diver::SPEED
    spawn_at_surface # sets position (player_x, diver_global_x, player_y, surfaced)
  end

  # Every round begins floating at the surface next to the home boat, head out
  # of the water — the player catches a breath and eases in before diving.
  def spawn_at_surface
    state.surfaced = true
    state.player_y = SURFACE_WATERLINE - SURFACE_FLOAT_DEPTH
    state.player_x = SURFACE_BOAT_X + 96 # in the water just beside the boat
    # Keep the world position in lockstep with the on-screen position, so the
    # sector boundary lines up with the screen edge (both wrap at SCREEN_WIDTH).
    state.diver_global_x = state.player_x
  end

  def update_characters(sprite_index)
    state.diver.tick(args, sprite_index)
    return if game_paused?

    state.fish ||= [] # resilience against stale state (e.g. DragonRuby hot reload)
    state.fish.each { |fish| fish.tick(args, sprite_index) }

    if shark_present?
      if state.diver.to_h.intersect_rect?(state.shark.to_h)
        state.game_scene = "game_over"
        state.death_cause = :eaten
      end
      update_shark(sprite_index)
    end
  end

  # Shark cruises across the screen, drifting vertically, and wraps around.
  def update_shark(sprite_index)
    if state.dark_shark.x > SCREEN_WIDTH
      state.dark_shark.x = -300
      state.dark_shark.y = rand(SCREEN_HEIGHT)
    else
      state.dark_shark.x += DarkShark::SPEED
    end

    if Kernel.tick_count % 30 == 0
      state.dark_shark.y = (state.dark_shark.y + ((-1)**rand(10) * rand(30))) % SCREEN_HEIGHT
    end

    state.shark.tick(args, sprite_index)
  end

  def basic_movements_per_tick
    if inputs.keyboard.key_down.escape
      state.game_scene = "title"
      return
    end

    # Move the on-screen and world x together so the sector boundary always
    # lines up with the screen edge.
    if inputs.left
      state.direction = :left
      state.player_x -= state.speed
      state.diver_global_x -= state.speed
    elsif inputs.right
      state.player_x += state.speed
      state.diver_global_x += state.speed
      state.direction = :right
    end
    # no else: keep facing the last direction while idle

    if inputs.up
      state.player_y += state.speed
    elsif inputs.down
      state.player_y -= state.speed
    end

    # Negatively buoyant: the diver slowly sinks unless he's swimming up. The one
    # exception is resting at the surface with his head out of the water
    # (breathing?) — a pause mode where he floats in place. Below the waterline he
    # always sinks. (sea floor / waterline clamps in apply_vertical_bounds)
    state.player_y -= 0.15 unless inputs.up || breathing?

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
      if state.surfaced
        "surface"
      elsif state.diver.global_position_x < 1281
        "area1"
      else
        "area2"
      end
  end

  # Vertical world bounds + surface transition (mirrors the horizontal
  # area1<->area2 wrap). The diver can never leave the water: while surfaced
  # its body is clamped at the waterline so only the head pokes above.
  def apply_vertical_bounds
    if state.surfaced
      float_y = SURFACE_WATERLINE - SURFACE_FLOAT_DEPTH
      state.player_y = float_y if state.player_y > float_y

      # The moment the head dips under the waterline the diver is diving, so hand
      # straight over to the underwater scene just below the surface — symmetric
      # with breaking the surface on the way up, no long descent in between.
      if state.player_y + Diver::HEIGHT < SURFACE_WATERLINE
        state.surfaced = false
        state.player_y = SCREEN_HEIGHT - 1
      end
    else
      if state.player_y >= SCREEN_HEIGHT # swam up past the top -> break the surface
        state.surfaced = true
        # Arrive right at the breathing position: reaching the top means you're
        # up, not facing another water column to climb inside the surface scene.
        state.player_y = SURFACE_WATERLINE - SURFACE_FLOAT_DEPTH
      end

      state.player_y = 1 if state.player_y < 1 # sea floor
    end
  end

  # Sprinting (holding the sprint key while actually swimming) makes the diver
  # faster but burns air quicker. Paused scenes never sprint. The decision is a
  # pure function so it stays trivially testable without stubbing inputs.
  def update_sprint
    state.sprinting = sprint_active?(inputs.keyboard.key_held.space, moving?)
    state.speed = current_speed
  end

  def sprint_active?(sprint_key, moving)
    return false if game_paused?

    !!sprint_key && !!moving
  end

  def moving?
    !!(inputs.up || inputs.down || inputs.left || inputs.right)
  end

  def current_speed
    state.sprinting ? Diver::SPEED * SPRINT_MULTIPLIER : Diver::SPEED
  end

  # Oxygen tops up only while the head is actually above the waterline,
  # otherwise it drains; running out drowns you.
  def update_oxygen
    if breathing?
      state.oxygen = [state.oxygen + OXYGEN_REFILL, OXYGEN_MAX].min
    else
      state.oxygen -= oxygen_drain
      if state.oxygen <= 0
        state.oxygen = 0
        state.game_scene = "game_over"
        state.death_cause = :drowned
      end
    end
  end

  def oxygen_drain
    state.sprinting ? OXYGEN_DRAIN * SPRINT_MULTIPLIER : OXYGEN_DRAIN
  end

  # The head clears the water only once the diver has floated up near the
  # waterline in the surface scene.
  def breathing?
    state.surfaced && state.player_y + Diver::HEIGHT >= SURFACE_WATERLINE
  end

  def render_panel
    return if game_paused?

    Panel.new(args, state.diver).to_a.each do |item|
      outputs.labels << item
    end
    render_oxygen_bar
    render_locator
  end

  # A discreet position readout, top-right. Later this can be gated behind
  # carrying a locator device (see locator?).
  def render_locator
    return unless locator?

    outputs.labels << {
      x: grid.w - 20, y: grid.h - 16,
      text: locator_text,
      size_enum: 1, alignment_enum: 2,
      r: 210, g: 228, b: 245, a: 175,
    }
  end

  def locator?
    true # later: only when the diver carries a locator / dive computer
  end

  def locator_text
    "Sektor #{world_index}    Tiefe #{current_depth} m"
  end

  # Depth below the surface in metres — a whole number, continuous across the
  # shallow surface scene and the deep underwater scene. 0 m at the waterline
  # (and just below the screen top underwater), growing as the diver descends.
  def current_depth
    if state.surfaced
      [(SURFACE_WATERLINE - state.player_y) / 10, 0].max.to_i
    else
      # 0 m just below the surface (screen top), growing as the diver descends —
      # continuous with the surface scene and always a whole number.
      ((SCREEN_HEIGHT - state.player_y) / 10).to_i
    end
  end

  def render_oxygen_bar
    x = 20
    y = 640
    w = 220
    h = 18
    ratio = state.oxygen / OXYGEN_MAX
    low = ratio < 0.3

    outputs.labels << { x: x, y: y + h + 22, text: "Sauerstoff", r: 225, g: 238, b: 255 }
    outputs.sprites << { x: x, y: y, w: w, h: h, r: 15, g: 25, b: 45, path: :solid } # track
    outputs.sprites << {                                                             # fill
      x: x, y: y, w: w * ratio, h: h,
      r: (low ? 210 : 40), g: (low ? 70 : 170), b: (low ? 80 : 230),
      path: :solid,
    }
  end

  def game_paused?
    ["title", "game_over"].include?(state.game_scene)
  end

  def render_diver
    outputs.sprites << state.diver.to_h
    if FOG_OF_WAR && !state.surfaced # no fog at the surface — there's daylight up here
      biome = current_world.biome
      outputs.sprites << FogOfWar.new(state.diver,
                                      radius: fog_radius(biome),
                                      color: fog_color(biome)).to_a
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

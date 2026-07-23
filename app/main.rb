require "app/ux/panel.rb"

require "app/scenes/title.rb"
require "app/scenes/game_over.rb"
require "app/scenes/area1.rb"
require "app/scenes/area2.rb"

require "app/entities/dark_shark.rb"
require "app/entities/sloppy_scalar.rb"
require "app/entities/diver.rb"

require "app/world/fog_of_war.rb"

require "app/world/rng.rb"
require "app/world/noise.rb"
require "app/world/biome.rb"
require "app/world/world.rb"
require "app/world/world_generator.rb"
require "app/world/static_worlds.rb"
require "app/world/world_renderer.rb"

SCREEN_WIDTH = 1280
SCREEN_HEIGHT = 720
WATERLINE_Y = SCREEN_HEIGHT # world y of the surface: water fills world 0..WATERLINE_Y, sky above it
CAMERA_ANCHOR = SCREEN_HEIGHT / 2 # target screen y for the diver; the camera scrolls the world past him
CAMERA_ANCHOR_X = SCREEN_WIDTH / 2 # target screen x for the diver; the world scrolls sideways past him
FLOOR_VIEW_MARGIN = 90 # how far below the sea floor the camera comes to rest (the dead zone at the bottom)
CAMERA_EASE = 0.1 # how quickly the camera catches up per tick — smooths the ragged floor out of the view
SURFACE_FLOAT_DEPTH = 20 # how far below the waterline the diver's center rests (only head/shoulders show)
SURFACE_BOAT_X = 120 # world x of the diver's home boat, floating at the waterline
OXYGEN_MAX = 100
OXYGEN_DRAIN = 0.009 # per tick underwater (~3 min of air at 60 fps)
OXYGEN_REFILL = 1.0 # per tick while breathing at the surface (fast top-up)
SPRINT_MULTIPLIER = 2 # sprinting: this much faster, and this much thirstier for air
SHARK_PATROL_SPREAD = 200 # how far above/below the diver's depth the shark comes back in
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
    update_depth_and_camera
    update_oxygen unless game_paused?
    send("#{state.game_scene}_tick")
    render_diver unless game_paused?
    render_panel # HUD last so it draws on top of the scene and fog
  end

  def initialize_game(sprite_index)
    state.angle = 0
    state.diver_global_x = Diver::START_X             # world horizontal position (source of truth)
    state.depth_y = WATERLINE_Y - SURFACE_FLOAT_DEPTH # world vertical position (0 = sea floor)
    state.camera_x = Diver::START_X - CAMERA_ANCHOR_X # world x shown at the left of the screen
    state.camera_y = 0                                # world y shown at the bottom of the screen
    state.player_x = CAMERA_ANCHOR_X                  # on-screen x, derived each tick from global_x - camera_x
    state.player_y = CAMERA_ANCHOR                    # on-screen y, derived each tick from depth_y - camera_y
    state.direction = :right
    state.world_cache = {}
    state.dark_shark = { x: -300, y: 300 }
    state.game_scene = "title"
    state.oxygen = OXYGEN_MAX
    state.death_cause = nil
    state.sprinting = false
    state.speed = Diver::SPEED
    state.initialized = true

    state.diver = Diver.new(args, sprite_index)
    state.shark = DarkShark.new(args, sprite_index)
    state.fish = [] # a per-world swarm, (re)spawned when a world loads (spawn_fauna)
    center_camera   # frame the diver right away instead of gliding in on the first ticks
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
    state.dark_shark = { x: -300, y: 300 }
    state.oxygen = OXYGEN_MAX
    state.death_cause = nil
    state.sprinting = false
    state.speed = Diver::SPEED
    spawn_at_surface # sets position (player_x, diver_global_x, depth_y, camera_y)
  end

  # Every round begins floating at the surface next to the home boat, head out
  # of the water — the player catches a breath and eases in before diving.
  def spawn_at_surface
    state.depth_y = WATERLINE_Y - SURFACE_FLOAT_DEPTH # head out, body just under the waterline
    state.diver_global_x = SURFACE_BOAT_X + 96 # world x, in the water just beside the boat
    center_camera
  end

  def update_characters(sprite_index)
    state.diver.tick(args, sprite_index)
    return if game_paused?

    state.fish ||= [] # resilience against stale state (e.g. DragonRuby hot reload)
    state.fish.each { |fish| fish.tick(args, sprite_index) }

    if shark_present?
      # Collide in world space: on-screen x/y are camera-relative, so compare the
      # diver at his world position against the shark at its world position (the
      # shark's local x lives in the current chunk).
      diver_rect = state.diver.to_h.merge(x: state.diver_global_x, y: state.depth_y)
      shark_rect = state.shark.to_h.merge(x: world_index * SCREEN_WIDTH + state.dark_shark.x,
                                          y: state.dark_shark.y)
      if diver_rect.intersect_rect?(shark_rect)
        state.game_scene = "game_over"
        state.death_cause = :eaten
      end
      update_shark(sprite_index)
    end
  end

  # Shark cruises across the segment, drifting vertically, and wraps around. It
  # hunts: each pass comes back in at roughly the diver's depth, so it's a threat
  # on a shallow bank and down in a trench alike.
  def update_shark(sprite_index)
    if state.dark_shark.x > SCREEN_WIDTH
      state.dark_shark.x = -300
      state.dark_shark.y = shark_patrol_y
    else
      state.dark_shark.x += DarkShark::SPEED
    end

    if Kernel.tick_count % 30 == 0
      state.dark_shark.y = in_water(state.dark_shark.y + ((-1)**rand(10) * rand(30)))
    end

    state.shark.tick(args, sprite_index)
  end

  # A depth to prowl at: near the diver, give or take, but never out of the water
  # or inside the sand.
  def shark_patrol_y
    in_water(state.depth_y + rand(2 * SHARK_PATROL_SPREAD) - SHARK_PATROL_SPREAD)
  end

  # Keep a world y inside the local water column.
  def in_water(y)
    top = WATERLINE_Y - 40
    floor = sea_floor_y
    return floor if y < floor
    return top if y > top

    y
  end

  def basic_movements_per_tick
    if inputs.keyboard.key_down.escape
      state.game_scene = "title"
      return
    end

    # Horizontal movement is in world space (diver_global_x); the camera turns it
    # into an on-screen position later, so no wrapping at the screen edge.
    if inputs.left
      state.direction = :left
      state.diver_global_x -= state.speed
    elsif inputs.right
      state.diver_global_x += state.speed
      state.direction = :right
    end
    # no else: keep facing the last direction while idle

    # Vertical movement is in world space now (depth_y): up = shallower, down =
    # deeper. The camera turns this into an on-screen position later.
    if inputs.up
      state.depth_y += state.speed
    elsif inputs.down
      state.depth_y -= state.speed
    end

    # Negatively buoyant: the diver slowly sinks unless he's swimming up. The one
    # exception is resting at the surface with his head out of the water
    # (breathing?) — a pause mode where he floats in place. Below the waterline he
    # always sinks. (sea floor / waterline clamps in update_depth_and_camera)
    state.depth_y -= 0.15 unless inputs.up || breathing?

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

    # Only the horizontal sector matters now — being at the surface is just a
    # high depth_y, rendered continuously, not a separate scene.
    state.game_scene = state.diver.global_position_x < 1281 ? "area1" : "area2"
  end

  # Clamp the diver in the water column, then move the camera (both axes) to
  # follow him and project his world position onto the on-screen player_x/y. One
  # continuous space: no scene switch, no teleport — the camera scrolls the world.
  def update_depth_and_camera
    clamp_depth
    # Vertical: ease toward the target so swimming along the ragged floor doesn't
    # make the view judder with every notch of sand.
    state.camera_y += (camera_target_y - state.camera_y) * CAMERA_EASE
    # Horizontal: centre the diver; the world scrolls sideways past him.
    state.camera_x = state.diver_global_x - CAMERA_ANCHOR_X
    project_diver
  end

  # Put the camera exactly where it belongs, without easing — for spawning, so a
  # new round starts framed instead of gliding into place.
  def center_camera
    clamp_depth
    state.camera_y = camera_target_y
    state.camera_x = state.diver_global_x - CAMERA_ANCHOR_X
    project_diver
  end

  # The diver lives between the sand and the waterline: he can rest on the floor
  # and float up until his head clears the water, but no further.
  def clamp_depth
    ceil = WATERLINE_Y - SURFACE_FLOAT_DEPTH # float no higher than head-out at the surface
    state.depth_y = ceil if state.depth_y > ceil
    state.depth_y = sea_floor_y if state.depth_y < sea_floor_y
  end

  # Follow the diver, but never scroll past the sea floor: near the bottom the
  # camera rests just under the sand (a dead zone) so he can swim around without
  # the world sliding. Since the floor's depth varies wildly, this target is
  # relative to the ground under him, not to a fixed world y.
  def camera_target_y
    [state.depth_y - CAMERA_ANCHOR, sea_floor_y - FLOOR_VIEW_MARGIN].max
  end

  def project_diver
    state.player_y = state.depth_y - state.camera_y
    state.player_x = state.diver_global_x - state.camera_x
  end

  # World y of the sand right under the diver, so he rests on the floor instead
  # of sinking through it. A little headroom keeps his body above the sand.
  def sea_floor_y
    current_world.floor_y_at(state.diver_global_x % SCREEN_WIDTH) + Diver::HEIGHT
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

  # The head clears the water once the diver has floated up to the waterline.
  def breathing?
    state.depth_y + Diver::HEIGHT >= WATERLINE_Y
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

  # Depth below the surface in metres — a whole number from the diver's world
  # position: 0 m at the waterline, growing as he descends toward the sea floor.
  def current_depth
    [(WATERLINE_Y - state.depth_y) / 10, 0].max.to_i
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
    if FOG_OF_WAR && !breathing? # no fog at the surface — there's daylight up here
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

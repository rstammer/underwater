require "app/ux/hud.rb"

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
require "app/world/island_world.rb"
require "app/world/world_stream.rb"
require "app/world/world_renderer.rb"

SCREEN_WIDTH = 1280
SCREEN_HEIGHT = 720
WATERLINE_Y = SCREEN_HEIGHT # world y of the surface: water fills world 0..WATERLINE_Y, sky above it
PIXELS_PER_METRE = 14 # how much sea a metre of depth is worth. The suit's rating caps how deep the
                      # ordinary world may go, so a bigger metre is what gives it room to feel deep
CAMERA_ANCHOR = SCREEN_HEIGHT / 2 # target screen y for the diver; the camera scrolls the world past him
CAMERA_ANCHOR_X = SCREEN_WIDTH / 2 # target screen x for the diver; the world scrolls sideways past him
CAMERA_FLOOR_SLACK = 60 # how far the smoothed floor may sit above the real sand before the camera trusts the sand
FLOOR_VIEW_MARGIN = 240 # how far below the sea floor the camera rests — the diver sits this high above the bottom edge
CAMERA_EASE = 0.1 # how quickly the camera catches up per tick — smooths the ragged floor out of the view
SURFACE_FLOAT_DEPTH = 20 # how far below the waterline the diver's center rests (only head/shoulders show)
SURFACE_BOAT_X = 120 # world x of the diver's home boat, floating at the waterline
OXYGEN_MAX = 100
OXYGEN_DRAIN = 0.009 # per tick underwater (~3 min of air at 60 fps)
OXYGEN_REFILL = 1.0 # per tick while breathing at the surface (fast top-up)
SUIT_MAX = 100
SUIT_DEPTH_LIMIT = 100 # metres this suit is rated for; below that the pressure works on it
SUIT_DRAIN = 0.0025 # damage per tick, per metre past the rated depth
SUIT_REPAIR = 0.4 # per tick while patching it up at the boat
BOAT_REACH = 160 # how close to the boat counts as being back home
SPRINT_MULTIPLIER = 2 # sprinting: this much faster, and this much thirstier for air
SHARK_PATROL_SPREAD = 200 # how far above/below the diver's depth the shark comes back in
DIVER_FOOTPRINT = 20 # how far to each side the diver's footing feels for sand to rest on
SOLID_STEP_UP = 48 # ledge he still slips over sideways; anything higher is a wall
ISLAND_MIN_SECTOR = 2 # no island lands on the home sector ...
ISLAND_MAX_SECTOR = 10 # ... nor further out than this
ISLAND_NEAR_SECTOR = 3 # ... except the first one, which always lands this close
ISLAND_COUNT = 3 # how many of them are out there in a round
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
    unless game_paused?
      update_oxygen
      update_suit
    end
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
    state.island_sectors = roll_island_sectors
    state.dark_shark = { x: -300, y: 300 }
    state.game_scene = "title"
    state.oxygen = OXYGEN_MAX
    state.suit = SUIT_MAX
    state.death_cause = nil
    state.sprinting = false
    state.speed = Diver::SPEED
    state.initialized = true

    state.diver = Diver.new(args, sprite_index)
    state.shark = DarkShark.new(args, sprite_index)
    state.fish = [] # a per-world swarm, (re)spawned when a world loads (spawn_fauna)
    center_camera   # frame the diver right away instead of gliding in on the first ticks
  end

  # Where the islands lie this round: distinct sectors to either side of home.
  # The first one lands close enough that you run into it swimming out in either
  # direction — otherwise a round can go by without ever finding one. The rest
  # are scattered further out, for exploring.
  def roll_island_sectors
    sectors = [roll_island_sector(1, ISLAND_NEAR_SECTOR)]
    sectors << roll_island_sector until sectors.uniq.length == ISLAND_COUNT
    sectors.uniq
  end

  def roll_island_sector(nearest = ISLAND_MIN_SECTOR, furthest = ISLAND_MAX_SECTOR)
    sector = nearest + rand(furthest - nearest + 1)
    rand(2).zero? ? -sector : sector
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
    state.world_cache = {}
    state.island_sectors = roll_island_sectors # a new round hides them somewhere else
    state.dark_shark = { x: -300, y: 300 }
    state.oxygen = OXYGEN_MAX
    state.suit = SUIT_MAX
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

  # Shark cruises across the segment, drifting vertically, and wraps around at the
  # far side. It hunts: each pass comes back in at roughly the diver's depth, so
  # it's a threat on a shallow bank and down in a trench alike. Rock stops it as
  # surely as it stops the diver — at the island it turns and patrols back.
  def update_shark(sprite_index)
    shark = state.dark_shark
    shark.dir = 1 if shark.dir.nil?

    if shark.x > SCREEN_WIDTH || shark.x < -300
      shark.x = shark.dir > 0 ? -300 : SCREEN_WIDTH
      shark.y = shark_patrol_y
    elsif shark_blocked?(shark)
      shark.dir = -shark.dir
    else
      shark.x += DarkShark::SPEED * shark.dir
    end

    if Kernel.tick_count % 30 == 0
      candidate = in_water(shark.y + ((-1)**rand(10) * rand(30)), shark_nose_x(shark))
      # Don't let the vertical drift settle the shark inside a slab — a skerry off
      # the shore is rock the drift could otherwise wander into. Check both ends.
      nose = shark_nose_x(shark)
      tail = nose - shark.dir * DarkShark::WIDTH * DarkShark::SCALE_FACTOR
      shark.y = candidate unless shark_span_solid?(nose, candidate) || shark_span_solid?(tail, candidate)
    end

    state.shark.tick(args, sprite_index)
  end

  # World x of the end of the shark it swims with — where it would hit rock.
  def shark_nose_x(shark)
    nose = shark.dir > 0 ? DarkShark::WIDTH * DarkShark::SCALE_FACTOR : 0
    world_index * SCREEN_WIDTH + shark.x + nose
  end

  def shark_blocked?(shark)
    shark_span_solid?(shark_nose_x(shark) + shark.dir * DarkShark::SPEED, shark.y)
  end

  # The shark is as tall as its body, so check rock across its whole height, not
  # just one point — it must turn before any part of it slides into a slab
  # (free-standing skerries are thin enough that a single sample can miss them).
  def shark_span_solid?(world_x, y)
    solid_at?(world_x, y - DarkShark::HEIGHT) ||
      solid_at?(world_x, y) ||
      solid_at?(world_x, y + DarkShark::HEIGHT)
  end

  # A depth to prowl at: near the diver, give or take, but never out of the water
  # or inside the sand.
  def shark_patrol_y
    in_water(state.depth_y + rand(2 * SHARK_PATROL_SPREAD) - SHARK_PATROL_SPREAD,
             shark_nose_x(state.dark_shark))
  end

  # Keep a world y inside the water column at a world x.
  def in_water(y, world_x)
    top = WATERLINE_Y - 40
    floor = floor_y_at(world_x) + DarkShark::HEIGHT
    return floor if y < floor
    return top if y > top

    y
  end

  # Is there rock at this point of the world?
  def solid_at?(world_x, y)
    world_at(world_x.idiv(SCREEN_WIDTH)).solid_at?(world_x % SCREEN_WIDTH, y)
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
      swim_sideways(-state.speed)
    elsif inputs.right
      swim_sideways(state.speed)
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

  # The diver lives between the rock below him and whatever is above: the
  # waterline in open water, or the underside of a cave roof. The floor gives
  # way to the ceiling where they conflict, so a wall of rock leaves him
  # floating beside it rather than flying over it.
  def clamp_depth
    floor, ceiling = rock_span_at(state.diver_global_x, state.depth_y)
    bottom = floor + Diver::HEIGHT
    top = depth_ceiling(ceiling, state.diver_global_x)

    state.depth_y = bottom if state.depth_y < bottom
    state.depth_y = top if state.depth_y > top
  end

  # As high as he can rise here. He floats at whatever water surface is above
  # him — the sea's, or the one inside an air chamber — and otherwise stops at
  # the rock of a cave roof. Whichever is lowest wins.
  def depth_ceiling(ceiling, world_x)
    limits = [WATERLINE_Y - SURFACE_FLOAT_DEPTH] # only head and shoulders show
    limits << ceiling - Diver::HEIGHT if ceiling
    air = air_line_at(world_x)
    limits << air - SURFACE_FLOAT_DEPTH if air
    limits.min
  end

  def air_line_at(world_x)
    world_at(world_x.idiv(SCREEN_WIDTH)).air_line_at(world_x % SCREEN_WIDTH)
  end

  # Follow the diver, but never scroll past the sea floor: near the bottom the
  # camera rests just under the sand (a dead zone) so he can swim around without
  # the world sliding. Since the floor's depth varies wildly, this target is
  # relative to the ground under him, not to a fixed world y.
  def camera_target_y
    [state.depth_y - CAMERA_ANCHOR, camera_floor_y - FLOOR_VIEW_MARGIN].max
  end

  # The ground the *camera* rides: the sea floor as a smooth curve, without the
  # terraces and notches the diver actually swims over. Reading the raw sand here
  # made the view lurch; reading only the broad shape left him pinned to the
  # bottom edge wherever the two disagreed — over a rocky rise, or down a chasm.
  def camera_floor_y
    x = state.diver_global_x
    smooth = WorldGenerator.smooth_floor_y_at(x)
    # Down a chasm wall the smoothed curve can sit hundreds of px above the sand
    # he is actually standing on, which would leave him under the bottom edge of
    # the screen. Where they disagree that badly, believe the sand. (The two meet
    # exactly at the slack, so switching between them never jumps.)
    [smooth, floor_top_at(x) + CAMERA_FLOOR_SLACK].min + Diver::HEIGHT
  end

  def project_diver
    state.player_y = state.depth_y - state.camera_y
    state.player_x = state.diver_global_x - state.camera_x
  end

  # Rock is solid: he only moves sideways into water he actually fits into. Small
  # ledges he slips over — the depth clamp lifts him onto them the same tick.
  def swim_sideways(step)
    target = state.diver_global_x + step
    state.diver_global_x = target unless blocked?(target)
  end

  # Would the diver end up inside rock at this world x? Sand too high to slip
  # over, a cave roof in his face, or a gap he simply doesn't fit through.
  def blocked?(world_x)
    feet = state.depth_y - Diver::HEIGHT
    head = state.depth_y + Diver::HEIGHT
    floor, ceiling = rock_span_at(world_x, state.depth_y)
    return true if floor > feet + SOLID_STEP_UP
    return false unless ceiling
    return true if ceiling < head - SOLID_STEP_UP

    ceiling - floor < Diver::HEIGHT * 2
  end

  # World y the diver's centre comes to rest at on the sand below him.
  def sea_floor_y
    floor_top_at(state.diver_global_x) + Diver::HEIGHT
  end

  # The highest sand across the diver's whole footprint at a world x, so he
  # glides over the ragged notches instead of dropping into every one of them.
  def floor_top_at(world_x)
    footprint(world_x).map { |x| floor_y_at(x) }.max
  end

  # The rock slab hanging over the diver's footprint at a world x: its lowest
  # underside and its highest top, or nil where the water is open all the way up.
  def roof_span_at(world_x)
    rocks = footprint(world_x).map { |x| roof_at(x) }.compact
    return nil if rocks.empty?

    { ceiling: rocks.map { |rock| rock[:ceiling] }.min,
      crown: rocks.map { |rock| rock[:crown] }.max }
  end

  # What bounds the water at a world x for a diver currently at `depth`:
  # [rock below, rock above (or nil for open water)]. Usually that is the sand
  # and a cave roof — but where he is swimming *over* a submerged slab, its top
  # is the floor and the sky is open.
  def rock_span_at(world_x, depth)
    sand = floor_top_at(world_x)
    rock = roof_span_at(world_x)
    return [sand, nil] unless rock
    return [[sand, rock[:crown]].max, nil] if over_slab?(rock, depth)

    [sand, rock[:ceiling]]
  end

  # He is over a slab only if he is above it *and* there is enough water left
  # above it to fit him — a hand's breadth of rock under the surface is a wall,
  # not a ledge to swim over.
  def over_slab?(rock, depth)
    depth - Diver::HEIGHT >= rock[:crown] &&
      rock[:crown] + Diver::HEIGHT * 2 <= WATERLINE_Y
  end

  def footprint(world_x)
    [world_x - DIVER_FOOTPRINT, world_x, world_x + DIVER_FOOTPRINT]
  end

  # Sand / rock at any world x, looked up in the segment it belongs to — so a
  # footprint reaching across a segment border reads the right world.
  def floor_y_at(world_x)
    world_at(world_x.idiv(SCREEN_WIDTH)).floor_y_at(world_x % SCREEN_WIDTH)
  end

  def roof_at(world_x)
    world_at(world_x.idiv(SCREEN_WIDTH)).roof_at(world_x % SCREEN_WIDTH)
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

  # The suit is rated for a depth. Below it the pressure works on the seams, the
  # harder the deeper you are — so the deep is a gradient to feel out, not a wall.
  # A failed suit ends the dive. Back at the boat you can patch it up again.
  def update_suit
    return repair_suit if at_the_boat?
    return unless too_deep?

    state.suit -= SUIT_DRAIN * (current_depth - SUIT_DEPTH_LIMIT)
    return if state.suit > 0

    state.suit = 0
    state.game_scene = "game_over"
    state.death_cause = :crushed
  end

  def repair_suit
    state.suit = [state.suit + SUIT_REPAIR, SUIT_MAX].min
  end

  def too_deep?
    current_depth > SUIT_DEPTH_LIMIT
  end

  # Back at the boat, up in the air beside it — the one place with tools aboard.
  def at_the_boat?
    at_open_surface? && (state.diver_global_x - SURFACE_BOAT_X).abs <= BOAT_REACH
  end

  # He breathes wherever his head is out of the water: up at the sea's surface,
  # or in air trapped under rock inside a cave.
  def breathing?
    head = state.depth_y + Diver::HEIGHT
    return true if head >= WATERLINE_Y

    air_at?(state.diver_global_x, head)
  end

  # Actually up in the daylight, as opposed to breathing in a cave. Fog and the
  # "only water up here" rules hang off this one, not off breathing?.
  def at_open_surface?
    state.depth_y + Diver::HEIGHT >= WATERLINE_Y
  end

  def air_at?(world_x, y)
    world_at(world_x.idiv(SCREEN_WIDTH)).air_at?(world_x % SCREEN_WIDTH, y)
  end

  def game_paused?
    ["title", "game_over"].include?(state.game_scene)
  end

  def render_diver
    outputs.sprites << state.diver.to_h
    if FOG_OF_WAR && !at_open_surface? # no fog at the surface — there's daylight up here
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

require "app/ux/hud.rb"
require "app/ux/controls.rb"

require "app/ux/story.rb"

require "app/scenes/title.rb"
require "app/scenes/name.rb"
require "app/scenes/intro.rb"
require "app/scenes/recap.rb"
require "app/scenes/night.rb"
require "app/scenes/darkroom.rb"
require "app/scenes/assignment_view.rb"
require "app/scenes/shop.rb"
require "app/scenes/game_over.rb"
require "app/scenes/area1.rb"
require "app/scenes/area2.rb"
require "app/scenes/home_menu.rb"
require "app/scenes/pause.rb"

require "app/entities/dark_shark.rb"
require "app/entities/creature.rb"
require "app/entities/crustacean.rb"
require "app/entities/jelly.rb"
require "app/entities/coral.rb"
require "app/entities/beachgoer.rb"
require "app/entities/diver.rb"

require "app/world/fog_of_war.rb"

require "app/world/rng.rb"
require "app/world/noise.rb"
require "app/world/biome.rb"
require "app/world/species.rb"
require "app/world/world.rb"
require "app/world/world_generator.rb"
require "app/world/wreck_world.rb"
require "app/world/static_worlds.rb"
require "app/world/island_world.rb"
require "app/world/world_stream.rb"
require "app/world/world_renderer.rb"
require "app/world/backdrop.rb"
require "app/world/items.rb"
require "app/world/photography.rb"
require "app/world/framing.rb"
require "app/world/islander.rb"
require "app/world/beach.rb"
require "app/world/camp.rb"
require "app/world/kraken.rb"
require "app/world/whale.rb"
require "app/world/sting.rb"
require "app/world/gear.rb"
require "app/world/assignment.rb"
require "app/world/sailing.rb"
require "app/world/save_file.rb"
require "app/world/save_slots.rb"

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
SURFACE_BOAT_X = 120 # world x the boat is first moored at. Only the *starting*
                     # place now: where it actually is lives in state.boat_x,
                     # because the boat can be sailed somewhere else and left
                     # there. Anything asking "where is home" must read the
                     # state — reading this constant keeps working perfectly
                     # until the day somebody moves the boat, which is the worst
                     # way for a thing to be wrong
OXYGEN_MAX = 100
# Per tick under water. The starting bottle is deliberately short — about a
# minute and a half — so the swim home is something you are counting from the
# very first dive, and so a bigger bottle is worth buying (see app/world/gear.rb).
OXYGEN_DRAIN = 0.0185
OXYGEN_REFILL = 1.0 # per tick while breathing at the surface (fast top-up)
SUIT_MAX = 100
SUIT_DEPTH_LIMIT = 100 # metres this suit is rated for; below that the pressure works on it
SUIT_DRAIN = 0.0025 # damage per tick, per metre past the rated depth
SUIT_REPAIR = 0.4 # per tick while patching it up at the boat
BOAT_REACH = 160 # how close to the boat counts as being back home
SPRINT_MULTIPLIER = 2 # sprinting: this much faster, and this much thirstier for air
ENERGY_MAX = 100
# A day is a quarter of an hour: 15 min x 60 s x 60 ticks. Energy *is* the day —
# the clock and the calendar are both read off this one number, so nothing can
# drift out of step with anything else.
ENERGY_DRAIN = ENERGY_MAX / (15.0 * 60 * 60)
TIRED_SPEED = 0.55    # what is left of him once the day is gone
SHARK_PATROL_SPREAD = 200 # how far above/below the diver's depth the shark comes back in
DIVER_FOOTPRINT = 20 # how far to each side the diver's footing feels for sand to rest on
SOLID_STEP_UP = 48 # ledge he still slips over sideways; anything higher is a wall
LAND_SPEED = 1.3   # walking in flippers. Faster than swimming rather than slower:
                   # an island is a place you cross to get somewhere, and at 0.9 the
                   # walk was the slowest thing in a game whose islands are wide
LAND_GRAVITY = 0.6 # px per tick² he gathers stepping off a terrace ...
LAND_FALL_MAX = 14 # ... and the fastest he ever falls
JUMP_SPEED = 6.0   # the push of a hop. Against LAND_GRAVITY that peaks about 33 px
                   # up — half his own height, which is what "a small hop" means.
                   # IslandWorld::CLIFF_MIN is set against stride + this, so raising
                   # it is raising how high a wall has to be to still be a wall
ISLAND_MIN_SECTOR = 2 # no island lands on the home sector ...
ISLAND_MAX_SECTOR = 10 # ... nor further out than this
ISLAND_NEAR_SECTOR = 3 # ... except the first one, which always lands this close
# How wide the chart is on the first morning, each way. Not nothing: the island
# next door sits at IslandWorld::HOME_SECTOR = -2 and exists precisely so that a
# round never opens with a hunt for somewhere to come ashore, and a chart
# starting at zero put it out of the boat's reach for ever. Three each way takes
# in that island and the Späti at +3, and leaves the beach at -5 to be found.
CHART_START = 3
ISLAND_COUNT = 4 # how many of them are out there in a round — three of them are
                 # fixed (home, the shop, the beach), so this is the last one
                 # that is actually rolled and worth finding
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
    update_controls # touch: read the on-screen joystick and buttons into intents
    update_shop      # L at the island shop opens Andi's, and closes it again
    update_shop_input # ... and inside it the arrows and E work the shelf
    update_home_menu # L at the boat opens the boat screen and closes it again
    update_exchange  # and while it's open, the arrows and E sort pack against hold
    update_boat_page # ... and Tab turns to the Artenbuch and back
    update_artenbuch_paging # ... and the arrows turn its pages
    update_escape    # ESC: out of the boat screen, or out of the dive to the title
    quit_game if at_the_boat? && inputs.keyboard.key_down.q # Q at the boat quits
    update_sleep # S at the boat ends the day
    update_assignment_key # T at the boat reads out the day's job
    update_assignment_view
    update_sprint
    update_characters(sprite_index)
    unless game_paused?
      update_sailing # E at the boat casts off; under way the arrows steer it
      basic_movements_per_tick
      update_depth_and_camera
      update_talking # E beside somebody on the beach gets a line out of them
      update_pickup # E near an item picks it up (if the pack has room)
      update_camera # F: the shutter down here, the darkroom up at the boat
      update_boat_stash # I at the boat empties the pack into the hold
      update_sting  # a bell against your arm costs air, not blood
      update_oxygen
      update_suit
      update_energy
      update_dive_hint # ... and the camera's rules come up, once the water closes
      update_kraken # deep down, the legend hangs at the edge of the dark
      update_whale  # ... and out in the blue, something very large goes past
      update_sightings # note which species you've now laid eyes on
      track_log # quietly record how deep you got and what you've seen
    end
    send("#{state.game_scene}_tick")
    render_diver unless game_paused? || state.aboard
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
    state.beach_band = nil # measured off stamped segments; it cannot outlive them
    state.active_world_index = nil # nothing loaded yet: the first tick builds and stocks it
    state.world_seed = new_world_seed # replaced by the book's own, if one is carried on
    state.island_sectors = roll_island_sectors
    state.dark_shark = { x: -300, y: 300 }
    state.game_scene = "title"
    state.oxygen = air_capacity
    state.suit = SUIT_MAX
    state.energy = ENERGY_MAX # the day ahead of him
    state.day = 1
    reset_day_tally
    state.death_cause = nil
    state.sprinting = false
    state.speed = Diver::SPEED
    state.player_name = ""  # typed in on the way past the title
    state.dive_hint_pending = false # ... and so are the camera's rules, on the first dive
    state.dive_hint_at = nil
    state.touch_seen = false        # on-screen controls appear once a finger touches
    state.touch_intents = {}
    state.touch_tapped = []
    state.touch_pressed = []
    state.touch_ids = []
    state.touch_began = false
    state.swim_pose = false
    state.on_land = false  # set every tick from the rock under him (clamp_depth)
    state.fall = 0         # how fast he is dropping, when he is dropping ...
    state.airborne = false # ... and whether his feet are off the ground at all
    state.initialized = true

    # Where the boat lies. Set here rather than in reset_game, and so outliving
    # a drowning: dying costs you the round, not the voyage that got you there.
    state.boat_x = SURFACE_BOAT_X
    state.aboard = false
    # How far he has swum, each way — what the boat's range is measured against.
    state.charted_west = -CHART_START
    state.charted_east = CHART_START
    # The balance. Like the book, it is the work of many dives and dying can't
    # take it — only the undeveloped film goes down with you.
    state.credits = 0
    state.sale_note = nil
    # What the logbook remembers past this one dive. Carried in the save file
    # with everything else, because a career you cannot look back on is a tally.
    state.log_dives = 0
    state.log_best = 0    # deepest he has ever been
    state.log_sold = 0    # finds sold from the boat
    state.log_earned = 0  # every credit ever taken in, spent or not
    state.album = {} # species documented for good — the one thing dying can't take
    state.sighted = {} # species laid eyes on — the Artenbuch only lists what you've seen
    state.flocks = {}  # ... and the biggest school of each you have brought home
    # What is on disk from last time. Loaded, not applied: the title asks first,
    # because carrying a book on is a choice and so is putting it down.
    state.book_slot = nil # no book is open until one is chosen at the title
    load_slots            # ... and what is on the shelf is read once, here
    state.kraken = nil # the legend only shows up when you go too deep
    state.whale = nil  # ... and nothing is crossing the blue yet
    state.diver = Diver.new(args, sprite_index)
    state.shark = DarkShark.new(args, sprite_index)
    state.fish = []       # a per-world swarm, (re)spawned when a world loads (spawn_fauna)
    state.crawlers = []   # ... what walks about on that segment's sea floor
    state.shore_life = [] # ... and what walks about on its beach, if it has one
    state.jellies = []    # ... and what drifts in it, where a field has settled
    state.stung_at = nil  # ... and nothing has stung him yet
    state.stash = [] # the boat's hold; survives dying, not a new career
    reset_gear      # nothing bought yet — the ladders all start at the bottom
    state.shop_met = 0
    state.kraken_met = 0 # the legend is hearsay until he has been down to it
    reset_log       # the dive log starts empty each round
    reset_items     # scatter fresh treasures, empty the pack
    reset_film      # a fresh roll, nothing exposed
    reset_framing   # ... and the viewfinder shut
    state.developed_roll = [] # ... and nothing pinned up in the darkroom
    center_camera   # frame the diver right away instead of gliding in on the first ticks
  end

  # Where the islands lie this round. One of them is always the island next door
  # (IslandWorld::HOME_SECTOR) — the same one every round, always walkable, a
  # screen's swim to the left — so a round never opens with a hunt for somewhere
  # to come ashore. The rest are rolled and scattered, for exploring.
  def roll_island_sectors
    rng = world_rng(1)
    sectors = [IslandWorld::HOME_SECTOR, IslandWorld::SHOP_SECTOR,
               IslandWorld::BEACH_SECTOR]
    sectors << roll_island_sector(rng) until sectors.uniq.length == ISLAND_COUNT
    sectors.uniq
  end

  def roll_island_sector(rng, nearest = ISLAND_MIN_SECTOR, furthest = ISLAND_MAX_SECTOR)
    sector = nearest + rng.int(furthest - nearest + 1)
    rng.int(2).zero? ? -sector : sector
  end

  # The number that makes a stretch of sea *yours*. The terrain never needed one
  # — it is a pure function of the world position, so the sand is the same shape
  # for everybody — but where the islands lie and where the treasures are buried
  # were rolled fresh every round, so the sea rearranged itself behind your back
  # every time you drowned. Salted per use, so the islands and the items are not
  # two readings of the same sequence.
  def world_rng(salt)
    Rng.new((state.world_seed || 1) * 7919 + salt)
  end

  # A sea nobody has had before. tick_count is in there because it is the moment
  # the player chose to start, which is the one thing that genuinely differs
  # between two runs of the same binary.
  def new_world_seed
    1 + Kernel.tick_count.abs + rand(1_000_000_000)
  end

  # The universal yes: space, enter, a gamepad's A. Enter is in here because a
  # menu you pick a row in is a menu you expect to confirm with it — and every
  # screen that asks "press on" means the same thing by it.
  #
  # It is deliberately *not* what deletes a save. A question that destroys
  # something answers only to the key that asked it.
  def fire_input?
    inputs.keyboard.key_down.enter ||
      inputs.keyboard.key_down.space ||
      inputs.keyboard.key_down.z ||
      inputs.keyboard.key_down.j ||
      inputs.controller_one.key_down.a
  end

  def reset_game
    state.angle = 0
    state.direction = :right
    state.world_cache = {}
    state.beach_band = nil # measured off stamped segments; it cannot outlive them
    # The far ranges are read off the islands, so they cannot outlive them
    # either — and they did: a new round opened with the previous round's hills
    # standing behind this round's coast. Both the silhouettes and the crown
    # heights kept off them go here.
    state.backdrop_isles = {}
    state.backdrop_lifts = {}
    # Forget which world is loaded, too: the cache alone isn't enough, and the
    # round would otherwise start out on the *previous* round's segment — old
    # island layout, old fish — until the diver happened to cross a border.
    state.active_world_index = nil
    state.island_sectors = roll_island_sectors # a new round hides them somewhere else
    state.dark_shark = { x: -300, y: 300 }
    state.oxygen = air_capacity
    state.suit = SUIT_MAX
    state.death_cause = nil
    state.sprinting = false
    state.speed = Diver::SPEED
    state.kraken = nil # a new round, the legend waits in the deep again
    state.whale = nil  # ... and the blue is empty again too
    reset_log        # a new round, a fresh log
    reset_items      # ... and a fresh scatter of treasures
    reset_film       # ... and a fresh film: whatever was on the old roll is lost
    spawn_at_surface # sets position (player_x, diver_global_x, depth_y, camera_y)
  end

  # Every round begins floating at the surface next to the home boat, head out
  # of the water — the player catches a breath and eases in before diving.
  #
  # Beside *the boat*, not beside where the boat first was: once it can be
  # sailed, waking up at the old mooring would undo the voyage every morning.
  def spawn_at_surface
    state.depth_y = WATERLINE_Y - SURFACE_FLOAT_DEPTH # head out, body just under the waterline
    state.diver_global_x = boat_x + 96 # world x, in the water just beside the boat
    center_camera
  end

  # Where home is. The single place that answers it, so nothing has to remember
  # to read the state rather than the constant. Falls back to the first mooring,
  # which is also what an old save without the line means.
  def boat_x
    state.boat_x ||= SURFACE_BOAT_X
  end

  # Which segment the boat is moored in — what the renderer asks to know whether
  # home is on screen.
  def boat_sector
    boat_x.idiv(SCREEN_WIDTH)
  end

  def update_characters(sprite_index)
    state.diver.tick(args, sprite_index)
    return if game_paused?

    state.fish ||= []     # resilience against stale state (e.g. DragonRuby hot reload)
    state.crawlers ||= []
    state.shore_life ||= []
    state.jellies ||= []
    state.corals ||= []
    update_shyness # before they tick, so a frightened one leaves this very frame
    creatures.each { |creature| creature.tick(args, sprite_index) }

    if shark_present?
      # Collide in world space: on-screen x/y are camera-relative, so compare the
      # diver at his world position against the shark at its world position (the
      # shark's local x lives in the current chunk).
      #
      # Each asks for its *body*, not its sprite square. Colliding the squares —
      # which is what this used to do — meant a third of the shark's frame and
      # most of the width of the diver's were empty water that still counted, and
      # it ate you across a visible gap.
      diver_rect = state.diver.hitbox(state.diver_global_x, state.depth_y)
      shark_rect = state.shark.hitbox(world_index * SCREEN_WIDTH + state.dark_shark.x,
                                      state.dark_shark.y)
      if diver_rect.intersect_rect?(shark_rect)
        state.game_scene = "game_over"
        state.death_cause = :eaten
      end
      update_shark(sprite_index)
    end
  end

  # Most things down here won't be swum up to. Come at one and it leaves; the
  # only way to get near enough for a perfect frame is to stop and let it come
  # back to you — which is the whole of the photography now being a matter of
  # patience rather than of swimming fast.
  #
  # It is *moving* that frightens them, not being there: holding still is what
  # settles them. And it is a property of the species (Species#shy), because the
  # shark hunts you and a crab already scuttles.
  CURIOUS_REACH = 3 # how far out a settled one will come to look, in shy-lengths

  def update_shyness
    offset = world_index * SCREEN_WIDTH
    local_x = state.diver_global_x - offset
    creatures.each do |creature|
      shy = creature.species.shy
      next if shy.zero?

      distance = photo_distance(offset + creature.x, creature.y)
      if moving?
        creature.bolt_from(local_x) if distance <= shy
      elsif distance <= shy * CURIOUS_REACH
        creature.drawn_to(local_x)
      end
    end
  end

  # Shark cruises across the segment, drifting vertically, and wraps around at the
  # far side. It hunts: each pass comes back in at roughly the diver's depth, so
  # it's a threat on a shallow bank and down in a trench alike. Rock stops it as
  # surely as it stops the diver — at the island it turns and patrols back.
  def update_shark(sprite_index)
    shark = state.dark_shark
    shark.dir = 1 if shark.dir.nil?

    if shark_off_segment?(shark) || shark_stuck?(shark)
      shark_come_round_again(shark)
    elsif shark_blocked?(shark)
      shark.dir = -shark.dir
      shark.turns = shark.turns.to_i + 1
    else
      shark.x += DarkShark::SPEED * shark.dir
      shark.turns = 0
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

  def shark_off_segment?(shark)
    shark.x > SCREEN_WIDTH || shark.x < -300
  end

  # Where the animal actually is, from belly to back.
  #
  # Its position is the bottom-left corner of its *sprite square*, and the fish
  # is drawn HITBOX_Y up from there — so probing y, y - HEIGHT and y + HEIGHT
  # (which is what this did) put two of the three samples below the animal and
  # never touched its back. A ceiling forty pixels over its belly was invisible,
  # which is half of how it ended up inside an island.
  def shark_body_ys(y)
    belly = y + DarkShark::HITBOX_Y
    back = belly + DarkShark::HITBOX_H
    [belly, (belly + back).idiv(2), back]
  end

  # Rock anywhere across its body, not just at one point — a free-standing
  # skerry is thin enough for a single sample to miss.
  def shark_span_solid?(world_x, y)
    shark_body_ys(y).any? { |body_y| solid_at?(world_x, body_y) }
  end

  # Does the animal fit here — both ends of it, because it is longer than most
  # of the gaps it can get itself into?
  #
  # One predicate, asked by everything: where it may come in, and whether it is
  # stuck. They were two different questions once — the way in checked only the
  # nose, being stuck checked nose and tail — so it would place itself somewhere
  # it immediately judged unfit, and hop between the same two spots for ever.
  def shark_fits?(nose, dir, y)
    tail = nose - dir * DarkShark::WIDTH * DarkShark::SCALE_FACTOR
    !shark_span_solid?(nose, y) && !shark_span_solid?(tail, y)
  end

  def shark_in_rock?(shark)
    !shark_fits?(shark_nose_x(shark), shark.dir, shark.y)
  end

  # Two ways to be lost: standing in rock, or turning round on the spot for so
  # long that it is plainly not getting anywhere. Both used to be permanent — in
  # rock, shark_blocked? reversed it every single tick, so it shivered in the
  # wall for the rest of the round. A shark you can watch not moving is worse
  # than no shark.
  SHARK_STUCK_TURNS = 20

  def shark_stuck?(shark)
    shark.turns.to_i >= SHARK_STUCK_TURNS || shark_in_rock?(shark)
  end

  # Out of sight and round for another pass — but only where there is a way in.
  #
  # The entry point was never looked at, only the depth: it came in at the edge
  # of the diver's own segment, which is a *neighbouring* segment in world terms
  # and can be solid island from the sand to well above the waterline (measured:
  # a slab from -1801 to 784 across the whole column). Straight into the rock,
  # every pass, and then the shivering.
  #
  # So both approaches are sounded out, and if neither has room it waits outside
  # instead of forcing its way in. Waiting is off-segment, so this runs again
  # next tick, and by then the diver has moved and the way in is elsewhere. A
  # shark that cannot reach you should be absent, not embedded.
  def shark_come_round_again(shark)
    [shark.dir, -shark.dir].each do |dir|
      x = dir > 0 ? -300 : SCREEN_WIDTH
      y = shark_patrol_y(shark_entry_nose_x(x, dir), dir)
      next unless y

      shark.dir = dir
      shark.x = x
      shark.y = y
      shark.turns = 0
      return
    end

    shark.x = shark.dir > 0 ? -301 : SCREEN_WIDTH + 1
    shark.turns = 0
  end

  # Where the leading end would be if it came in at this edge, in world x.
  def shark_entry_nose_x(x, dir)
    nose = dir > 0 ? DarkShark::WIDTH * DarkShark::SCALE_FACTOR : 0
    world_index * SCREEN_WIDTH + x + nose
  end

  SHARK_PATROL_TRIES = 12 # depths it will sound out before giving up on a way in

  # A depth to prowl at: near the diver, give or take — and one the animal
  # actually fits in. `nil` means this stretch of water is walled off, which is
  # a thing the caller has to be able to hear; it used to clamp against the sand
  # and the waterline only, which are the two things an island is not.
  def shark_patrol_y(nose = shark_nose_x(state.dark_shark), dir = state.dark_shark.dir)
    SHARK_PATROL_TRIES.times do
      y = in_water(state.depth_y + rand(2 * SHARK_PATROL_SPREAD) - SHARK_PATROL_SPREAD, nose)
      return y if shark_fits?(nose, dir, y)
    end
    nil
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
    # Under way the arrows are the tiller, and Game#sail has already used them.
    # Without this they steer the boat *and* swim the man standing in it, and he
    # slides off the stern at twice the speed she is making.
    return if state.aboard

    # Movement reads will_* (keyboard OR the touch joystick), so the two paths
    # are one from here down.
    # Horizontal movement is in world space (diver_global_x); the camera turns it
    # into an on-screen position later, so no wrapping at the screen edge.
    if will_left?
      state.direction = :left
      swim_sideways(-state.speed)
    elsif will_right?
      swim_sideways(state.speed)
      state.direction = :right
    end
    # no else: keep facing the last direction while idle

    # Vertical movement is in world space now (depth_y): up = shallower, down =
    # deeper. The camera turns this into an on-screen position later.
    #
    # None of it on land: there is no swimming up a mountain, and what brings him
    # down there is gravity rather than buoyancy (see clamp_depth). To get off an
    # island you walk back down the beach the way you came up it.
    if on_land?
      update_jump
    else
      if will_up?
        state.depth_y += state.speed
      elsif will_down?
        state.depth_y -= state.speed
      end

      # Negatively buoyant: the diver slowly sinks unless he's swimming up. The one
      # exception is resting at the surface with his head out of the water
      # (breathing?) — a pause mode where he floats in place. Below the waterline he
      # always sinks. (sea floor / waterline clamps in update_depth_and_camera)
      state.depth_y -= 0.15 unless will_up? || breathing?
    end

    return state.angle = 0 if on_land? # the lean is a swimmer's; on sand it tips him over

    if state.direction == :right
      if will_up? && (will_left? || will_right?)
        state.angle += 0.5
      elsif will_down? && (will_left? || will_right?)
        state.angle -= 0.5
      else
        state.angle = 0
      end
    else
      if will_up? && (will_left? || will_right?)
        state.angle -= 0.5
      elsif will_down? && (will_left? || will_right?)
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
  #
  # It reads the pocket with his full stride (SOLID_STEP_UP), the same as the
  # sideways move: once he has stepped onto a terrace, the clamp has to lift him
  # onto it. Reading it without the stride would decide he was standing *under*
  # the slab he just climbed and drop him through the island.
  def clamp_depth
    # In the boat the rock underneath is not his problem — she passes astern of
    # the island, and he is standing on a deck. Left to run, this found the
    # island's rock under him, decided he was climbing it, and took the camera
    # with him: sailing past a beach dropped the whole view underwater.
    return if state.aboard

    floor, ceiling = rock_span_at(state.diver_global_x, state.depth_y, SOLID_STEP_UP)
    bottom = floor + Diver::HEIGHT
    top = depth_ceiling(ceiling, state.diver_global_x, floor)
    # Whether he is *coming off rock*, read before the new ground overwrites it.
    # This is the whole difference between a fall and the surface clamp, and it
    # is a fact about where he was, not about where he is going to land.
    dropping = on_land? || state.airborne
    # Everything that behaves differently up on an island hangs off this: the
    # rock under him holds him higher than he would ever float.
    state.on_land = bottom > WATERLINE_Y - SURFACE_FLOAT_DEPTH

    if state.depth_y < bottom
      state.depth_y = bottom
      state.fall = 0
      state.airborne = false
    elsif state.depth_y > top
      # Above where he belongs. Off rock — one terrace to the next, or a cliff
      # over open sea — that is a fall. This used to ask whether the ground he
      # was heading *for* was land, and the sea is not, so walking off a cliff
      # covered the whole drop in a single frame. Water still catches him; it
      # just no longer reaches up and yanks him down.
      #
      # Under the surface it stays a snap, because there the clamp is buoyancy
      # rather than gravity: a diver stroking upwards must be held at the
      # waterline every tick, not handed an accelerating arc.
      dropping ? fall_toward(top) : state.depth_y = top
    else
      state.fall = 0
      state.airborne = false
    end
  end

  def on_land?
    !!state.on_land
  end

  # Step off a terrace and he drops, gathering speed, until the ground catches
  # him. Snapping him to the rock below in a single frame read as a teleport.
  # A hop is the same arc read backwards: state.fall starts out negative, so the
  # first ticks carry him up before gravity turns him round.
  def fall_toward(top)
    state.airborne = true
    state.fall = (state.fall || 0) + LAND_GRAVITY
    state.fall = LAND_FALL_MAX if state.fall > LAND_FALL_MAX
    state.depth_y -= state.fall
    return if state.depth_y > top

    state.depth_y = top
    state.fall = 0
    state.airborne = false
  end

  # A hop, on the space bar. Only up on an island — in the water the same key is
  # the sprint, and there is nothing to push off from anyway. Only from the
  # ground, too: holding the key down must not wind him up into the sky.
  #
  # It lifts him clear this very tick, because clamp_depth runs after this and
  # would otherwise find him still resting on the rock and put the speed back to
  # nothing.
  def update_jump
    return unless wants_jump?
    return if state.airborne

    state.fall = -JUMP_SPEED
    state.depth_y -= state.fall
    state.airborne = true
  end

  def wants_jump?
    inputs.keyboard.key_down.space || inputs.controller_one.key_down.a || tapped?(:jump)
  end

  # As high as he can rise here. He floats at whatever water surface is above
  # him — the sea's, or the one inside an air chamber — and otherwise stops at
  # the rock of a cave roof. Whichever is lowest wins.
  #
  # Except that ground beats the surface: where the rock he is standing on lifts
  # him past the waterline he stands on it, in the air. Wading up a beach and
  # walking over an island is the same thing as resting on the sand, only on the
  # other side of the water. And standing is *all* he does up there — his own
  # ground is his ceiling too, so there is no swimming up into the sky.
  def depth_ceiling(ceiling, world_x, floor)
    limits = [[WATERLINE_Y - SURFACE_FLOAT_DEPTH, floor + Diver::HEIGHT].max]
    limits << ceiling - Diver::HEIGHT if ceiling
    # Only air that is actually over him. air_line_at knows a pocket by its x
    # alone, and a chamber deep inside an island shares its x with the mountain
    # above it — so once walking over the top became possible, that surface
    # reached up through a hundred metres of rock and pulled him down into the
    # cave. A ceiling stops a rise; it must never haul him down from above.
    air = air_line_at(world_x)
    limits << air - SURFACE_FLOAT_DEPTH if air && air >= state.depth_y
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
    # Under way the view is a boat's: waterline across the picture, sky over it,
    # and that framing held whatever the sea floor is doing underneath. Riding
    # the diver's camera, a shoal or an island lifted the ground into shot and
    # the horizon slid about while you were trying to steer by it.
    return WATERLINE_Y - HORIZON if state.aboard

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
    floor, ceiling = rock_span_at(world_x, state.depth_y, SOLID_STEP_UP)
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

  # What bounds the water at a world x for a diver currently at `depth`:
  # [rock below, rock above (or nil for open water)]. A column can hold several
  # slabs — one passage running over another — so what matters is not the topmost
  # or bottommost rock but the *pocket he is actually in*: what he rests on, and
  # what he'd bump his head on. Read across his whole footprint, so he only fits
  # where he fits on both sides of himself.
  def rock_span_at(world_x, depth, reach = 0)
    floors = []
    ceilings = []
    footprint(world_x).each do |x|
      floor, ceiling = pocket_at(x, depth, reach)
      floors << floor
      ceilings << ceiling
    end
    [floors.max, ceilings.compact.min]
  end

  # The pocket at a single world x: the sand, raised to the top of any slab he is
  # standing on, and the underside of the lowest slab above him (nil if the water
  # is open to the sky). `reach` is how far up he takes a step in his stride —
  # rock within it is ground he climbs onto rather than a wall he swims into.
  def pocket_at(world_x, depth, reach = 0)
    floor = floor_y_at(world_x)
    ceiling = nil
    slabs_at(world_x).each do |slab|
      if over_slab?(slab, depth, reach)
        floor = slab[:crown] if slab[:crown] > floor
      elsif ceiling.nil? || slab[:ceiling] < ceiling
        ceiling = slab[:ceiling]
      end
    end
    [floor, ceiling]
  end

  # He is over a slab if his feet are on top of it, or close enough under its top
  # to step up — the same tolerance the sand has always had. Rock needed it too:
  # without it an island's terraces are a staircase he can see and never climb.
  #
  # The stride is safe against stepping *through* rock because every slab in the
  # world is thicker than it (ROCK_SPAN is 64 against a 48 px stride, and an
  # island or a skerry is far thicker) — so feet within a stride of the top are
  # necessarily above the bottom. The second test says so out loud rather than
  # leaving it to that arithmetic.
  def over_slab?(rock, depth, reach = 0)
    feet = depth - Diver::HEIGHT
    feet + reach >= rock[:crown] && feet >= rock[:ceiling]
  end

  def footprint(world_x)
    [world_x - DIVER_FOOTPRINT, world_x, world_x + DIVER_FOOTPRINT]
  end

  # Sand / rock at any world x, looked up in the segment it belongs to — so a
  # footprint reaching across a segment border reads the right world.
  def floor_y_at(world_x)
    world_at(world_x.idiv(SCREEN_WIDTH)).floor_y_at(world_x % SCREEN_WIDTH)
  end

  def slabs_at(world_x)
    world_at(world_x.idiv(SCREEN_WIDTH)).slabs_at(world_x % SCREEN_WIDTH)
  end

  # Sprinting (holding the sprint key while actually swimming) makes the diver
  # faster but burns air quicker. Paused scenes never sprint. The decision is a
  # pure function so it stays trivially testable without stubbing inputs.
  def update_sprint
    state.sprinting = sprint_active?(will_sprint?, moving?)
    state.speed = current_speed
  end

  def sprint_active?(sprint_key, moving)
    return false if game_paused?
    return false if on_land? # up here the space bar is a hop, not a sprint

    !!sprint_key && !!moving
  end

  def moving?
    !!(will_up? || will_down? || will_left? || will_right?)
  end

  def current_speed
    # Fins push on the sprint, not on the cruise — see Game#swim_factor.
    speed = state.sprinting ? Diver::SPEED * SPRINT_MULTIPLIER * swim_factor : Diver::SPEED
    speed *= LAND_SPEED if on_land?
    speed *= TIRED_SPEED if exhausted? # a day gone is a long swim home
    speed
  end

  # Oxygen tops up only while the head is actually above the waterline,
  # otherwise it drains; running out drowns you.
  def update_oxygen
    if breathing?
      state.oxygen = [state.oxygen + OXYGEN_REFILL, air_capacity].min
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

    state.suit -= SUIT_DRAIN * (current_depth - suit_limit)
    return if state.suit > 0

    state.suit = 0
    state.game_scene = "game_over"
    state.death_cause = :crushed
  end

  def repair_suit
    state.suit = [state.suit + SUIT_REPAIR, SUIT_MAX].min
  end

  # --- the day --------------------------------------------------------------
  #
  # Oxygen says how long you can stay under and the suit says how deep you can
  # go; energy says how much day is left. It runs whether you are down there or
  # bobbing at the surface, because what is passing is the day, not your breath.
  # Running out doesn't kill you — it leaves you too tired to do much but get
  # home, which is where the only bed is.

  DAY_PHASES = [:morgen, :vormittag, :mittag, :nachmittag, :abend, :nacht]

  def update_energy
    state.energy = [state.energy - ENERGY_DRAIN, 0].max
  end

  # What this *day* has come to — not this round. A day survives drowning and
  # trying again, so the round's own log can't answer for it.
  def reset_day_tally
    state.day_earned = 0
    state.day_species = 0
    state.day_deepest = 0
    state.day_sold = 0
  end

  def exhausted?
    state.energy <= 0
  end

  # The clock, read off the gauge: no second counter to keep in step with it.
  def time_of_day
    spent = (ENERGY_MAX - state.energy) / ENERGY_MAX.to_f
    phase = (spent * DAY_PHASES.length).floor
    phase = 0 if phase < 0
    phase = DAY_PHASES.length - 1 if phase >= DAY_PHASES.length
    DAY_PHASES[phase]
  end

  def day_phase_index
    DAY_PHASES.index(time_of_day)
  end

  def update_sleep
    sleep_at_boat if inputs.keyboard.key_down.s && !game_paused?
  end

  # Turn in for the night. The only way to get a day back — and the boat sees to
  # the suit while you are asleep, which is the other reason to come home.
  #
  # It doesn't just tick the day over: it stops and shows you what the day came
  # to, and reading that is what ends it (night_tick -> wake_up). So a day is
  # never closed behind your back.
  def sleep_at_boat
    return unless at_the_boat?

    state.game_scene = "night"
  end

  # Morning. Called by the night scene once it has been read.
  def wake_up
    state.day += 1
    state.energy = ENERGY_MAX
    state.suit = SUIT_MAX
    state.oxygen = air_capacity
    reset_day_tally
    # A new day is a new job, and the morning says so — it is the one moment the
    # assignment can be announced rather than looked up.
    state.assignment_note_at = Kernel.tick_count
    save_book # a day ended is worth remembering
    resume_scene
  end

  def too_deep?
    current_depth > suit_limit
  end

  # Back at the boat, up in the air beside it — the one place with tools aboard.
  def at_the_boat?
    at_open_surface? && (state.diver_global_x - boat_x).abs <= BOAT_REACH
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
    ["title", "name", "intro", "recap", "night", "darkroom", "shop",
     "game_over", "home_menu", "pause", "assignment"].include?(state.game_scene)
  end

  # The boat screen: press L at the boat to open it, L to close it again. The
  # frozen world sits behind it, so the world's own input is off while it's up.
  def update_home_menu
    toggle_home_menu(menu_key?)
  end

  # The state change on its own, so it's testable without faking key presses.
  def toggle_home_menu(open_or_close)
    if state.game_scene == "home_menu"
      resume_scene if open_or_close
    elsif !game_paused? && at_the_boat? && !at_the_shop? && open_or_close
      state.game_scene = "home_menu"
      reset_exchange # every visit starts on the first thing you brought up
    end
  end

  # ESC (and the on-screen pause button) means one thing per screen, decided in a
  # single place. Underwater it opens the pause menu rather than dropping you on
  # the title — ESC used to throw the whole round away with no way back.
  def update_escape
    escape = inputs.keyboard.key_down.escape
    case state.game_scene
    when "home_menu" then resume_scene if escape
    when "darkroom" then close_darkroom if escape
    when "recap" then quit_to_title if escape # nothing is lost: the book is on disk
    when "name" then abandon_name if escape
    when "pause" then resume_scene if escape # ESC also closes the pause menu
    when "area1", "area2"
      # ESC out of a half-composed shot rather than into the pause menu: the
      # frame is the thing in front of you, so it is what a cancel means.
      next_action = framing? ? :cancel : :pause
      if escape || tapped?(:pause)
        next_action == :cancel ? cancel_framing : open_pause
      end
    end
  end

  def open_pause
    state.game_scene = "pause"
    # Remember the tick: the same tap (or key) that opened the menu must not be
    # read as "carry on" by pause_tick later in this very tick.
    state.paused_at = Kernel.tick_count
  end

  # "Spiel beenden" from the pause menu: back to the title, where a new dive
  # begins. Not a hard quit — on the web that would just freeze a dead tab.
  def quit_to_title
    state.game_scene = "title"
    # Put him back at the surface on the way out. The title draws the real sea
    # (render_boat_horizon), and that only comes out as a clean horizon while the
    # diver is up in the air — left three hundred metres down, the title would
    # open on a wall of sand.
    spawn_at_surface
  end

  def menu_key?
    inputs.keyboard.key_down.l
  end

  # "Spiel beenden" from the boat — close the game down to the desktop.
  def quit_game
    $gtk.request_quit
  end

  # Back to diving in whichever sector the diver is standing in.
  def resume_scene
    state.game_scene = state.diver_global_x < 1281 ? "area1" : "area2"
  end

  # The dive log for this round: how deep you got, and what you've come across.
  def reset_log
    state.log_deepest = 0
    state.log_sectors = {}
    state.log_islands = {}
    state.log_caves = {}
  end

  # Recorded once per diving tick. Sectors and islands are keyed by index so
  # revisiting one doesn't count twice; a cave counts once you've surfaced to
  # breathe in its trapped air.
  def track_log
    state.log_deepest = current_depth if current_depth > state.log_deepest
    state.log_best = current_depth if current_depth > state.log_best
    state.day_deepest = current_depth if current_depth > state.day_deepest
    state.log_sectors[world_index] = true
    state.log_islands[world_index] = true if state.island_sectors.include?(world_index)
    state.log_caves[world_index] = true if breathing? && !at_open_surface?
    chart_sector
  end

  # The chart: the furthest sector he has ever *swum* to, each way. It outlives
  # the round (log_sectors does not) because it is what the boat's range is
  # measured against, and a range that forgot itself every morning would be no
  # range at all.
  #
  # Riding the boat does not count. That is the whole load-bearing part: if
  # sailing charted the water it crossed, you could inch out for ever — sail to
  # the edge, let the crossing chart it, sail one further — and the rule would
  # be no rule. Water you have been carried over is not water you know.
  def chart_sector
    return if state.aboard

    state.charted_east = world_index if world_index > state.charted_east.to_i
    state.charted_west = world_index if world_index < state.charted_west.to_i
  end

  # How far the boat may be taken: one sector past the chart, each way.
  def boat_range
    [state.charted_west.to_i - 1, state.charted_east.to_i + 1]
  end

  # --- the book on disk -----------------------------------------------------
  #
  # Written exactly when what it holds changes — a species developed into the
  # book, a species laid eyes on for the first time, a name typed in. That is a
  # handful of writes a session, and it means the file is never behind: quitting
  # by any means, including closing the window, loses nothing that mattered.

  # Where the book lives. Under the test runner, somewhere disposable — saving
  # happens the moment a species is first sighted, so any test that swims near a
  # fish would otherwise write over the real thing.
  # The runtime is an argument so the guard below can actually be tested against
  # one that hasn't got argv.
  # Carry the saved book on: same diver, same pages, same sea, straight into the
  # water. No opening story and no camera card — he has been here before.
  def continue_round(slot = 1)
    open_slot(slot)
    book = state.saved_book || slot_book(slot) || SaveFile.blank
    state.player_name = book[:name]
    state.album = book[:album]
    state.sighted = book[:sighted]
    state.flocks = book[:flocks] || {} # a book from before schools simply has none
    # A book written before seas had seeds hasn't got one; that diver gets a
    # fresh sea rather than an error.
    # Defaulted, not trusted: a book saved before any of these existed simply
    # hasn't got them, and a career that starts at nil crashes on its first dive.
    state.credits = book[:credits] || 0
    state.log_dives = book[:dives] || 0
    state.log_best = book[:best] || 0
    state.log_sold = book[:sold] || 0
    state.log_earned = book[:earned] || 0
    state.day = book[:day] || 1
    state.energy = book[:energy] || ENERGY_MAX
    # The day he was in the middle of, not a fresh one: closing the game at
    # lunchtime and coming back must not hand him a morning he hasn't earned.
    state.day_earned = book[:day_earned] || 0
    state.day_species = book[:day_species] || 0
    state.day_deepest = book[:day_deepest] || 0
    state.day_sold = book[:day_sold] || 0
    state.assignment_paid_day = book[:assignment_paid_day] || 0
    state.assignment_log = book[:assignment_log] || []
    # What he has bought, before reset_game refills the tank and the roll from it.
    state.gear = { film: book[:gear_film] || 0, air: book[:gear_air] || 0,
                   suit: book[:gear_suit] || 0, mask: book[:gear_mask] || 0,
                   fins: book[:gear_fins] || 0 }
    state.shop_met = book[:shop_met] || 0 # whether he has introduced himself
    state.kraken_met = book[:kraken_met] || 0 # ... and whether the legend is real to him
    state.world_seed = book[:seed] || new_world_seed
    # Where he left the boat. Set before reset_game, because spawning puts him
    # in the water beside it — carrying on a book must not sail it home for him.
    state.boat_x = book[:boat_x] || SURFACE_BOAT_X
    # Never narrower than a diver starting today. A book written before there
    # was a chart has one full of zeroes, and its owner's real exploring was
    # never written down anywhere — so there is nothing to reconstruct it from,
    # and the least the game can do is not box him in tighter than a beginner.
    state.charted_west = [book[:charted_west] || 0, -CHART_START].min
    state.charted_east = [book[:charted_east] || 0, CHART_START].max
    reset_game # rebuild the world from that seed before he is put in it
    state.stash = book[:stash] || [] # ... and the hold as he left it, after reset_items
    # Not straight into the water: he gets told where he left off first, and
    # pressing on there is what starts the dive (recap_tick -> start_round).
    state.game_scene = "recap"
  end

  # Put it down and start over: a new diver, an empty book, and a sea nobody has
  # had before. The file itself isn't touched until the new diver has a name —
  # change your mind on the name screen and the old book is still there.
  def fresh_round(slot = nil)
    # Into the first free slot, or the one you pointed at — never over a book
    # that is already there.
    open_slot(slot || (1..SAVE_SLOTS).find { |i| !slot_used?(i) } || 1)
    state.album = {}
    state.sighted = {}
    state.flocks = {}
    state.player_name = ""
    state.credits = 0
    state.log_dives = 0
    state.log_best = 0
    state.log_sold = 0
    state.log_earned = 0
    state.day = 1
    state.energy = ENERGY_MAX
    reset_gear # a new diver owns nothing
    state.shop_met = 0 # ... and has not met him yet
    state.kraken_met = 0 # ... nor been deep enough for the legend
    reset_day_tally
    state.stash = [] # a new career comes with an empty hold
    state.world_seed = new_world_seed
    reset_game
    state.game_scene = "name"
  end

  # Nothing while he is aboard: he is *in* the boat, and drawn as well he
  # floated alongside his own hull like a man being towed — the one reading the
  # whole feature must not have. The guard is here as well as at the call above,
  # so a scene that draws him some other way cannot put him back in the water.
  def render_diver
    return if state.aboard

    outputs.sprites << state.diver.to_h
    render_fog
  end

  # The dark closing in around him. It belongs to the *world*, not to the diver —
  # drawing it as part of him meant the pause screen, which freezes the world and
  # draws it without him, lifted the fog and handed you the whole map for one key
  # press. Anything that draws the sea has to draw this too.
  def render_fog
    return unless FOG_OF_WAR
    return if at_open_surface? # no fog at the surface — there's daylight up here

    biome = current_world.biome
    outputs.sprites << FogOfWar.new(state.diver,
                                    radius: fog_radius(biome),
                                    color: fog_color(biome)).to_a
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

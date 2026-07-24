# Collectible items hidden on the sea floor: a message in a bottle, a lost shoe,
# a tin can, a gem, an old key. Reopens Game. They live in *world* coordinates
# (absolute x/y), rolled once per round into state.world_items, so they stay put
# when you swim away and back. The diver carries up to INVENTORY_MAX at a time
# and stows the rest at the boat (see the boat actions). Drawing and the pickup
# interaction both live here — it's one small subsystem.
class Game
  ITEM_SPRITES = {
    "bottle" => { path: "sprites/items/bottle.png", w: 17, h: 8 },
    "shoe"   => { path: "sprites/items/shoe.png",   w: 14, h: 8 },
    "can"    => { path: "sprites/items/can.png",    w: 10, h: 10 },
    "jewel"  => { path: "sprites/items/jewel.png",  w: 11, h: 8 },
    "key"    => { path: "sprites/items/key.png",    w: 15, h: 7 },
  }
  ITEM_NAMES = {
    "bottle" => "Flaschenpost", "shoe" => "Schuh", "can" => "Dose",
    "jewel" => "Schmuck", "key" => "Schlüssel",
  }
  ITEM_KINDS = ITEM_SPRITES.keys
  ITEM_SCALE = 3
  INVENTORY_MAX = 3   # how many the diver can carry at once
  ITEM_REACH = 74     # px radius within which E grabs one
  ITEM_LIFT = 12      # rest a little above the sand
  ITEM_COUNT = 8      # how many are hidden out there each round
  ITEM_SPACING = 300  # px two finds keep from each other — well past ITEM_REACH,
                      # so one stop never picks up two
  ITEM_MIN_SECTOR = 1 # spread across the sectors near home ...
  ITEM_MAX_SECTOR = 9 # ... but not too far out to ever find

  # A fresh scatter of treasures for the round, plus an empty pack and stash.
  def reset_items
    state.inventory = []
    state.stash = []
    state.world_items = roll_world_items
    reset_exchange
  end

  # Scatter ITEM_COUNT items on the open sea floor around home — never on the
  # home sector, never on an island sector (they'd be buried in rock), and not
  # stacked on top of each other. Rolled once; positions then live in state.
  def roll_world_items
    items = []
    attempts = 0
    while items.length < ITEM_COUNT && attempts < 400
      attempts += 1
      sector = item_sector
      next if sector.zero? || island_sector?(sector)

      wx = sector * SCREEN_WIDTH + 240 + rand(SCREEN_WIDTH - 480) # clear of the segment edges
      # Real distance, not a grid bucket: two slots either side of a boundary can
      # be a pixel apart, and then one find hands you two.
      next if items.any? { |item| (item[:x] - wx).abs < ITEM_SPACING }

      items << { kind: ITEM_KINDS[rand(ITEM_KINDS.length)],
                 x: wx, y: WorldGenerator.floor_y_at(wx) + ITEM_LIFT, collected: false }
    end
    items
  end

  def item_sector
    s = ITEM_MIN_SECTOR + rand(ITEM_MAX_SECTOR - ITEM_MIN_SECTOR + 1)
    rand(2).zero? ? -s : s
  end

  # An island is wider than a segment, so "not on an island" means not on any
  # segment one of them reaches into — not just the sector it is centred on, or
  # treasures end up buried in the flank of the one next door.
  def island_sector?(sector)
    !islands_over(sector).empty?
  end

  # The nearest un-taken item the diver could grab right now, or nil.
  def item_in_reach
    return nil unless state.world_items

    state.world_items.find do |item|
      !item[:collected] &&
        (item[:x] - state.diver_global_x).abs <= ITEM_REACH &&
        (item[:y] - state.depth_y).abs <= ITEM_REACH
    end
  end

  def inventory_full?
    state.inventory.length >= INVENTORY_MAX
  end

  def update_pickup
    grab_item if inputs.keyboard.key_down.e
  end

  def update_boat_stash
    store_items if at_the_boat? && inputs.keyboard.key_down.i
  end

  # Everything you're carrying goes into the boat's hold — an unlimited stash at
  # home — and the pack is empty again for the next dive. Pure state change so
  # it's testable without a key press.
  def store_items
    return if state.inventory.empty?

    state.stash.concat(state.inventory)
    state.inventory = []
  end

  # --- The exchange at the boat -------------------------------------------
  #
  # Two lists side by side: what you carry (the pack) and what lies in the
  # boat's hold. A cursor walks them — left/right picks the side, up/down the
  # row, E moves the selected piece across. Everything below is a plain state
  # change so the whole interaction tests without a single key press; the boat
  # screen in app/scenes/home_menu.rb only draws what these methods say.

  PACK_SIDE = "pack"
  HOLD_SIDE = "hold"

  # The hold, gathered into one row per kind — six cans read better as "Dose 6"
  # than as six identical rows. Ordered like ITEM_KINDS so the rows don't shuffle
  # around under the cursor as things come and go.
  def hold_stacks
    ITEM_KINDS.map { |kind| { kind: kind, count: state.stash.count { |stored| stored == kind } } }
              .reject { |stack| stack[:count].zero? }
  end

  def exchange_rows(side)
    side == PACK_SIDE ? state.inventory : hold_stacks
  end

  # The cursor starts on what you just brought up — that's what you came to sort.
  def reset_exchange
    state.exchange_side = PACK_SIDE
    state.exchange_index = 0
  end

  # dx picks the side (-1 pack, +1 hold), drow walks the rows (+1 = one further
  # down the list) and wraps at either end — with this few rows, wrapping beats
  # bumping into a wall.
  def move_exchange(dx, drow)
    state.exchange_side = dx < 0 ? PACK_SIDE : HOLD_SIDE unless dx.zero?
    state.exchange_index += drow
    clamp_exchange
  end

  # Keep the cursor on a row that is actually there — after a step, after
  # switching sides, and after a transfer took the row away underneath it.
  def clamp_exchange
    rows = exchange_rows(state.exchange_side).length
    state.exchange_index = rows - 1 if state.exchange_index < 0
    state.exchange_index = 0 if rows.zero? || state.exchange_index >= rows
  end

  # E on the boat screen: whatever the cursor is on goes to the other side.
  def transfer_selected
    state.exchange_side == PACK_SIDE ? stow_selected : fetch_selected
  end

  # Out of the pack, into the hold — which takes as much as you can bring it.
  def stow_selected
    kind = state.inventory[state.exchange_index]
    return unless kind

    state.inventory.delete_at(state.exchange_index)
    state.stash << kind
    clamp_exchange # the row is gone; keep the cursor on one that exists
  end

  # One piece off the selected stack, back into the pack — if there's room.
  def fetch_selected
    return if inventory_full?

    stack = hold_stacks[state.exchange_index]
    return unless stack

    state.stash.delete_at(state.stash.index(stack[:kind]))
    state.inventory << stack[:kind]
    clamp_exchange # emptying a stack drops its row out from under the cursor
  end

  # Menu keys, live only while the boat screen is up. The world's own input is
  # off then (game_paused?), so E means "move this" here and nothing else.
  def update_exchange
    return unless state.game_scene == "home_menu"

    keys = inputs.keyboard.key_down
    move_exchange(-1, 0) if keys.left
    move_exchange(1, 0) if keys.right
    move_exchange(0, -1) if keys.up
    move_exchange(0, 1) if keys.down
    transfer_selected if keys.e || keys.enter
  end

  # Pick up the item under the diver, if there is one and the pack has room. The
  # state change on its own, so it's testable without faking the key press.
  def grab_item
    item = item_in_reach
    return unless item
    return if inventory_full?

    item[:collected] = true
    state.inventory << item[:kind]
  end

  # Drawn in world space, shifted by the camera. Hidden from the surface like the
  # rest of the underwater world, and gone once collected. A slow bob so they
  # catch the eye on the sand.
  def render_world_items
    return unless submerged_visible?
    return unless state.world_items

    state.world_items.each do |item|
      next if item[:collected]

      sx = item[:x] - state.camera_x
      next if sx < -60 || sx > grid.w + 60 # off screen this frame

      sprite = ITEM_SPRITES[item[:kind]]
      bob = Math.sin((Kernel.tick_count + item[:x]) / 40.0) * 2
      outputs.sprites << {
        x: sx, y: item[:y] - state.camera_y + bob,
        w: sprite[:w] * ITEM_SCALE, h: sprite[:h] * ITEM_SCALE,
        path: sprite[:path], anchor_x: 0.5, anchor_y: 0,
      }
    end
  end
end

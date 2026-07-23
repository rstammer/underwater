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
  ITEM_MIN_SECTOR = 1 # spread across the sectors near home ...
  ITEM_MAX_SECTOR = 9 # ... but not too far out to ever find

  # A fresh scatter of treasures for the round, plus an empty pack and stash.
  def reset_items
    state.inventory = []
    state.stash = []
    state.world_items = roll_world_items
  end

  # Scatter ITEM_COUNT items on the open sea floor around home — never on the
  # home sector, never on an island sector (they'd be buried in rock), and not
  # stacked on top of each other. Rolled once; positions then live in state.
  def roll_world_items
    items = []
    used = {}
    attempts = 0
    while items.length < ITEM_COUNT && attempts < 400
      attempts += 1
      sector = item_sector
      next if sector.zero? || island_sector?(sector)

      wx = sector * SCREEN_WIDTH + 240 + rand(SCREEN_WIDTH - 480) # clear of the segment edges
      slot = wx.idiv(140)
      next if used[slot] # keep them apart

      used[slot] = true
      items << { kind: ITEM_KINDS[rand(ITEM_KINDS.length)],
                 x: wx, y: WorldGenerator.floor_y_at(wx) + ITEM_LIFT, collected: false }
    end
    items
  end

  def item_sector
    s = ITEM_MIN_SECTOR + rand(ITEM_MAX_SECTOR - ITEM_MIN_SECTOR + 1)
    rand(2).zero? ? -s : s
  end

  def island_sector?(sector)
    !!state.island_sectors && state.island_sectors.include?(sector)
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

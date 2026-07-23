# The in-game HUD, drawn on top of everything else. Reopens Game so tick can
# just call render_panel; the individual readouts live here rather than in
# main.rb, which is about running the world, not describing it.
class Game
  def render_panel
    return if game_paused?

    render_debug
    render_gauges
    render_locator
    render_inventory
    render_pickup_prompt
  end

  INV_X = 20
  INV_Y = 24 # slots sit this far up from the bottom edge
  INV_SLOT = 46
  INV_GAP = 8

  # The three carry slots, bottom-left, clear of the gauges up top — each holds
  # the icon of what's in it; empty slots sit as dim frames so you can see how
  # much room is left.
  def render_inventory
    outputs.labels << { x: INV_X, y: INV_Y + INV_SLOT + 24, text: "Inventar",
                        size_enum: 1, vertical_alignment_enum: 2, r: 210, g: 228, b: 245, a: 175 }
    INVENTORY_MAX.times do |i|
      x = INV_X + i * (INV_SLOT + INV_GAP)
      outputs.sprites << { x: x, y: INV_Y, w: INV_SLOT, h: INV_SLOT, r: 14, g: 30, b: 50, a: 185, path: :solid }
      outputs.sprites << { x: x, y: INV_Y + INV_SLOT - 2, w: INV_SLOT, h: 2, r: 90, g: 140, b: 170, a: 150, path: :solid }

      kind = state.inventory[i]
      next unless kind

      sprite = ITEM_SPRITES[kind]
      outputs.sprites << { x: x + INV_SLOT / 2, y: INV_Y + INV_SLOT / 2,
                           w: sprite[:w] * 2, h: sprite[:h] * 2, path: sprite[:path],
                           anchor_x: 0.5, anchor_y: 0.5 }
    end
  end

  # When an item is within reach, a line telling you what it is and how to take it
  # — or, if the pack is full, that you need to stow something at the boat first.
  def render_pickup_prompt
    item = item_in_reach
    return unless item

    full = inventory_full?
    text = full ? "Inventar voll — am Boot einlagern" : "[ E ]  #{ITEM_NAMES[item[:kind]]} aufheben"
    cx = grid.w / 2
    outputs.sprites << { x: cx - 260, y: 128, w: 520, h: 44, r: 12, g: 30, b: 48, a: 180, path: :solid }
    outputs.labels << { x: cx, y: 150, text: text, size_enum: 2, alignment_enum: 1, vertical_alignment_enum: 1,
                        r: full ? 240 : 232, g: full ? 200 : 244, b: full ? 150 : 252 }
  end

  # Only with DEBUG on: the diver's world and screen x, for chasing coordinate bugs.
  def render_debug
    return unless !!DEBUG

    outputs.labels << {
      x: 140, y: grid.h - 10, anchor_y: 100,
      text: "x: #{state.diver_global_x} (screen #{state.player_x})",
      r: 200, g: 100, b: 100,
    }
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
    [(WATERLINE_Y - state.depth_y) / PIXELS_PER_METRE, 0].max.to_i
  end

  GAUGE_X = 20
  GAUGE_Y = 664 # the oxygen bar; the suit hangs under it
  GAUGE_W = 220
  GAUGE_H = 18
  GAUGE_GAP = 62 # enough for the lower gauge's own label to sit clear
  OXYGEN_COLOR = [40, 170, 230]
  SUIT_COLOR = [190, 160, 90]

  # The two things that can run out on you, stacked: how long you can stay down,
  # and how deep you can go.
  def render_gauges
    render_gauge(GAUGE_Y, "Sauerstoff", state.oxygen / OXYGEN_MAX, OXYGEN_COLOR)
    render_gauge(GAUGE_Y - GAUGE_GAP, suit_label, state.suit / SUIT_MAX, SUIT_COLOR)
  end

  def suit_label
    too_deep? ? "Anzug — Druck!" : "Anzug"
  end

  def render_gauge(y, label, ratio, color)
    low = ratio < 0.3
    ratio = 0 if ratio < 0

    outputs.labels << { x: GAUGE_X, y: y + GAUGE_H + 22, text: label,
                        r: low ? 235 : 225, g: low ? 150 : 238, b: low ? 150 : 255 }
    outputs.sprites << { x: GAUGE_X, y: y, w: GAUGE_W, h: GAUGE_H,
                         r: 15, g: 25, b: 45, path: :solid } # track
    outputs.sprites << {                                     # fill
      x: GAUGE_X, y: y, w: GAUGE_W * ratio, h: GAUGE_H,
      r: (low ? 210 : color[0]), g: (low ? 70 : color[1]), b: (low ? 80 : color[2]),
      path: :solid,
    }
  end
end

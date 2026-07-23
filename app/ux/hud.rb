# The in-game HUD, drawn on top of everything else. Reopens Game so tick can
# just call render_panel; the individual readouts live here rather than in
# main.rb, which is about running the world, not describing it.
class Game
  def render_panel
    return if game_paused?

    Panel.new(args, state.diver).to_a.each do |item|
      outputs.labels << item
    end
    render_gauges
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

  GAUGE_Y = 640
  GAUGE_W = 220
  GAUGE_H = 18
  OXYGEN_COLOR = [40, 170, 230]
  SUIT_COLOR = [190, 160, 90]

  # The two things that can run out on you, side by side: how long you can stay
  # down, and how deep you can go.
  def render_gauges
    render_gauge(20, "Sauerstoff", state.oxygen / OXYGEN_MAX, OXYGEN_COLOR)
    render_gauge(260, suit_label, state.suit / SUIT_MAX, SUIT_COLOR)
  end

  def suit_label
    too_deep? ? "Anzug — Druck!" : "Anzug"
  end

  def render_gauge(x, label, ratio, color)
    low = ratio < 0.3
    ratio = 0 if ratio < 0

    outputs.labels << { x: x, y: GAUGE_Y + GAUGE_H + 22, text: label,
                        r: low ? 235 : 225, g: low ? 150 : 238, b: low ? 150 : 255 }
    outputs.sprites << { x: x, y: GAUGE_Y, w: GAUGE_W, h: GAUGE_H,
                         r: 15, g: 25, b: 45, path: :solid } # track
    outputs.sprites << {                                     # fill
      x: x, y: GAUGE_Y, w: GAUGE_W * ratio, h: GAUGE_H,
      r: (low ? 210 : color[0]), g: (low ? 70 : color[1]), b: (low ? 80 : color[2]),
      path: :solid,
    }
  end
end

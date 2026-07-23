# The in-game HUD, drawn on top of everything else. Reopens Game so tick can
# just call render_panel; the individual readouts live here rather than in
# main.rb, which is about running the world, not describing it.
class Game
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
end

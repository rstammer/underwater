class Game
  MENU_W = 560
  MENU_H = 380
  MENU_BG = [14, 34, 54]
  MENU_ACCENT = [120, 190, 220]
  MENU_INK = [232, 244, 252]
  MENU_DIM_INK = [150, 184, 208]

  # The logbook, opened with E while you're at the boat. The world sits frozen
  # behind a dim veil; this is your home base, where the round's dive so far is
  # tallied up. E or ESC drops you back in the water (handled in update_home_menu).
  def home_menu_tick
    render_underwater # the frozen world behind the veil
    outputs.sprites << { x: 0, y: 0, w: grid.w, h: grid.h, r: 4, g: 12, b: 22, a: 150, path: :solid }
    render_logbook
  end

  # The record rows, as [label, value] pairs — a plain method so the tally is
  # testable without reaching into the rendered labels.
  def logbook_rows
    [
      ["Tiefster Tauchgang", "#{state.log_deepest} m"],
      ["Inseln gefunden", "#{state.log_islands.length} / #{ISLAND_COUNT}"],
      ["Sektoren erkundet", "#{state.log_sectors.length}"],
      ["Höhlen durchtaucht", "#{state.log_caves.length}"],
    ]
  end

  def render_logbook
    left = (grid.w - MENU_W) / 2
    bottom = (grid.h - MENU_H) / 2
    right = left + MENU_W
    top = bottom + MENU_H
    pad = 32

    outputs.sprites << { x: left, y: bottom, w: MENU_W, h: MENU_H,
                         r: MENU_BG[0], g: MENU_BG[1], b: MENU_BG[2], a: 240, path: :solid }
    outputs.sprites << { x: left, y: top - 4, w: MENU_W, h: 4,
                         r: MENU_ACCENT[0], g: MENU_ACCENT[1], b: MENU_ACCENT[2], path: :solid }

    outputs.labels << { x: left + pad, y: top - pad, text: "Logbuch", size_enum: 4,
                        vertical_alignment_enum: 2, r: MENU_INK[0], g: MENU_INK[1], b: MENU_INK[2] }
    outputs.labels << { x: right - pad, y: top - pad - 4, text: "Dein Boot", size_enum: 1,
                        alignment_enum: 2, vertical_alignment_enum: 2,
                        r: MENU_DIM_INK[0], g: MENU_DIM_INK[1], b: MENU_DIM_INK[2] }

    row_y = top - pad - 74
    logbook_rows.each do |label, value|
      outputs.sprites << { x: left + pad, y: row_y - 12, w: MENU_W - pad * 2, h: 1,
                           r: MENU_ACCENT[0], g: MENU_ACCENT[1], b: MENU_ACCENT[2], a: 40, path: :solid }
      outputs.labels << { x: left + pad, y: row_y, text: label, size_enum: 2,
                          vertical_alignment_enum: 2, r: MENU_DIM_INK[0], g: MENU_DIM_INK[1], b: MENU_DIM_INK[2] }
      outputs.labels << { x: right - pad, y: row_y, text: value, size_enum: 3, alignment_enum: 2,
                          vertical_alignment_enum: 2, r: MENU_INK[0], g: MENU_INK[1], b: MENU_INK[2] }
      row_y -= 62
    end

    outputs.labels << { x: (left + right) / 2, y: bottom + pad, text: "E / ESC  —  schließen",
                        size_enum: 1, alignment_enum: 1, vertical_alignment_enum: 2,
                        r: MENU_DIM_INK[0], g: MENU_DIM_INK[1], b: MENU_DIM_INK[2] }
  end
end

# The end of a day, as its own screen. Reopens Game.
#
# Sleeping used to be one keypress that silently put the numbers back up: the
# gauges refilled, the day counter ticked, and nothing said what the day had
# actually come to. A day is the unit this game is counted in, so it gets a
# moment — the boat at night, and the four numbers that say whether it was a
# good one.
#
# The scene doesn't change anything; pressing on is what ends the day (wake_up).
# So a night can be looked at for as long as you like, and closing the game
# during one loses nothing that was not already banked.
class Game
  NIGHT_W = 720
  NIGHT_PAD = 34
  NIGHT_ROW_H = 46
  NIGHT_TOP = 96          # air above the panel
  # Where the stars sit on the panel's sky, as [x, y, size]. Fixed rather than
  # rolled: they must not crawl about while you read.
  NIGHT_STARS = [[168, 604, 2], [402, 668, 3], [742, 626, 2], [988, 690, 2],
                 [1130, 592, 3], [286, 700, 2], [858, 574, 2]]

  def night_tick
    if fire_input? || touch_began?
      wake_up
      return
    end

    render_night_sea
    render_night_panel
    outputs.labels << night_labels
  end

  # The same sea the intro uses — the real renderer, parked at the boat — with
  # the day taken out of it. One flat wash rather than a recoloured world,
  # because the world is drawn from a hundred places and this is one sprite.
  def render_night_sea
    render_boat_horizon
    outputs.sprites << { x: 0, y: 0, w: grid.w, h: grid.h,
                         r: 4, g: 10, b: 32, a: 176, path: :solid }
    outputs.sprites << night_moon
    NIGHT_STARS.each do |x, y, size|
      outputs.sprites << { x: x, y: y, w: size, h: size, r: 226, g: 236, b: 252,
                           a: 150 + (Math.sin((Kernel.tick_count + x) / 40.0) * 80).to_i, path: :solid }
    end
  end

  def night_moon
    { x: grid.w - 160, y: grid.h - 150, w: 96, h: 96, path: DAYTIME_SHEET,
      source_x: (DAY_PHASES.length - 1) * DAYTIME_FRAME, source_y: 0,
      source_w: DAYTIME_FRAME, source_h: DAYTIME_FRAME, a: 235 }
  end

  # Sized from what it holds, top down, the way the intro's is — so a row more
  # or less in the tally can never push the prompt onto the last line.
  def render_night_panel
    left = (grid.w - NIGHT_W) / 2 - NIGHT_PAD
    top = grid.h - NIGHT_TOP
    bottom = night_prompt_y - 34

    outputs.sprites << { x: left, y: bottom, w: NIGHT_W + NIGHT_PAD * 2, h: top - bottom,
                         r: 6, g: 18, b: 38, a: 226, path: :solid }
    outputs.sprites << { x: left, y: top - 4, w: NIGHT_W + NIGHT_PAD * 2, h: 4,
                         r: MENU_ACCENT[0], g: MENU_ACCENT[1], b: MENU_ACCENT[2], a: 220, path: :solid }
  end

  # What the day came to. Day-scoped, not round-scoped: drowning and going back
  # out is still the same day, and the evening should count it as one.
  def night_rows
    [
      ["Verdient", "#{state.day_earned} Cr"],
      ["Neue Arten", "#{state.day_species}"],
      ["Auftrag", night_assignment_value],
      ["Tiefster Punkt", "#{state.day_deepest} m"],
      ["Fundstücke verkauft", "#{state.day_sold}"],
    ]
  end

  # Delivered, or not. A job that was never handed in says so plainly and costs
  # nothing — the morning brings another one.
  def night_assignment_value
    return "#{state.assignment_earned || 0} Cr" if assignment_paid?
    return "im Kasten, nicht entwickelt" if assignment_done?

    "nicht geschafft"
  end

  def night_rows_top
    grid.h - NIGHT_TOP - 118
  end

  def night_prompt_y
    night_rows_top - NIGHT_ROW_H * night_rows.length - 30
  end

  def night_labels
    left = (grid.w - NIGHT_W) / 2
    labels = [
      { x: left, y: grid.h - NIGHT_TOP - 34, text: "Tag #{state.day} geht zu Ende",
        size_enum: 6, r: 255, g: 244, b: 205 },
      { x: left, y: grid.h - NIGHT_TOP - 78, text: night_verdict, size_enum: 2,
        r: 150, g: 198, b: 224 },
    ]

    y = night_rows_top
    night_rows.each do |label, value|
      labels << { x: left, y: y, text: label, size_enum: 2, vertical_alignment_enum: 2,
                  r: MENU_DIM_INK[0], g: MENU_DIM_INK[1], b: MENU_DIM_INK[2] }
      labels << { x: left + NIGHT_W, y: y, text: value, size_enum: 5, alignment_enum: 2,
                  vertical_alignment_enum: 2, r: MENU_INK[0], g: MENU_INK[1], b: MENU_INK[2] }
      y -= NIGHT_ROW_H
    end

    labels << { x: left, y: night_prompt_y, text: night_prompt, size_enum: 3,
                r: 255, g: 244, b: 205, a: Kernel.tick_count.idiv(30).even? ? 255 : 140 }
    labels
  end

  # One line on how it went, off the day's own numbers. Nothing is a failure —
  # a blank day is a blank day, and there is another one in the morning.
  def night_verdict
    return "Auftrag erledigt und bezahlt. So geht das." if assignment_paid?
    return "Der Auftrag liegt noch auf dem Film. Schade um den Tag." if assignment_done?
    return "Ein Tag ohne eine einzige Aufnahme. Kommt vor." if state.day_species.zero? && state.day_earned.zero?
    return "Vier neue Seiten im Artenbuch. Ein guter Tag." if state.day_species >= 4
    return "Das Konto sieht deutlich freundlicher aus." if state.day_earned >= 100
    return "Die Kamera hat sich heute gelohnt." if state.day_species > 0

    "Nichts Neues gesehen, aber die Kasse stimmt."
  end

  def night_prompt
    state.touch_seen ? "Tippen und schlafen" : "[ Leertaste ]  schlafen"
  end
end

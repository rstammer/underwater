# Coming back to a career already under way, as its own screen. Reopens Game.
#
# Carrying a book on used to drop you straight in the water: mid-afternoon of a
# day you had no memory of, with a balance you had to swim home and open the boat
# screen to find out. A save that resumes silently makes you reconstruct your own
# situation from the gauges.
#
# So the game says where you left off, and you say when to go on — the same shape
# as the night screen at the other end of a day. Nothing here changes anything:
# continue_round has already loaded the book, and pressing on is what counts as
# starting the dive (start_round), so a recap can be read for as long as you like
# and quitting during one costs nothing.
class Game
  RECAP_W = 720
  RECAP_PAD = 34
  RECAP_ROW_H = 44
  RECAP_TOP = 96 # air above the panel

  def recap_tick
    if fire_input? || touch_began?
      start_round(told: true) # he has been here before: no story, no camera card
      return
    end

    render_intro_sea # the same sea the opening uses — his own boat, from the surface
    render_recap_panel
    outputs.labels << recap_labels
  end

  # Where he left off, in the terms the boat screen uses — so the numbers here
  # are the numbers he will find again in the logbook, not a second accounting.
  def recap_rows
    [
      ["Guthaben", "#{state.credits} Cr"],
      ["Artenbuch", "#{album_found} / #{(state.sighted || {}).length} gesichtet"],
      ["Tiefster Punkt je", "#{state.log_best} m"],
      ["Tauchgänge", "#{state.log_dives}"],
      ["Im Lager", "#{(state.stash || []).length} Fundstücke"],
    ]
  end

  # One line on where in the day he is standing. Read off the energy gauge like
  # everything else about the day, so it can never disagree with the clock.
  def recap_note
    return "Du bist durch. Am Boot schlafen bringt den nächsten Tag." if exhausted?

    case time_of_day
    when :morgen, :vormittag then "Der Tag ist noch jung."
    when :mittag, :nachmittag then "Der halbe Tag ist herum."
    when :abend then "Es wird langsam dunkel da unten."
    else "Spät. Was du heute noch holst, holst du im Dunkeln."
    end
  end

  # Far enough under the three lines of head that the first row cannot land on
  # the note — every label here hangs from its own top edge, so this is the one
  # number that keeps the two blocks apart.
  def recap_rows_top
    grid.h - RECAP_TOP - 186
  end

  def recap_prompt_y
    recap_rows_top - RECAP_ROW_H * recap_rows.length - 30
  end

  # Sized from what it holds, top down, the way the intro's and the night's are —
  # a row more in the tally can never push the prompt onto the last line.
  def render_recap_panel
    left = (grid.w - RECAP_W) / 2 - RECAP_PAD
    top = grid.h - RECAP_TOP
    bottom = recap_prompt_y - 34

    outputs.sprites << { x: left, y: bottom, w: RECAP_W + RECAP_PAD * 2, h: top - bottom,
                         r: 6, g: 18, b: 38, a: 226, path: :solid }
    outputs.sprites << { x: left, y: top - 4, w: RECAP_W + RECAP_PAD * 2, h: 4,
                         r: MENU_ACCENT[0], g: MENU_ACCENT[1], b: MENU_ACCENT[2], a: 220, path: :solid }
  end

  def recap_labels
    left = (grid.w - RECAP_W) / 2
    labels = [
      { x: left, y: grid.h - RECAP_TOP - 30, text: "Willkommen zurück, #{diver_name}",
        size_enum: 6, vertical_alignment_enum: 2, r: 255, g: 244, b: 205 },
      { x: left, y: grid.h - RECAP_TOP - 88, text: "Tag #{state.day}   ·   #{DAY_NAMES[time_of_day]}",
        size_enum: 2, vertical_alignment_enum: 2, r: 150, g: 198, b: 224 },
      { x: left, y: grid.h - RECAP_TOP - 126, text: recap_note, size_enum: 1,
        vertical_alignment_enum: 2, r: 150, g: 198, b: 224, a: 200 },
    ]

    y = recap_rows_top
    recap_rows.each do |label, value|
      labels << { x: left, y: y, text: label, size_enum: 2, vertical_alignment_enum: 2,
                  r: MENU_DIM_INK[0], g: MENU_DIM_INK[1], b: MENU_DIM_INK[2] }
      labels << { x: left + RECAP_W, y: y, text: value, size_enum: 4, alignment_enum: 2,
                  vertical_alignment_enum: 2, r: MENU_INK[0], g: MENU_INK[1], b: MENU_INK[2] }
      y -= RECAP_ROW_H
    end

    labels << { x: left, y: recap_prompt_y, text: recap_prompt, size_enum: 3,
                r: 255, g: 244, b: 205, a: Kernel.tick_count.idiv(30).even? ? 255 : 140 }
    labels
  end

  def recap_prompt
    state.touch_seen ? "Tippen — okay, weiter" : "[ Leertaste ]  okay, weiter"
  end
end

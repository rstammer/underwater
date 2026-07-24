class Game
  MENU_W = 900
  MENU_H = 470
  MENU_BG = [14, 34, 54]
  MENU_ACCENT = [120, 190, 220]
  MENU_INK = [232, 244, 252]
  MENU_DIM_INK = [150, 184, 208]
  MENU_WARN = [240, 200, 150]

  MENU_PAD = 32
  MENU_ROW_H = 52     # one line of the logbook, one row of either list
  MENU_COL_W = 250    # the pack and hold columns
  MENU_LOG_W = 250    # the tally on the left
  MENU_ICON_X = 22    # where an item's icon sits inside its row
  MENU_RULE_GAP = 8   # air between a column title and the rule under it
  MENU_VEIL = 190     # how far the frozen world behind the screen is dimmed

  # The boat screen, opened with L while you're at the boat. The world sits
  # frozen behind a dim veil; this is home base — the round's dive tallied up on
  # the left, and on the right what you carry against what lies in the hold, so
  # you can trade the two around before heading back out. L or ESC drops you
  # back in the water (handled in update_home_menu).
  def home_menu_tick
    render_underwater # the frozen world behind the veil
    outputs.sprites << { x: 0, y: 0, w: grid.w, h: grid.h, r: 4, g: 12, b: 22, a: MENU_VEIL, path: :solid }
    render_boat_screen
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

  def render_boat_screen
    left = (grid.w - MENU_W) / 2
    bottom = (grid.h - MENU_H) / 2
    right = left + MENU_W
    top = bottom + MENU_H

    # Solid, not translucent: the sea behind it is pretty, but reading what you
    # carry against what's in the hold is what this screen is for.
    outputs.sprites << { x: left, y: bottom, w: MENU_W, h: MENU_H,
                         r: MENU_BG[0], g: MENU_BG[1], b: MENU_BG[2], path: :solid }
    outputs.sprites << { x: left, y: top - 4, w: MENU_W, h: 4,
                         r: MENU_ACCENT[0], g: MENU_ACCENT[1], b: MENU_ACCENT[2], path: :solid }

    outputs.labels << { x: left + MENU_PAD, y: top - MENU_PAD, text: "Dein Boot", size_enum: 4,
                        vertical_alignment_enum: 2, r: MENU_INK[0], g: MENU_INK[1], b: MENU_INK[2] }
    outputs.labels << { x: right - MENU_PAD, y: top - MENU_PAD - 4, text: diver_name, size_enum: 1,
                        alignment_enum: 2, vertical_alignment_enum: 2,
                        r: MENU_DIM_INK[0], g: MENU_DIM_INK[1], b: MENU_DIM_INK[2] }

    head_y = top - MENU_PAD - 60
    row_y = top - MENU_PAD - 128 # clear of the rule under the headings
    render_logbook(left + MENU_PAD, head_y, row_y)
    render_pack_column(left + MENU_PAD + 316, head_y, row_y)
    render_hold_column(left + MENU_PAD + 584, head_y, row_y)

    outputs.labels << { x: (left + right) / 2, y: bottom + MENU_PAD,
                        text: "Pfeiltasten wählen   ·   [ E ] verschieben   ·   L / ESC schließen",
                        size_enum: 1, alignment_enum: 1, vertical_alignment_enum: 2,
                        r: MENU_DIM_INK[0], g: MENU_DIM_INK[1], b: MENU_DIM_INK[2] }
  end

  def render_logbook(x, head_y, row_y)
    column_heading(x, head_y, "Logbuch", MENU_LOG_W)

    logbook_rows.each do |label, value|
      outputs.labels << { x: x, y: row_y, text: label, size_enum: 1,
                          vertical_alignment_enum: 2,
                          r: MENU_DIM_INK[0], g: MENU_DIM_INK[1], b: MENU_DIM_INK[2] }
      outputs.labels << { x: x + MENU_LOG_W, y: row_y, text: value, size_enum: 2, alignment_enum: 2,
                          vertical_alignment_enum: 2, r: MENU_INK[0], g: MENU_INK[1], b: MENU_INK[2] }
      row_y -= MENU_ROW_H
    end
  end

  # What you're carrying: one row per piece, INVENTORY_MAX slots deep, so the
  # empty rows show how much room is left. Turns warm when there's none.
  def render_pack_column(x, head_y, row_y)
    full = inventory_full?
    column_heading(x, head_y, "Rucksack  #{state.inventory.length} / #{INVENTORY_MAX}", MENU_COL_W,
                   full ? MENU_WARN : nil)

    INVENTORY_MAX.times do |i|
      kind = state.inventory[i]
      y = row_y - i * MENU_ROW_H
      if kind
        render_exchange_row(x, y, kind, nil, selected?(PACK_SIDE, i), true)
      else
        empty_row(x, y, "—")
      end
    end
  end

  # The hold: one row per kind with how many of it are down there. Rows go dim
  # while the pack is full — nothing can come up until something goes back.
  def render_hold_column(x, head_y, row_y)
    stacks = hold_stacks
    column_heading(x, head_y, "Lager  #{state.stash.length}", MENU_COL_W)
    return empty_row(x, row_y, "leer") if stacks.empty?

    stacks.each_with_index do |stack, i|
      render_exchange_row(x, row_y - i * MENU_ROW_H, stack[:kind], stack[:count],
                          selected?(HOLD_SIDE, i), !inventory_full?)
    end
  end

  def selected?(side, index)
    state.exchange_side == side && state.exchange_index == index
  end

  # A column title with a rule under it. The label hangs from its top edge
  # (vertical_alignment_enum: 2), so the rule has to clear the text's actual
  # height — a fixed offset ran the line straight through the letters.
  def column_heading(x, y, text, width, color = nil)
    color ||= MENU_DIM_INK
    outputs.labels << { x: x, y: y, text: text, size_enum: 1, vertical_alignment_enum: 2,
                        r: color[0], g: color[1], b: color[2] }
    outputs.sprites << { x: x, y: y - text_height(text, 1) - MENU_RULE_GAP, w: width, h: 1,
                         r: MENU_ACCENT[0], g: MENU_ACCENT[1], b: MENU_ACCENT[2], a: 60, path: :solid }
  end

  def text_height(text, size_enum)
    args.gtk.calcstringbox(text, size_enum)[1]
  end

  # One line of either list: the item's icon, its name, and — in the hold — how
  # many of them there are. The selected row gets a lit bar behind it.
  def render_exchange_row(x, y, kind, count, selected, live)
    if selected
      outputs.sprites << { x: x - 12, y: y - 22, w: MENU_COL_W + 24, h: 44,
                           r: MENU_ACCENT[0], g: MENU_ACCENT[1], b: MENU_ACCENT[2],
                           a: live ? 55 : 30, path: :solid }
    end

    sprite = ITEM_SPRITES[kind]
    outputs.sprites << { x: x + MENU_ICON_X, y: y, w: sprite[:w] * 2, h: sprite[:h] * 2,
                         path: sprite[:path], anchor_x: 0.5, anchor_y: 0.5,
                         a: live ? 255 : 120 }

    ink = live ? MENU_INK : MENU_DIM_INK
    outputs.labels << { x: x + 52, y: y, text: ITEM_NAMES[kind], size_enum: 1,
                        vertical_alignment_enum: 1, r: ink[0], g: ink[1], b: ink[2] }
    return unless count

    outputs.labels << { x: x + MENU_COL_W, y: y, text: "#{count}", size_enum: 2, alignment_enum: 2,
                        vertical_alignment_enum: 1, r: ink[0], g: ink[1], b: ink[2] }
  end

  def empty_row(x, y, text)
    outputs.labels << { x: x + 52, y: y, text: text, size_enum: 1, vertical_alignment_enum: 1,
                        r: MENU_DIM_INK[0], g: MENU_DIM_INK[1], b: MENU_DIM_INK[2], a: 130 }
  end
end

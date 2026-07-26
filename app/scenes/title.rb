# The title, and the shelf of careers on it. Reopens Game.
#
# It used to be a doorway with one book behind it: carry that book on, or put it
# down and start over. "Start over" wrote the new diver straight over the old,
# which is how a career got lost — so the choice is no longer one book against
# nothing, it is which of five you are opening.
#
# The screen itself is built on the game's own sea (render_boat_horizon), left
# aligned in one column, with the panel's top edge on the waterline. What sits
# in the panel is the shelf: five rows, each either a diver or an empty slot,
# and pressing on opens the one you are pointing at. Nothing is ever written
# over without you saying so, and deleting takes a second press.
class Game
  TITLE_LEFT = 92
  TITLE_CARD_W = 680
  TITLE_CARD_PAD = 24
  TITLE_ROW_H = 56
  TITLE_WORDMARK = "Underwater"
  TITLE_WORDMARK_SIZE = 22
  TITLE_TAGLINE = "Tauche ein und erkunde die Unterwasserwelt"
  TITLE_BAR_W = 12
  TITLE_INK = [236, 246, 255]
  TITLE_GOLD = [255, 244, 205]
  # The head sits on the *sky*, which is the brightest thing in the game. Light
  # type on it was a whisper; dark type on it is a poster. Same navy as the panel
  # below, so the wordmark up in the air and the shelf down in the water read as
  # one piece of furniture rather than two designs.
  TITLE_HEAD_INK = [8, 34, 58]
  TITLE_HEAD_DIM = [24, 68, 100]

  # Fish drifting across the water half: real species off the roster, so the
  # title shows the things you are going to be photographing. One to a lane and
  # slow — they are the movement on an otherwise still screen. Every y is under
  # HORIZON, because that is where the water is.
  TITLE_FISH = [
    { key: "hornhering", y: 372, speed: 0.55, size: 3, dir: 1 },
    { key: "burgunder",  y: 286, speed: 0.40, size: 3, dir: -1 },
    { key: "rabauke",    y: 190, speed: 0.62, size: 3, dir: 1 },
    # Under the hint line, not through it: the shelf takes most of the water
    # now, and at y 104 this one swam straight across "[ Leertaste ] öffnen".
    { key: "scalarus",   y: 40, speed: 0.34, size: 2, dir: -1 },
  ]

  def title_tick
    read_title_input

    render_boat_horizon # the game's own sea, from the surface beside the boat
    outputs.sprites << title_fish
    render_title_head
    render_title_card
    render_title_shelf
    outputs.labels << title_labels
  end

  # --- the shelf --------------------------------------------------------------

  def title_row
    row = state.title_row || 0
    row = 0 if row < 0 || row >= SAVE_SLOTS
    state.title_row = row
    row
  end

  def title_slot
    title_row + 1
  end

  def move_title_row(by)
    state.title_row = (title_row + by) % SAVE_SLOTS
    state.title_confirm = nil # pointing somewhere else calls the deletion off
  end

  # Space opens whatever the cursor is on: a diver you carry on, an empty slot
  # you start in. There is no way to land on a career you did not point at.
  def open_title_slot
    slot = title_slot
    slot_used?(slot) ? continue_round(slot) : fresh_round(slot)
  end

  # Deleting takes two presses, and the first one says which career it means.
  # This is the one action on the screen that destroys something.
  def ask_to_delete
    return unless slot_used?(title_slot)

    state.title_confirm = title_slot
  end

  def confirming_delete?
    state.title_confirm == title_slot
  end

  def read_title_input
    # Down goes down the screen. Row zero is drawn at the top (title_row_y), so
    # the arrow and the index run the same way — they were inverted, copied from
    # a shop shelf that had it inverted too.
    move_title_row(1) if inputs.keyboard.key_down.down
    move_title_row(-1) if inputs.keyboard.key_down.up
    return read_delete_input if state.title_confirm

    if inputs.keyboard.key_down.delete || inputs.keyboard.key_down.backspace ||
       inputs.keyboard.key_down.x
      return ask_to_delete
    end

    # A tap opens the row it landed on, not the row the cursor happens to be on:
    # on a phone the finger *is* the cursor.
    tapped = (1..SAVE_SLOTS).find { |slot| tapped?(:"slot_#{slot}") }
    if tapped
      state.title_row = tapped - 1
      return open_title_slot
    end

    open_title_slot if fire_input?
  end

  def read_delete_input
    if inputs.keyboard.key_down.escape || fire_input?
      return state.title_confirm = nil
    end

    return unless inputs.keyboard.key_down.delete || inputs.keyboard.key_down.backspace ||
                  inputs.keyboard.key_down.x

    delete_slot(state.title_confirm)
    state.title_confirm = nil
  end

  # One row per slot, as data: what it says is testable without drawing it.
  def title_rows
    (1..SAVE_SLOTS).map do |slot|
      summary = slot_summary(slot)
      { slot: slot, summary: summary,
        title: summary ? summary[:name] : "— leerer Platz —",
        detail: summary ? title_row_detail(summary) : "hier eine neue Laufbahn anfangen" }
    end
  end

  def title_row_detail(summary)
    "Tag #{summary[:day]}   ·   #{summary[:documented]} von #{summary[:sighted]} Arten" \
      "   ·   #{summary[:credits]} Cr"
  end

  # --- what there is to press -------------------------------------------------

  # A row is a button, so a thumb can pick a career the same way the arrows do.
  def title_layout
    x = TITLE_LEFT + TITLE_CARD_PAD
    w = TITLE_CARD_W - TITLE_CARD_PAD * 2
    (1..SAVE_SLOTS).map do |slot|
      { id: :"slot_#{slot}", label: "Platz #{slot}", w: w, h: TITLE_ROW_H - 6,
        x: x, y: title_row_y(slot - 1) }
    end
  end

  def title_row_y(index)
    title_card_top - TITLE_CARD_PAD - (index + 1) * TITLE_ROW_H + 3
  end

  # --- the layout -------------------------------------------------------------

  # The panel's top edge is the waterline. Not a coincidence to be maintained by
  # hand: both read HORIZON, so the sea and the type are laid out against the
  # same line.
  def title_card_top
    HORIZON
  end

  def title_card_h
    TITLE_CARD_PAD * 2 + SAVE_SLOTS * TITLE_ROW_H
  end

  def title_card_bottom
    title_card_top - title_card_h
  end

  def title_head_y
    grid.h - 58
  end

  # --- drawing ---------------------------------------------------------------

  # The wordmark, up in the sky, with a solid bar beside it. The bar is measured
  # against the type rather than given a number — the wordmark's height is the
  # font's business, and a guessed bar was a bar that did not line up.
  def render_title_head
    wordmark_h = text_height(TITLE_WORDMARK, TITLE_WORDMARK_SIZE)
    tagline_h = text_height(TITLE_TAGLINE, 3)
    bar_h = wordmark_h + tagline_h + 18

    outputs.sprites << { x: TITLE_LEFT, y: title_head_y - bar_h, w: TITLE_BAR_W, h: bar_h,
                         r: TITLE_HEAD_INK[0], g: TITLE_HEAD_INK[1], b: TITLE_HEAD_INK[2],
                         path: :solid }
  end

  def render_title_card
    # Opaque, not a wash: at 224 a fish drifting past showed through the panel
    # and read as a stain on it.
    outputs.sprites << { x: TITLE_LEFT, y: title_card_bottom, w: TITLE_CARD_W, h: title_card_h,
                         r: 6, g: 22, b: 40, path: :solid }
    outputs.sprites << { x: TITLE_LEFT, y: title_card_top - 4, w: TITLE_CARD_W, h: 4,
                         r: MENU_ACCENT[0], g: MENU_ACCENT[1], b: MENU_ACCENT[2], path: :solid }
  end

  def render_title_shelf
    title_rows.each_with_index do |row, i|
      here = title_row == i
      button = title_layout[i]
      pressed = (state.touch_pressed || []).include?(button[:id])
      used = !row[:summary].nil?

      outputs.sprites << { x: button[:x], y: button[:y], w: button[:w], h: button[:h],
                           r: MENU_PANEL[0], g: MENU_PANEL[1], b: MENU_PANEL[2],
                           a: here ? (pressed ? 255 : 235) : 90, path: :solid }
      outputs.sprites << { x: button[:x], y: button[:y], w: 4, h: button[:h],
                           r: MENU_ACCENT[0], g: MENU_ACCENT[1], b: MENU_ACCENT[2],
                           a: here ? 255 : 0, path: :solid }

      outputs.labels << { x: button[:x] + 18, y: button[:y] + button[:h] - 12,
                          text: "#{row[:slot]}", size_enum: 1, vertical_alignment_enum: 2,
                          r: MENU_DIM_INK[0], g: MENU_DIM_INK[1], b: MENU_DIM_INK[2] }

      ink = used ? (here ? TITLE_GOLD : TITLE_INK) : MENU_DIM_INK
      outputs.labels << { x: button[:x] + 44, y: button[:y] + button[:h] - 10,
                          text: row[:title], size_enum: 2, vertical_alignment_enum: 2,
                          r: ink[0], g: ink[1], b: ink[2] }
      detail = here && state.title_confirm == row[:slot] ? title_delete_warning : row[:detail]
      colour = here && state.title_confirm == row[:slot] ? MENU_WARN : MENU_DIM_INK
      outputs.labels << { x: button[:x] + 44, y: button[:y] + button[:h] - 34,
                          text: detail, size_enum: 0, vertical_alignment_enum: 2,
                          r: colour[0], g: colour[1], b: colour[2] }
    end
  end

  def title_delete_warning
    "Wirklich löschen?   [ Entf ] ja   ·   [ Enter ] nein"
  end

  def title_fish
    span = grid.w + 240
    TITLE_FISH.each_with_index.map do |f, i|
      species = Species[f[:key]]
      frame = 0.frame_index(count: species.frames_per_row, hold_for: 8, repeat: true) || 0
      travel = (Kernel.tick_count * f[:speed] + i * 320) % span
      x = f[:dir] > 0 ? travel - 120 : grid.w + 120 - travel
      {
        x: x,
        y: f[:y],
        w: species.frame_w * f[:size],
        h: species.frame_h * f[:size],
        path: species.sheet,
        source_x: species.frame_w * frame,
        source_y: species.frame_h * (frame / species.frames_per_row).floor,
        source_w: species.frame_w,
        source_h: species.frame_h,
        flip_horizontally: f[:dir] < 0,
      }
    end
  end

  # Everything written on the screen apart from the shelf, which carries its own
  # type. One method so a test can read the screen without drawing it.
  def title_labels
    wordmark_h = text_height(TITLE_WORDMARK, TITLE_WORDMARK_SIZE)
    labels = [
      { x: TITLE_LEFT + 34, y: title_head_y, text: TITLE_WORDMARK,
        size_enum: TITLE_WORDMARK_SIZE, vertical_alignment_enum: 2,
        r: TITLE_HEAD_INK[0], g: TITLE_HEAD_INK[1], b: TITLE_HEAD_INK[2] },
      { x: TITLE_LEFT + 36, y: title_head_y - wordmark_h - 14, text: TITLE_TAGLINE,
        size_enum: 3, vertical_alignment_enum: 2,
        r: TITLE_HEAD_DIM[0], g: TITLE_HEAD_DIM[1], b: TITLE_HEAD_DIM[2] },
    ]
    return labels if state.touch_seen # a phone has no keys to list

    labels << { x: TITLE_LEFT, y: title_card_bottom - 22, text: title_hint,
                size_enum: 1, vertical_alignment_enum: 2,
                r: 188, g: 214, b: 236, a: 220 }
    labels
  end

  def title_hint
    return "[ Entf ] löschen wirklich   ·   [ Enter ] abbrechen" if state.title_confirm

    "↑ ↓ wählen   ·   [ Enter ] öffnen   ·   [ Entf ] löschen"
  end

  # Still asked by the touch layout and by anything that wants to know whether
  # there is a career on this machine at all.
  def saved_book?
    any_slot_used?
  end
end

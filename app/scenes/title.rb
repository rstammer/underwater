# The title. Reopens Game.
#
# It used to be a picture of its own — a flat blue gradient, four vertical shafts
# of light, a seabed of evenly spaced weed, twenty bubbles on random paths and a
# small diver bobbing in the middle — with the wordmark, the diver's name, the
# book's tally, the controls and two key prompts all stacked down the centre. The
# background was not this game's sea, and the bottom third was five lines of type
# printing over each other.
#
# So it is built the way every other screen outside the water is now: the game's
# own sea, drawn by the game's own renderer and parked beside the boat
# (render_boat_horizon), with everything written left-aligned in one column that
# hangs off the horizon. Fewer, bigger things: a wordmark with a bar beside it, a
# panel whose top edge *is* the waterline, and the choice as two solid buttons
# rather than as two lines of prompt text.
#
# The buttons are drawn from the same list the hit-test reads (title_layout), and
# now they are drawn for everybody: a keyboard player sees the key written on the
# button they would press, so there is one thing on the screen instead of a
# button for phones and a sentence for desktops.
class Game
  TITLE_LEFT = 92
  TITLE_CARD_W = 560
  TITLE_CARD_PAD = 26
  TITLE_BUTTON_H = 62
  TITLE_BUTTON_GAP = 12
  TITLE_WORDMARK = "Underwater"
  TITLE_WORDMARK_SIZE = 22
  TITLE_TAGLINE = "Tauche ein und erkunde die Unterwasserwelt"
  TITLE_BAR_W = 12
  TITLE_INK = [236, 246, 255]
  TITLE_GOLD = [255, 244, 205]
  # The head sits on the *sky*, which is the brightest thing in the game. Light
  # type on it was a whisper; dark type on it is a poster. Same navy as the panel
  # below, so the wordmark up in the air and the card down in the water read as
  # one piece of furniture rather than two designs.
  TITLE_HEAD_INK = [8, 34, 58]
  TITLE_HEAD_DIM = [24, 68, 100]

  # Fish drifting across the water half: real species off the roster, so the
  # title shows the things you are going to be photographing. One to a lane and
  # slow — they are the movement on an otherwise still screen, and a shoal of
  # them darting about was noise. Every y is under HORIZON, because that is where
  # the water is.
  # dir +1 swims right, -1 swims left (sprite flipped).
  TITLE_FISH = [
    { key: "hornhering", y: 372, speed: 0.55, size: 3, dir: 1 },
    { key: "burgunder",  y: 286, speed: 0.40, size: 3, dir: -1 },
    { key: "rabauke",    y: 190, speed: 0.62, size: 3, dir: 1 },
    { key: "scalarus",   y: 104, speed: 0.34, size: 2, dir: -1 },
  ]

  def title_tick
    read_title_input

    render_boat_horizon # the game's own sea, from the surface beside the boat
    outputs.sprites << title_fish
    render_title_head
    render_title_card
    render_title_buttons
    outputs.labels << title_labels
  end

  # With a book on disk the title is a choice rather than a doorway: carry it on,
  # or put it down and start over. Without one there is nothing to choose, so a
  # key — or a tap anywhere, on a phone — just goes.
  def read_title_input
    return title_choice if saved_book?
    return unless fire_input? || touch_began?

    state.game_scene = "name"
  end

  def title_choice
    return continue_round if fire_input? || tapped?(:carry_on)

    fresh_round if inputs.keyboard.key_down.n || tapped?(:start_over)
  end

  # --- what there is to choose ----------------------------------------------
  #
  # The actions as data, without any geometry: the card's height is worked out
  # from how many there are, and the geometry is worked out from the height, so
  # the two cannot be asked for in a circle.

  def title_actions
    return [[:carry_on, "Weitertauchen", "Leertaste"],
            [:start_over, "Neu anfangen", "N"]] if saved_book?

    [[:begin, "Tauchgang beginnen", "Leertaste"]]
  end

  def title_layout
    x = TITLE_LEFT + TITLE_CARD_PAD
    w = TITLE_CARD_W - TITLE_CARD_PAD * 2
    top = title_card_top - TITLE_CARD_PAD - title_card_head_h
    title_actions.each_with_index.map do |action, i|
      { id: action[0], label: action[1], key: action[2], x: x, w: w, h: TITLE_BUTTON_H,
        y: top - (i + 1) * TITLE_BUTTON_H - i * TITLE_BUTTON_GAP }
    end
  end

  # --- the layout ------------------------------------------------------------

  # The panel's top edge is the waterline. Not a coincidence to be maintained by
  # hand: both read HORIZON, so the sea and the type are laid out against the
  # same line.
  def title_card_top
    HORIZON
  end

  def title_card_head_h
    saved_book? ? 96 : 52
  end

  def title_card_h
    count = title_actions.length
    TITLE_CARD_PAD * 2 + title_card_head_h +
      count * TITLE_BUTTON_H + (count - 1) * TITLE_BUTTON_GAP
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

  # The first action is the one you came for, so it is the solid one. The key is
  # written on the button it belongs to; on a phone there is no key to write, and
  # the label is the whole of it.
  def render_title_buttons
    title_layout.each_with_index do |button, i|
      primary = i.zero?
      pressed = (state.touch_pressed || []).include?(button[:id])
      fill = primary ? MENU_ACCENT : MENU_PANEL
      outputs.sprites << { x: button[:x], y: button[:y], w: button[:w], h: button[:h],
                           r: fill[0], g: fill[1], b: fill[2],
                           a: pressed ? 255 : (primary ? 235 : 200), path: :solid }
      unless primary
        outputs.sprites << { x: button[:x], y: button[:y], w: button[:w], h: 2,
                             r: MENU_ACCENT[0], g: MENU_ACCENT[1], b: MENU_ACCENT[2],
                             a: 150, path: :solid }
      end

      ink = primary ? [10, 28, 44] : TITLE_INK
      outputs.labels << { x: button[:x] + 24, y: button[:y] + button[:h] / 2 + 1,
                          text: button[:label], size_enum: 3, vertical_alignment_enum: 1,
                          r: ink[0], g: ink[1], b: ink[2] }
      next if state.touch_seen

      outputs.labels << { x: button[:x] + button[:w] - 24, y: button[:y] + button[:h] / 2 + 1,
                          text: button[:key], size_enum: 1, alignment_enum: 2,
                          vertical_alignment_enum: 1, r: ink[0], g: ink[1], b: ink[2],
                          a: primary && Kernel.tick_count.idiv(30).even? ? 255 : 170 }
    end
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

  # How much there is to carry on with, said in the terms the book itself uses.
  def saved_book_summary
    book = state.saved_book
    "#{book[:album].length} von #{book[:sighted].length} gesichteten Arten   ·   Tag #{book[:day] || 1}"
  end

  # Everything written on the screen apart from the buttons, which carry their
  # own type. One method so a test can read the screen without drawing it.
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
    title_card_labels(labels)
    return labels if state.touch_seen # a phone has no keys to list

    labels << { x: grid.w / 2, y: 68, text: "Pfeile / WASD  bewegen      Leertaste  sprinten      ESC  Pause",
                size_enum: 1, alignment_enum: 1, vertical_alignment_enum: 2,
                r: 188, g: 214, b: 236, a: 210 }
    labels
  end

  # The head of the card. The name it was kept under goes first: what is being
  # offered is *that diver's* book, not a save slot.
  def title_card_labels(labels)
    x = TITLE_LEFT + TITLE_CARD_PAD
    y = title_card_top - TITLE_CARD_PAD
    unless saved_book?
      labels << { x: x, y: y, text: "Ein neues Artenbuch, ein leeres Meer.", size_enum: 1,
                  vertical_alignment_enum: 2,
                  r: MENU_DIM_INK[0], g: MENU_DIM_INK[1], b: MENU_DIM_INK[2] }
      return labels
    end

    name = state.saved_book[:name]
    name = DIVER_NAME if name.nil? || name.empty?
    labels << { x: x, y: y, text: name, size_enum: 5, vertical_alignment_enum: 2,
                r: TITLE_GOLD[0], g: TITLE_GOLD[1], b: TITLE_GOLD[2] }
    labels << { x: x, y: y - 46, text: saved_book_summary, size_enum: 1,
                vertical_alignment_enum: 2,
                r: MENU_DIM_INK[0], g: MENU_DIM_INK[1], b: MENU_DIM_INK[2] }
    labels
  end
end

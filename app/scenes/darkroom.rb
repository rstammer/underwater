# The darkroom: the prints coming out of the tank, pinned up to be read. Reopens Game.
#
# Developing used to be a keypress that moved numbers in silence. The film went,
# the balance went up, and the one moment the whole game is *for* — a species
# nobody had, now on paper with a name and a date — went past unremarked, three
# menus deep in the Artenbuch if you thought to go and look.
#
# So the tank stops the game. Each frame that made it into the book gets a print:
# the animal itself, what it is called, how big it actually is (which the sprite
# cannot say — a crab and a shark are both a handful of pixels), the day it was
# taken, and what the magazine paid. Nothing here changes anything; develop_film
# has already banked all of it, so a print wall can be looked at for as long as
# you like and closing the game during one loses nothing.
class Game
  DARKROOM_MARGIN = 26
  DARKROOM_PAD = 26
  DARKROOM_HEAD = 92     # the band with the title and what the roll earned
  DARKROOM_FOOT = 46
  DARKROOM_GAP = 16
  DARKROOM_COLS = 4
  DARKROOM_ROWS = 2
  DARKROOM_PER_PAGE = DARKROOM_COLS * DARKROOM_ROWS
  DARKROOM_CAPTION_H = 112 # the written half of a print, under the picture
  DARKROOM_INSET = 12      # white edge around the picture, the way a print has one
  PRINT_BG = [8, 26, 44]
  PRINT_EDGE = [214, 230, 240]
  NEW_BADGE = [236, 226, 150]

  # Opened by developing, and only if the tank actually produced something —
  # a blank screen saying nothing came out would be worse than the old silence.
  def open_darkroom
    prints = state.developed_roll
    return if prints.nil? || prints.empty?

    state.game_scene = "darkroom"
    state.darkroom_page = 0
    # The very press that opened it must not also be read as "seen it, thanks".
    # A key_down (or a tap) is true for a whole tick, and darkroom_tick runs
    # later in the same one — the exact trap ESC fell into with the pause menu.
    state.developed_at = Kernel.tick_count
  end

  def close_darkroom
    state.developed_roll = []
    resume_scene
  end

  def darkroom_tick
    read_darkroom_input
    render_underwater # the frozen sea beside the boat ...
    render_fog        # ... and whatever dark belongs with it
    outputs.sprites << { x: 0, y: 0, w: grid.w, h: grid.h,
                         r: 3, g: 10, b: 18, a: 218, path: :solid }
    render_darkroom
  end

  def read_darkroom_input
    return if state.developed_at == Kernel.tick_count

    turn_darkroom_page(-1) if inputs.keyboard.key_down.left
    turn_darkroom_page(1) if inputs.keyboard.key_down.right
    return close_darkroom if fire_input? || inputs.keyboard.key_down.f
    return unless touch_began?

    # On a phone there are no arrow keys, so a tap walks the wall and the last
    # print is the way out. One rule, and the prompt says which half you are on.
    darkroom_last_page? ? close_darkroom : turn_darkroom_page(1)
  end

  # --- what is on the wall ---------------------------------------------------

  def darkroom_prints
    state.developed_roll || []
  end

  def darkroom_pages
    pages = (darkroom_prints.length + DARKROOM_PER_PAGE - 1).idiv(DARKROOM_PER_PAGE)
    pages < 1 ? 1 : pages
  end

  # Clamped rather than trusted, the way the Artenbuch's is: a page left over
  # from a fuller roll would show an empty wall.
  def darkroom_page_prints
    page = state.darkroom_page || 0
    page = darkroom_pages - 1 if page >= darkroom_pages
    page = 0 if page < 0
    state.darkroom_page = page
    darkroom_prints[page * DARKROOM_PER_PAGE, DARKROOM_PER_PAGE] || []
  end

  def turn_darkroom_page(by)
    state.darkroom_page = ((state.darkroom_page || 0) + by) % darkroom_pages
  end

  def darkroom_last_page?
    (state.darkroom_page || 0) >= darkroom_pages - 1
  end

  def darkroom_earned
    darkroom_prints.reduce(0) { |sum, print| sum + print[:fee] }
  end

  def darkroom_discoveries
    darkroom_prints.count { |print| print[:fresh] }
  end

  # One line on what the roll came to, in the terms the game counts in: pages
  # are the point, money is the consequence.
  def darkroom_verdict
    new_ones = darkroom_discoveries
    return "Nichts Neues auf dem Film — aber die Bilder sind besser als die alten." if new_ones.zero?
    return "Eine neue Art im Artenbuch." if new_ones == 1

    "#{new_ones} neue Arten im Artenbuch."
  end

  # --- drawing ---------------------------------------------------------------

  def darkroom_left
    DARKROOM_MARGIN + DARKROOM_PAD
  end

  def darkroom_right
    grid.w - DARKROOM_MARGIN - DARKROOM_PAD
  end

  def darkroom_body_top
    grid.h - DARKROOM_MARGIN - DARKROOM_HEAD
  end

  def darkroom_body_bottom
    DARKROOM_MARGIN + DARKROOM_FOOT
  end

  def darkroom_card_w
    (darkroom_right - darkroom_left - DARKROOM_GAP * (DARKROOM_COLS - 1)).idiv(DARKROOM_COLS)
  end

  def darkroom_card_h
    (darkroom_body_top - darkroom_body_bottom - DARKROOM_GAP * (DARKROOM_ROWS - 1)).idiv(DARKROOM_ROWS)
  end

  def render_darkroom
    render_darkroom_head
    darkroom_page_prints.each_with_index do |print, i|
      col = i % DARKROOM_COLS
      row = i.idiv(DARKROOM_COLS)
      x = darkroom_left + col * (darkroom_card_w + DARKROOM_GAP)
      y = darkroom_body_top - (row + 1) * darkroom_card_h - row * DARKROOM_GAP
      render_print(x, y, darkroom_card_w, darkroom_card_h, print)
    end
    render_darkroom_foot
  end

  def render_darkroom_head
    top = grid.h - DARKROOM_MARGIN
    outputs.sprites << { x: DARKROOM_MARGIN, y: top - 4, w: grid.w - DARKROOM_MARGIN * 2, h: 4,
                         r: MENU_ACCENT[0], g: MENU_ACCENT[1], b: MENU_ACCENT[2], path: :solid }
    outputs.labels << { x: darkroom_left, y: top - 26, text: "Dunkelkammer", size_enum: 6,
                        vertical_alignment_enum: 2, r: 255, g: 244, b: 205 }
    outputs.labels << { x: darkroom_left, y: top - 66, text: darkroom_verdict, size_enum: 2,
                        vertical_alignment_enum: 2,
                        r: MENU_DIM_INK[0], g: MENU_DIM_INK[1], b: MENU_DIM_INK[2] }

    outputs.labels << { x: darkroom_right, y: top - 22, text: "+#{darkroom_earned} Cr",
                        size_enum: 8, alignment_enum: 2, vertical_alignment_enum: 2,
                        r: CREDIT_INK[0], g: CREDIT_INK[1], b: CREDIT_INK[2] }
    caption = darkroom_pages > 1 ? "Blatt #{state.darkroom_page + 1} / #{darkroom_pages}" : "Honorar"
    outputs.labels << { x: darkroom_right, y: top - 62, text: caption, size_enum: 0,
                        alignment_enum: 2, vertical_alignment_enum: 2,
                        r: MENU_DIM_INK[0], g: MENU_DIM_INK[1], b: MENU_DIM_INK[2] }
  end

  def render_darkroom_foot
    hint =
      if darkroom_pages > 1
        "← → blättern   ·   [ Leertaste ]  okay, weiter"
      else
        "[ Leertaste ]  okay, weiter"
      end
    hint = darkroom_last_page? ? "Tippen — okay, weiter" : "Tippen — weitere Bilder" if state.touch_seen
    outputs.labels << { x: grid.w / 2, y: DARKROOM_MARGIN + DARKROOM_FOOT - 12, text: hint,
                        size_enum: 1, alignment_enum: 1, vertical_alignment_enum: 2,
                        r: 255, g: 244, b: 205, a: Kernel.tick_count.idiv(30).even? ? 255 : 150 }
  end

  # One print: the animal in the picture, and under it what a field note would
  # say — what it is, in latin, how big, when, and what it fetched.
  def render_print(x, y, w, h, print)
    species = print[:species]
    picture_h = h - DARKROOM_CAPTION_H

    outputs.sprites << { x: x, y: y, w: w, h: h,
                         r: MENU_PANEL[0], g: MENU_PANEL[1], b: MENU_PANEL[2], path: :solid }
    render_picture(x, y + DARKROOM_CAPTION_H, w, picture_h, species, print[:quality])
    render_print_caption(x, y, w, print)
    return unless print[:fresh]

    # The badge is the whole reason this screen exists: it says which of these
    # nobody had before.
    outputs.sprites << { x: x + DARKROOM_INSET, y: y + h - DARKROOM_INSET - 22, w: 54, h: 22,
                         r: NEW_BADGE[0], g: NEW_BADGE[1], b: NEW_BADGE[2], path: :solid }
    outputs.labels << { x: x + DARKROOM_INSET + 27, y: y + h - DARKROOM_INSET - 11, text: "NEU",
                        size_enum: 0, alignment_enum: 1, vertical_alignment_enum: 1,
                        r: 12, g: 30, b: 48 }
  end

  # The picture itself, on a scrap of dark water with a white edge round it. The
  # sprite is scaled by a *whole* number that fits the space — pixel art at 7.3x
  # is pixel art with some rows twice as thick as others.
  def render_picture(x, y, w, h, species, quality)
    outputs.sprites << { x: x + DARKROOM_INSET, y: y + DARKROOM_INSET,
                         w: w - DARKROOM_INSET * 2, h: h - DARKROOM_INSET * 2,
                         r: PRINT_EDGE[0], g: PRINT_EDGE[1], b: PRINT_EDGE[2], a: 200, path: :solid }
    inner_x = x + DARKROOM_INSET + 3
    inner_y = y + DARKROOM_INSET + 3
    inner_w = w - DARKROOM_INSET * 2 - 6
    inner_h = h - DARKROOM_INSET * 2 - 6
    outputs.sprites << { x: inner_x, y: inner_y, w: inner_w, h: inner_h,
                         r: PRINT_BG[0], g: PRINT_BG[1], b: PRINT_BG[2], path: :solid }

    scale = fit_scale(species, inner_w - 16, inner_h - 16)
    outputs.sprites << { x: inner_x + inner_w / 2, y: inner_y + inner_h / 2,
                         w: species.frame_w * scale, h: species.frame_h * scale,
                         path: species.sheet, anchor_x: 0.5, anchor_y: 0.5,
                         source_x: 0, source_y: 0,
                         source_w: species.frame_w, source_h: species.frame_h,
                         # A blurred frame prints faint — the grade is visible in
                         # the picture, not only written under it.
                         a: quality == :unscharf ? 170 : 255 }
  end

  def fit_scale(species, w, h)
    scale = [w.idiv(species.frame_w), h.idiv(species.frame_h)].min
    scale < 1 ? 1 : scale
  end

  def render_print_caption(x, y, w, print)
    species = print[:species]
    left = x + DARKROOM_INSET + 4
    right = x + w - DARKROOM_INSET - 4

    outputs.labels << { x: left, y: y + DARKROOM_CAPTION_H - 12, text: species.name, size_enum: 1,
                        vertical_alignment_enum: 2,
                        r: MENU_INK[0], g: MENU_INK[1], b: MENU_INK[2] }
    outputs.labels << { x: left, y: y + DARKROOM_CAPTION_H - 40, text: species.latin, size_enum: 0,
                        vertical_alignment_enum: 2,
                        r: MENU_DIM_INK[0], g: MENU_DIM_INK[1], b: MENU_DIM_INK[2], a: 170 }
    outputs.labels << { x: left, y: y + DARKROOM_CAPTION_H - 64,
                        text: "#{species.size_label}   ·   Tag #{print[:day]}", size_enum: 0,
                        vertical_alignment_enum: 2,
                        r: MENU_DIM_INK[0], g: MENU_DIM_INK[1], b: MENU_DIM_INK[2] }
    outputs.labels << { x: left, y: y + DARKROOM_CAPTION_H - 88, text: print[:quality].to_s,
                        size_enum: 0, vertical_alignment_enum: 2,
                        r: MENU_INK[0], g: MENU_INK[1], b: MENU_INK[2] }
    outputs.labels << { x: right, y: y + DARKROOM_CAPTION_H - 88, text: "+#{print[:fee]} Cr",
                        size_enum: 0, alignment_enum: 2, vertical_alignment_enum: 2,
                        r: CREDIT_INK[0], g: CREDIT_INK[1], b: CREDIT_INK[2] }
  end
end

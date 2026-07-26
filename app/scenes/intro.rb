# The opening, as its own screen. Reopens Game.
#
# It used to be the card that hangs over the boat, read while floating alongside
# — a nice idea, and it stayed that way for a while, but a card that has to fit
# beside a boat is a narrow column of small type, and the story got longer as the
# game got a point. Prose wants room.
#
# So: one screen, once, between typing your name and going in the water. Left
# aligned, because centred prose is pretty and hard to read. Behind it the game's
# own sea — the real renderer, at the boat, seen from the surface — rather than
# an abstract gradient, so the opening is a place and not a title card.
class Game
  INTRO_W = 800       # the text column
  INTRO_LINE_H = 30
  INTRO_GAP_H = 14    # a blank line in story_lines is a paragraph break
  INTRO_TOP = 44      # air above the panel ...
  INTRO_PAD = 34
  # Where the gulls hang, as [x, y, how fast they drift]. Off over the water,
  # which is where gulls are.
  INTRO_GULLS = [[210, 596, 150.0], [430, 640, 190.0], [980, 612, 120.0], [1140, 656, 230.0]]

  def intro_tick
    if fire_input? || touch_began?
      start_round
      return
    end

    render_intro_sea
    render_intro_panel
    outputs.labels << intro_labels
  end

  # The game's own sea, drawn by the game's own renderer. The camera is put where
  # the boat is and high enough to show the waterline; the diver is still floating
  # at the surface from initialize_game, so submerged_visible? is false and the
  # sea floor stays out of it — which is exactly the clean horizon this wants.
  def render_intro_sea
    render_boat_horizon
    outputs.sprites << intro_gulls
  end

  def intro_gulls
    sprite = DECOR_SPRITES["gull"]
    INTRO_GULLS.map do |x, y, period|
      { x: x + Math.sin(Kernel.tick_count / period) * 120,
        y: y + Math.sin(Kernel.tick_count / (period / 3.2)) * 9,
        w: sprite[:w] * 3, h: sprite[:h] * 3, path: sprite[:path],
        anchor_x: 0.5, anchor_y: 0.5 }
    end
  end

  # A dark panel so the type has something to sit on — the sky behind it is far
  # too bright for small text. Sized from the text it actually holds, top down,
  # so the prompt can never end up printed over the last paragraph again.
  def render_intro_panel
    left = (grid.w - INTRO_W) / 2 - INTRO_PAD
    bottom = intro_prompt_y - 30
    top = grid.h - INTRO_TOP

    outputs.sprites << { x: left, y: bottom, w: INTRO_W + INTRO_PAD * 2, h: top - bottom,
                         r: 6, g: 22, b: 40, a: 214, path: :solid }
    outputs.sprites << { x: left, y: top - 4, w: INTRO_W + INTRO_PAD * 2, h: 4,
                         r: MENU_ACCENT[0], g: MENU_ACCENT[1], b: MENU_ACCENT[2], a: 220, path: :solid }
  end

  # Where the story stops — the one number the whole layout hangs off, so nothing
  # has to guess where anything else went.
  def intro_body_bottom
    y = grid.h - INTRO_TOP - 84 # under the name
    story_lines.each { |line| y -= line.empty? ? INTRO_GAP_H : INTRO_LINE_H }
    y
  end

  def intro_prompt_y
    intro_body_bottom - 52
  end

  def intro_labels
    left = (grid.w - INTRO_W) / 2
    labels = [{ x: left, y: grid.h - INTRO_TOP - 32, text: diver_name, size_enum: 6,
                r: 255, g: 244, b: 205 }]

    y = grid.h - INTRO_TOP - 84
    story_lines.each do |line|
      unless line.empty?
        labels << { x: left, y: y, text: line, size_enum: 2, r: 216, g: 234, b: 248 }
      end
      y -= line.empty? ? INTRO_GAP_H : INTRO_LINE_H
    end

    labels << { x: left, y: intro_body_bottom - 8, text: story_closing, size_enum: 2,
                r: 150, g: 198, b: 224 }
    labels << intro_prompt(left)
    labels
  end

  def intro_prompt(left)
    text = state.touch_seen ? "Tippen zum Abtauchen" : "[ Leertaste ]  abtauchen"
    { x: left, y: intro_prompt_y, text: text, size_enum: 3, r: 255, g: 244, b: 205,
      a: Kernel.tick_count.idiv(30).even? ? 255 : 140 }
  end
end

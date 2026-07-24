# The pause menu. ESC (or the on-screen pause button) freezes the dive here
# rather than throwing the round away — the world sits behind a veil, oxygen and
# the suit hold, and you choose: carry on, or end the dive and go back to the
# title. Reopens Game.
class Game
  PAUSE_W = 640
  PAUSE_H = 320

  def pause_tick
    render_underwater # the frozen world behind the veil
    outputs.sprites << { x: 0, y: 0, w: grid.w, h: grid.h, r: 4, g: 12, b: 22, a: 170, path: :solid }
    read_pause_input
    render_pause_card
  end

  # Q ends the dive; ESC / Space / a tap carries on. ESC is handled in
  # update_escape (one place for that key); here we take Space, Q and taps. The
  # input that opened the menu this tick is ignored, or the same tap would open
  # and instantly resume.
  def read_pause_input
    return if state.paused_at == Kernel.tick_count

    if inputs.keyboard.key_down.q || tapped?(:quit)
      quit_to_title
    elsif fire_input? || touch_began?
      resume_scene
    end
  end

  def render_pause_card
    left = (grid.w - PAUSE_W) / 2
    bottom = (grid.h - PAUSE_H) / 2
    top = bottom + PAUSE_H
    cx = left + PAUSE_W / 2

    outputs.sprites << { x: left, y: bottom, w: PAUSE_W, h: PAUSE_H,
                         r: MENU_BG[0], g: MENU_BG[1], b: MENU_BG[2], path: :solid }
    outputs.sprites << { x: left, y: top - 4, w: PAUSE_W, h: 4,
                         r: MENU_ACCENT[0], g: MENU_ACCENT[1], b: MENU_ACCENT[2], path: :solid }

    outputs.labels << { x: cx, y: top - 46, text: "PAUSE", size_enum: 10, alignment_enum: 1,
                        vertical_alignment_enum: 2, r: MENU_INK[0], g: MENU_INK[1], b: MENU_INK[2] }

    if state.touch_seen
      render_pause_buttons(left, bottom)
    else
      outputs.labels << { x: cx, y: bottom + 116, text: "ESC / Leertaste  —  weiterspielen",
                          size_enum: 2, alignment_enum: 1, r: MENU_INK[0], g: MENU_INK[1], b: MENU_INK[2] }
      outputs.labels << { x: cx, y: bottom + 64, text: "Q  —  Spiel beenden", size_enum: 2,
                          alignment_enum: 1, r: MENU_DIM_INK[0], g: MENU_DIM_INK[1], b: MENU_DIM_INK[2] }
    end
  end

  # On a phone: a "Beenden" button (the quit hit-zone) and a hint that a tap
  # anywhere else carries on.
  def render_pause_buttons(left, bottom)
    cx = left + PAUSE_W / 2
    button = control_layout.find { |b| b[:id] == :quit }
    if button
      pressed = (state.touch_pressed || []).include?(:quit)
      outputs.sprites << { x: button[:x], y: button[:y], w: button[:w], h: button[:h],
                           r: 150, g: 60, b: 56, a: pressed ? 255 : 210, path: :solid }
      outputs.labels << { x: button[:x] + button[:w] / 2, y: button[:y] + button[:h] / 2,
                          text: button[:label], size_enum: 3, alignment_enum: 1,
                          vertical_alignment_enum: 1, r: 244, g: 232, b: 230 }
    end
    outputs.labels << { x: cx, y: bottom + 56, text: "Tippen zum Weiterspielen", size_enum: 1,
                        alignment_enum: 1, r: MENU_DIM_INK[0], g: MENU_DIM_INK[1], b: MENU_DIM_INK[2] }
  end
end

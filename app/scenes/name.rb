# Before the first dive: who's going down there? The name is the player's own,
# typed in, and the boat greets them by it (see app/ux/story.rb).
#
# Typed characters arrive as inputs.keyboard.key_down.char — one per tick, the
# way DragonRuby's own docs do text entry. NOT via args.inputs.text: that only
# fills while text input is switched on with DR.start_text_input, which is a Pro
# tier feature and quietly does nothing on this Standard build, so the field
# stayed empty and the game could not be started at all.
#
# Enter confirms (space is a legal character in a name, so it can't be the
# confirm key here), backspace deletes, ESC goes back to the title.
class Game
  NAME_MAX = 16
  NAME_PROMPT = "Wie heißt du?"
  NAME_SUB = "Damit im Logbuch steht, wer da unten war."
  NAME_W = 720
  NAME_H = 340

  def name_tick
    read_name_input

    outputs.sprites << title_background
    outputs.sprites << title_light_rays
    outputs.sprites << title_bubbles
    outputs.sprites << { x: 0, y: 0, w: grid.w, h: grid.h, r: 4, g: 12, b: 22, a: 120, path: :solid }
    render_name_card
  end

  def read_name_input
    return confirm_name if inputs.keyboard.key_down.enter

    backspace_name if inputs.keyboard.key_down.backspace || inputs.keyboard.key_down.delete
    type_name([inputs.keyboard.key_down.char])
  end

  # Whatever was typed this tick, as far as the field still has room. Control
  # characters (the ones a keyboard sends alongside real input) are dropped.
  def type_name(chars)
    return unless chars

    chars.each do |char|
      break if state.player_name.length >= NAME_MAX
      next unless char && char.length == 1 && char.ord >= 32

      state.player_name += char
    end
  end

  def backspace_name
    state.player_name = state.player_name.chop
  end

  # A blank name isn't one, so Enter just doesn't do anything yet.
  def confirm_name
    return unless named?

    start_round
  end

  # Into the water, beside the boat, with the story still to be told.
  def start_round
    state.story_told = false
    spawn_at_surface
    state.game_scene = "area1"
  end

  def abandon_name
    state.game_scene = "title"
  end

  def render_name_card
    left = (grid.w - NAME_W) / 2
    bottom = (grid.h - NAME_H) / 2
    top = bottom + NAME_H

    outputs.sprites << { x: left, y: bottom, w: NAME_W, h: NAME_H,
                         r: MENU_BG[0], g: MENU_BG[1], b: MENU_BG[2], path: :solid }
    outputs.sprites << { x: left, y: top - 4, w: NAME_W, h: 4,
                         r: MENU_ACCENT[0], g: MENU_ACCENT[1], b: MENU_ACCENT[2], path: :solid }

    cx = left + NAME_W / 2
    outputs.labels << { x: cx, y: top - 46, text: NAME_PROMPT, size_enum: 6,
                        alignment_enum: 1, vertical_alignment_enum: 2,
                        r: MENU_INK[0], g: MENU_INK[1], b: MENU_INK[2] }
    outputs.labels << { x: cx, y: top - 104, text: NAME_SUB, size_enum: 1,
                        alignment_enum: 1, vertical_alignment_enum: 2,
                        r: MENU_DIM_INK[0], g: MENU_DIM_INK[1], b: MENU_DIM_INK[2] }

    render_name_field(left, bottom)

    hint = named? ? "Enter  —  los geht's" : "… tipp deinen Namen"
    ink = named? ? MENU_ACCENT : MENU_DIM_INK
    outputs.labels << { x: cx, y: bottom + 56, text: hint, size_enum: 1,
                        alignment_enum: 1, vertical_alignment_enum: 2,
                        r: ink[0], g: ink[1], b: ink[2] }
  end

  # The field itself: what's been typed so far, on a line, with a caret blinking
  # after it so it's obvious the keyboard is live.
  def render_name_field(left, bottom)
    field_w = NAME_W - 160
    x = left + 80
    y = bottom + 116

    outputs.sprites << { x: x, y: y - 12, w: field_w, h: 2,
                         r: MENU_ACCENT[0], g: MENU_ACCENT[1], b: MENU_ACCENT[2], a: 120, path: :solid }

    caret = Kernel.tick_count.idiv(30).even? ? "_" : ""
    outputs.labels << { x: x + 8, y: y + 40, text: "#{state.player_name}#{caret}", size_enum: 4,
                        vertical_alignment_enum: 2, r: MENU_INK[0], g: MENU_INK[1], b: MENU_INK[2] }
  end
end

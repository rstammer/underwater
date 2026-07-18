class Game
  def game_over_tick
    if fire_input?
      state.game_scene = "area1"
      reset_game
      return
    end

    cx = grid.w / 2

    # dark backdrop + a subtly darker vignette band behind the text
    outputs.sprites << { x: 0, y: 0, w: grid.w, h: grid.h, r: 40, g: 14, b: 16, path: :solid }
    outputs.sprites << { x: 0, y: 330, w: grid.w, h: 200, r: 55, g: 18, b: 20, path: :solid }
    # accent line under the heading
    outputs.sprites << { x: cx - 200, y: 452, w: 400, h: 3, r: 205, g: 95, b: 82, path: :solid }

    labels = []
    labels << {
      x: cx, y: 520, text: "GAME OVER",
      size_enum: 24, alignment_enum: 1,
      r: 242, g: 228, b: 224,
    }
    labels << {
      x: cx, y: 424, text: death_message,
      size_enum: 6, alignment_enum: 1,
      r: 236, g: 198, b: 193,
    }
    # gentle blink so the restart prompt draws the eye
    if Kernel.tick_count.idiv(30).even?
      labels << {
        x: cx, y: 170, text: "Drücke LEERTASTE, um es nochmal zu versuchen",
        size_enum: 2, alignment_enum: 1,
        r: 228, g: 182, b: 178,
      }
    end

    outputs.labels << labels
  end

  # Cause-specific game-over message (shark vs. running out of air).
  def death_message
    case state.death_cause
    when :drowned then "Dir ging die Luft aus — du bist ertrunken!"
    else "Oh nein! Du wurdest gefressen!"
    end
  end
end

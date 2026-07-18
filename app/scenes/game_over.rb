class Game
  def game_over_tick
    if fire_input?
      state.game_scene = "area1"
      reset_game
      return
    end

    labels = []
    labels << {
      x: 40,
      y: grid.h - 40,
      r: 0,
      g: 0,
      b: 0,
      text: "Oh nein! Du wurdest leider gefressen!",
      size_enum: 20,
    }
    labels << {
      x: 40,
      y: grid.h - 128,
      text: "Versuche es noch einmal.",
    }
    labels << {
      x: 40,
      y: 80,
      text: "Drücke LEERTASTE um neu zu starten",
      size_enum: 2,
    }

    outputs.sprites << {
      x: 0,
      y: 0,
      w: grid.w,
      h: grid.h,
      r: 156,
      g: 44,
      b: 40,
      path: :solid,
    }

    outputs.labels << labels
  end
end

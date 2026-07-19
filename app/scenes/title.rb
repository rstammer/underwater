class Game
  def title_tick
    if fire_input?
      spawn_at_surface
      state.game_scene = "surface"
      return
    end

    labels = []
    labels << {
      x: 40,
      y: grid.h - 40,
      r: 0,
      g: 0,
      b: 0,
      text: "Underwater",
      size_enum: 20,
    }
    labels << {
      x: 40,
      y: grid.h - 128,
      text: "Explore the underwater world and survive!",
    }
    labels << {
      x: 40,
      y: 120,
      text: "Arrows or WASD to move | ESC for pause | gamepad works, too",
    }
    labels << {
      x: 40,
      y: 80,
      text: "Press space to start",
      size_enum: 2,
    }

    outputs.sprites << {
      x: 0,
      y: 0,
      w: grid.w,
      h: grid.h,
      r: 48,
      g: 95,
      b: 177,
      path: :solid,
    }

    outputs.labels << labels
  end
end

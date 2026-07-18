class Game
  def area2_tick
    # Shark movement
    if state.dark_shark.x > SCREEN_WIDTH
      state.dark_shark.x = -300
      state.dark_shark.y = rand(SCREEN_HEIGHT)
    else
      state.dark_shark.x = (state.dark_shark.x + DarkShark::SPEED)
    end

    if Kernel.tick_count % 30 == 0
      state.dark_shark.y = (state.dark_shark.y + ((-1)**rand(10) * rand(30))) % SCREEN_WIDTH
    end

    outputs.sprites << default_background
    outputs.sprites << water(60)
    outputs.sprites << ground
    outputs.sprites << state.shark.to_h
    outputs.sprites << (state.scalars.map(&:to_h) + state.weeds.map(&:to_h)).flatten
  end
end

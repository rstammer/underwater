class Game
  def area1_tick
    render_underwater
  end

  # Both underwater segments render the same way now — the active world (its
  # biome, floor and decorations) drives the look, plus its fish and any shark.
  # Fauna lives in world space, so shift it onto the screen by the camera.
  def render_underwater
    render_world
    outputs.sprites << state.fish.map { |fish| place_in_current_chunk(fish.to_h) } if fauna_visible?
    outputs.sprites << place_in_current_chunk(state.shark.to_h) if shark_present?
  end
end

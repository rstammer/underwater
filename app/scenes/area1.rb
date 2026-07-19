class Game
  def area1_tick
    render_underwater
  end

  # Both underwater segments render the same way now — the active world (its
  # biome, floor and decorations) drives the look, plus its fish and any shark.
  def render_underwater
    render_world(current_world)
    outputs.sprites << state.fish.map(&:to_h)
    outputs.sprites << state.shark.to_h if shark_present?
  end
end

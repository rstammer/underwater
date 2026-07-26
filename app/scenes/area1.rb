class Game
  def area1_tick
    render_underwater
  end

  # Both underwater segments render the same way now — the active world (its
  # biome, floor and decorations) drives the look, plus its fish, the crabs on
  # its floor and any shark. Fauna lives in world space, so shift it onto the
  # screen by the camera.
  def render_underwater
    render_world
    render_world_items
    outputs.sprites << sea_creatures.map { |c| place_in_current_chunk(c.to_h) } if fauna_visible?
    # The beach crabs stand in the daylight, so they show from either side of the
    # surface — like the island they are scuttling about on.
    outputs.sprites << shore_creatures.map { |c| place_in_current_chunk(c.to_h) }
    outputs.sprites << place_in_current_chunk(state.shark.to_h) if shark_present?
    render_whale  # the big one, in world space — it is longer than a chunk
    render_kraken # the legend, drawn before the fog so the dark keeps it a suggestion
  end
end

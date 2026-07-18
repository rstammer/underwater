class Game
  # The water surface: sky above the waterline, water below. The diver's head
  # can poke out here to breathe (see apply_vertical_bounds). Kept as its own
  # scene so it can grow into the diver's "home" (a boat) later.
  def surface_tick
    outputs.sprites << default_background
    outputs.sprites << water(60)
    outputs.sprites << sky_band
    outputs.sprites << waterline
  end

  def sky_band
    {
      x: 0,
      y: SURFACE_WATERLINE,
      w: grid.w,
      h: grid.h - SURFACE_WATERLINE,
      r: 135,
      g: 206,
      b: 235,
      path: :solid,
    }
  end

  def waterline
    {
      x: 0,
      y: SURFACE_WATERLINE - 3,
      w: grid.w,
      h: 6,
      r: 200,
      g: 230,
      b: 245,
      path: :solid,
    }
  end
end

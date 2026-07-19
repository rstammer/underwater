class Game
  # The water surface: sky above the waterline, water below. The diver's head
  # can poke out here to breathe (see apply_vertical_bounds). Kept as its own
  # scene so it can grow into the diver's "home" (a boat) later.
  def surface_tick
    outputs.sprites << default_background
    outputs.sprites << water(60)
    outputs.sprites << sky_band
    outputs.sprites << waterline
    outputs.sprites << surface_boat
    outputs.labels << surface_hint
  end

  # The diver's home: a small boat bobbing on the waterline. The diver spawns
  # right next to it (see spawn_at_surface). Meant to grow into a hub later.
  def surface_boat
    scale = 3
    bob = Math.sin(Kernel.tick_count / 45.0) * 4
    {
      x: SURFACE_BOAT_X,
      y: SURFACE_WATERLINE - 24 + bob,
      w: 48 * scale,
      h: 34 * scale,
      path: "sprites/decor/boat.png",
    }
  end

  # A quiet nudge in the sky, encouraging the player to dive and explore.
  # Deliberately low-contrast and small so it stays in the background.
  def surface_hint
    {
      x: grid.w / 2,
      y: grid.h - 60,
      text: "Tauche ab und erkunde die Unterwasserwelt",
      size_enum: 2,
      alignment_enum: 1,
      r: 30,
      g: 60,
      b: 80,
      a: 170,
    }
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

# What stands behind the islands. Reopens Game.
#
# An island used to be a flat cut-out against a flat sky: one silhouette, one
# colour, nothing behind it. It read as a wall with palms on top rather than as
# land you were looking *at*, because there was no second thing further away to
# tell you the first one was near.
#
# So: ridges drawn behind the island, in two ranks, each paler and hazier than
# the one in front. That is the whole of aerial perspective and it is the
# cheapest depth there is — no new sprites, no parallax bookkeeping, just the
# fact that distance drains colour.
#
# They are *behind everything*: drawn after the sky and before any of the world's
# own rock, so an island always occludes them. And they never break the horizon
# line — a ridge rising out of the sea in the wrong place would read as terrain
# you could swim to, which is exactly what they are not.
class Game
  # Two ranks. More would be mush at this palette; one would look like a mistake.
  # The far rank is drawn first and the near one over it, so the near one has to
  # be the darker: haze drains colour with distance, and a pale hill in front of
  # a dark one reads as fog rather than as land.
  BACKDROP_RANKS = [
    # [how far off (parallax divisor), height in px, colour, alpha]
    [6.0, 330, [150, 186, 206], 255],
    [3.2, 230, [112, 154, 178], 255],
  ].freeze
  # Short enough that a screen holds two or three summits. At 1700 you saw one
  # slope at a time and it read as a grey slab rather than as hills.
  BACKDROP_WAVELENGTH = 820
  BACKDROP_SEED = 90_210
  BACKDROP_STEP = 16         # px per drawn column: pixel-art ridges, not curves
  # How far below the waterline the ranks are rooted. They sit *in* the sea by a
  # margin rather than exactly on it, so no rank ever shows a gap of sky under
  # its own feet when the camera rises.
  BACKDROP_FOOT = 6 # they stand on the sea line, near enough

  # Only where there is sky to put them in — under water there is no horizon and
  # a distant hill would be a hallucination.
  def backdrop_visible?
    WATERLINE_Y - state.camera_y < SCREEN_HEIGHT
  end

  def render_backdrop
    return unless backdrop_visible?

    BACKDROP_RANKS.each_with_index do |(distance, height, colour, haze), rank|
      outputs.sprites << backdrop_rank(distance, height, colour, haze, rank)
    end
  end

  # One rank, as a row of columns. Parallax by division: a rank three times as
  # far away slides a third as fast, which is what makes the near island appear
  # to move against it.
  def backdrop_rank(distance, height, colour, haze, rank)
    base = WATERLINE_Y - state.camera_y - BACKDROP_FOOT
    origin = (state.camera_x / distance).to_i
    columns = (SCREEN_WIDTH / BACKDROP_STEP) + 2

    (0...columns).map do |i|
      x = i * BACKDROP_STEP
      world_x = origin + x
      top = base + backdrop_height(world_x, height, rank)
      { x: x, y: base, w: BACKDROP_STEP + 1, h: top - base,
        r: colour[0], g: colour[1], b: colour[2], a: haze, path: :solid }
    end
  end

  # The skyline itself: two octaves of the world's own noise so the ridges have
  # both a shape and a texture, rastered to BACKDROP_STEP so they are drawn in
  # blocks like everything else in this game rather than as a smooth curve.
  def backdrop_height(world_x, height, rank)
    seed = BACKDROP_SEED + rank * 977
    broad = Noise.value(world_x, BACKDROP_WAVELENGTH, seed)
    fine = Noise.value(world_x, BACKDROP_WAVELENGTH / 4, seed + 31)
    ridge = broad * 0.78 + fine * 0.22
    ((ridge * height) / BACKDROP_STEP).floor * BACKDROP_STEP
  end
end

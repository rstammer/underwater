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
    [6.0, 260, [158, 194, 212], 255],
    [3.4, 420, [104, 146, 172], 255],
  ].freeze
  # Short enough that a screen holds two or three summits. At 1700 you saw one
  # slope at a time and it read as a grey slab rather than as hills.
  # Short enough that a summit is a summit. At 520 the peaks were wider than the
  # screen and came out as one grey plateau — the very slab this was meant to
  # replace.
  BACKDROP_WAVELENGTH = 300
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

  # Only where there is an island. On the open sea the horizon is the point —
  # a ridge out there would be land you can see and never reach, which is a
  # promise the game cannot keep.
  def render_backdrop
    # Never on the framing screens. The title, the opening, the recap and the
    # night all park the camera at the boat *for the clean horizon* — that is
    # the whole reason they draw the real sea — and the home island is close
    # enough that its hills turned up behind the boat and spoiled exactly the
    # thing those screens were built on.
    return if game_paused?
    return unless backdrop_visible?

    visible_islands.each do |sector|
      BACKDROP_RANKS.each_with_index do |(distance, height, colour, alpha), rank|
        outputs.sprites << backdrop_ridge(sector, distance, height, colour, alpha, rank)
      end
    end
  end

  def visible_islands
    (state.island_sectors || []).select do |sector|
      visible_world_indices.any? { |index| IslandWorld.covers?(sector, index) }
    end
  end

  # A mass rising behind *this* island, centred on it and wider than it: the
  # island is the front of a hill, and this is the rest of the hill carrying on
  # backwards. Anchored to the island's own centre rather than scrolling with
  # the world, so the two never come apart.
  #
  # Parallax pulls the far ranks *towards* that centre as you walk past — near
  # the middle they sit still and the flanks compress, which is what a solid
  # thing seen from a moving point does.
  BACKDROP_SPREAD = 1500 # px each side of the island's centre the mass reaches

  def backdrop_ridge(sector, distance, height, colour, alpha, rank)
    base = WATERLINE_Y - state.camera_y - BACKDROP_FOOT
    centre = IslandWorld.centre_x(sector)
    columns = (SCREEN_WIDTH / BACKDROP_STEP) + 2

    (0...columns).map do |i|
      x = i * BACKDROP_STEP
      # Screen x back to world x, then pulled toward the island by the parallax.
      world_x = centre + ((state.camera_x + x) - centre) / distance
      lift = backdrop_height(world_x, centre, height, rank)
      next nil if lift <= 0

      { x: x, y: base, w: BACKDROP_STEP + 1, h: lift,
        r: colour[0], g: colour[1], b: colour[2], a: alpha, path: :solid }
    end.compact
  end

  # A dome that falls away to nothing at BACKDROP_SPREAD, roughened by the
  # world's own noise so it is a ridge rather than a hill from a geometry
  # lesson. Rastered to BACKDROP_STEP: blocks, like everything else here.
  # Peaks, not a hill. A smooth dome across fifteen hundred pixels comes out as
  # a flat slab on a screen this wide — a wall behind the island rather than
  # land behind it. Ridged noise (the fold at 0.5 makes a *point* where plain
  # noise makes a bump) gives summits and saddles at a wavelength short enough
  # that two or three of them fit behind one island.
  #
  # The dome survives as an envelope only: it is what brings the range down to
  # nothing at the ends instead of cutting it off mid-mountain.
  def backdrop_height(world_x, centre, height, rank)
    t = (world_x - centre).abs / BACKDROP_SPREAD.to_f
    return 0 if t >= 1.0

    envelope = (Math.cos(t * Math::PI) + 1) / 2.0
    seed = BACKDROP_SEED + rank * 977
    ridge = 1.0 - (2.0 * Noise.value(world_x, BACKDROP_WAVELENGTH, seed) - 1.0).abs
    detail = 1.0 - (2.0 * Noise.value(world_x, BACKDROP_WAVELENGTH / 3, seed + 41) - 1.0).abs
    peaks = ridge * 0.75 + detail * 0.25
    # Steep: cubed peaks give sharp summits with real saddles between them
    # instead of a rolling line that reads as one mass.
    ((envelope * (0.12 + 0.88 * peaks * peaks * peaks) * height) / BACKDROP_STEP).floor * BACKDROP_STEP
  end
end

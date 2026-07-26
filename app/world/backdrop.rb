# What stands behind an island. Reopens Game.
#
# An island used to be a flat cut-out against a flat sky: one silhouette, one
# colour, nothing behind it. It read as a wall with palms on top rather than as
# land you were looking *at*, because there was nothing further away to say the
# near thing was near.
#
# The first three attempts were a separate parallax layer behind a visibility
# switch, and every symptom followed from that choice: a hard switch has to pop,
# and a layer that scrolls slower than the world has to drag along behind you —
# right for a distant mountain range, wrong for the thing this is meant to be.
#
# So it is not a layer. It is **the island's own crown curve, drawn again**: the
# same shape read at a squeezed x so it comes out wider, multiplied so it comes
# out taller, shifted a little sideways, and hazed. Three things follow for free
# and none of them needs tuning:
#
#   * it cannot appear without its island, because it *is* its island;
#   * it cannot drag, because it moves with it;
#   * it cannot stand beside it, because it comes off the same curve.
#
# And it arrives the way land arrives: the far end of the range slides in from
# the screen edge at whatever height the curve has there, rather than switching
# on at full size.
class Game
  # Each rank: [how much wider, how much taller, how far shifted, colour, alpha].
  #
  # Kept close to the island's own width. At 2.9 the range ran most of a screen
  # past the coast on both sides — the island's underwater flanks are long, and
  # stretching them put hills over open water where there is plainly no land.
  # Taller instead: height is what reads as distance, width is what gives it
  # away.
  # The nearer rank is the darker one — haze drains colour with distance, and a
  # pale ridge in front of a dark one reads as fog rather than as land.
  BACKDROP_RANKS = [
    [1.75, 1.95, -190, [154, 190, 210], 255],
    [1.35, 1.55, 110, [112, 152, 178], 255],
  ].freeze
  BACKDROP_STEP = 12 # px per drawn column: pixel-art ridges, not curves
  BACKDROP_ON = true

  # Only above water, and never on the framing screens: the title, the opening,
  # the recap and the night park the camera at the boat *for* a clean horizon,
  # and the island next door is close enough that its hills came along with it.
  def render_backdrop
    return unless BACKDROP_ON
    return if game_paused?
    return unless backdrop_visible?

    visible_islands.each do |sector|
      BACKDROP_RANKS.each_with_index do |rank, i|
        outputs.sprites << backdrop_silhouette(sector, rank, i)
      end
      outputs.sprites << backdrop_birds(sector)
    end
  end

  def backdrop_visible?
    WATERLINE_Y - state.camera_y < SCREEN_HEIGHT
  end

  # Generously: the silhouette is wider than the island it comes from, so a range
  # can properly reach the screen while its island has not. It falls away to
  # nothing on its own, so there is nothing here to be exact about.
  def visible_islands
    middle = state.camera_x + SCREEN_WIDTH / 2
    (state.island_sectors || []).select do |sector|
      (IslandWorld.centre_x(sector) - middle).abs <= SCREEN_WIDTH * 2
    end
  end

  # The island as an object, so its crown can be asked about. Memoised: building
  # one rolls its whole shape, and this runs every frame.
  def backdrop_island(sector)
    state.backdrop_isles ||= {}
    state.backdrop_isles[sector] ||= IslandWorld.new(world_at(sector), sector)
  end

  def backdrop_silhouette(sector, rank, index)
    wider, taller, shift, colour, alpha = rank
    isle = backdrop_island(sector)
    centre = IslandWorld.centre_x(sector)
    base = WATERLINE_Y - state.camera_y
    columns = (SCREEN_WIDTH / BACKDROP_STEP) + 2

    (0...columns).map do |i|
      x = i * BACKDROP_STEP
      world_x = state.camera_x + x
      # Sample the island's own curve a third of the way out from its middle and
      # draw it at full width: that is what turns the same shape into a wider one.
      source = centre + (world_x - centre - shift) / wider
      lift = backdrop_lift(isle, source, taller, index)
      next nil if lift <= 0

      { x: x, y: base, w: BACKDROP_STEP + 1, h: lift,
        r: colour[0], g: colour[1], b: colour[2], a: alpha, path: :solid }
    end.compact
  end

  # How high this column stands over the water. Zero wherever the island's own
  # crown is at or below the waterline, which is what keeps the range inside the
  # land it belongs to and lets it end without a cut.
  def backdrop_lift(isle, source_x, taller, index)
    above = isle.crown_y_at(source_x) - WATERLINE_Y
    return 0 if above <= 0

    lift = above * taller + index * 30
    lift = SCREEN_HEIGHT if lift > SCREEN_HEIGHT
    (lift / BACKDROP_STEP).floor * BACKDROP_STEP
  end

  # A few birds over the range, in its haze rather than in their own colours —
  # anything that far off is the colour of the air between you and it. They
  # circle rather than travel, so they never arrive anywhere or leave.
  # Higher than the ranges and spread across them, or the island simply stands
  # in front of them — they are drawn with the backdrop, so anything below a
  # crown is behind rock. Drawn at 4x as well: at 2x a gull is twenty-four
  # pixels of pale grey against a pale sky, which is nothing at all.
  BACKDROP_BIRDS = [[-560, 470, 210.0], [-140, 545, 170.0],
                    [330, 500, 240.0], [700, 580, 300.0]].freeze
  BACKDROP_BIRD_INK = [176, 204, 220].freeze

  def backdrop_birds(sector)
    sprite = DECOR_SPRITES["gull"]
    centre = IslandWorld.centre_x(sector)
    BACKDROP_BIRDS.map do |dx, height, period|
      x = centre + dx - state.camera_x + Math.sin(Kernel.tick_count / period) * 90
      next nil if x < -40 || x > SCREEN_WIDTH + 40

      { x: x,
        y: WATERLINE_Y + height - state.camera_y +
           Math.sin(Kernel.tick_count / (period / 2.6)) * 12,
        w: sprite[:w] * 4, h: sprite[:h] * 4, path: sprite[:path],
        r: BACKDROP_BIRD_INK[0], g: BACKDROP_BIRD_INK[1], b: BACKDROP_BIRD_INK[2],
        a: 190, anchor_x: 0.5, anchor_y: 0.5 }
    end.compact
  end
end

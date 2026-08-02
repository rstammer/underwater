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
  # *Narrower* than the island, not wider. That was the mistake underneath every
  # version of this: widening the curve necessarily makes the range stick out
  # past the coast on both sides, which is exactly where there is plainly no
  # land. A mountain behind an island does not stick out — it rises over the
  # top of it. So the curve is squeezed inward and pushed up instead.
  # The nearer rank is the darker one — haze drains colour with distance, and a
  # pale ridge in front of a dark one reads as fog rather than as land.
  BACKDROP_RANKS = [
    [0.72, 2.30, -170, [140, 178, 168], 255],
    [0.86, 1.75, 90, [74, 126, 104], 255],
  ].freeze
  # Finer than they were (12/24). A ridge could be drawn coarsely because a ridge
  # is one long line; a canopy cannot, because at twelve pixels of height per
  # step a crown is two steps tall and comes out as a battlement. Roughly three
  # hundred solid rects across both ranks, which is nothing beside the sea floor.
  BACKDROP_STEP = 6    # px per drawn column: pixel-art ridges, not curves
  BACKDROP_SAMPLE = 12 # px of island curve per sample, locked to the world
  BACKDROP_ON = true

  # What turns the far ridge into a far *wood*.
  #
  # The island's crown steps in wide terraces, so a silhouette taken straight off
  # it holds one height for a long way and then jumps — which is the outline of
  # bare rock, and no amount of green makes it read as anything else. Trees break
  # that edge up: every sample gets a crown of its own, so the top is busy at the
  # scale of a treetop instead of at the scale of a hillside.
  #
  # Rolled from the sample's own world position, like everything else out here.
  # It has to be: the whole reason this walks a fixed world grid is that the same
  # place must answer the same however the camera stands, and a canopy that
  # wobbled per frame would bring back exactly the shimmer that cost three
  # attempts to get rid of.
  # Two scales, and the big one has to be *smooth*. Rolling every sample on its
  # own gave each drawn column an independent height, and a row of narrow columns
  # at independent heights is a skyline — the first version of this looked like a
  # city on the horizon. A crown is wider than one sample, so the main shape is
  # interpolated noise at about the width of a tree, and the per-sample roll is
  # left as the small ragged edge on top of it.
  CANOPY_SPAN = 56     # world px per crown — the wavelength of the round part
  CANOPY_RISE = 30     # how much of the height comes from that
  CANOPY_RAGGED = 7    # ... and how much is the per-column fringe
  CANOPY_SEED = 4242
  # Now and then one tree is well clear of the rest. Rain forest reads the way it
  # does largely because of these — without them a canopy is a hedge.
  #
  # Interpolated too, and for the same reason as the crowns: rolled per sample,
  # an emergent came out one column wide, which at this sample rate is eight
  # pixels of pole standing off a wood. A tree that stands out still has to be a
  # tree's width, so it is a short wavelength rather than a spike.
  CANOPY_EMERGENT_SPAN = 34
  CANOPY_EMERGENT = 0.82 # rolls above this get the extra
  CANOPY_EMERGENT_RISE = 34

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
  # one rolls its whole shape, and this runs every frame. Game#reset_game drops
  # the lot — a new round is new land, and a silhouette that outlives the island
  # it came off draws the previous round's hills behind this one's coast.
  def backdrop_island(sector)
    state.backdrop_isles ||= {}
    state.backdrop_isles[sector] ||= IslandWorld.new(world_at(sector), sector)
  end

  def backdrop_silhouette(sector, rank, index)
    wider, taller, shift, colour, alpha = rank
    isle = backdrop_island(sector)
    centre = IslandWorld.centre_x(sector)
    base = WATERLINE_Y - state.camera_y

    # Walked along the *curve*, not along the screen. Walking the screen means
    # each drawn column asks about a slightly different place on the island as
    # the camera moves, and since the crown steps in terraces the whole range
    # shimmered: a column would flick between one terrace and the next every
    # few pixels of swimming. Stepping the source on a fixed world grid and
    # projecting each sample onto the screen means the same places are always
    # asked about, so the silhouette can only ever slide sideways.
    #
    # Which way round it is matters more than it looks — it is the difference
    # between "where is the island at this pixel?" and "where does this bit of
    # island land?", and only the second one holds still.
    first = to_source(centre, shift, wider, state.camera_x)
    last = to_source(centre, shift, wider, state.camera_x + SCREEN_WIDTH)
    first, last = last, first if first > last
    step = BACKDROP_SAMPLE
    source = (first / step).floor * step
    width = (step * wider).ceil + 1

    out = []
    while source <= last + step
      lift = backdrop_lift(isle, source, taller, index)
      if lift > 0
        x = centre + (source - centre) * wider + shift - state.camera_x
        out << { x: x, y: base, w: width, h: lift,
                 r: colour[0], g: colour[1], b: colour[2], a: alpha, path: :solid }
      end
      source += step
    end
    out
  end

  # Screen x back to a place on the island's curve.
  def to_source(centre, shift, wider, world_x)
    centre + (world_x - centre - shift) / wider
  end

  # How high this column stands over the water — worked out once per place and
  # kept.
  #
  # Keeping it is the whole payoff of walking a fixed world grid. Every sample
  # rolls a crown height and three octaves of canopy noise, and Noise.jitter
  # builds an Rng to do each of them; at ~150 samples a rank, two ranks and up
  # to three islands in view, the far hills came to 5.5 ms of a 9 ms frame —
  # more than the sea floor, the fish and the HUD together, spent re-rolling
  # hills that had not moved. Since the answer cannot depend on anything but the
  # place (that is what tests/vegetation_tests.rb#test_the_canopy_holds_still is
  # for), asking twice is pure waste.
  #
  # It is bounded by the land rather than by how far anyone swims: a range only
  # reaches so far past its island (visible_islands), so an island's whole ridge
  # is about a thousand numbers and a round holds four islands. It goes when
  # they do (reset_game).
  def backdrop_lift(isle, source_x, taller, index)
    lifts = (state.backdrop_lifts ||= {})
    key = "#{isle.sector} #{index} #{source_x}"
    kept = lifts[key]
    return kept if kept

    lifts[key] = rolled_backdrop_lift(isle, source_x, taller, index)
  end

  # Zero wherever the island's own crown is at or below the waterline, which is
  # what keeps the range inside the land it belongs to and lets it end without
  # a cut.
  def rolled_backdrop_lift(isle, source_x, taller, index)
    above = isle.crown_y_at(source_x) - WATERLINE_Y
    return 0 if above <= 0

    lift = above * taller + index * 30 + canopy_rise(source_x, index)
    lift = SCREEN_HEIGHT if lift > SCREEN_HEIGHT
    (lift / BACKDROP_STEP).floor * BACKDROP_STEP
  end

  # The trees on this column. Two rolls: the ordinary spread of crown heights,
  # and the occasional one that stands out of it. Each rank rolls its own, or the
  # two ridges would carry the same wood twice and the far one would read as a
  # shadow of the near one.
  def canopy_rise(source_x, index)
    cell = source_x.idiv(BACKDROP_SAMPLE)
    seed = CANOPY_SEED + index * 17

    rise = Noise.value(source_x, CANOPY_SPAN, seed) * CANOPY_RISE
    rise += Noise.jitter(cell, seed + 3) * CANOPY_RAGGED
    tall = Noise.value(source_x, CANOPY_EMERGENT_SPAN, seed + 5)
    rise += (tall - CANOPY_EMERGENT) / (1 - CANOPY_EMERGENT) * CANOPY_EMERGENT_RISE if tall > CANOPY_EMERGENT
    rise
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

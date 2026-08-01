# The wreck: the first hand-built world in the game, pinned to one segment.
#
# Everything else out there is a function of the world position — swim to the
# same place and the same sea is computed again. That is what makes the sea
# endless, and it is also its limit: nothing in it was ever *put* anywhere, so
# nothing in it can be a landmark. A generated trench is somewhere deep. A ship
# lying on its side at a hundred and fifty metres is somewhere.
#
# It is out of reach on the suit you start with. SUIT_DEPTH_LIMIT is a hundred
# metres and the pressure works on you below it, so the wreck is not a place you
# find early and die at — it is a place you hear about, look at from above, and
# come back to once Andi has sold you the next suit. That is the whole reason it
# is this deep and not seventy metres down.
#
# Built as slabs rather than as a sprite: the hull *is* terrain, so the diver,
# the fish and the camera all treat it as what it is without any of them being
# told about ships. Swim in through the break amidships and you are inside a
# hold that the generator could never have produced.
module WreckWorld
  SECTOR = -8            # far enough west that the chart has to be earned
  DEPTH_METRES = 150     # the floor it lies on
  # Nearly the whole segment. A wreck you can take in at a glance is a prop; this
  # one you have to swim the length of to see all of, which is the difference
  # between a thing in the sea and a place in it.
  BOW = 8                # first column of the ship ...
  STERN = 150            # ... and the last, in a 160-column segment
  BREAK_FROM = 74        # the hole in the deck you drop in through ...
  BREAK_TO = 86          # ... which is the only way in
  HOLD_H = 132           # headroom in the hold — swimmable, and tall enough to
                         # feel like a hold rather than a crawlspace
  DECK_H = 22            # thickness of the deck over your head
  NOSE = 16              # columns the bow rises over ...
  TAIL = 12              # ... and the stern falls over
  # The stem: the last few columns of the bow stand *above* the deck line, the
  # way an old ship's does. This is the single most recognisable thing about the
  # silhouette — a hull that stops flush at the deck is a barge.
  STEM = 5               # columns of raised stem at the very bow
  STEM_RISE = 74         # how far it stands over the deck
  # The quarterdeck aft, raised over the main deck.
  QUARTER_FROM = 116
  QUARTER_H = 46
  # What is left of the mainmast: a stump on the deck, and the broken-off length
  # of it lying where it fell, sloping down towards the bow.
  MAST_COL = 62
  MAST_W = 3             # columns thick
  MAST_STUMP = 96        # how much of it is still standing
  FALLEN_FROM = 30       # the fallen length lies between these columns ...
  FALLEN_TO = 58         # ... sloping down towards the bow
  FALLEN_THICK = 12
  # Where the gun ended up when it came off its carriage.
  CANNON_COL = 100
  # The foremast, snapped shorter than the main. Two stumps read as a ship that
  # was rigged; one reads as a post.
  FORE_COL = 34
  FORE_STUMP = 52
  # The bowsprit, out over the stem. It is the one line on the whole ship that
  # is neither upright nor flat, and it is what a bow is recognised by.
  SPRIT_LEN = 9          # columns it reaches forward of the stem
  SPRIT_THICK = 9
  SPRIT_RISE = 4         # px it climbs per column — a bowsprit is a shallow
                         # line, not a mast lying over; at 7 it left the top of
                         # the picture before it left the ship

  def self.floor_y
    WATERLINE_Y - DEPTH_METRES * PIXELS_PER_METRE
  end

  # A flat, silted bottom with a shallow dish under the hull — a ship that has
  # been down here a while has settled into the mud rather than perching on it.
  def self.build_floor(columns)
    (0...columns).map do |col|
      dip = if col.between?(BOW - 6, STERN + 6)
              -10 - (Math.sin((col - BOW) / 30.0) * 6).round
            else
              0
            end
      floor_y + dip + (col % 7 == 0 ? 3 : 0)
    end
  end

  # The ship, column by column.
  #
  # Read as a cross-section, which is what this game draws: the deck is a slab
  # over your head, the hold is the water under it, and the bow and stern are
  # solid from the mud all the way up. So the hull is not a wall you swim
  # *through* — it is a roof with two closed ends, and the one hole in that roof
  # is the only way in. Dropping through it is the moment the wreck becomes a
  # place rather than a silhouette.
  #
  # Bow and stern taper into the mud over a dozen columns each. That taper is
  # what makes it a ship from a distance: a box with a hole in it reads as a
  # building, and the game has no buildings on the sea floor.
  def self.build_roof(columns, floor)
    (0...columns).map do |col|
      # The bowsprit reaches forward of the stem, so these columns carry ship
      # without being part of the hull.
      if col.between?(BOW - SPRIT_LEN, BOW - 1)
        out = BOW - col
        deck_top = floor[col] + HOLD_H + DECK_H
        lift = STEM_RISE + out * SPRIT_RISE
        next [{ ceiling: (deck_top + lift).round,
                crown: (deck_top + lift + SPRIT_THICK).round, wood: true }]
      end
      next [] unless col.between?(BOW, STERN)

      slabs = []
      deck_bottom = floor[col] + HOLD_H
      deck_top = deck_bottom + DECK_H
      from_bow = col - BOW
      from_stern = STERN - col

      if from_bow < NOSE || from_stern < TAIL
        # The ends are solid: hull from the mud up to wherever the sheer has got
        # to, which is what closes the hold off.
        #
        # The bow does not taper down to the mud the way the stern does — it
        # stands up. The first attempt ran the stem *and* a taper on the same
        # columns, so the front came out as a notch: a spike, a dip, then the
        # deck. An old ship's stem is the highest thing forward and everything
        # behind it falls away aft, so that is what it does now.
        top =
          if from_bow < NOSE
            # One curve, not two pieces. Built as a stem and then a separate
            # easing-off, the two met at different heights and the sheer rose
            # again a few columns behind the bow — a notch, which is exactly what
            # a bow must not have. Squared, so it drops away steeply just behind
            # the stem and then flattens onto the deck line.
            run = 1 - from_bow / NOSE.to_f
            deck_top + STEM_RISE * run * run
          else
            floor[col] + (deck_top - floor[col]) * ((from_stern + 1) / TAIL.to_f)
          end
        # A hull with a bottom to it: the very tip of the bow lifts clear of the
        # mud, the way a stem does where the keel runs out.
        base = from_bow < 3 ? floor[col] + (3 - from_bow) * 22 : floor[col]
        slabs << { ceiling: base.round, crown: top.round, wood: true }
      elsif col.between?(BREAK_FROM, BREAK_TO)
        # The hole. No deck here, so the hold is open to the water above it.
      else
        slabs << { ceiling: deck_bottom.round, crown: deck_top.round, wood: true }
      end

      # The bulkheads that close the forward compartment off. Without them the
      # trapped air had open water on both sides — a rectangle of air hanging in
      # the sea. They stop short of the mud, so you can still swim under them
      # into the compartment and come up inside it.
      if (col - AIR_FROM).abs < BULKHEAD_W || (col - AIR_TO).abs < BULKHEAD_W
        slabs << { ceiling: (floor[col] + 46).round, crown: deck_bottom.round, wood: true }
      end

      # The quarterdeck aft, standing on the main deck: a second slab rather
      # than a taller deck, so the hold underneath keeps its headroom.
      if col >= QUARTER_FROM && from_stern >= TAIL
        slabs << { ceiling: deck_top.round, crown: (deck_top + QUARTER_H).round, wood: true }
      end

      # The masts, or what is left of them — two stumps, snapped at different
      # heights. Two say the ship was rigged; one says post.
      if (col - MAST_COL).abs < MAST_W && !col.between?(BREAK_FROM, BREAK_TO)
        slabs << { ceiling: deck_top.round, crown: (deck_top + MAST_STUMP).round, wood: true }
      end
      if (col - FORE_COL).abs < MAST_W
        slabs << { ceiling: deck_top.round, crown: (deck_top + FORE_STUMP).round, wood: true }
      end

      # ... and the length that came off it, lying across the foredeck where it
      # fell, sloping down towards the bow. A snapped mast on the deck is the
      # one thing that says this ship did not just settle — something happened
      # to it.
      if col.between?(FALLEN_FROM, FALLEN_TO)
        run = (col - FALLEN_FROM) / (FALLEN_TO - FALLEN_FROM).to_f
        lift = 10 + (44 * run).round
        slabs << { ceiling: (deck_top + lift).round,
                   crown: (deck_top + lift + FALLEN_THICK).round, wood: true }
      end
      slabs
    end
  end

  # A pocket of air caught under the highest part of the deck. Somewhere to put
  # your head up in a place where surfacing is otherwise a two-minute swim — the
  # same trick the islands' dead ends use, and the reason a wreck is worth going
  # *into* rather than photographing from outside.
  # Air caught in the forward compartment.
  #
  # It hung in the middle of the hold at first, with open water on all sides —
  # a rectangle of air floating in the sea, which is not how air behaves. Air
  # collects *under* something and is held in by walls. So the pocket is flush
  # against the underside of the deck, and the compartment it sits in has a
  # bulkhead at each end (build_roof draws them). It is a room with air at the
  # top of it, which is a thing that can exist.
  AIR_FROM = BOW + NOSE + 2   # the compartment's forward bulkhead ...
  AIR_TO = BOW + NOSE + 15    # ... and its after one
  AIR_H = 34                  # how deep the trapped air reaches down from the deck
  BULKHEAD_W = 2              # columns thick

  def self.build_air(floor)
    first = AIR_FROM + BULKHEAD_W
    last = AIR_TO - BULKHEAD_W
    x = first * World::COLUMN_WIDTH
    w = (last - first) * World::COLUMN_WIDTH
    # The deck follows the mud, and the mud dips — so the ceiling of the
    # compartment is not level. Measured at its lowest point across the whole
    # pocket, or the air would be inside the deck at one end of it.
    ceiling = (first..last).map { |c| floor[c] }.min + HOLD_H
    [{ x: x, y: ceiling - AIR_H, w: w, h: AIR_H }]
  end

  # What has grown on it in the meantime. Weed along the hull and on the open
  # mud, thicker where the hull has been standing longest — a wreck that is bare
  # looks like it went down last week.
  # Everything aboard her, and what has grown on her since.
  #
  # This is where the wreck stops being a shape and becomes a place: a ship on
  # the bottom is somewhere people worked, and the things they left are what say
  # so. Half of it is out on the deck where it can be seen from outside — the
  # gun, the wheel, the anchor in the mud — and half is down in the hold, which
  # is the payoff for finding the way in.
  def self.build_decorations(floor)
    weed(floor) + on_deck(floor) + in_the_hold(floor)
  end

  def self.deck_y(floor, col)
    floor[col] + HOLD_H + DECK_H
  end

  def self.weed(floor)
    [2, 5, 154, 158].each_with_index.map do |col, i|
      { kind: %w[seaweed coral seaweed starfish][i % 4],
        x: col * World::COLUMN_WIDTH, y: floor[col], scale: 2 }
    end
  end

  # What is still up top. The wheel goes aft on the quarterdeck, where a wheel
  # belongs; the gun lies on the main deck where it came off its carriage; the
  # anchor is down in the mud off the bow, fouled, where it did the ship no good
  # at all.
  def self.on_deck(floor)
    [
      { kind: "cannon", x: CANNON_COL * World::COLUMN_WIDTH,
        y: deck_y(floor, CANNON_COL), scale: 3 },
      { kind: "cannon", x: (CANNON_COL - 12) * World::COLUMN_WIDTH,
        y: deck_y(floor, CANNON_COL - 12), scale: 3 },
      { kind: "wheel", x: (QUARTER_FROM + 6) * World::COLUMN_WIDTH,
        y: deck_y(floor, QUARTER_FROM + 6) + QUARTER_H, scale: 3 },
      { kind: "barrel", x: (STERN - 22) * World::COLUMN_WIDTH,
        y: deck_y(floor, STERN - 22), scale: 3 },
      { kind: "anchor", x: (BOW - 4) * World::COLUMN_WIDTH,
        y: floor[BOW - 4], scale: 3 },
    ]
  end

  # And what is down in the hold, which you only see if you drop through the
  # deck. The chest is the far one, right forward past the air pocket: something
  # to swim the length of the hold for.
  def self.in_the_hold(floor)
    [
      { kind: "barrel", x: (BREAK_TO + 6) * World::COLUMN_WIDTH,
        y: floor[BREAK_TO + 6], scale: 3 },
      { kind: "barrel", x: (BREAK_TO + 11) * World::COLUMN_WIDTH,
        y: floor[BREAK_TO + 11], scale: 3 },
      { kind: "barrel", x: (BREAK_FROM - 8) * World::COLUMN_WIDTH,
        y: floor[BREAK_FROM - 8], scale: 3 },
      { kind: "chest", x: (BOW + NOSE + 3) * World::COLUMN_WIDTH,
        y: floor[BOW + NOSE + 3], scale: 3 },
    ]
  end

  def self.build(index)
    columns = SCREEN_WIDTH / World::COLUMN_WIDTH
    floor = build_floor(columns)
    World.new(index: index, biome: Biome::WRECK, floor: floor,
              decorations: build_decorations(floor),
              roof: build_roof(columns, floor),
              air_pockets: build_air(floor))
  end
end

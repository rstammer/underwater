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

      # The quarterdeck aft, standing on the main deck: a second slab rather
      # than a taller deck, so the hold underneath keeps its headroom.
      if col >= QUARTER_FROM && from_stern >= TAIL
        slabs << { ceiling: deck_top.round, crown: (deck_top + QUARTER_H).round, wood: true }
      end

      # The mast, or what is left of it — a stump still standing amidships.
      if (col - MAST_COL).abs < MAST_W && !col.between?(BREAK_FROM, BREAK_TO)
        slabs << { ceiling: deck_top.round, crown: (deck_top + MAST_STUMP).round, wood: true }
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
  def self.build_air(floor)
    col = BOW + NOSE + 6
    x = col * World::COLUMN_WIDTH
    w = 12 * World::COLUMN_WIDTH
    bottom = floor[col] + HOLD_H - 34
    [{ x: x, y: bottom, w: w, h: 30 }]
  end

  # What has grown on it in the meantime. Weed along the hull and on the open
  # mud, thicker where the hull has been standing longest — a wreck that is bare
  # looks like it went down last week.
  def self.build_decorations(floor)
    spots = [2, 4, 155, 158]
    items = spots.each_with_index.map do |col, i|
      kind = %w[seaweed coral seaweed starfish][i % 4]
      { kind: kind, x: col * World::COLUMN_WIDTH, y: floor[col], scale: 2 }
    end
    items << cannon(floor)
  end

  # The gun, lying on the main deck aft where it came off its carriage. Drawn as
  # decoration rather than built as a slab: it is the one thing up here that is a
  # made object rather than a piece of ship, and it should look like one.
  def self.cannon(floor)
    { kind: "cannon", x: CANNON_COL * World::COLUMN_WIDTH,
      y: floor[CANNON_COL] + HOLD_H + DECK_H, scale: 3 }
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

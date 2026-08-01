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
  BOW = 26               # first column of the ship ...
  STERN = 126            # ... and the last, in a 160-column segment
  BREAK_FROM = 68        # the hole in the deck you drop in through ...
  BREAK_TO = 78          # ... which is the only way in
  HOLD_H = 96            # headroom in the hold — enough to swim along it
  DECK_H = 26            # thickness of the deck over your head
  BRIDGE_FROM = 92       # the superstructure aft: where it starts ...
  BRIDGE_TO = 110        # ... and ends
  BRIDGE_H = 54          # ... and how far it stands over the deck
  NOSE = 12              # columns over which the bow tapers down to the mud
  TAIL = 9               # ... and the stern

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
        # The ends are solid: hull from the mud up to wherever the sheer has
        # got to, which is what closes the hold off.
        share = from_bow < NOSE ? (from_bow + 1) / NOSE.to_f : (from_stern + 1) / TAIL.to_f
        top = floor[col] + (deck_top - floor[col]) * share
        slabs << { ceiling: floor[col].round, crown: top.round }
      elsif col.between?(BREAK_FROM, BREAK_TO)
        # The hole. No deck here, so the hold is open to the water above it.
      else
        slabs << { ceiling: deck_bottom.round, crown: deck_top.round }
      end

      # The superstructure aft, standing on the deck. It is what tells you at a
      # glance which end is which, and it is drawn as a second slab rather than
      # a taller deck so the hold underneath keeps its headroom.
      if col.between?(BRIDGE_FROM, BRIDGE_TO) && from_stern >= TAIL
        slabs << { ceiling: deck_top.round, crown: (deck_top + BRIDGE_H).round }
      end
      slabs
    end
  end

  # A pocket of air caught under the highest part of the deck. Somewhere to put
  # your head up in a place where surfacing is otherwise a two-minute swim — the
  # same trick the islands' dead ends use, and the reason a wreck is worth going
  # *into* rather than photographing from outside.
  def self.build_air(floor)
    col = BOW + NOSE + 4
    x = col * World::COLUMN_WIDTH
    w = 12 * World::COLUMN_WIDTH
    bottom = floor[col] + HOLD_H - 34
    [{ x: x, y: bottom, w: w, h: 30 }]
  end

  # What has grown on it in the meantime. Weed along the hull and on the open
  # mud, thicker where the hull has been standing longest — a wreck that is bare
  # looks like it went down last week.
  def self.build_decorations(floor)
    spots = [8, 16, 34, 46, 58, 80, 92, 104, 126, 140, 150]
    spots.each_with_index.map do |col, i|
      kind = %w[seaweed coral seaweed starfish][i % 4]
      { kind: kind, x: col * World::COLUMN_WIDTH, y: floor[col], scale: 2 }
    end
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

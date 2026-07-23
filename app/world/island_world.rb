# The island: the first hand-built place in an otherwise generated sea.
#
# It is *stamped onto* a generated world rather than replacing it, so the terrain
# still meets its neighbours seamlessly at the segment borders — only the middle
# of the segment is rebuilt. Above the waterline it breaks the surface as a rocky
# hump you can swim up to; at its base a tunnel runs all the way through, so the
# way past the island is *under* it.
module IslandWorld
  SPAN = 720           # px of island across, centred in the segment (borders stay untouched)
  PEAK = 200           # how far above the waterline the summit rises
  SHORE_LIP = 24       # how far the rock still stands out of the water at the shore
  TUNNEL_HEIGHT = 200  # clear water between the tunnel floor and its roof
  DOME_SPAN = 240      # width of the air chamber halfway through the tunnel
  DOME_RISE = 260      # how much higher the chamber's roof sits than the tunnel's
  AIR_DEPTH = 90       # how deep the air trapped under that roof reaches
  CROWN_STEP = 16      # the island's own terrace grid — chunkier than the sea floor
  CROWN_ROUGH = 56     # how much the summit line breaks up
  CROWN_SEED = 707
  SUMMIT_ROCKS = 5     # decor sprites scattered along the crown

  def self.build(world)
    first = first_column
    last = last_column
    floor = world.floor.dup
    roof = Array.new(world.columns) { nil }
    mouth_left = world.floor[first]
    mouth_right = world.floor[last - 1]

    # The chamber's roof is level even though the tunnel floor ramps, so the air
    # under it is a clean pocket rather than a wedge.
    dome = tunnel_floor(mouth_left, mouth_right, chamber_t) + TUNNEL_HEIGHT + DOME_RISE

    (first...last).each do |col|
      t = (col - first) / (last - 1 - first).to_f # 0..1 across the island
      base = tunnel_floor(mouth_left, mouth_right, t)
      floor[col] = base
      ceiling = chamber?(col) ? dome : base + TUNNEL_HEIGHT
      roof[col] = { ceiling: ceiling, crown: crown_y(col, t, base) }
    end

    World.new(index: world.index, biome: world.biome, floor: floor, roof: roof,
              decorations: decorations(world, roof, first, last),
              air_pockets: [chamber_air(dome)])
  end

  # Where the chamber sits along the island, 0..1.
  def self.chamber_t
    ((chamber_first + chamber_last) / 2 - first_column) / (last_column - 1 - first_column).to_f
  end

  # Halfway through the tunnel the roof lifts into a chamber. The dome is flat so
  # the air under it is a clean pocket — and stepping back out of it means diving
  # under the lower tunnel roof again.
  def self.chamber?(col)
    col >= chamber_first && col < chamber_last
  end

  def self.chamber_first
    (first_column + last_column) / 2 - DOME_SPAN.idiv(World::COLUMN_WIDTH) / 2
  end

  def self.chamber_last
    chamber_first + DOME_SPAN.idiv(World::COLUMN_WIDTH)
  end

  # The air trapped under the dome: from the water surface inside the chamber up
  # to the rock. Surfacing in here means breathing — the cave is a rest stop, not
  # a one-way trip.
  def self.chamber_air(ceiling)
    {
      x: chamber_first * World::COLUMN_WIDTH,
      y: ceiling - AIR_DEPTH,
      w: (chamber_last - chamber_first) * World::COLUMN_WIDTH,
      h: AIR_DEPTH,
    }
  end

  def self.first_column
    ((SCREEN_WIDTH - SPAN) / 2).idiv(World::COLUMN_WIDTH)
  end

  def self.last_column
    first_column + SPAN.idiv(World::COLUMN_WIDTH)
  end

  def self.island?(local_x)
    col = local_x.idiv(World::COLUMN_WIDTH)
    col >= first_column && col < last_column
  end

  # The tunnel's bottom: a straight ramp from the sand at one mouth to the sand
  # at the other, so the corridor meets the sea floor flush at both ends and the
  # diver never has to climb a step to get in or out.
  def self.tunnel_floor(mouth_left, mouth_right, t)
    y = mouth_left + (mouth_right - mouth_left) * t
    (y / WorldGenerator::FLOOR_STEP).floor * WorldGenerator::FLOOR_STEP
  end

  # The island's outer silhouette: a hump breaking the surface, roughed up and
  # terraced so it reads as rock rather than a smooth dome. It always stands
  # clear of the water — a shelf just under the surface would be a wall the
  # diver can neither pass nor swim over.
  def self.crown_y(col, t, base)
    hump = Math.sin(Math::PI * t)
    rough = (Noise.value(col * World::COLUMN_WIDTH, 96, CROWN_SEED) - 0.5) * CROWN_ROUGH
    y = WATERLINE_Y + SHORE_LIP + PEAK * hump + rough
    y = (y / CROWN_STEP).floor * CROWN_STEP
    lowest = WATERLINE_Y + SHORE_LIP
    y < lowest ? lowest : y
  end

  # Keep the sea floor's decorations outside the island (the ones inside would
  # now sit in solid rock) and scatter a few rocks along the summit instead.
  def self.decorations(world, roof, first, last)
    outside = world.decorations.reject do |d|
      col = d[:x].idiv(World::COLUMN_WIDTH)
      col >= first && col < last
    end
    outside + summit_rocks(roof, first, last)
  end

  def self.summit_rocks(roof, first, last)
    step = (last - first) / (SUMMIT_ROCKS + 1)
    (1..SUMMIT_ROCKS).map do |i|
      col = first + i * step
      { kind: "rock", x: col * World::COLUMN_WIDTH, y: roof[col][:crown], scale: 3 }
    end
  end
end

# A generated (or hand-authored) underwater world, as *data*: a floor
# heightmap, decoration placements and its biome. Rendering happens elsewhere
# (Game#render_world) — this object never touches outputs, so it stays testable
# and can come from either the generator or a static definition.
class World
  COLUMN_WIDTH = 8 # width in px of one floor column (small = finely stepped sand)

  attr_reader :index, :biome, :floor, :decorations, :roof, :air_pockets

  # floor:       array of sand *world y* values, one per column across the
  #              segment. Higher = shallower; deep trenches are far below 0.
  # decorations: array of { kind:, x:, y:, scale: } resting on the floor
  # roof:        optional solid rock *above* the sand — nil when the segment has
  #              none at all, otherwise one entry per column: an array of slabs,
  #              each { ceiling:, crown: } — rock from `ceiling` (its underside,
  #              what the diver bumps his head on) up to `crown` (its top), and
  #              `[]` where the water is open all the way up. A heightmap alone
  #              cannot describe a cave; this is the other half. It is a *list*
  #              because one column can hold more than one slab — that is what
  #              lets a passage run over another one with rock in between, and
  #              so what makes a tunnel a network rather than a corridor.
  # air_pockets: rects { x:, y:, w:, h: } of air trapped under rock. Their bottom
  #              edge is the water surface inside; a diver whose head is in one
  #              can breathe there.
  def initialize(index:, biome:, floor:, decorations:, roof: nil, air_pockets: [])
    @index = index
    @biome = biome
    @floor = floor
    @decorations = decorations
    @roof = roof
    @air_pockets = air_pockets
  end

  # The water surface inside an air pocket over this segment-local x — the level
  # a diver floats at in there — or nil where there is no trapped air.
  def air_line_at(x)
    over = air_pockets.select { |air| x >= air[:x] && x < air[:x] + air[:w] }
    over.empty? ? nil : over.map { |air| air[:y] }.min
  end

  # Is this segment-local point inside rock — sand below the floor, or the body
  # of any slab hanging above it?
  def solid_at?(x, y)
    return true if y < floor_y_at(x)

    slabs_at(x).any? { |slab| y >= slab[:ceiling] && y <= slab[:crown] }
  end

  # Is this segment-local point inside trapped air?
  def air_at?(x, y)
    air_pockets.any? do |air|
      x >= air[:x] && x < air[:x] + air[:w] && y >= air[:y] && y <= air[:y] + air[:h]
    end
  end

  def columns
    floor.length
  end

  # World y of the sand surface at a given segment-local x.
  def floor_y_at(x)
    floor[column_at(x)]
  end

  # Every slab of rock stacked over a segment-local x, lowest first — empty where
  # the water is open all the way to the surface.
  def slabs_at(x)
    return [] unless roof

    roof[column_at(x)] || []
  end

  def column_at(x)
    col = x / COLUMN_WIDTH
    return 0 if col < 0
    return columns - 1 if col >= columns

    col
  end
end

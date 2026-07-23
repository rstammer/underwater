# A generated (or hand-authored) underwater world, as *data*: a floor
# heightmap, decoration placements and its biome. Rendering happens elsewhere
# (Game#render_world) — this object never touches outputs, so it stays testable
# and can come from either the generator or a static definition.
class World
  COLUMN_WIDTH = 8 # width in px of one floor column (small = finely stepped sand)

  attr_reader :index, :biome, :floor, :decorations

  # floor:       array of sand *world y* values, one per column across the
  #              segment. Higher = shallower; deep trenches are far below 0.
  # decorations: array of { kind:, x:, y:, scale: } resting on the floor
  def initialize(index:, biome:, floor:, decorations:)
    @index = index
    @biome = biome
    @floor = floor
    @decorations = decorations
  end

  def columns
    floor.length
  end

  # World y of the sand surface at a given segment-local x.
  def floor_y_at(x)
    col = x / COLUMN_WIDTH
    col = 0 if col < 0
    col = columns - 1 if col >= columns
    floor[col]
  end

  # The deepest point of this segment — how far down there is to explore here.
  def deepest_y
    floor.min
  end
end

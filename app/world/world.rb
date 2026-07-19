# A generated (or hand-authored) underwater world, as *data*: a floor
# heightmap, decoration placements and its biome. Rendering happens elsewhere
# (Game#render_world) — this object never touches outputs, so it stays testable
# and can come from either the generator or a static definition.
class World
  COLUMN_WIDTH = 16 # width in px of one floor column

  attr_reader :index, :biome, :floor, :decorations

  # floor:       array of sand heights (px), one per column across the screen
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

  # Sand height at a given screen x.
  def floor_height_at(x)
    col = x / COLUMN_WIDTH
    col = 0 if col < 0
    col = columns - 1 if col >= columns
    floor[col]
  end
end

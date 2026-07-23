# A generated (or hand-authored) underwater world, as *data*: a floor
# heightmap, decoration placements and its biome. Rendering happens elsewhere
# (Game#render_world) — this object never touches outputs, so it stays testable
# and can come from either the generator or a static definition.
class World
  COLUMN_WIDTH = 8 # width in px of one floor column (small = finely stepped sand)

  attr_reader :index, :biome, :floor, :decorations, :roof

  # floor:       array of sand *world y* values, one per column across the
  #              segment. Higher = shallower; deep trenches are far below 0.
  # decorations: array of { kind:, x:, y:, scale: } resting on the floor
  # roof:        optional second solid span per column — nil for open water, or
  #              { ceiling:, crown: }: rock from `ceiling` (its underside, what
  #              the diver bumps his head on) up to `crown` (its top). A
  #              heightmap alone cannot describe a cave; this is the other half.
  def initialize(index:, biome:, floor:, decorations:, roof: nil)
    @index = index
    @biome = biome
    @floor = floor
    @decorations = decorations
    @roof = roof
  end

  def columns
    floor.length
  end

  # World y of the sand surface at a given segment-local x.
  def floor_y_at(x)
    floor[column_at(x)]
  end

  # The rock overhead at a segment-local x — { ceiling:, crown: } or nil where
  # the water is open all the way to the surface.
  def roof_at(x)
    roof && roof[column_at(x)]
  end

  def column_at(x)
    col = x / COLUMN_WIDTH
    return 0 if col < 0
    return columns - 1 if col >= columns

    col
  end
end

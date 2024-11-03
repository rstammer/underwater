class SandTile
  COLORS = [
    [242, 208, 169],
    [238, 200, 143],
    [225, 188, 109]
  ]
  def initialize(grid, x, y)
    @grid = grid
    @x = x
    @y = y
    @r, @g, @b = COLORS.sample
  end

  def to_h
    {
      x: @x,
      y: @y,
      w: 8,
      h: 12 + rand(4),
      r: @r + (-1)**rand(2) + rand(25),
      g: @g + (-1)**rand(2) + rand(25),
      b: @b + (-1)**rand(2) + rand(25),
    }
  end
end

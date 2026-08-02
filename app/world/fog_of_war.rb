# The dark closing in around the diver: everything further off than the radius
# is painted over, on a 40 px grid so the edge is blocky rather than smooth.
#
# It used to be emitted one cell at a time — 33 × 19 of them, each with its own
# square root and its own hash, of which up to 582 were actually drawn. That is
# most of a frame's primitives spent on a shape with two edges, and it was the
# single largest thing the web build was paying for.
#
# A row of the grid is a *run*: the clear circle cuts one contiguous hole out of
# it, so everything left of the hole is one rect and everything right of it is
# another. Same grid, same blocky edge, the same cells dark — 26 rects instead
# of 582, and one square root per row instead of one per cell.
# tests/fog_of_war_tests.rb holds the runs against a cell-by-cell reading.
class FogOfWar
  CELL = 40
  LAST_COL = 32 # x: 0..32 ...
  LAST_ROW = 18 # ... y: 0..18 — a little past the screen on both axes

  # radius: how far the diver can see (bigger = brighter, more open water).
  # color:  the fog tint, so it blends with the biome's deep water.
  def initialize(diver, radius: 220, color: [8, 5, 77])
    @diver = diver
    @radius = radius
    @color = color
  end

  def fog_square(x, y, w, h)
    {
      x: x,
      y: y,
      w: w,
      h: h,
      r: @color[0],
      g: @color[1],
      b: @color[2],
      path: :solid,
    }
  end

  def to_a
    here = @diver.to_h
    dark = []
    row = 0
    while row <= LAST_ROW
      add_row(dark, here[:x], here[:y], row)
      row += 1
    end
    dark
  end

  private

  # One row of the grid: the dark either side of the clear span, or the whole
  # row where the circle does not reach it at all.
  def add_row(dark, x, y, row)
    clear = clear_span(x, y, row)
    unless clear
      dark << fog_square(0, row * CELL, (LAST_COL + 1) * CELL, CELL)
      return
    end

    first, last = clear
    dark << fog_square(0, row * CELL, first * CELL, CELL) if first > 0
    return unless last < LAST_COL

    dark << fog_square((last + 1) * CELL, row * CELL, (LAST_COL - last) * CELL, CELL)
  end

  # The columns of this row the diver can see, as [first, last] — or nil if the
  # circle misses the row entirely and the whole of it is dark.
  #
  # A cell is clear when it is no further off than the radius, which for a fixed
  # row is |x - col * CELL| <= sqrt(radius² - dy²): one square root for the row,
  # and the ends of the span fall out of it by rounding inward.
  def clear_span(x, y, row)
    dy = y - row * CELL
    reach = @radius * @radius - dy * dy
    return nil if reach < 0

    half = Math.sqrt(reach)
    first = ((x - half) / CELL.to_f).ceil
    last = ((x + half) / CELL.to_f).floor
    first = 0 if first < 0
    last = LAST_COL if last > LAST_COL
    return nil if last < first

    [first, last]
  end
end

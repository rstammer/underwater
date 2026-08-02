class FogOfWarTests
  # Minimal stand-in for a Diver: FogOfWar only calls #to_h and reads :x/:y.
  class DiverStub
    def initialize(x, y)
      @x = x
      @y = y
    end

    def to_h
      { x: @x, y: @y }
    end
  end

  CELL = FogOfWar::CELL
  TOTAL_CELLS = 33 * 19 # x: 0..32, y: 0..18

  # What the fog *means*, spelled out the plain way: one 40 px cell at a time,
  # dark wherever the diver is further off than the radius. The fog is drawn as
  # row runs now — two rects a row instead of up to thirty-three — so this is
  # what the runs are held against. If the two ever disagree the shape changed,
  # which is the only thing about the fog that was ever meant to be fixed.
  def reference_cells(x, y, radius)
    cells = {}
    (0..32).each do |cx|
      (0..18).each do |cy|
        next unless Math.sqrt((x - cx * CELL)**2 + (y - cy * CELL)**2) > radius

        cells["#{cx},#{cy}"] = true
      end
    end
    cells
  end

  # The cells a list of fog rects actually covers.
  def covered_cells(rects)
    cells = {}
    rects.each do |rect|
      cx = rect[:x].idiv(CELL)
      last_x = (rect[:x] + rect[:w]).idiv(CELL)
      while cx < last_x
        cy = rect[:y].idiv(CELL)
        last_y = (rect[:y] + rect[:h]).idiv(CELL)
        while cy < last_y
          cells["#{cx},#{cy}"] = true
          cy += 1
        end
        cx += 1
      end
    end
    cells
  end

  def fog_at(x, y, radius)
    FogOfWar.new(DiverStub.new(x, y), radius: radius).to_a
  end

  def test_everything_is_fogged_when_diver_is_far_away(args, assert)
    fog = fog_at(-10_000, -10_000, 220)

    assert.equal! covered_cells(fog).length, TOTAL_CELLS
  end

  def test_area_around_diver_is_clear(args, assert)
    # With the diver on-screen, the cells within radius 220 are not fogged,
    # so fewer than all cells come back.
    cells = covered_cells(fog_at(640, 360, 220))

    assert.true! cells.length > 0,           "expected some fog, got none"
    assert.true! cells.length < TOTAL_CELLS, "expected a clear area, got full fog"
  end

  def test_fog_squares_are_a_row_of_the_grid_tall(args, assert)
    square = fog_at(-10_000, -10_000, 220).first

    assert.equal! square[:h], CELL
    assert.equal! square[:path], :solid
    assert.equal! square[:w] % CELL, 0, "a run is a whole number of cells wide"
  end

  # The whole point of the runs: the same picture, a fraction of the rects. It
  # used to push up to 582 of them a frame — most of everything the sea drew.
  MOST_RECTS = 40

  def test_the_fog_is_drawn_as_runs_not_as_cells(args, assert)
    # The tightest fog there is (the deep, at depth) is also the fog that used
    # to cost the most, because the smaller the clear circle the more cells fall
    # outside it.
    [120, 153, 220, 293, 410].each do |radius|
      fog = fog_at(640, 360, radius)

      assert.true! fog.length <= MOST_RECTS,
                   "radius #{radius} came out in #{fog.length} rects, not #{MOST_RECTS} or fewer"
    end
  end

  # And the same picture: run-merged or cell by cell, the dark has to fall on
  # exactly the same 40 px squares. Walked across radii and positions, including
  # the corners and well off the screen, where the circle only clips a row or two.
  def test_the_runs_cover_exactly_what_the_cells_did(args, assert)
    checked = 0
    [80, 120, 153, 220, 240, 293, 350, 410].each do |radius|
      [[640, 360], [0, 0], [1279, 719], [200, 120], [1100, 640],
       [640, 60], [-300, 360], [1600, 360], [640, -200], [640, 900]].each do |(x, y)|
        assert.equal! covered_cells(fog_at(x, y, radius)), reference_cells(x, y, radius),
                      "fog at #{x},#{y} radius #{radius} covers different cells"
        checked += 1
      end
    end

    assert.true! checked >= 80, "only #{checked} combinations checked"
  end

  # The diver does not stand on the grid, so the awkward cases are the ones
  # where he is a pixel or two off it. Rolled rather than listed: a fixed
  # handful of positions is exactly the handful an off-by-one hides between.
  def test_the_runs_hold_at_positions_off_the_grid(args, assert)
    rng = Rng.new(20_260_802)
    120.times do
      x = rng.int(1400) - 60
      y = rng.int(800) - 40
      radius = 60 + rng.int(360)

      assert.equal! covered_cells(fog_at(x, y, radius)), reference_cells(x, y, radius),
                    "fog at #{x},#{y} radius #{radius} covers different cells"
    end
  end
end

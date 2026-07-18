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

  TOTAL_CELLS = 33 * 19 # x: 0..32, y: 0..18

  def test_everything_is_fogged_when_diver_is_far_away(args, assert)
    fog = FogOfWar.new(DiverStub.new(-10_000, -10_000)).to_a

    assert.equal! fog.length, TOTAL_CELLS
  end

  def test_area_around_diver_is_clear(args, assert)
    # With the diver on-screen, the cells within radius 220 are not fogged,
    # so fewer than all cells come back.
    fog = FogOfWar.new(DiverStub.new(640, 360)).to_a

    assert.true! fog.length > 0,             "expected some fog, got none"
    assert.true! fog.length < TOTAL_CELLS,   "expected a clear area, got full fog"
  end

  def test_fog_squares_are_40x40_solids(args, assert)
    fog = FogOfWar.new(DiverStub.new(-10_000, -10_000)).to_a
    square = fog.first

    assert.equal! square[:w], 40
    assert.equal! square[:h], 40
    assert.equal! square[:path], :solid
  end
end

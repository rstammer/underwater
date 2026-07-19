class FogOfWar
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
    (0..32).map do |x|
      (0..18).map do |y|
        if Math.sqrt((@diver.to_h[:x] - x * 40)**2 + (@diver.to_h[:y] - y * 40)**2) > @radius
          fog_square(40 * x, 40 * y, 40, 40)
        end
      end
    end.flatten.compact
  end
end

class FogOfWar
  def fog_square(x, y, w, h)
    {
      x: x,
      y: y,
      w: w,
      h: h,
      r: 8,
      g: 5,
      b: 77,
    }
  end

  def create(args)
    (0..32).map do |x|
      (0..18).map do |y|
        if Math.sqrt((args.state.player_x - x*40)**2 + (args.state.player_y - y*40)**2) > 220
          fog_square(40*x, 40*y, 40, 40)
        end
      end
    end.flatten.compact.map(&:solid)
  end
end

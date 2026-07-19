class Game
  def deepness_factors
    state.deepness_values ||= (6..10).to_a.map { |n| n / 10 }
  end

  def water(grid_size)
    if Kernel.tick_count % 122 != 0
      state.water_bands
    else
      deepness_factor = deepness_factors.sample
      state.water_bands =
        # Start at 0 so the bands cover the very bottom rows too — otherwise the
        # default_background peeks through as a light stripe at the bottom edge.
        (0...grid_size).map do |n|
          {
            x: 0,
            y: n * grid.h / grid_size,
            w: grid.w,
            h: grid.h / grid_size + 1,
            r: 0 + rand(25),
            g: 0 + rand(25),
            b: 15 + deepness_factor * n * grid.h / grid_size,
            path: :solid,
          }
        end
    end
  end
end

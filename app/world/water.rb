def deepness_factors
  @deepness_factors ||= (6..10).to_a.map{ |n| n / 10 }
end

def water(args, grid_size)
  if args.state.tick_count % 122 != 0
    @water
  else
    deepness_factor = deepness_factors.sample
    @water =
      (1..grid_size).map do |n|
        {
          x: 0,
          y: n*args.grid.h / grid_size,
          w: args.grid.w,
          h: args.grid.h / grid_size,
          r: 0 + rand(25),
          g: 0 + rand(25),
          b: 15 + deepness_factor * n*args.grid.h / grid_size
        }
      end
  end
end

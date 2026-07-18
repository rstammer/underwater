# NOTE: args.state property names must not collide with these top-level
# method names (water/ground/deepness_factors) — reading args.state.water
# would dispatch to the method. Hence the *_bands / *_values suffixes.
def deepness_factors(args)
  args.state.deepness_values ||= (6..10).to_a.map{ |n| n / 10 }
end

def water(args, grid_size)
  if args.tick_count % 122 != 0
    args.state.water_bands
  else
    deepness_factor = deepness_factors(args).sample
    args.state.water_bands =
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

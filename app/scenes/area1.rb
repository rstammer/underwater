def area1_tick(args)
  args.outputs.solids << default_background(args.grid)
  args.outputs.solids << water(args, 60)
  args.outputs.solids << ground(args)
  args.outputs.sprites << @diver.to_h
  args.outputs.sprites << @dark_shark.to_h
  args.outputs.sprites << (@scalars.map(&:to_h) + @weeds.map(&:to_h)).flatten
  args.outputs.primitives << @fog.create(args) if !!FOG_OF_WAR
end


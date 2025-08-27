def area2_tick(args)
  args.outputs.solids << default_background(args.grid)
  args.outputs.solids << water(args, 60)
  args.outputs.solids << ground(args)
  args.outputs.sprites << @diver.to_h
  args.outputs.primitives << @fog.create(args) if !!FOG_OF_WAR
end


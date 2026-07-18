def area1_tick(args)
  args.outputs.sprites << default_background(args.grid)
  args.outputs.sprites << water(args, 60)
  args.outputs.sprites << ground(args)
end


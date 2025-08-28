def area2_tick(args)
  # Shark movement
  if args.state.dark_shark.x > SCREEN_WIDTH
    args.state.dark_shark.x = -300
    args.state.dark_shark.y = rand(SCREEN_HEIGHT)
  else
    args.state.dark_shark.x = (args.state.dark_shark.x + DarkShark::SPEED)
  end

  if args.tick_count % 30 == 0
    args.state.dark_shark.y = (args.state.dark_shark.y + ((-1)**rand(10) * rand(30))) % SCREEN_WIDTH
  end

  args.outputs.solids << default_background(args.grid)
  args.outputs.solids << water(args, 60)
  args.outputs.solids << ground(args)
  args.outputs.sprites << @dark_shark.to_h
  args.outputs.sprites << (@scalars.map(&:to_h) + @weeds.map(&:to_h)).flatten
end

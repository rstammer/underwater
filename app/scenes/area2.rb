def area2_tick(args)
  if args.inputs.keyboard.key_down.escape
    args.state.game_scene = "title"
    return
  end

  if args.inputs.left
    args.state.direction = :left
    args.state.player_x -= 2
  elsif args.inputs.right
    args.state.player_x += 2
    args.state.direction = :right
  else
    args.state.direction = :right
  end

  if args.inputs.up
    args.state.player_y += 2
  elsif args.inputs.down
    args.state.player_y -= 2
  end

  if !args.inputs.up && args.state.player_y >= 1
    args.state.player_y -= 0.15
  end

  if args.state.player_y <= 1
    args.state.player_y = 1
  end

  if args.state.direction == :right
    if args.inputs.up && (args.inputs.left || args.inputs.right)
      args.state.angle += 0.5
    elsif args.inputs.down && (args.inputs.left || args.inputs.right)
      args.state.angle -= 0.5
    else
      args.state.angle = 0
    end
  else
    if args.inputs.up && (args.inputs.left || args.inputs.right)
      args.state.angle -= 0.5
    elsif args.inputs.down && (args.inputs.left || args.inputs.right)
      args.state.angle += 0.5
    else
      args.state.angle = 0
    end
  end

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

  # Render screen
  args.outputs.solids << default_background(args.grid)
  args.outputs.solids << water(args, 60)
  args.outputs.solids << ground(args)
  args.outputs.sprites << @diver.to_h
  args.outputs.sprites << @dark_shark.to_h
  args.outputs.sprites << (@scalars.map(&:to_h) + @weeds.map(&:to_h)).flatten
  args.outputs.primitives << @fog.create(args) if !!FOG_OF_WAR
end


def title_tick(args)
  if fire_input?(args)
    args.state.game_scene = "active"
    return
  end

  labels = []
  labels << {
    x: 40,
    y: args.grid.h - 40,
    r: 0,
    g: 0,
    b: 0,
    text: "Underwater",
    size_enum: 20,
  }
  labels << {
    x: 40,
    y: args.grid.h - 128,
    text: "Just try to survive :)",
  }
  labels << {
    x: 40,
    y: 120,
    text: "Arrows or WASD to move | ESC for pause | gamepad works, too",
  }
  labels << {
    x: 40,
    y: 80,
    text: "Press space to start",
    size_enum: 2,
  }

  args.outputs.solids << {
    x: 0,
    y: 0,
    w: args.grid.w,
    h: args.grid.h,
    r: 48,
    g: 95,
    b: 177,
  }

  args.outputs.labels << labels
end


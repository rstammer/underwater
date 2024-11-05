def game_over_tick(args)
  if fire_input?(args)
    args.state.game_scene = "active"
    reset_game(args)
    return
  end

  labels = []
  labels << {
    x: 40,
    y: args.grid.h - 40,
    r: 0,
    g: 0,
    b: 0,
    text: "Oh nein! Du wurdest leider gefressen!",
    size_enum: 20,
  }
  labels << {
    x: 40,
    y: args.grid.h - 128,
    text: "Versuche es noch einmal.",
  }
  labels << {
    x: 40,
    y: 80,
    text: "Drücke LEERTASTE um neu zu starten",
    size_enum: 2,
  }

  args.outputs.solids << {
    x: 0,
    y: 0,
    w: args.grid.w,
    h: args.grid.h,
    r: 156,
    g: 44,
    b: 40,
  }

  args.outputs.labels << labels
end

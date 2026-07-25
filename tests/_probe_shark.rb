class ProbeSharkTests
  def test_probe(args, assert)
    game = Game.new
    game.args = args
    game.initialize_game(0)
    args.state.island_sectors = []
    args.state.world_cache = {}
    sector = (0..40).find { |i| game.world_for(i).biome.shark }
    args.state.game_scene = "area1"
    args.state.diver_global_x = sector * SCREEN_WIDTH + 640
    args.state.depth_y = WorldGenerator.floor_y_at(args.state.diver_global_x) + 300
    game.center_camera
    game.current_world
    d = args.state.depth_y

    on_screen = 0
    jumps = 0
    prev_sx = nil
    runs = []   # stretches of consecutive on-screen ticks
    current = 0
    1500.times do
      game.swim_sideways(Diver::SPEED) # ... but this time he is exploring
      game.update_depth_and_camera
      game.current_world               # so segments change under him
      game.update_characters(0)
      args.state.game_scene = "area1" # ignore bites, we only want the picture
      args.state.depth_y = d
      sprite = game.place_in_current_chunk(args.state.shark.to_h)
      sx = sprite[:x]
      visible = sx > -DarkShark::WIDTH * 2 && sx < SCREEN_WIDTH &&
                sprite[:y] > -64 && sprite[:y] < SCREEN_HEIGHT
      if visible
        on_screen += 1
        current += 1
      elsif current > 0
        runs << current
        current = 0
      end
      jumps += 1 if prev_sx && (sx - prev_sx).abs > 50
      prev_sx = sx
    end
    runs << current if current > 0

    puts "over 1500 ticks (25 s): on screen #{on_screen} ticks (#{(on_screen * 100 / 1500)}%)"
    puts "  visible stretches, in ticks: #{runs.inspect}"
    puts "  (#{runs.map { |r| (r / 60.0).round(1) }.inspect} seconds)"
    puts "  sudden jumps of the on-screen x: #{jumps}"
    puts "  shark y #{args.state.dark_shark.y.round} vs diver #{d.round}; camera_y #{args.state.camera_y.round}"
    assert.true! true
  end
end

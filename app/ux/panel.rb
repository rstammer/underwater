class Panel
  SCENE_TITLES = {
    "area1" => "Spürst du die große Stille?",
    "area2" => "Achtung, Skalare und mehr!"
  }

  def initialize(args, diver)
    @current_args = args
    @diver = diver
  end

  def to_a
    [scene] + debug_output
  end

  def debug_output
    return [] unless !!DEBUG

    [
      {
        x: 140,
        y: 720 - 10,
        anchor_y: 100,
        text: "x: #{@current_args.state.player_x} (#{@diver.to_h[:x]})",
        r: 200,
        g: 100,
        b: 100
      }
    ]
  end

  def scene
    {
      x: 20,
      y: 720 - 10,
      anchor_y: 100,
      text: SCENE_TITLES[@current_args.state.game_scene],
      r: 200,
      g: 100,
      b: 100
    }
  end
end

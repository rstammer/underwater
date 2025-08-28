class Panel
  def initialize(args, diver)
    @current_args = args
    @diver = diver
  end

  def to_a
    [
      {
        x: 20,
        y: 720 - 10,
        anchor_y: 100,
        text: "#{@current_args.state.game_scene}",
        r: 200,
        g: 100,
        b: 100
 
      },
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
end

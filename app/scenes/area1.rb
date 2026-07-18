class Game
  def area1_tick
    outputs.sprites << default_background
    outputs.sprites << water(60)
    outputs.sprites << ground
  end
end

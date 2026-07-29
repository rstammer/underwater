# One of the island's people, at the place on it where they are standing today.
#
# The same split as Species and Creature: Islander is the description — who they
# are and what they say — and this is that person put somewhere. It carries no
# behaviour of its own because they have none: they do not walk, they do not
# flee, they stand in the sun where they always stand. Placing them is a pure
# function of the island (Game#place_islander), so there is nothing to tick.
class Beachgoer
  attr_reader :islander, :x, :y

  def initialize(islander:, x:, y:)
    @islander = islander
    @x = x
    @y = y
  end

  def key
    @islander.key
  end

  def name
    @islander.name
  end

  def kind
    @islander.kind
  end
end

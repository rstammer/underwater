# What you are carrying, as opposed to what the game is. Reopens Game.
#
# Film, air and the suit's rating used to be constants — three numbers baked
# into the rules. They are the three clocks the whole game runs on: how many
# pictures a dive is worth, how long you may stay, how deep you may go. Making
# them buyable turns each of them from a rule into a decision, and that only
# works if they are *things you own*: they belong in the save file next to the
# Artenbuch, because kit is the other half of a career.
#
# Each is a level rather than a number, so the shop has a ladder to sell and the
# save file has one small integer to keep. The constants stay as the bottom rung
# — a diver with no gear at all is exactly the diver the game had before.
class Game
  # The bottom rung of each ladder is written out rather than read off the
  # constant it matches: this file is required from the top of main.rb, and the
  # top-level constants are defined *below* those requires — reaching for
  # OXYGEN_MAX here takes the whole game down at boot. A test pins each first
  # rung to its constant instead, which catches the drift without the load
  # order having to cooperate.
  #
  # Frames on a roll (FILM_MAX).
  FILM_STEPS = [12, 20, 30].freeze
  # Air, as tank capacity (OXYGEN_MAX). At OXYGEN_DRAIN that is about 1.5, 2.5 and 3.5
  # minutes under water — the first rung is deliberately short, because the swim
  # home has to be something you think about from the very first dive.
  AIR_STEPS = [100, 166, 233].freeze
  # Metres the suit is rated for (SUIT_DEPTH_LIMIT) before the pressure starts working on it.
  SUIT_STEPS = [100, 170, 250].freeze

  # The shop's stock, as data: what it is, what it does, what each rung costs.
  # One list, read by the shelf, the prices and the tests alike.
  GEAR = [
    { key: :film, name: "Filmrolle", steps: FILM_STEPS, prices: [nil, 150, 420],
      unit: "Aufnahmen",
      blurb: "Mehr Bilder pro Tauchgang. Nichts ärgert so wie ein leerer Film über einer neuen Art." },
    { key: :air, name: "Sauerstoffflasche", steps: AIR_STEPS, prices: [nil, 220, 560],
      unit: "Luft",
      blurb: "Länger unten bleiben. Rechne trotzdem immer den Rückweg mit." },
    { key: :suit, name: "Tauchanzug", steps: SUIT_STEPS, prices: [nil, 380, 950],
      unit: "m Druck",
      blurb: "Tiefer runter, ohne dass die Nähte arbeiten. Da unten wohnt, was sonst niemand fotografiert." },
  ].freeze

  def reset_gear
    state.gear = { film: 0, air: 0, suit: 0 }
  end

  # Defaulted rather than trusted: a book written before there was any gear
  # simply has not got it, and that diver owns nothing, which is the same as
  # starting where everybody starts.
  def gear_level(key)
    (state.gear && state.gear[key]) || 0
  end

  def gear_item(key)
    GEAR.find { |item| item[:key] == key }
  end

  def gear_value(key)
    item = gear_item(key)
    item[:steps][gear_level(key)] || item[:steps].last
  end

  def film_capacity
    gear_value(:film)
  end

  def air_capacity
    gear_value(:air)
  end

  def suit_limit
    gear_value(:suit)
  end

  # --- buying it -------------------------------------------------------------

  def gear_top?(key)
    gear_level(key) >= gear_item(key)[:steps].length - 1
  end

  # What the next rung costs, or nil where there is no next rung.
  def gear_price(key)
    return nil if gear_top?(key)

    gear_item(key)[:prices][gear_level(key) + 1]
  end

  def can_afford?(key)
    price = gear_price(key)
    !price.nil? && state.credits >= price
  end

  # Bought. The tank and the roll are *filled* on the spot rather than only
  # counting from the next dive — you have just paid for them, and standing on
  # an island holding a bigger empty bottle would be a poor thank you.
  #
  # A pure state change: no key reading, no screen, so the shop's arithmetic can
  # be tested without a shop.
  def buy_gear(key)
    return false unless can_afford?(key)

    state.credits -= gear_price(key)
    state.gear[key] = gear_level(key) + 1
    state.oxygen = air_capacity if key == :air
    state.film_left = film_capacity if key == :film
    state.suit = SUIT_MAX if key == :suit
    save_book # kit is career, and a career belongs on disk the moment it changes
    true
  end
end

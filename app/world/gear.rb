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
  # How far you see, as a multiplier on the fog. A mask is the one piece of kit
  # you look *through*, so it buys the thing the deep takes away first.
  MASK_STEPS = [100, 130, 165].freeze
  # And how fast you swim, in percent. Fins are the difference between the sea
  # being big and the sea being far.
  FINS_STEPS = [100, 118, 140].freeze

  # The shop's stock, as data: what it is, what it does, what each rung costs.
  # One list, read by the shelf, the prices and the tests alike.
  # Every rung has a name, because "Stufe 2" tells you nothing and a diver talks
  # about their kit by what it is called. They are also the only place in the
  # game allowed to be silly.
  GEAR = [
    { key: :film, name: "Filmrolle", steps: FILM_STEPS, prices: [nil, 150, 420],
      unit: "Aufnahmen",
      titles: ["Zwölfer-Rolle", "Zwanziger-Rolle", "Dreißiger-Grossbild"],
      blurb: "Mehr Bilder pro Tauchgang. Nichts ärgert so wie ein leerer Film über einer neuen Art." },
    { key: :air, name: "Sauerstoffflasche", steps: AIR_STEPS, prices: [nil, 220, 560],
      unit: "Luft",
      titles: ["Rostige Pressluftpulle", "Solide Doppelflasche", "Tiefsee-Zwilling XL"],
      blurb: "Länger unten bleiben. Rechne trotzdem immer den Rückweg mit." },
    { key: :suit, name: "Tauchanzug", steps: SUIT_STEPS, prices: [nil, 380, 950],
      unit: "m Druck",
      titles: ["Dünner Leih-Neopren", "Verstärkter Zweiteiler", "Abgrund-Montur"],
      blurb: "Tiefer runter, ohne dass die Nähte arbeiten. Da unten wohnt, was sonst niemand fotografiert." },

    { key: :mask, name: "Tauchmaske", steps: MASK_STEPS, prices: [nil, 190, 480],
      unit: "% Sicht",
      titles: ["Beschlagene Leihmaske", "Klarsicht Panorama", "Weitwinkel Adlerauge"],
      blurb: "Du siehst weiter. Was du früher siehst, kannst du früher fotografieren." },

    { key: :fins, name: "Flossen", steps: FINS_STEPS, prices: [nil, 160, 430],
      unit: "% Tempo",
      titles: ["Ausgelatschte Gummifüße", "Schnelle Schwimmhäute", "Turbo-Delfinflossen"],
      blurb: "Schneller unterwegs. Das Meer wird nicht kleiner, aber die Wege werden kürzer." },
  ].freeze

  def reset_gear
    state.gear = { film: 0, air: 0, suit: 0, mask: 0, fins: 0 }
  end

  # What this rung is called. The shop and the boat's kit page both say it, so a
  # diver names their gear rather than reciting its number.
  def gear_title(key)
    item = gear_item(key)
    item[:titles][gear_level(key)] || item[:titles].last
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

  # A rung as the player experiences it. The tank's raw capacity is a number
  # nobody can act on — "166 Luft" means nothing, and it was printed on the shelf
  # exactly like that. What you actually feel is minutes, so that is what the
  # shop says.
  def gear_reading(key, value)
    case key
    when :air then air_minutes_label(value)
    when :suit then "#{value} m"
    else "#{value} Aufnahmen"
    end
  end

  # Tenths of a minute, with the German comma, built by hand — there is no
  # locale in here to ask and no format string that would do it.
  def air_minutes_label(capacity)
    tenths = (capacity / OXYGEN_DRAIN / 360.0).round
    "#{tenths.idiv(10)},#{tenths % 10} min"
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

  # Both are percentages of the bare-kit value, so an unbought pair of fins and
  # an unbought mask leave the game exactly as it was.
  def sight_factor
    gear_value(:mask) / 100.0
  end

  def swim_factor
    gear_value(:fins) / 100.0
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

# The island shop, and the woman who runs it. Reopens Game.
#
# It stands on a fixed island (IslandWorld::SHOP_SECTOR), always in the same
# place, always with a beach you can walk up. A shop you have to search for is
# not somewhere you pop back to.
#
# What it sells is the three clocks the game runs on — film, air, pressure (see
# app/world/gear.rb). Each is a ladder of three rungs and each rung is a decision
# about which limit you would rather stop feeling.
#
# Insa is the other half of it. Her line is not decoration and it is not a
# pot of quotes rolled at random: it is picked off *your* state — how deep you
# have been, how the book is coming along, what you are carrying, what you have
# not seen yet. A shopkeeper who tells you the same thing every visit is a
# vending machine; one who notices is a person, and she doubles as the only
# signposting the game has for water you have not found yet.
class Game
  SHOP_KEEPER = "Insa"
  SHOP_MARGIN = 26
  SHOP_PAD = 26
  SHOP_HEAD_H = 96
  SHOP_FOOT_H = 44
  SHOP_ROW_H = 96
  SHOP_INK = [232, 244, 252]
  SHOP_DIM = [150, 184, 208]
  SHOP_WARN = [240, 200, 150]

  # --- getting in and out ----------------------------------------------------

  def update_shop
    if state.game_scene == "shop"
      close_shop if shop_key? || inputs.keyboard.key_down.escape
    elsif !game_paused? && at_the_shop? && shop_key?
      open_shop
    end
  end

  def shop_key?
    inputs.keyboard.key_down.l
  end

  def open_shop
    state.game_scene = "shop"
    state.shop_row = 0
    state.shop_said = shop_tip # settled on entry, so it cannot change while read
  end

  def close_shop
    state.game_scene = state.diver_global_x < 1281 ? "area1" : "area2"
  end

  # Arrows walk the shelf, E buys. A plain state change apiece, so the shop's
  # behaviour is testable without simulated keys.
  def update_shop_input
    return unless state.game_scene == "shop"

    move_shop_cursor(-1) if inputs.keyboard.key_down.down
    move_shop_cursor(1) if inputs.keyboard.key_down.up
    buy_selected if inputs.keyboard.key_down.e || inputs.keyboard.key_down.enter
  end

  def move_shop_cursor(by)
    state.shop_row = ((state.shop_row || 0) + by) % GEAR.length
  end

  def selected_gear
    GEAR[(state.shop_row || 0) % GEAR.length][:key]
  end

  # She says something about what you just bought — the one moment a shopkeeper
  # is guaranteed to have your attention.
  def buy_selected
    key = selected_gear
    return false unless buy_gear(key)

    state.shop_said = "Gute Wahl. #{gear_item(key)[:blurb]}"
    true
  end

  # --- what she says ---------------------------------------------------------

  # Read off the state, most specific first. The order is the point: the first
  # thing that is true about this diver is the most useful thing to tell them.
  def shop_tip
    return "Du bist ja ganz neu. Fang flach an — die Sandbank ist voller Anfänger wie du, und die zahlen auch." if state.log_dives.to_i <= 1
    return "Erst mal Luft holen? Dein Anzug hat was abbekommen." if state.suit < SUIT_MAX * 0.4
    return "Mit dem Anzug kommst du keine hundert Meter tief. Das Beste da unten fängt aber erst darunter an." if gear_level(:suit).zero? && state.log_best.to_i >= 80
    return "Zwölf Bilder sind schnell weg, wenn's mal gut läuft. Frag mich, wenn du magst." if gear_level(:film).zero? && album_found >= 4
    return "Anderthalb Minuten Luft sind nicht viel. Die meisten kaufen als Erstes die grössere Flasche." if gear_level(:air).zero?
    return "Such mal das ganz klare Wasser weiter draussen. Da zieht was durch, das passt auf kein Foto." unless (state.sighted || {}).key?("blauwal")
    return "Quallenfelder sehen harmlos aus. Schwimm drumrum, nicht durch — das kostet dich sonst den Rückweg." unless (state.sighted || {}).key?("mondqualle")
    return "Du hast Geld auf der Tasche. Gönn dir was, das Meer läuft dir nicht weg." if state.credits >= 400
    return "Das Artenbuch füllt sich. Die seltenen sitzen tief und lassen sich nicht anschwimmen — warte, bis sie kommen." if album_found >= 8

    "Schön, dich zu sehen. Pass auf dich auf da draussen."
  end

  # --- the screen ------------------------------------------------------------

  def shop_rows
    GEAR.map do |item|
      key = item[:key]
      { key: key, name: item[:name],
        now: gear_value(key),
        nxt: gear_top?(key) ? nil : item[:steps][gear_level(key) + 1],
        price: gear_price(key), unit: item[:unit], blurb: item[:blurb] }
    end
  end

  def shop_tick
    render_underwater # the frozen island behind the veil
    render_fog
    outputs.sprites << { x: 0, y: 0, w: grid.w, h: grid.h,
                         r: 4, g: 12, b: 22, a: MENU_VEIL, path: :solid }
    render_shop_screen
  end

  def render_shop_screen
    left = SHOP_MARGIN
    right = grid.w - SHOP_MARGIN
    top = grid.h - SHOP_MARGIN
    bottom = SHOP_MARGIN

    outputs.sprites << { x: left, y: bottom, w: right - left, h: top - bottom,
                         r: MENU_BG[0], g: MENU_BG[1], b: MENU_BG[2], path: :solid }
    outputs.sprites << { x: left, y: top - 4, w: right - left, h: 4,
                         r: MENU_ACCENT[0], g: MENU_ACCENT[1], b: MENU_ACCENT[2], path: :solid }

    render_shop_head(left, right, top)
    render_shop_shelf(left, right, top - SHOP_HEAD_H - 16)
    outputs.labels << { x: (left + right) / 2, y: bottom + SHOP_FOOT_H - 14,
                        text: "↑ ↓ wählen   ·   [ E ] kaufen   ·   L / ESC zurück",
                        size_enum: 1, alignment_enum: 1, vertical_alignment_enum: 2,
                        r: SHOP_DIM[0], g: SHOP_DIM[1], b: SHOP_DIM[2] }
  end

  # Her name, what she just said, and what you have to spend. The line she says
  # gets the width — it is the reason to come in as much as the shelf is.
  def render_shop_head(left, right, top)
    outputs.sprites << { x: left, y: top - SHOP_HEAD_H, w: right - left, h: SHOP_HEAD_H,
                         r: MENU_PANEL[0], g: MENU_PANEL[1], b: MENU_PANEL[2], path: :solid }
    outputs.labels << { x: left + SHOP_PAD, y: top - 22, text: "#{SHOP_KEEPER}s Laden",
                        size_enum: 4, vertical_alignment_enum: 2,
                        r: SHOP_INK[0], g: SHOP_INK[1], b: SHOP_INK[2] }
    outputs.labels << { x: left + SHOP_PAD, y: top - 60,
                        text: "„#{state.shop_said || shop_tip}\"", size_enum: 1,
                        vertical_alignment_enum: 2, r: 214, g: 232, b: 248 }
    outputs.labels << { x: right - SHOP_PAD, y: top - 22, text: "#{state.credits} Cr",
                        size_enum: 8, alignment_enum: 2, vertical_alignment_enum: 2,
                        r: CREDIT_INK[0], g: CREDIT_INK[1], b: CREDIT_INK[2] }
  end

  def render_shop_shelf(left, right, top)
    shop_rows.each_with_index do |row, i|
      y = top - (i + 1) * SHOP_ROW_H
      here = (state.shop_row || 0) == i
      affordable = row[:price] && state.credits >= row[:price]

      outputs.sprites << { x: left + SHOP_PAD, y: y, w: right - left - SHOP_PAD * 2, h: SHOP_ROW_H - 12,
                           r: MENU_PANEL[0], g: MENU_PANEL[1], b: MENU_PANEL[2],
                           a: here ? 255 : 120, path: :solid }
      outputs.sprites << { x: left + SHOP_PAD, y: y, w: 4, h: SHOP_ROW_H - 12,
                           r: MENU_ACCENT[0], g: MENU_ACCENT[1], b: MENU_ACCENT[2],
                           a: here ? 255 : 0, path: :solid }

      x = left + SHOP_PAD + 24
      ink = here ? SHOP_INK : SHOP_DIM
      outputs.labels << { x: x, y: y + SHOP_ROW_H - 30, text: row[:name], size_enum: 3,
                          vertical_alignment_enum: 2, r: ink[0], g: ink[1], b: ink[2] }
      outputs.labels << { x: x, y: y + SHOP_ROW_H - 62, text: row[:blurb], size_enum: 0,
                          vertical_alignment_enum: 2,
                          r: SHOP_DIM[0], g: SHOP_DIM[1], b: SHOP_DIM[2], a: 190 }

      # The whole decision in one line: what you have, what you would have.
      step = row[:nxt] ? "#{row[:now]}  →  #{row[:nxt]} #{row[:unit]}" : "#{row[:now]} #{row[:unit]}"
      outputs.labels << { x: right - SHOP_PAD - 200, y: y + SHOP_ROW_H - 34, text: step,
                          size_enum: 2, alignment_enum: 2, vertical_alignment_enum: 2,
                          r: ink[0], g: ink[1], b: ink[2] }

      price =
        if row[:price].nil? then "ausgereizt"
        elsif affordable then "#{row[:price]} Cr"
        else "#{row[:price]} Cr — zu teuer"
        end
      colour = row[:price].nil? ? SHOP_DIM : (affordable ? CREDIT_INK : SHOP_WARN)
      outputs.labels << { x: right - SHOP_PAD - 24, y: y + SHOP_ROW_H - 34, text: price,
                          size_enum: 2, alignment_enum: 2, vertical_alignment_enum: 2,
                          r: colour[0], g: colour[1], b: colour[2] }
    end
  end
end

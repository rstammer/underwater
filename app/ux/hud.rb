# The in-game HUD, drawn on top of everything else. Reopens Game so tick can
# just call render_panel; the individual readouts live here rather than in
# main.rb, which is about running the world, not describing it.
class Game
  def render_panel
    return if game_paused?

    render_debug
    render_gauges
    render_film_gauge
    render_locator
    render_credits
    render_inventory
    render_dive_hint
    render_flash    # the shutter going off, over the whole picture
    render_messages # ... and everything the game says to you in passing, down at the foot
    render_touch_controls # the joystick and buttons, once a finger has touched
  end

  # Everything the game tells you while you are swimming: what is in the lens,
  # what is within reach, what you just caught. It used to be strewn across the
  # middle of the screen — which is exactly where the diver is and where you are
  # looking — so it all sits along the bottom edge now.
  #
  # Each kind keeps its own slot rather than the lines closing up: a prompt that
  # jumps a row because something else appeared is harder to read than a gap.
  # Slots count upward from the bottom, so the steadiest line is nearest the eye.
  MESSAGE_Y = 46      # baseline of the lowest slot, up from the bottom edge
  MESSAGE_ROW = 42    # ... and the step between slots
  MESSAGE_W = 600     # one width for every box, whatever is in it (see below)
  MESSAGE_H = 38
  SLOT_PHOTO = 0
  SLOT_PICKUP = 1
  SLOT_NOTE = 2
  SLOT_NEW = 3

  def render_messages
    running_messages.each { |line| render_message(line) }
  end

  def running_messages
    [photo_message, pickup_message, shot_message, fresh_message].compact
  end

  # One fixed width, not a box measured around its own text. Fitting each line
  # snugly meant the box resized every time a different fish came into the lens,
  # and a panel that changes shape under your eyes is read as *movement* — you
  # end up watching it flinch instead of reading it. A test measures the longest
  # line any of these can hold against this width.
  def render_message(line)
    y = MESSAGE_Y + line[:slot] * MESSAGE_ROW
    cx = grid.w / 2

    outputs.sprites << { x: cx - MESSAGE_W / 2, y: y - MESSAGE_H / 2,
                         w: MESSAGE_W, h: MESSAGE_H,
                         r: 12, g: 30, b: 48, a: 180, path: :solid }
    outputs.labels << { x: cx, y: y, text: line[:text], size_enum: line[:size] || 2,
                        alignment_enum: 1, vertical_alignment_enum: 1,
                        r: line[:color][0], g: line[:color][1], b: line[:color][2] }
  end

  HINT_W = 660
  HINT_ROW_H = 30

  # The camera's rules, up in the top half of the screen so they don't sit over
  # the diver, for the first stretch of the first dive.
  def render_dive_hint
    return unless dive_hint_visible?

    lines = dive_hint_lines
    height = 56 + lines.length * HINT_ROW_H + 20
    left = (grid.w - HINT_W) / 2
    top = grid.h - 60

    outputs.sprites << { x: left, y: top - height, w: HINT_W, h: height,
                         r: 12, g: 32, b: 52, a: 225, path: :solid }
    outputs.sprites << { x: left, y: top - 3, w: HINT_W, h: 3,
                         r: 120, g: 190, b: 220, a: 200, path: :solid }

    cx = left + HINT_W / 2
    outputs.labels << { x: cx, y: top - 18, text: "Deine Kamera", size_enum: 2,
                        alignment_enum: 1, vertical_alignment_enum: 2,
                        r: 232, g: 244, b: 252 }
    y = top - 62
    lines.each do |line|
      outputs.labels << { x: cx, y: y, text: line, size_enum: 0,
                          alignment_enum: 1, vertical_alignment_enum: 2,
                          r: 186, g: 214, b: 236 }
      y -= HINT_ROW_H
    end
  end

  FILM_INK = [214, 226, 240]

  # How many frames are left on the roll, under the two gauges. It only matters
  # under water, but it is quiet enough to leave up.
  def render_film_gauge
    outputs.labels << {
      x: GAUGE_X, y: GAUGE_Y - GAUGE_GAP * 2 + 12,
      text: "Film  #{state.film_left} / #{FILM_MAX}", size_enum: 1,
      r: state.film_left.zero? ? 235 : FILM_INK[0],
      g: state.film_left.zero? ? 150 : FILM_INK[1],
      b: state.film_left.zero? ? 150 : FILM_INK[2],
    }
  end

  # A species tells you its name only once it is in the Artenbuch — which is to
  # say once you have brought a picture of it home and developed it. Until then
  # you get what you could actually tell by looking at it (Species#tease): "rot
  # und schlecht gelaunt", "ein Schneckenhaus mit Beinen".
  #
  # That is still the whole answer to "have I got this one already?" — a name
  # means yes, a description means no — but a description is something to read
  # rather than a row of question marks to squint at.
  def species_label(species)
    state.album[species.key] ? species.name : species.tease
  end

  # And the colour says what this shot would be worth, at a glance:
  NEW_INK = [255, 214, 120]    # never had it — this is the one worth the film
  BETTER_INK = [150, 220, 255] # have it, but this would be a better picture
  ENOUGH_INK = [150, 168, 186] # have it, no better than what's in the book

  def photo_ink(species, quality)
    return NEW_INK unless state.album[species.key]
    return BETTER_INK if improves?(species.key, quality)

    ENOUGH_INK
  end

  # With a creature in the lens, a line saying what it is worth and how the shot
  # would come out — so getting closer is visibly worth it before you spend the
  # frame.
  def photo_message
    subject = photo_subject
    return nil unless subject

    species = subject[:species]
    quality = photo_quality(subject[:distance])
    text =
      if state.film_left.zero?
        "Kein Film mehr — am Boot entwickeln"
      elsif !improves?(species.key, quality)
        # Nothing to gain here, so it says nothing about it: the name alone, in
        # the colour that means "you have this". Being told off for swimming past
        # something you already own gets old fast.
        species_label(species)
      else
        "[ F ]  #{species_label(species)}  (#{quality})"
      end

    { text: text, slot: SLOT_PHOTO, color: photo_ink(species, quality) }
  end

  # The flash of the shutter, over the whole picture. Not a message — it is the
  # camera going off, so it stays where it always was.
  def render_flash
    return unless state.shot_at

    since = Kernel.tick_count - state.shot_at
    return unless since < SHUTTER_TICKS

    fade = 255 - (255 * since / SHUTTER_TICKS)
    outputs.sprites << { x: 0, y: 0, w: grid.w, h: grid.h, r: 255, g: 255, b: 255,
                         a: fade, path: :solid }
  end

  # Afterwards, a line saying what he caught. Still nameless if it isn't in the
  # book yet — you have exposed film, not a discovery, and what it was is
  # something the boat tells you.
  def shot_message
    note = fresh_note
    return nil unless note

    # The kraken leaves no grade behind: there is nothing to grade.
    text = note[:quality] ? "#{note[:name]}  —  #{note[:quality]}" : note[:name]
    { text: text, slot: SLOT_NOTE, size: 3,
      color: note[:fresh] ? NEW_INK : [236, 246, 255] }
  end

  def fresh_message
    note = fresh_note
    return nil unless note && note[:fresh]

    { text: "Etwas Neues! Am Boot entwickeln", slot: SLOT_NEW, color: NEW_INK }
  end

  def fresh_note
    return nil unless state.shot_at && state.shot_note
    return nil if Kernel.tick_count - state.shot_at > NOTE_TICKS

    state.shot_note
  end

  INV_X = 20
  INV_Y = 24 # slots sit this far up from the bottom edge
  INV_SLOT = 46
  INV_GAP = 8

  # The three carry slots, bottom-left, clear of the gauges up top — each holds
  # the icon of what's in it; empty slots sit as dim frames so you can see how
  # much room is left.
  def render_inventory
    outputs.labels << { x: INV_X, y: INV_Y + INV_SLOT + 24, text: "Inventar",
                        size_enum: 1, vertical_alignment_enum: 2, r: 210, g: 228, b: 245, a: 175 }
    INVENTORY_MAX.times do |i|
      x = INV_X + i * (INV_SLOT + INV_GAP)
      outputs.sprites << { x: x, y: INV_Y, w: INV_SLOT, h: INV_SLOT, r: 14, g: 30, b: 50, a: 185, path: :solid }
      outputs.sprites << { x: x, y: INV_Y + INV_SLOT - 2, w: INV_SLOT, h: 2, r: 90, g: 140, b: 170, a: 150, path: :solid }

      kind = state.inventory[i]
      next unless kind

      sprite = ITEM_SPRITES[kind]
      outputs.sprites << { x: x + INV_SLOT / 2, y: INV_Y + INV_SLOT / 2,
                           w: sprite[:w] * 2, h: sprite[:h] * 2, path: sprite[:path],
                           anchor_x: 0.5, anchor_y: 0.5 }
    end
  end

  # When an item is within reach, a line telling you what it is and how to take it
  # — or, if the pack is full, that you need to stow something at the boat first.
  def pickup_message
    item = item_in_reach
    return nil unless item

    full = inventory_full?
    text = full ? "Inventar voll — am Boot einlagern" : "[ E ]  #{ITEM_NAMES[item[:kind]]} aufheben"
    { text: text, slot: SLOT_PICKUP,
      color: full ? [240, 200, 150] : [232, 244, 252] }
  end

  # Only with DEBUG on: the diver's world and screen x, for chasing coordinate bugs.
  def render_debug
    return unless !!DEBUG

    outputs.labels << {
      x: 140, y: grid.h - 10, anchor_y: 100,
      text: "x: #{state.diver_global_x} (screen #{state.player_x})",
      r: 200, g: 100, b: 100,
    }
  end

  # A discreet position readout, top-right. Later this can be gated behind
  # carrying a locator device (see locator?).
  def render_locator
    return unless locator?

    outputs.labels << {
      x: grid.w - 20, y: grid.h - 16,
      text: locator_text,
      size_enum: 1, alignment_enum: 2,
      r: 210, g: 228, b: 245, a: 175,
    }
  end

  def locator?
    true # later: only when the diver carries a locator / dive computer
  end

  def locator_text
    "Sektor #{world_index}    Tiefe #{current_depth} m"
  end

  CREDIT_INK = [236, 226, 150]

  # The balance, under the locator. Always up: what you are down here for is
  # money, and a freelance's balance is the one number he never stops knowing.
  def render_credits
    outputs.labels << {
      x: grid.w - 20, y: grid.h - 44,
      text: "#{state.credits} Cr",
      size_enum: 2, alignment_enum: 2,
      r: CREDIT_INK[0], g: CREDIT_INK[1], b: CREDIT_INK[2],
    }
  end

  # Depth below the surface in metres — a whole number from the diver's world
  # position: 0 m at the waterline, growing as he descends toward the sea floor.
  def current_depth
    [(WATERLINE_Y - state.depth_y) / PIXELS_PER_METRE, 0].max.to_i
  end

  GAUGE_X = 20
  GAUGE_Y = 664 # the oxygen bar; the suit hangs under it
  GAUGE_W = 220
  GAUGE_H = 18
  GAUGE_GAP = 62 # enough for the lower gauge's own label to sit clear
  OXYGEN_COLOR = [40, 170, 230]
  SUIT_COLOR = [190, 160, 90]

  # The two things that can run out on you, stacked: how long you can stay down,
  # and how deep you can go.
  def render_gauges
    render_gauge(GAUGE_Y, "Sauerstoff", state.oxygen / OXYGEN_MAX, OXYGEN_COLOR)
    render_gauge(GAUGE_Y - GAUGE_GAP, suit_label, state.suit / SUIT_MAX, SUIT_COLOR)
  end

  def suit_label
    too_deep? ? "Anzug — Druck!" : "Anzug"
  end

  def render_gauge(y, label, ratio, color)
    low = ratio < 0.3
    ratio = 0 if ratio < 0

    outputs.labels << { x: GAUGE_X, y: y + GAUGE_H + 22, text: label,
                        r: low ? 235 : 225, g: low ? 150 : 238, b: low ? 150 : 255 }
    outputs.sprites << { x: GAUGE_X, y: y, w: GAUGE_W, h: GAUGE_H,
                         r: 15, g: 25, b: 45, path: :solid } # track
    outputs.sprites << {                                     # fill
      x: GAUGE_X, y: y, w: GAUGE_W * ratio, h: GAUGE_H,
      r: (low ? 210 : color[0]), g: (low ? 70 : color[1]), b: (low ? 80 : color[2]),
      path: :solid,
    }
  end
end

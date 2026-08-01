# The day's briefing, as its own window. Reopens Game.
#
# It had a tab in the boat screen first, and a tab was the wrong shape for it:
# the hold, the book and the logbook are things you go and look through, and the
# job is the one thing you are supposed to know *before* you go down. Behind a
# tab it sat wherever you last left the screen, two presses away, competing with
# a page of jewellery.
#
# So it is a key of its own, and it says what a magazine's call would say: what
# they want, what it pays, and how you would actually go about it. Nothing on it
# can be pressed — reading it is all it is for, which is why it can be opened
# from the deck and from inside the boat screen alike.
class Game
  ASSIGNMENT_W = 720
  ASSIGNMENT_H = 420
  ASSIGNMENT_PAD = 34
  ASSIGNMENT_HEAD_H = 78
  ASSIGNMENT_LINE_H = 34
  ASSIGNMENT_PANEL = [16, 32, 48]
  ASSIGNMENT_EDGE = [92, 132, 158]
  ASSIGNMENT_TITLE_INK = [236, 246, 255]
  ASSIGNMENT_BODY_INK = [186, 206, 224]
  ASSIGNMENT_FEE_INK = [255, 214, 120]

  # Only at the boat, and only when there is a boat to be at: this is the radio
  # call you take at home, not something you read treading water.
  def open_assignment
    return unless at_the_boat?
    return if ["assignment", "title", "name", "intro", "recap", "night",
               "darkroom", "shop", "game_over"].include?(state.game_scene)

    state.assignment_return = state.game_scene
    state.game_scene = "assignment"
  end

  def close_assignment
    back = state.assignment_return
    state.assignment_return = nil
    # Back to the boat screen if that is where it was opened from, otherwise
    # into the water — closing a briefing should put you where you were.
    if back == "home_menu"
      state.game_scene = "home_menu"
    else
      resume_scene
    end
  end

  # T opens it and T shuts it again, in one place — read in two, the press that
  # closed it would be read again by the one that opens it and it would never go
  # away.
  def update_assignment_key
    return unless inputs.keyboard.key_down.t

    state.game_scene == "assignment" ? close_assignment : open_assignment
  end

  def update_assignment_view
    return unless state.game_scene == "assignment"

    close_assignment if inputs.keyboard.key_down.escape
  end

  def assignment_tick
    render_underwater
    render_fog
    outputs.sprites << { x: 0, y: 0, w: grid.w, h: grid.h,
                         r: 3, g: 10, b: 18, a: 218, path: :solid }
    render_assignment_window
  end

  def render_assignment_window
    x = (SCREEN_WIDTH - ASSIGNMENT_W) / 2
    y = (SCREEN_HEIGHT - ASSIGNMENT_H) / 2
    job = todays_assignment

    outputs.sprites << { x: x - 2, y: y - 2, w: ASSIGNMENT_W + 4, h: ASSIGNMENT_H + 4,
                         r: ASSIGNMENT_EDGE[0], g: ASSIGNMENT_EDGE[1], b: ASSIGNMENT_EDGE[2],
                         path: :solid }
    outputs.sprites << { x: x, y: y, w: ASSIGNMENT_W, h: ASSIGNMENT_H,
                         r: ASSIGNMENT_PANEL[0], g: ASSIGNMENT_PANEL[1], b: ASSIGNMENT_PANEL[2],
                         path: :solid }

    top = y + ASSIGNMENT_H - ASSIGNMENT_PAD
    outputs.labels << { x: x + ASSIGNMENT_PAD, y: top, text: "Auftrag für Tag #{state.day}",
                        size_enum: 4, vertical_alignment_enum: 2,
                        r: ASSIGNMENT_TITLE_INK[0], g: ASSIGNMENT_TITLE_INK[1],
                        b: ASSIGNMENT_TITLE_INK[2] }
    if job
      outputs.labels << { x: x + ASSIGNMENT_W - ASSIGNMENT_PAD, y: top,
                          text: "#{job.fee} Cr", size_enum: 5, alignment_enum: 2,
                          vertical_alignment_enum: 2,
                          r: ASSIGNMENT_FEE_INK[0], g: ASSIGNMENT_FEE_INK[1],
                          b: ASSIGNMENT_FEE_INK[2] }
    end

    line_y = top - ASSIGNMENT_HEAD_H
    assignment_briefing(job).each do |line|
      size = line[:size] || 1
      ink = line[:ink] || ASSIGNMENT_BODY_INK
      outputs.labels << { x: x + ASSIGNMENT_PAD, y: line_y, text: line[:text],
                          size_enum: size, vertical_alignment_enum: 2,
                          r: ink[0], g: ink[1], b: ink[2] }
      line_y -= line[:gap] || ASSIGNMENT_LINE_H
    end

    outputs.labels << { x: x + ASSIGNMENT_W / 2, y: y + ASSIGNMENT_PAD,
                        text: "[ T ] / [ ESC ]  zurück", size_enum: 0,
                        alignment_enum: 1, vertical_alignment_enum: 2,
                        r: 130, g: 154, b: 176 }
  end

  # What the call actually says. A list rather than a paragraph, because the
  # three things you want off it — what, how, and where it stands — are three
  # different questions and get read in different orders.
  def assignment_briefing(job = todays_assignment)
    return [{ text: "Heute liegt nichts an.", size: 2 }] unless job

    lines = [{ text: assignment_text(job), size: 3, ink: ASSIGNMENT_TITLE_INK, gap: 46 }]
    lines << { text: assignment_detail(job), size: 1, gap: 30 }
    lines << { text: "Honorar: #{job.fee} Cr — gezahlt beim Entwickeln am Boot.",
               size: 1, ink: ASSIGNMENT_FEE_INK, gap: 46 }

    state_text, ink = assignment_state_line(job)
    lines << { text: state_text, size: 2, ink: ink, gap: 40 }
    lines << { text: "Unscharfe Bilder zählen nicht. Morgen früh liegt ein neuer Auftrag an.",
               size: 0, ink: [130, 154, 176] }
    lines
  end

  # The part that says how you would go and do it. The sector job needs it most:
  # a number is not a place, so it says which way to steer.
  def assignment_detail(job)
    case job.kind
    when :species
      species = job.species
      "#{species.tease.capitalize}. #{assignment_where(species)}"
    when :flock
      "Alle #{job.count} müssen ganz im Bild sein — ein angeschnittenes Tier zählt nicht mit. " \
        "#{assignment_where(job.species)}"
    when :shore
      "Was oben an Land lebt, nicht im Wasser. Eine Insel ansteuern, an Land gehen, dort suchen."
    when :sector
      "#{assignment_bearing(job.sector)} Die Tiefenanzeige oben rechts nennt den Sektor, in dem du gerade bist."
    else
      ""
    end
  end

  # Where an animal lives, in the words the game already uses for it.
  def assignment_where(species)
    return "Am Meeresboden." if species.habitat == :floor
    return "Oben an Land." if species.habitat == :shore

    band = "#{species.shallowest}–#{species.deepest} m"
    "Zwischen #{band}."
  end

  # Which way to steer, off the boat's own position — the one thing that makes a
  # sector number mean something you can act on.
  def assignment_bearing(sector)
    here = boat_sector
    return "Genau dort, wo das Boot gerade liegt." if sector == here

    steps = (sector - here).abs
    way = sector < here ? "nach Westen" : "nach Osten"
    "Vom Boot aus #{steps} #{steps == 1 ? "Sektor" : "Sektoren"} #{way}."
  end
end

# Who you are and what you're out here for, and the rules of the camera.
#
# The story used to be the card hanging over the boat, read while floating
# alongside — but a card beside a boat is a narrow column of small type, and the
# story got longer as the game got a point. It has its own screen now
# (app/scenes/intro.rb); this file is the words.
#
# The text is meant to be rewritten: the prose is in story_lines, and the name
# comes from whatever the player typed on the way in (see app/scenes/name.rb).
# Nothing wraps — one entry is one line, "" is a paragraph break, and a test
# measures every line against the intro screen's column.
class Game
  DIVER_NAME = "Taucher" # only used if somehow nobody typed a name

  def diver_name
    named? ? state.player_name.strip : DIVER_NAME
  end

  def named?
    !!state.player_name && !state.player_name.strip.empty?
  end

  # One entry per line, "" for a paragraph break.
  def story_lines
    [
      "Freier Wildlife-Fotograf. Spezialisiert auf alles, was unter",
      "Wasser lebt. Festanstellung war noch nie deins.",
      "",
      "Du arbeitest für eine Reihe von Magazinen und Online-Plattformen",
      "sowie einige maritime Forschungsprojekte. Du wirst bezahlt für",
      "Bilder, die sonst keiner hat — Kuriositäten unter Wasser und",
      "neue Arten, die bisher niemand vor die Linse bekommen hat.",
      "",
      "Dafür die Kamera an deinem Gurt: Jede Art einmal scharf im Bild,",
      "und sie steht in deinem Artenbuch. Entwickelt wird an Bord deines",
      "Schiffs, und dort wird auch abgerechnet. Ein entwickeltes Foto",
      "bringt dir Geld. Was du sonst noch vom Grund holst, kannst du",
      "vom Boot aus online verkaufen.",
      "",
      "Achtung: Dein Tauchanzug hält hundert Meter aus, die Luft ein",
      "paar Minuten. Alles andere ist Neugier.",
    ]
  end

  def story_closing
    "Tauch ab, wenn du so weit bist."
  end

  # --- The card that comes up the first time you go under ------------------
  #
  # The boat's card is read at the surface, before any of it is real. The rules
  # of the camera only mean something once there is water over your head, so
  # they are told there, once per round started from the title.

  DIVE_HINT_METRES = 20 # how far down he has to get before the card is in the way
  DIVE_HINT_TICKS = 1800 # backstop for someone who reads it while hovering

  def dive_hint_lines
    [
      "[ F ]  fotografiert, was vor dir ist",
      "Je näher dran, desto schärfer — Sprinten verwackelt",
      "Der Film reicht für #{FILM_MAX} Aufnahmen",
      "Entwickelt wird am Boot. Was du nicht heimbringst, ist weg.",
    ]
  end

  # Brought up by the water closing over him, and retired once he has swum on
  # down. Both are one-way: the card shows once per round and goes once.
  def update_dive_hint
    return raise_dive_hint if state.dive_hint_pending

    dismiss_dive_hint if state.dive_hint_at && done_reading?
  end

  def raise_dive_hint
    return if at_open_surface?

    state.dive_hint_pending = false
    state.dive_hint_at = Kernel.tick_count
    state.dive_hint_depth = current_depth # where he was when he started reading
  end

  # You read it hanging just under the surface; by the time you are properly on
  # your way down it is out of the way. The clock is only a backstop for someone
  # who hovers there and reads it twice.
  #
  # It matters that this *retires* the card rather than being asked every frame.
  # As a live condition on how deep he is now, it came back the moment he rose
  # again — so surfacing for air put the camera's rules back on the screen beside
  # the boat, the one place they mean nothing.
  def done_reading?
    Kernel.tick_count - state.dive_hint_at >= DIVE_HINT_TICKS ||
      current_depth - state.dive_hint_depth >= DIVE_HINT_METRES
  end

  def dive_hint_visible?
    !!state.dive_hint_at
  end

  # Once he has actually taken a picture the card has done its job.
  def dismiss_dive_hint
    state.dive_hint_at = nil
  end

end

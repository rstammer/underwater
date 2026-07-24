# Who you are and what you're out here for. It isn't a screen you click past —
# it's the boat talking, on the card that already hangs over it while you float
# alongside. You read it bobbing at the surface with the sea under you, and it's
# gone for good the moment you first dive.
#
# The text is meant to be rewritten: the prose is in story_lines, and the name
# comes from whatever the player typed on the way in (see app/scenes/name.rb).
# The card doesn't wrap — keep the lines inside STORY_W (tests measure them).
class Game
  DIVER_NAME = "Taucher" # only used if somehow nobody typed a name
  STORY_W = 620

  def diver_name
    named? ? state.player_name.strip : DIVER_NAME
  end

  def named?
    !!state.player_name && !state.player_name.strip.empty?
  end

  # One entry per line, "" for a paragraph break.
  def story_lines
    [
      "Hobby-Meeresbiologe. Und Schatzsucher.",
      "Was davon zuerst da war, weißt du selbst nicht mehr.",
      "",
      "Unter dir liegt ein Meer, von dem du die ersten Meter",
      "kennst. Zwischen Kelp und Riff, in den Höhlen der Inseln",
      "und drunten in den Gräben lebt allerlei, das noch nie",
      "jemand aufgeschrieben hat.",
      "",
      "Dafür die Kamera an deinem Gurt: jede Art einmal scharf",
      "im Bild, und sie steht in deinem Artenbuch. Entwickelt",
      "wird hier an Bord — was du nicht heimbringst, zählt nicht.",
      "",
      "Der Anzug hält hundert Meter aus, die Luft ein paar",
      "Minuten. Alles andere ist Neugier.",
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

  # Triggered by the water closing over him, not by a timer or a key.
  def update_dive_hint
    return unless state.dive_hint_pending
    return if at_open_surface?

    state.dive_hint_pending = false
    state.dive_hint_at = Kernel.tick_count
    state.dive_hint_depth = current_depth # where he was when he started reading
  end

  # It goes when he has swum on down — you read it hanging just under the
  # surface, and by the time you are properly on your way it is out of the way.
  # The clock is only a backstop for someone who hovers there and reads twice.
  def dive_hint_visible?
    return false unless state.dive_hint_at
    return false if Kernel.tick_count - state.dive_hint_at >= DIVE_HINT_TICKS

    current_depth - state.dive_hint_depth < DIVE_HINT_METRES
  end

  # Once he has actually taken a picture the card has done its job.
  def dismiss_dive_hint
    state.dive_hint_at = nil
  end

  # Still to be told? Only until the first time you go under — after that the
  # card goes back to being the boat's list of actions.
  def story_pending?
    !state.story_told
  end

  # Diving is the acknowledgement; there's no key to press. Called from the tick
  # while the world is running, so it can't trigger behind a menu.
  def update_story
    state.story_told = true unless at_open_surface?
  end

  # The story in the shape the boat card draws: the name as its heading, the
  # prose under it, and a quiet closing line.
  def boat_story_lines
    lines = [{ text: diver_name, size: 2, color: [232, 244, 252] }]
    story_lines.each { |line| lines << { text: line, size: 0, color: [186, 214, 236] } }
    lines << { text: "", size: 0, color: [186, 214, 236] }
    lines << { text: story_closing, size: 0, color: [150, 198, 224] }
    lines
  end
end

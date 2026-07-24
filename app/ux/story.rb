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
      "und drunten in den Gräben liegt allerlei herum: Dinge,",
      "die jemand verloren hat — und Dinge, die noch nie",
      "jemand gesehen hat.",
      "",
      "Der Anzug hält hundert Meter aus, die Luft ein paar",
      "Minuten. Alles andere ist Neugier.",
    ]
  end

  def story_closing
    "Tauch ab, wenn du so weit bist."
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

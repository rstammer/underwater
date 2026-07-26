# Getting stung. Reopens Game.
#
# The shark is the sea's only other way of hurting you and it is a *predator*:
# it comes for you, and meeting it is an event. A jellyfish field is the
# opposite kind of danger — it does not come anywhere, it is simply somewhere,
# and swimming through it is a decision you make. That is why the cost is air
# rather than a bite: it does not end the dive, it *shortens* it, and the whole
# question becomes "is the way round worth the detour?"
#
# It costs oxygen and not the suit on purpose. The suit is the depth clock and
# is repaired only at the boat, so a wall of jellyfish between you and home
# would be a death sentence rather than a decision.
class Game
  STING_COST = 4.5      # oxygen per touch — about eight seconds of breathing
  STING_GRACE = 45      # ticks before the same swim can be stung again
  STING_NOTE_TICKS = 130

  STING_NOTES = [
    "Autsch — Nesselzellen.",
    "Es brennt. Luft raus.",
    "Erwischt. Das kostet Atem.",
  ]

  def update_sting
    return if state.jellies.nil? || state.jellies.empty?
    return if stung_recently?

    return unless touching_a_jelly?

    state.oxygen -= STING_COST
    state.oxygen = 0 if state.oxygen < 0
    state.stung_at = Kernel.tick_count
    state.sting_note = STING_NOTES[rand(STING_NOTES.length)]
  end

  # Not every tick in the field: a grace period turns "hold still and lose all
  # your air in two seconds" into "each brush through costs you". Without it the
  # field is not an obstacle, it is a wall of instant death.
  def stung_recently?
    state.stung_at && Kernel.tick_count - state.stung_at < STING_GRACE
  end

  # Bell against body, not sprite against sprite. Most of a jellyfish's frame is
  # trailing thread and empty water, and being stung by water you can see
  # through is the sort of thing that makes a game feel unfair.
  def touching_a_jelly?
    offset = world_index * SCREEN_WIDTH
    body = state.diver.hitbox(state.diver_global_x, state.depth_y)
    state.jellies.any? do |jelly|
      bell = jelly.bell
      body.intersect_rect?({ x: bell[:x] + offset, y: bell[:y],
                             w: bell[:w], h: bell[:h] })
    end
  end

  def sting_note_visible?
    state.stung_at && Kernel.tick_count - state.stung_at < STING_NOTE_TICKS
  end
end

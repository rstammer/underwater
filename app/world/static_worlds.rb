# Registry for hand-authored static worlds that override procedural generation
# at chosen indices — this is the hook the "mix of generated + static" is built
# on. Empty for now; add entries as { index => ->(index) { World.new(...) } }
# (a builder that returns a World) to pin a bespoke world at that segment.
module StaticWorlds
  # The wreck is the first entry, and the reason the hook exists. Everything
  # else in the sea is a function of where you are, which is what makes it
  # endless and also what stops any of it from being a landmark; this one
  # segment is *placed*, and a ship on the bottom at a hundred and fifty metres
  # is somewhere rather than somewhere deep.
  REGISTRY = {
    WreckWorld::SECTOR => ->(index) { WreckWorld.build(index) },
  }

  # Returns a hand-built World for the index, or nil to fall back to generation.
  def self.for(index)
    builder = REGISTRY[index]
    builder && builder.call(index)
  end
end

# Registry for hand-authored static worlds that override procedural generation
# at chosen indices — this is the hook the "mix of generated + static" is built
# on. Empty for now; add entries as { index => ->(index) { World.new(...) } }
# (a builder that returns a World) to pin a bespoke world at that segment.
module StaticWorlds
  REGISTRY = {}

  # Returns a hand-built World for the index, or nil to fall back to generation.
  def self.for(index)
    builder = REGISTRY[index]
    builder && builder.call(index)
  end
end

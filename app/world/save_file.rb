# What survives closing the game: the Artenbuch, what you have laid eyes on, and
# the name you dive under. Deliberately *not* the round — a dive is a dive, and
# losing an undeveloped film is the whole reason developing it means anything.
#
# A line-based format rather than anything clever, because it has to survive the
# roster changing under it. A species that no longer exists is skipped on the way
# in; one that has been added since is simply absent, which is the same as never
# having seen it. Nothing here can make the game refuse to start.
#
#   name Kins Klausky
#   album burgunder perfekt
#   sighted laternentraeger
#   stash bottle 3
#
# Pure: encoding and decoding never touch the filesystem, so they are testable
# without writing over anybody's real book (Game#save_book does the I/O).
class SaveFile
  PATH = "artenbuch.txt"
  # Where it goes when the suite is running. Running the tests must never cost
  # the person running them the book they collected — and it did exactly that
  # once: a sighting inside a test wrote straight over the real file, because
  # saving happens the moment a species is first seen. tmp/ is gitignored.
  TEST_PATH = "tmp/artenbuch_under_test.txt"
  QUALITIES = { "unscharf" => :unscharf, "gut" => :gut, "perfekt" => :perfekt }

  # Counters that are simply written as "key n" and read back the same way, all
  # of them optional. Listed once so adding another is a word in a list rather
  # than three edits that have to agree.
  # Kit is career, so it travels with the book. Levels rather than values: a
  # ladder that grows a rung later still reads an old save correctly, and a
  # level nobody has bought is simply absent (COUNTERS only writes what is > 0).
  COUNTERS = ["credits", "dives", "best", "sold", "earned", "day", "energy",
              "day_earned", "day_species", "day_deepest", "day_sold",
              "gear_film", "gear_air", "gear_suit", "shop_met"]

  def self.encode(name:, album:, sighted:, seed: nil, stash: [], **counters)
    lines = []
    lines << "name #{name.strip}" if name && !name.strip.empty?
    lines << "seed #{seed}" if seed
    COUNTERS.each do |key|
      value = counters[key.to_sym]
      lines << "#{key} #{value}" if value && value > 0
    end
    # The boat's hold, as one line per kind. Written as counts rather than one
    # line per tin can, because a hold can hold rather a lot of tin cans.
    (stash || []).uniq.each do |kind|
      lines << "stash #{kind} #{stash.count { |stored| stored == kind }}"
    end
    (album || {}).each { |key, quality| lines << "album #{key} #{quality}" }
    # Documented implies seen, so those keys don't need saying twice.
    (sighted || {}).each_key do |key|
      lines << "sighted #{key}" unless album && album.key?(key)
    end
    lines.join("\n")
  end

  def self.decode(text)
    book = blank
    return book if text.nil?

    text.split("\n").each { |line| read_line(book, line.strip.split(" ")) }
    book
  end

  def self.read_line(book, parts)
    case parts[0]
    when "name"
      book[:name] = parts[1..-1].join(" ")
    when *COUNTERS
      book[parts[0].to_sym] = parts[1].to_i if parts[1].to_i > 0
    when "stash"
      # A kind that no longer exists is dropped, the same as a retired species.
      book[:stash].concat([parts[1]] * parts[2].to_i) if Game::ITEM_KINDS.include?(parts[1])
    when "seed"
      # A book written before seas had seeds simply hasn't got this line, and
      # that is not an error — it gets a fresh sea.
      book[:seed] = parts[1].to_i if parts[1].to_i > 0
    when "album"
      return unless known?(parts[1]) && QUALITIES.key?(parts[2])

      book[:album][parts[1]] = QUALITIES[parts[2]]
      book[:sighted][parts[1]] = true
    when "sighted"
      book[:sighted][parts[1]] = true if known?(parts[1])
    end
  end

  def self.known?(key)
    !key.nil? && !Species[key].nil?
  end

  # Nothing worth carrying over — so the title has nothing to offer to continue.
  def self.empty?(book)
    book.nil? || (book[:album].empty? && book[:sighted].empty?)
  end

  def self.blank
    book = { name: "", album: {}, sighted: {}, seed: nil, stash: [] }
    COUNTERS.each { |key| book[key.to_sym] = 0 }
    # A day starts at one, and "no energy written" has to stay tellable from
    # "worn out": nil means a fresh morning, 0 means he has nothing left.
    book[:day] = 1
    book[:energy] = nil
    book
  end
end

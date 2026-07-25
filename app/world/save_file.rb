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

  def self.encode(name:, album:, sighted:)
    lines = []
    lines << "name #{name.strip}" if name && !name.strip.empty?
    (album || {}).each { |key, quality| lines << "album #{key} #{quality}" }
    # Documented implies seen, so those keys don't need saying twice.
    (sighted || {}).each_key do |key|
      lines << "sighted #{key}" unless album && album.key?(key)
    end
    lines.join("\n")
  end

  def self.decode(text)
    book = { name: "", album: {}, sighted: {} }
    return book if text.nil?

    text.split("\n").each { |line| read_line(book, line.strip.split(" ")) }
    book
  end

  def self.read_line(book, parts)
    case parts[0]
    when "name"
      book[:name] = parts[1..-1].join(" ")
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
    { name: "", album: {}, sighted: {} }
  end
end

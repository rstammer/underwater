# The people on the beach island, as a roster — the same idea as Species: a
# description that never moves, which the world then places somewhere.
#
# They exist because the game had exactly one voice telling you about water you
# had not found yet (Andi, in the Späti), and one shopkeeper cannot carry the
# whole of the unknown. These seven carry the other half: the rumour that there
# is something down there at all.
#
# The important thing about them is that they are *wrong*. They stand in the sun
# on the surface talking about a place none of them has ever been — so the boy
# exaggerates, his friend contradicts him to look unbothered, the bather has it
# third-hand, and the musicians disagree about whether they are hearing anything
# at all. A rumour that turns out to be half-false is remembered; a correct tip
# is used once and forgotten. That is also the honest way to say little.
#
# Mike is the single exception, and running the place is his reason for being
# it: the campers are here for a fortnight, he has watched this water for years
# and watched everybody who ever went out from here. So his is the line you can
# act on — the kraken's escape rule, up and never after it, which is the one
# thing about the deep worth being told rather than found out.
#
# What each of them says follows how far along you are (Game#islander_line):
# hearsay while you have never been down, warier once you have, and something
# shared once you have met the thing yourself. The staged lines are why they
# read as people rather than signposts — the beach notices what you have done.
class Islander
  # Where on the island each one is, as a fraction of the part of it that is out
  # of the water (Game#islander_x) — not of its span, which runs out under the
  # sea at both ends. The order is the order you walk the campsite: the children
  # play at the water's edge, the bathers stand just past them, Mike is at
  # reception by the gate, and the two musicians are at the far end by the fire.
  # The camp's own buildings are spaced into the same run (app/world/camp.rb),
  # so the two lists have to be read together — a tent must not land on Tall Pete.
  attr_reader :key, :name, :kind, :spot, :lines, :deeper, :met, :useful

  # kind picks the sprite and how it is drawn — :boy and :bather stand about at
  # the water, :musician sits at the fire, :warden stands at reception.
  #
  # useful marks the one whose line is worth acting on, so a test can hold the
  # rest to being rumour and this one to being real.
  # The two halves of asking somebody a question, both keyed on a species being
  # in the Artenbuch: `asks` is said *until* it is there, `documented` from then
  # on. Everything else about these people accumulates — what they said when you
  # were new they still say later (Game#islander_pool) — but a question has to
  # stop once it has been answered, or the person asking it is furniture.
  attr_reader :asks, :documented

  def initialize(key:, name:, kind:, spot:, lines:, deeper: [], met: [],
                 asks: {}, documented: {}, useful: false)
    @key = key
    @name = name
    @kind = kind
    @spot = spot
    @lines = lines
    @deeper = deeper
    @met = met
    @asks = asks
    @documented = documented
    @useful = useful
  end

  # Everything this person can ever say, at any stage — what a test checks when
  # it wants to hold the whole cast to a rule.
  def all_lines
    @lines + @deeper + @met + @asks.values + @documented.values.flatten
  end

  ALL = [
    # The two boys, at the water's edge, where the water is knee-deep and safe.
    # Flori believes every word of it and Falko cannot afford to.
    new(key: "flori", name: "Flori", kind: :boy, spot: 0.04,
        lines: ["Mein Bruder sagt, da unten wohnt was. Was ganz Grosses.",
                "Ich geh da nie rein. Nur bis zu den Knien, und keinen Schritt weiter.",
                "Es hat Arme. So lange Arme. Hat mein Bruder gesagt."],
        deeper: ["Du warst da unten? Richtig unten? Und du lebst noch?"],
        met: ["Du hast's gesehen. Ich WUSSTE es. Keiner glaubt mir, nie."]),
    new(key: "falko", name: "Falko", kind: :boy, spot: 0.11,
        lines: ["Flori spinnt. Da ist nichts. Mein Papa fährt da dauernd raus.",
                "Also. Vielleicht ist da was. Aber bestimmt nichts Grosses."],
        deeper: ["Wie weit runter? Nee. Nee, so weit geht keiner."],
        met: ["Sag Flori nichts davon. Der lässt mich sonst nie wieder in Ruhe."],
        # He asks about the shark until you have actually got one, and then he
        # has to deal with the answer being yes.
        asks: { "schattenhai" => "Sag mal, hast du schon mal einen echten Schattenhai fotografiert?" },
        documented: { "schattenhai" => [
          "Du hast einen Schattenhai auf Film. Einen echten. Ich sag's keinem.",
          "Wie nah warst du dran? Nein. Sag's nicht. Ich will's nicht wissen.",
        ] }),

    # The bathers, standing in the shallows. Hendrik cannot stop talking and has
    # all of it from somebody else; Tall Pete would rather be left alone and is the
    # one who points you at Mike.
    new(key: "hendrik", name: "Hendrik", kind: :bather, spot: 0.20,
        lines: ["Letztes Jahr war hier ein Taucher. Der ist runter und nicht wiedergekommen.",
                "Gefunden haben sie nur sein Boot. Angeblich. Sagt man.",
                "Ich geh nicht tiefer als bis zum Bauch. Aus Prinzip."],
        deeper: ["So weit runter? Mir wird schon anders, wenn ich den Grund nicht mehr sehe.",
                 "Sagen Sie mal — Ihre Bilder waren doch neulich in der GEO?",
                 "Doch, ganz sicher. Die mit dem Licht von oben. Grossartig war das."],
        met: ["Ihr Gesicht. Sie müssen mir gar nichts erzählen, ich seh's ja."]),
    new(key: "tall_pete", name: "Tall Pete", kind: :bather, spot: 0.28,
        lines: ["Schönes Wasser heute. Warm. Ich bleib hier oben, danke.",
                "Fragen Sie nicht mich. Fragen Sie Mike vorn an der Rezeption, dem gehört der Platz.",
                "Haben Sie die beiden da hinten schon gehört? Macblinded. Die haben's voll drauf.",
                "Die werden mal gross, sag ich Ihnen. Ganz gross."],
        deeper: ["Sie sehen aus, als hätten Sie was gesehen. Setzen Sie sich erst mal."],
        met: ["Das ist es also. Na dann. Ich bleib erst recht hier oben."]),

    # The two musicians, sitting further up with their backs to the water. They
    # are arguing about whether the sea makes a sound, which is the rumour
    # arriving in a form nobody can check.
    #
    # They are also the one thread tying the two islands together: Andi, who is
    # minding the Späti over on the other one, is their drummer — on holiday,
    # covering a counter, and not at a rehearsal. Sebastián thinks he is coming
    # back, George has stopped thinking so, and neither of them is sure. It
    # is also the only line in the game that points at the *shop*, for anybody
    # who found the beach first.
    new(key: "sebastian", name: "Sebastián", kind: :musician, spot: 0.38,
        lines: ["Hörst du das? Wenn's ganz still ist, brummt das Wasser. Ganz tief.",
                "George sagt, das sind die Wellen. Wellen brummen aber nicht in G.",
                "Zu zweit klingt's dünn. Unser Trommler hat Urlaub, drüben im Späti."],
        deeper: ["Du warst unten. Sag mal — hat's da auch gebrummt?"],
        met: ["Dann war's kein Wellending. Wusst ich's doch."]),
    new(key: "george", name: "George", kind: :musician, spot: 0.50,
        lines: ["Sebastián hört Gespenster. Das ist die Strömung an den Felsen, sonst nichts.",
                "Andi steht drüben hinterm Tresen. Zwei Wochen, hat er gesagt.",
                "Der mischt uns sonst ab. Ohne ihn klingen wir wie ein Eimer."],
        deeper: ["... obwohl. Neulich nachts war das Brummen lauter. Sag ihm das nicht."],
        met: ["Ich nehme alles zurück. Alles."]),

    # Mike, the warden, at reception by the gate — the only one who has watched
    # this water for years rather than for a fortnight, which is why his is the
    # line you can act on. It is the kraken's one rule: it pulls downward, and
    # the way out is the way you least want to go.
    #
    # He used to sit on the island's high point and the useful line was framed
    # as a view ("von hier oben"). Running the place is the better reason to
    # know: a warden has watched everybody who ever went out from here, and some
    # of them came back and some did not.
    new(key: "mike", name: "Mike", kind: :warden, spot: 0.88, useful: true,
        lines: ["Mike. Campamento del Kraken Profundo. Stell dein Zeug hin, wo Platz ist.",
                "Den Namen hat mein Vater ausgesucht. Gesehen hat es hier nie einer.",
                "Wenn du da unten was siehst, das nicht aufs Bild will — schwimm ihm nicht nach.",
                "Genau das will es nämlich. Es geht immer ein Stück tiefer als du."],
        deeper: ["Der Weg raus ist nach oben. Immer nach oben. Runter zieht's dich von allein.",
                 "Ich seh sie jedes Jahr rausfahren. Die meisten kommen wieder."],
        met: ["Du hast's gesehen. Und du bist hochgekommen. Nicht alle kommen hoch."]),
  ]

  # Andi, over on the *other* island, behind the counter of the Insel-Späti. He
  # is in this roster rather than in a mechanism of his own because being able
  # to say hello to somebody is not a different feature depending on which
  # island they are standing on — L still opens his shelf, E now gets a word out
  # of him, and the shop screen is for shopping.
  #
  # He has no sprite here (Game::ISLANDER_SPRITES has no entry): the stall's own
  # picture already has him drawn into it, behind the counter where he belongs.
  KEEPER = new(key: "andi", name: "Andi", kind: :keeper, spot: 0,
               lines: ["Alles klar? Kannst dich umsehen. L, wenn du was brauchst.",
                       "Zwei Wochen Urlaub, hab ich gesagt. Ist jetzt die dritte.",
                       "Drüben proben sie ohne mich weiter. Hör ich bis hier rüber.",
                       "Ein Schlagzeug kriegst du nicht mit aufs Boot. Hab's versucht."],
               deeper: ["So tief? Ich geh nicht mal bis zur Boje, ehrlich."],
               met: ["Du hast da unten was gesehen. Steht dir ins Gesicht geschrieben."])

  ALL << KEEPER

  def self.[](key)
    ALL.find { |person| person.key == key }
  end
end

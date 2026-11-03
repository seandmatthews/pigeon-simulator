class_name CitizenClass
## The citizen classes (T-113). Append-only: T-114 hangs scoring deltas off Kind,
## T-115 hangs the victory ending off the favor total — neither reorders these.
enum Kind { CIVILIAN, VISITOR, SUPERFAN }

const TEAM_GOLD := Color(1.0, 0.80, 0.0)          ## The invader's gold (research readability table).
const VISITOR_BLACK := Color(0.08, 0.08, 0.08)    ## The invader's near-black garment tone.
const SUPERFAN_CARDINAL := Color(0.78, 0.06, 0.18) ## The hometown loyalist's cardinal.


## (T-151) The class word the hit feedback chain names — the WORD ONLY, no
## claim about which class paid what. Static so the world popup, the HUD combo
## strip and the game-over split all spell the class the same way without
## instancing anything.
static func label(kind: Kind) -> String:
	match kind:
		Kind.VISITOR:
			return "Visitor"
		Kind.SUPERFAN:
			return "Superfan"
		_:
			return "Civilian"

class_name CitizenClass
## The citizen classes (T-113). Append-only: T-114 hangs scoring deltas off Kind,
## T-115 hangs the victory ending off the favor total — neither reorders these.
enum Kind { CIVILIAN, VISITOR, SUPERFAN }

const TEAM_GOLD := Color(1.0, 0.80, 0.0)          ## The invader's gold (research readability table).
const VISITOR_BLACK := Color(0.08, 0.08, 0.08)    ## The invader's near-black garment tone.
const SUPERFAN_CARDINAL := Color(0.78, 0.06, 0.18) ## The hometown loyalist's cardinal.

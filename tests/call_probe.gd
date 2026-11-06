extends Node
## (T-169) The call verb's typed-method probe — a test-only node whose
## methods pin the coercion surface the dev `call` verb applies, so the
## sim scenario can machine-check what the verb PUTS IN the parameters (and
## what it leaves alone) without staging a gameplay node for it. Instantiated
## by `sim_test.gd`'s `dev_call_verb` scenario and resolved through the
## verb's /root path arm. Every method returns a tell-string or a value that
## names what it received:
##
## - `probe_vec3` demands a Vector3: it only runs if the verb coerced the
##   JSON array into a Vector3 (a raw array would type-refuse pre-call).
## - `probe_array` / `probe_untyped` demand an Array / nothing: the verb
##   must hand the JSON array through UNCHANGED — the array-stays-an-array
##   law the ticket pins (a would-be coercing verb fails the type refusal
##   or, worse, lands a vector; either way the tell reads wrong).
## - `probe_defaulted` carries a defaulted second parameter: the undershoot
##   contract (the engine fills what the method list cannot see).
## - `probe_add` returns a float: the numeric half of the result serializer.

func probe_vec3(p: Vector3) -> String:
	return "Vector3:%s" % p


func probe_array(a: Array) -> String:
	return "Array:%d:%s" % [a.size(), type_string(typeof(a[0]))]


func probe_untyped(a) -> String:
	return "%s:%d" % [type_string(typeof(a)), a.size()]


func probe_defaulted(a: float, b: float = 2.5) -> Array:
	return [a, b]


func probe_add(a: float, b: float) -> float:
	return a + b

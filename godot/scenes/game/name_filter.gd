class_name NameFilter
extends RefCounted

## Blocks offensive player names and public map names. The server runs the same
## check (server/community.sql) so it can't be skipped; this copy just gives
## instant feedback in the game.

## Blocked anywhere inside a name, after lowercasing, undoing leetspeak and
## dropping everything that isn't a letter (so "f_u_c_k" and "5h1t" match).
const ANYWHERE := [
	"fuck", "shit", "bitch", "cunt", "nigger", "nigga", "faggot", "retard",
	"whore", "slut", "pussy", "penis", "vagina", "nazi", "hitler", "porn",
	"kike", "wank", "twat", "dildo", "jizz", "molest", "pedophil", "asshole",
	"dickhead", "bastard", "chink", "tranny", "kkk", "rapist",
]
## Short words that are only blocked as a whole word (split on spaces, _ and
## digits), so ordinary names like "Classic", "Grass" or "Speedo" stay allowed.
const WHOLE_WORD := ["ass", "dick", "cock", "rape", "sex", "cum", "tits", "spic", "fag", "pedo", "anal", "coon", "hoe"]
const LEET := {"0": "o", "1": "i", "!": "i", "3": "e", "4": "a", "@": "a", "5": "s", "$": "s", "7": "t", "8": "b", "9": "g"}

static func is_clean(text: String) -> bool:
	var lower := text.to_lower()
	var letters := ""
	for ch in lower:
		var c: String = LEET.get(ch, ch)
		if c >= "a" and c <= "z":
			letters += c
	var squashed := _squash(letters)
	for word: String in ANYWHERE:
		if letters.contains(word):
			return false
		# Stretched spellings ("fuuuck"): only for words with no doubled letters,
		# otherwise "kkk" would squash to "k" and block everything.
		if _squash(word) == word and squashed.contains(word):
			return false
	var words := PackedStringArray()
	var current := ""
	for ch in lower:
		if ch >= "a" and ch <= "z":
			current += ch
		else:
			if not current.is_empty():
				words.append(current)
			current = ""
	if not current.is_empty():
		words.append(current)
	for w in words:
		if WHOLE_WORD.has(w) or WHOLE_WORD.has(_squash(w)):
			return false
	return true

## Collapses repeated letters ("fuuuck" -> "fuck").
static func _squash(s: String) -> String:
	var out := ""
	for ch in s:
		if out.is_empty() or out[out.length() - 1] != ch:
			out += ch
	return out

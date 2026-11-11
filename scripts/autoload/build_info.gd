## What build this is, for the lobby's version label. Not an autoload: static helpers.
## CI (`.github/workflows/release.yml`, step "Stamp the version") writes res://data/build.json
## with the release tag before exporting, so the label always matches the tag the launcher shows:
##   {"version": "v0.0.2-dev.3"}
## No file (the editor, a local run or a local export): "dev". build.json is git-ignored.
class_name BuildInfo
extends RefCounted

const FILE := "res://data/build.json"


## The release tag this build was made from, or "dev".
static func version(path := FILE) -> String:
	if not FileAccess.file_exists(path):
		return "dev"
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string(path)) != OK or not j.data is Dictionary:
		return "dev"
	var v := str(j.data.get("version", "")).strip_edges()
	return v if v != "" else "dev"


## The footer text: the tag as-is ("v0.0.2-dev.3"), or "dev".
static func label(path := FILE) -> String:
	var v := version(path)
	return v if v == "dev" or v.begins_with("v") else "v" + v

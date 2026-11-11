## A-15 / P-06 (barks-lambda-fix-1): a bark bubble that has been freed (its speaker left, the
## scene changed) drops out of HillBarks.bubbles() without the filter lambda logging an engine
## error. gdUnit ignores engine ERRORs, so a Logger counts them for the assertion.
class_name TestHillBarksFreed
extends GdUnitTestSuite


class ErrorCounter extends Logger:
	var errors: Array[String] = []
	var _lock := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, _error_type: int, _script_backtrace: Array[ScriptBacktrace]) -> void:
		_lock.lock()
		errors.append("%s:%d %s %s %s" % [file, line, function, code, rationale])
		_lock.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass


var _barks: HillBarks
var _log: ErrorCounter


func before_test() -> void:
	_barks = HillBarks.new()      # not in the tree: bubbles() only reads its own list
	_log = ErrorCounter.new()
	OS.add_logger(_log)


func after_test() -> void:
	OS.remove_logger(_log)
	for b in _barks._bubbles:
		if is_instance_valid(b):
			b.free()
	_barks.free()


func _bubble() -> PictoBubbleNode:
	var b := PictoBubbleNode.new()
	_barks._bubbles.append(b)
	return b


func test_a_freed_bubble_drops_out_of_bubbles_without_an_error() -> void:
	var keep := _bubble()
	var gone := _bubble()
	var also := _bubble()
	assert_int(_barks.bubbles().size()).is_equal(3)
	gone.free()
	var live := _barks.bubbles()
	assert_int(live.size()).is_equal(2)
	assert_bool(live.has(keep) and live.has(also)).is_true()
	assert_array(_log.errors).is_empty()


func test_step_prunes_freed_bubbles_and_keeps_live_ones() -> void:
	var keep := _bubble()
	_bubble().free()
	_bubble().free()
	_barks.step(0.1)      # no game: no players, so step() only prunes its bubble list
	assert_int(_barks._bubbles.size()).is_equal(1)
	assert_object(_barks._bubbles[0]).is_same(keep)
	assert_int(_barks.bubbles().size()).is_equal(1)
	assert_array(_log.errors).is_empty()


func test_a_typed_lambda_would_have_logged_the_error() -> void:
	# The counter really sees the old bug (func(b: PictoBubbleNode) on a freed bubble), so the empty
	# error lists above mean something.
	_bubble().free()
	_barks._bubbles.filter(func(b: PictoBubbleNode) -> bool: return is_instance_valid(b))
	assert_bool(_log.errors.is_empty()).is_false()

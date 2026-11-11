## gdUnit4: the shared block pile.
class_name TestInventory
extends GdUnitTestSuite

var _log: Array = []


func before_test() -> void:
	Inventory.clear()
	_log = []


func after_test() -> void:
	Inventory.clear()


func _on_changed(block: StringName, n: int) -> void:
	_log.append([block, n])


func test_add_and_count() -> void:
	assert_int(Inventory.count(&"dirt")).is_equal(0)
	Inventory.add(&"dirt")
	Inventory.add(&"dirt", 4)
	assert_int(Inventory.count(&"dirt")).is_equal(5)
	Inventory.add(&"dirt", 0)
	Inventory.add(&"dirt", -3)
	assert_int(Inventory.count(&"dirt")).is_equal(5)


func test_can_afford() -> void:
	Inventory.add(&"dirt", 10)
	assert_bool(Inventory.can_afford({})).is_true()
	assert_bool(Inventory.can_afford({&"dirt": 10})).is_true()
	assert_bool(Inventory.can_afford({&"dirt": 11})).is_false()
	assert_bool(Inventory.can_afford({"dirt": 10})).is_true()
	assert_bool(Inventory.can_afford({&"dirt": 5, &"clay": 1})).is_false()


func test_spend_is_all_or_nothing() -> void:
	Inventory.add(&"dirt", 10)
	Inventory.add(&"clay", 2)
	assert_bool(Inventory.spend({&"dirt": 5, &"clay": 3})).is_false()
	assert_int(Inventory.count(&"dirt")).is_equal(10)
	assert_int(Inventory.count(&"clay")).is_equal(2)
	assert_bool(Inventory.spend({&"dirt": 5, "clay": 2})).is_true()
	assert_int(Inventory.count(&"dirt")).is_equal(5)
	assert_int(Inventory.count(&"clay")).is_equal(0)
	assert_bool(Inventory.spend({})).is_true()


func test_signal_emitted_per_change() -> void:
	Events.inventory_changed.connect(_on_changed)
	Inventory.add(&"dirt", 3)
	Inventory.add(&"clay", 1)
	Inventory.spend({&"dirt": 2, &"clay": 1})
	Inventory.spend({&"dirt": 99})
	Events.inventory_changed.disconnect(_on_changed)
	assert_int(_log.size()).is_equal(4)
	assert_array(_log[0]).is_equal([&"dirt", 3])
	assert_array(_log[1]).is_equal([&"clay", 1])
	assert_array(_log[2]).is_equal([&"dirt", 1])
	assert_array(_log[3]).is_equal([&"clay", 0])


func test_save_round_trip_through_json() -> void:
	Inventory.add(&"dirt", 12)
	Inventory.add(&"stone", 3)
	var back = JSON.parse_string(JSON.stringify(Inventory.to_save()))
	Inventory.clear()
	Inventory.load_save(back)
	assert_int(Inventory.count(&"dirt")).is_equal(12)
	assert_int(Inventory.count(&"stone")).is_equal(3)
	assert_bool(Inventory.to_save().has("dirt")).is_true()


func test_clear() -> void:
	Inventory.add(&"dirt", 12)
	Inventory.clear()
	assert_int(Inventory.count(&"dirt")).is_equal(0)
	assert_dict(Inventory.to_save()).is_empty()


func before() -> void:
	SuiteSandbox.enter("inventory")   # never the real profile, settings or picks file


func after() -> void:
	SuiteSandbox.leave()

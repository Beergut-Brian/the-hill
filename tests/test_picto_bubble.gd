## S-15: the PictoBubble scene (arcs, barks, prompts) and PictoBubble costs (the build book).
extends GdUnitTestSuite


func test_cost_columns_stack_five_high_in_block_order() -> void:
	var cols := PictoBubble.cost_columns({&"stone": 3, &"dirt": 7}, [&"dirt", &"clay", &"stone"])
	assert_array(cols).is_equal([[&"dirt", 5], [&"dirt", 2], [&"stone", 3]])
	# String keys (from .tres / json) count the same.
	assert_array(PictoBubble.cost_columns({"clay": 5}, [&"clay"])).is_equal([[&"clay", 5]])
	assert_array(PictoBubble.cost_columns({})).is_empty()


func test_the_scene_follows_its_speaker_pops_in_and_frees_itself() -> void:
	var host := Node2D.new()
	add_child(host)
	var who := Node2D.new()
	host.add_child(who)
	who.position = Vector2(100, 200)
	var b := PictoBubbleNode.pop(host, who, [&"rock", &"face_happy"], 0.5)
	assert_str(b.scene_file_path).is_equal(PictoBubbleNode.SCENE)
	assert_vector(b.global_position).is_equal(Vector2(100, 200) + b.head)
	who.position = Vector2(140, 200)
	await get_tree().process_frame
	assert_vector(b.global_position).is_equal(Vector2(140, 200) + b.head)
	assert_float(b.alpha()).is_greater(0.5)
	await get_tree().create_timer(0.7).timeout
	assert_bool(is_instance_valid(b)).is_false()
	host.queue_free()


func test_a_held_prompt_stays_until_hidden_and_goes_with_its_speaker() -> void:
	var host := Node2D.new()
	add_child(host)
	var who := Node2D.new()
	host.add_child(who)
	var b := PictoBubbleNode.pop(host, who, [&"question"], 0.0)
	await get_tree().create_timer(0.4).timeout
	assert_bool(is_instance_valid(b)).is_true()
	b.hide_bubble()
	await get_tree().create_timer(0.4).timeout
	assert_bool(is_instance_valid(b)).is_false()
	var c := PictoBubbleNode.pop(host, who, [&"question"], 0.0)
	who.free()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_bool(is_instance_valid(c)).is_false()
	host.queue_free()


func test_the_build_book_draws_its_costs_and_bubbles_through_picto_bubble() -> void:
	var src := (load("res://scenes/ui/build_book.gd") as GDScript).source_code
	assert_str(src).contains("PictoBubble.draw_cost(")
	assert_str(src).contains("PictoBubble.draw_round(")

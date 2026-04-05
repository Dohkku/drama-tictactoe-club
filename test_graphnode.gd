extends SceneTree

func _init():
	var gn = GraphNode.new()
	print("GraphNode properties:")
	print("  has resizable: ", "resizable" in gn)
	print("  has reset_size: ", gn.has_method("reset_size"))
	print("  size: ", gn.size)
	gn.size = Vector2(400, 800)
	print("  size after set: ", gn.size)
	gn.size = Vector2.ZERO
	print("  size after zero: ", gn.size)
	if gn.has_method("reset_size"):
		gn.reset_size()
		print("  size after reset_size: ", gn.size)

	# Check GraphElement (parent class)
	print("  class: ", gn.get_class())
	print("  is GraphElement: ", gn is GraphElement)

	# Check if resizable is a property
	for p in gn.get_property_list():
		if "resiz" in p.name.to_lower():
			print("  found property: ", p.name)

	gn.free()
	quit()

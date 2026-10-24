extends SceneTree

func _init() -> void:
	print("Testing parcel boundary geometry...")
	var homestead_rect := Rect2i(0, 0, 12, 12)
	var east_rect := Rect2i(12, 0, 12, 12)
	var south_rect := Rect2i(0, 12, 12, 12)
	var plateau_rect := Rect2i(12, 12, 12, 12)

	# Footprint poly for 12x12
	var hs_poly = FarmerMovement.get_footprint_polygon_local(homestead_rect.position, homestead_rect.size)
	print("Homestead poly:", hs_poly)
	assert(hs_poly.size() == 4)
	print("Top:", hs_poly[0], " Right:", hs_poly[1], " Bottom:", hs_poly[2], " Left:", hs_poly[3])

	# The shared edge between homestead and east_meadows is:
	# homestead top_v to right_v? Or right_v to bottom_v?
	# In homestead:
	# right_v is (12, 0). bottom_v is (12, 12).
	# In east_meadows (start 12, 0):
	# top_v is (12, 0). left_v is (12, 12).
	# So hs right_v == east top_v, and hs bottom_v == east left_v!
	# That means the segment between (12, 0) and (12, 12) is EXACTLY the dividing line between homestead and east_meadows!
	var east_poly = FarmerMovement.get_footprint_polygon_local(east_rect.position, east_rect.size)
	print("East poly top:", east_poly[0], " left:", east_poly[3])
	assert(hs_poly[1].is_equal_approx(east_poly[0]))
	assert(hs_poly[2].is_equal_approx(east_poly[3]))

	# In south_plains (start 0, 12):
	# top_v is (0, 12). right_v is (12, 12).
	# In homestead: left_v is (0, 12), bottom_v is (12, 12).
	var south_poly = FarmerMovement.get_footprint_polygon_local(south_rect.position, south_rect.size)
	print("South poly top:", south_poly[0], " right:", south_poly[1])
	assert(hs_poly[3].is_equal_approx(south_poly[0]))
	assert(hs_poly[2].is_equal_approx(south_poly[1]))

	print("ALL PARCEL GEOMETRY ASSERTIONS PASSED 100%!")
	quit(0)

extends GutTest

func test_expansion_catalog_is_registered() -> void:
	assert_eq(FarmExpansionData.find_all().size(), 4)
	assert_not_null(FarmExpansionData.find(&"big_coop"))
	assert_not_null(FarmExpansionData.find(&"deluxe_barn"))

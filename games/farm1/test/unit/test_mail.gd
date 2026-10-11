extends GutTest

## Farm1's letters. How mail is delivered and claimed is tested with the
## progression module.

func test_content_contains_progression_mail_entries() -> void:
	var ids: Array[String] = []
	for mail: MailData in MailData.find_all():
		ids.append(String(mail.id))
	ids.sort()
	assert_eq(ids, [
		"mira_garden_restored",
		"mira_welcome",
		"neri_first_catch",
		"neri_harbor_restocked",
		"rowan_after_slime",
		"rowan_mine_bottom",
		"rowan_workshop_expanded",
	])

class_name GameCropCatalog
extends Node

func get_crop(crop_id: StringName) -> CropData:
	return ContentDB.get_crop(crop_id)

class_name GameSetup
extends GameModule

## MFarm's own module: a small farm, a seaside town and their seasons, revived
## from the Unity MFarm demo. The game uses no gameplay module of Tiamat: its
## bags (`Bags`) and land (`Farmland`) are its own and keep their state in
## `WorldState`. This registers its kinds of content.

func install() -> void:
	ContentDB.register_kind(MFarmItemData.KIND, MFarmItemData)
	ContentDB.register_kind(MFarmBagData.KIND, MFarmBagData)
	ContentDB.register_kind(MFarmBlueprintData.KIND, MFarmBlueprintData)
	ContentDB.register_kind(MFarmCropData.KIND, MFarmCropData)
	ContentDB.register_kind(MFarmMapData.KIND, MFarmMapData)
	ContentDB.register_kind(MFarmNpcData.KIND, MFarmNpcData)

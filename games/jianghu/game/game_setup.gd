class_name GameSetup
extends GameModule

## Pocket Jianghu's own module: a small wuxia hero who cultivates and roams
## while the player works. The game uses no gameplay module of Tiamat; its
## state lives in `Cultivation`, which keeps it in `WorldState`. This registers
## its kinds of content.

func install() -> void:
	ContentDB.register_kind(JianghuArtData.KIND, JianghuArtData)
	ContentDB.register_kind(JianghuRealmData.KIND, JianghuRealmData)
	ContentDB.register_kind(JianghuRegionData.KIND, JianghuRegionData)
	ContentDB.register_kind(JianghuFoeData.KIND, JianghuFoeData)

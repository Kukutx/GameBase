class_name ContentPack
extends Resource

## A list of content entries of any kinds. A game lists its packs in
## `GameDefinition.content`; `ContentDB` indexes every entry of every pack by
## the kind its class is registered as.

@export var entries: Array[ContentEntry] = []

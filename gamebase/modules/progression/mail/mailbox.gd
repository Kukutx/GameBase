class_name GameMailbox
extends Node2D

@onready var interactable: Interactable = $Interactable
@onready var label: Label = $Label

func _ready() -> void:
	interactable.interacted.connect(_on_interacted)
	MailState.mail_received.connect(_on_mail_changed)
	MailState.mail_read.connect(_on_mail_changed)
	_refresh()

func _on_interacted(_actor: Node) -> void:
	MailState.refresh_deliveries()
	var menu := get_tree().get_first_node_in_group("mailbox_menu") as MailboxMenu
	if menu == null:
		GameEvents.toast("Mailbox UI is unavailable")
		return
	menu.open()
	_refresh()

func _on_mail_changed(_mail_id: StringName) -> void:
	_refresh()

func _refresh() -> void:
	if interactable == null or label == null:
		return
	var unread := MailState.get_unread_mail().size()
	label.text = tr("Mailbox") if unread <= 0 else tr("Mailbox · %d new") % unread
	if unread <= 0:
		interactable.set_prompt("Check Mailbox")
	else:
		interactable.set_prompt("Read Mail (%d new)", [unread])

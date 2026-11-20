class_name MailboxMenu
extends MenuLayer

## The player's letters, one at a time, with the previous and the next a press
## away and a letter's attachments claimed from it. The letters keep the order
## the mailbox opened with (the unread first), any that arrive while it shows
## coming last, so a claim leaves the player on the letter they claimed from;
## and the focus stays on the button that has it while that one still works,
## so Next pages on through the letters.

@onready var title_label: Label = $Panel/VBox/Title
@onready var sender_label: Label = $Panel/VBox/Sender
@onready var body_label: RichTextLabel = $Panel/VBox/Body
@onready var rewards_label: Label = $Panel/VBox/Rewards
@onready var previous_button: Button = $Panel/VBox/Navigation/Previous
@onready var next_button: Button = $Panel/VBox/Navigation/Next
@onready var claim_button: Button = $Panel/VBox/Claim
@onready var close_button: Button = $Panel/VBox/Close

var _mail: Array[MailData] = []
var _index := 0

func _init() -> void:
	super(&"mailbox_menu")

func _ready() -> void:
	previous_button.pressed.connect(_previous)
	next_button.pressed.connect(_next)
	claim_button.pressed.connect(_claim)
	close_button.pressed.connect(close)
	MailState.mail_received.connect(_on_mail_changed)
	MailState.mail_claimed.connect(_on_mail_changed)

func open() -> void:
	_mail = MailState.get_received_mail()
	if _mail.is_empty():
		GameEvents.toast(tr("The mailbox is empty"))
		return
	_index = _first_unread_index()
	show_menu()
	_show_current(true)

func _show_current(opening := false) -> void:
	if _mail.is_empty():
		close()
		return
	_index = clampi(_index, 0, _mail.size() - 1)
	var mail := _mail[_index]
	MailState.mark_read(mail.id)
	title_label.text = tr(mail.subject)
	sender_label.text = tr("From: %s   ·   %d/%d") % [mail.get_sender_display_name(), _index + 1, _mail.size()]
	body_label.text = tr(mail.body)
	rewards_label.text = _reward_text(mail)
	var has_rewards := mail.reward_money > 0 or not mail.reward_items.is_empty()
	claim_button.visible = has_rewards
	claim_button.disabled = not has_rewards or MailState.is_claimed(mail.id)
	claim_button.text = tr("Claimed") if MailState.is_claimed(mail.id) else tr("Claim rewards")
	previous_button.disabled = _index <= 0
	next_button.disabled = _index >= _mail.size() - 1
	_keep_focus(opening)

# Leaves the focus on the button that has it while it still works, else hands
# it to the first that does: claiming, the next letter, the previous, closing.
# A mailbox just opened starts on claiming, or closing.
func _keep_focus(opening: bool) -> void:
	var focused := get_viewport().gui_get_focus_owner() as Button
	if not opening and focused != null and is_ancestor_of(focused) and focused.is_visible_in_tree() and not focused.disabled:
		return
	var order: Array[Button] = [claim_button, close_button]
	if not opening:
		order = [claim_button, next_button, previous_button, close_button]
	for button: Button in order:
		if button.visible and not button.disabled:
			button.grab_focus()
			return

func _reward_text(mail: MailData) -> String:
	var parts: PackedStringArray = []
	for raw_id: Variant in mail.reward_items.keys():
		var item := ItemData.find(StringName(String(raw_id)))
		parts.append("%s x%d" % [tr(item.display_name) if item != null else String(raw_id), int(mail.reward_items[raw_id])])
	if mail.reward_money > 0:
		parts.append("%dg" % mail.reward_money)
	return tr("Attachments: %s") % GameText.list(parts) if not parts.is_empty() else tr("No attachments")

func _claim() -> void:
	if _mail.is_empty():
		return
	var mail := _mail[_index]
	if MailState.claim_rewards(mail.id):
		GameEvents.toast(tr("Claimed attachments from %s") % mail.get_sender_display_name())
	_show_current()

func _previous() -> void:
	_index -= 1
	_show_current()

func _next() -> void:
	_index += 1
	_show_current()

func _first_unread_index() -> int:
	for index in _mail.size():
		if not MailState.is_read(_mail[index].id):
			return index
	return maxi(_mail.size() - 1, 0)

# A letter claimed or arrived: the letters keep their order, a new one coming
# last, as the service's own order puts the unread first and would move the
# one the player reads.
func _on_mail_changed(_mail_id: StringName) -> void:
	if not visible:
		return
	for mail: MailData in MailState.get_received_mail():
		if not _mail.has(mail):
			_mail.append(mail)
	_show_current()

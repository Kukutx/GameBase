class_name JianghuNumbers
extends RefCounted

## Numbers as the player reads them: whole below ten thousand, then in the
## units of the language (万 and 亿 in Chinese; K, M, B and T otherwise).

const CHINESE_UNITS: Array[String] = ["", "万", "亿", "万亿", "亿亿"]
const WESTERN_UNITS: Array[String] = ["", "K", "M", "B", "T", "Qa", "Qi"]

static func format(value: float, locale := "") -> String:
	if locale.is_empty():
		locale = TranslationServer.get_locale()
	if is_nan(value) or is_inf(value):
		return "∞"
	var negative := value < 0.0
	var amount := absf(value)
	var text := ""
	if amount < 10000.0:
		text = str(int(floor(amount)))
	elif locale.begins_with("zh"):
		text = _with_units(amount, 10000.0, CHINESE_UNITS)
	else:
		text = _with_units(amount, 1000.0, WESTERN_UNITS)
	return "-" + text if negative else text

## A rate per second: one decimal while it is small.
static func format_rate(value: float, locale := "") -> String:
	if absf(value) < 100.0:
		return String.num(snappedf(value, 0.1), 1)
	return format(value, locale)

## A span of seconds as hours and minutes, or minutes and seconds.
static func format_duration(seconds: float) -> String:
	var total := int(maxf(seconds, 0.0))
	if total >= 3600:
		return String(TranslationServer.translate("%dh %dm")) % [total / 3600, (total % 3600) / 60]
	if total >= 60:
		return String(TranslationServer.translate("%dm %ds")) % [total / 60, total % 60]
	return String(TranslationServer.translate("%ds")) % total

static func _with_units(amount: float, step: float, units: Array[String]) -> String:
	var index := 0
	while amount >= step and index < units.size() - 1:
		amount /= step
		index += 1
	var digits := 2 if amount < 10.0 else (1 if amount < 100.0 else 0)
	var shown := floorf(amount * pow(10.0, digits)) / pow(10.0, digits)
	return ("%.*f" % [digits, shown]) + units[index]

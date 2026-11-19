class_name WeatherData
extends ContentEntry

## A kind of weather (clear skies, rain, a storm, snow): what it is called,
## whether it waters what grows outside, and how the `WeatherOverlay` shows it.
## A game lists its weather as content and rolls it per season
## (`GameDefinition.weather_odds`); a game without any has no weather.

const KIND := &"weather"

## What falls from the sky.
enum Particle {
	NONE,
	RAIN,
	SNOW,
}

@export var display_name: String
## Whether it waters the ground outside: what grows there needs no watering.
@export var wets_ground := false
## What falls from the sky, drawn by the `WeatherOverlay`.
@export var particle := Particle.NONE
## How much falls: 1 is a shower.
@export_range(0.0, 3.0, 0.05) var density := 1.0
## How fast it falls: 1 is rain's pace.
@export_range(0.05, 3.0, 0.05) var fall_speed := 1.0
## How far the wind blows it aside: pixels per rain streak.
@export_range(-20.0, 20.0, 0.5) var wind := 4.0
## The colour of what falls.
@export var particle_color := Color(0.72, 0.84, 1.0, 0.36)
## The colour laid over the view (alpha 0: none).
@export var tint := Color(0.0, 0.0, 0.0, 0.0)
## Whether lightning flashes now and then.
@export var lightning := false

## The weather with `entry_id` in the running game's content, or null.
static func find(entry_id: StringName) -> WeatherData:
	return ContentRegistry.active.get_entry(KIND, entry_id) as WeatherData

## Whether the overlay shows anything of it.
func shows_effects() -> bool:
	return particle != Particle.NONE or tint.a > 0.0 or lightning

func find_problems(_registry: ContentRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	if display_name.strip_edges().is_empty():
		problems.append("has no display name")
	return problems

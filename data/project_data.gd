class_name ProjectData
extends Resource

## Container for all project data: characters + tournament events.
## Can be saved/loaded as .tres files.

@export var project_name: String = "Mi Proyecto"
@export var characters: Array[Resource] = []  # Array of CharacterData
@export var events: Array[Resource] = []  # Array of TournamentEvent

extends SceneTree

func _init():
	print("=== Godot CLI Mode - Hello World! ===")
	print("Godot version: ", Engine.get_version_info())
	print("OS: ", OS.get_name())
	print("Working dir: ", OS.get_executable_path().get_base_dir())
	print("")

	# Command line args (after --)
	var args = OS.get_cmdline_user_args()
	if args.size() > 0:
		print("Custom args: ", args)
	else:
		print("No custom args (pass them after -- )")

	# Simple file I/O test
	var file = FileAccess.open("res://test_output.txt", FileAccess.WRITE)
	if file:
		file.store_string("Hello from Godot CLI at " + Time.get_datetime_string_from_system())
		file.close()
		print("Wrote test_output.txt successfully!")

	print("")
	print("=== Godot CLI is working! ===")
	quit()

#	Copyright (c) 2021 K. S. Ernest (iFire) Lee and V-Sekai Contributors.
#	Copyright (c) 2007-2021 Juan Linietsky, Ariel Manzur.
#	Copyright (c) 2014-2021 Godot Engine contributors (cf. AUTHORS.md).
#
#	Permission is hereby granted, free of charge, to any person obtaining a copy
#	of this software and associated documentation files (the "Software"), to deal
#	in the Software without restriction, including without limitation the rights
#	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#	copies of the Software, and to permit persons to whom the Software is
#	furnished to do so, subject to the following conditions:
#
#	The above copyright notice and this permission notice shall be included in all
#	copies or substantial portions of the Software.
#
#	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
#	SOFTWARE.

@tool
extends EditorSceneFormatImporter

const settings_blender_path = "filesystem/import/blend/blender_path"

var blender_path : String

func _init():
	if not ProjectSettings.has_setting(settings_blender_path):
		ProjectSettings.set_initial_value(settings_blender_path, "blender")
		ProjectSettings.set_setting(settings_blender_path, "blender")
	else:
		blender_path = ProjectSettings.get_setting(settings_blender_path)
	var property_info = {
		"name": settings_blender_path,
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_GLOBAL_FILE,
		"hint_string": ""
	}
	ProjectSettings.add_property_info(property_info)


func _get_extensions():
	return ["blend"]


func _get_import_flags():
	return EditorSceneFormatImporter.IMPORT_SCENE


func _import_scene(path: String, flags: int, bake_fps: int):
	var import_config_file = ConfigFile.new()
	import_config_file.load(path + ".import")
	var compression_flags: int = import_config_file.get_value("params", "meshes/compress", 0)
	# ARRAY_COMPRESS_BASE = (ARRAY_INDEX + 1)
	compression_flags = compression_flags << (RenderingServer.ARRAY_INDEX + 1)
	if import_config_file.get_value("params", "meshes/octahedral_compression", false):
		compression_flags |= RenderingServer.ARRAY_FLAG_USE_OCTAHEDRAL_COMPRESSION

	var path_global : String = ProjectSettings.globalize_path(path)
	path_global = path_global.c_escape()
	var output_path : String = "res://.godot/imported/" + path.get_file().get_basename() + "-" + path.md5_text() + ".glb"
	var output_path_global = ProjectSettings.globalize_path(output_path)
	output_path_global = output_path_global.c_escape()
	var stdout = [].duplicate()
	var addon_path : String = blender_path
	var addon_path_global = ProjectSettings.globalize_path(addon_path)
	var params: PackedStringArray = [
		"filepath='%s'" % output_path_global,
		"export_format='GLB'",
		"export_colors=True",
		"export_all_influences=True",
		"export_extras=True",
		"export_cameras=True",
		"export_lights=True",
		"export_apply=(len(bpy.data.shape_keys)==0)"
	]
	var script : String = "import bpy; bpy.ops.export_scene.gltf(%s)" % ",".join(params)
	path_global = path_global.c_escape()
	var args = PackedStringArray([
		path_global,
		"--background",
		"--python-expr",
		script
	])
	var ret = OS.execute(addon_path_global, args, stdout, true)
	if ret != OK:
		push_error(
			"Blender import failed with code=%d.\nCommand: %s\nOutput: %s" % [
				ret,
				" ".join(args),
				"\n".join(stdout)
			]
		)
		return null
	var gltf_importer : EditorSceneFormatImporterGLTF = EditorSceneFormatImporterGLTF.new()
	var root_node: Node3D = gltf_importer.import_scene_from_other_importer(output_path, flags, bake_fps)
	return root_node

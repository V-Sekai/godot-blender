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

tool
extends EditorSceneImporter

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
	return ["bvh"]


func _get_import_flags():
	return EditorSceneImporter.IMPORT_SCENE


func _add_all_gltf_nodes_to_skin(obj: Dictionary):
	var scene_nodes = {}.duplicate()
	for scene in obj["scenes"]:
		for node in scene["nodes"]:
			scene_nodes[int(node)] = true
	var new_joints = [].duplicate()
	for node in range(len(obj["nodes"])):
		if scene_nodes.get(int(node), false):
			obj["nodes"][node]["name"] = "Armature"
		else:
			new_joints.push_back(node)
	new_joints.sort()

	var new_skin: Dictionary = {"joints": new_joints}

	if not obj.has("skins"):
		obj["skins"] = [].duplicate()

	obj["skins"].push_back(new_skin)


func _add_all_glb_nodes_to_skin(path):
	var f = File.new()
	if f.open(path, File.READ) != OK:
		return FAILED

	var magic = f.get_32()
	if magic != 0x46546C67:
		return ERR_FILE_UNRECOGNIZED
	var version = f.get_32() # version
	var full_length = f.get_32() # length

	var chunk_length = f.get_32();
	var chunk_type = f.get_32();

	if chunk_type != 0x4E4F534A:
		return ERR_PARSE_ERROR
	var orig_json_utf8 : PoolByteArray = f.get_buffer(chunk_length)
	var rest_data : PoolByteArray = f.get_buffer(full_length - chunk_length - 20)
	if (f.get_len() != full_length):
		push_error("Incorrect full_length in " + str(path))

	f.close()

	var gltf_json_parsed_result: JSONParseResult = JSON.parse(orig_json_utf8.get_string_from_utf8())
	if gltf_json_parsed_result.error != OK:
		push_error("Failed to parse JSON part of glTF file in " + str(path) + ":" + str(gltf_json_parsed_result.error_line) + ": " + gltf_json_parsed_result.error_string)
		return ERR_FILE_UNRECOGNIZED
	var gltf_json_parsed: Dictionary = gltf_json_parsed_result.result
	_add_all_gltf_nodes_to_skin(gltf_json_parsed)
	var json_utf8: PoolByteArray = JSON.print(gltf_json_parsed).to_utf8()

	f = File.new()
	if f.open(path, File.WRITE) != OK:
		return FAILED
	f.store_32(magic)
	f.store_32(version)
	f.store_32(full_length + len(json_utf8) - len(orig_json_utf8))
	f.store_32(len(json_utf8))
	f.store_32(chunk_type)
	f.store_buffer(json_utf8)
	f.store_buffer(rest_data)
	f.close()

func _import_scene(path: String, flags: int, bake_fps: int):
	var import_config_file = ConfigFile.new()
	import_config_file.load(path + ".import")
	var compression_flags: int = import_config_file.get_value("params", "meshes/compress", 0)
	# ARRAY_COMPRESS_BASE = (ARRAY_INDEX + 1)
	compression_flags = compression_flags << (VisualServer.ARRAY_INDEX + 1)
	if import_config_file.get_value("params", "meshes/octahedral_compression", false):
		compression_flags |= VisualServer.ARRAY_FLAG_USE_OCTAHEDRAL_COMPRESSION

	var path_global : String = ProjectSettings.globalize_path(path)
	path_global = path_global.c_escape()
	var output_path : String = "res://.import/" + path.get_file() + "-" + path.md5_text() + ".glb"
	var output_path_global = ProjectSettings.globalize_path(output_path)
	output_path_global = output_path_global.c_escape()
	var stdout = [].duplicate()
	var addon_path : String = blender_path
	var addon_path_global = ProjectSettings.globalize_path(addon_path)
	var script : String = ("import bpy, os, sys;" +
		"bpy.context.scene.render.fps=" + str(int(bake_fps)) + ";" +
		"bpy.ops.import_anim.bvh(filepath='GODOT_FILENAME', target='ARMATURE', update_scene_duration=True, use_fps_scale=True);" +
		"bpy.ops.export_scene.gltf(filepath='GODOT_EXPORT_PATH',export_format='GLB',export_colors=True,export_all_influences=False,export_extras=True,export_cameras=True,export_lights=True);")
	path_global = path_global.c_escape()
	script = script.replace("GODOT_FILENAME", path_global)
	output_path_global = output_path_global.c_escape()
	script = script.replace("GODOT_EXPORT_PATH", output_path_global)
	var dir = Directory.new()
	var tex_dir_global = output_path_global + "_textures"
	tex_dir_global.c_escape()
	dir.make_dir(tex_dir_global)
	script = script.replace("GODOT_TEXTURE_PATH", tex_dir_global)
	var args = [
		"--background",
		"--python-expr",
		script]
	print(args)
	var ret = OS.execute(addon_path_global, args, true, stdout, true)
	for line in stdout:
		print(line)
	if ret != 0:
		print("Blender returned " + str(ret))
		return null

	_add_all_glb_nodes_to_skin(output_path)

	var root_node: Spatial = null
	if Engine.get_version_info()["major"] <= 3 and Engine.get_version_info()["minor"] <= 3:
		root_node = call("import_scene_from_other_importer", output_path, flags, bake_fps)
	else:
		root_node = call("import_scene_from_other_importer", output_path, flags, bake_fps, compression_flags)
	return root_node



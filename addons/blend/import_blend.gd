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

func _get_extensions():
	return ["blend"]


func _get_import_flags():
	return EditorSceneFormatImporter.IMPORT_SCENE


func _import_scene(path: String, flags: int, bake_fps: int):
	var path_global : String = ProjectSettings.globalize_path(path)
	var output_path : String = "res://.godot/imported/" + path.get_file().get_basename() + "-" + path.md5_text() + ".glb" 
	var output_path_global = ProjectSettings.globalize_path(output_path)
	var stdout = [].duplicate()
	var addon_path: String = "blender"
	var script : String = """--python-expr \"import bpy;\
import os;\
import sys;\
filename = 'GODOT_FILENAME';\
bpy.ops.wm.open_mainfile(filepath=filename);\
export_path = 'GODOT_EXPORT_PATH';\
bpy.ops.export_scene.gltf(\
filepath=export_path,\
export_format='GLB',\
export_colors=True,\
export_all_influences=True,\
export_extras=True,\
export_cameras=True,\
export_lights=True);\""""
	script = script.replace("GODOT_FILENAME", path_global)
	script = script.replace("GODOT_EXPORT_PATH", output_path_global)
	var args = [
		addon_path,
		"--background",
		script]
	var ret = OS.execute("blender", args, stdout, true)
	for line in stdout:
		print(line)
	if ret != 0:
		print("Blender returned " + str(ret))
		return null

	var gstate : GLTFState = GLTFState.new()
	var gltf : GLTFDocument = GLTFDocument.new()
	var root_node : Node = gltf.import_scene(output_path, 0, 1000.0, gstate)
	root_node.name = path.get_basename().get_file()
	return root_node

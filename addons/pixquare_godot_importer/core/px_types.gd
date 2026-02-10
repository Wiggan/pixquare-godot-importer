extends Node


class PxDocument:
	var w: int
	var h: int
	var root_layer_order: Array[String]
	var layers_by_id: Dictionary
	var frame_content_by_id: Dictionary

#static func _load_document(source_file: String) -> PxDocument:

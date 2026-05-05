class_name QInterface

static func implements(thing: Object, interface) -> bool:
	return &"implements" in thing and interface in thing.implements

@tool
class_name QInterfacePlugin extends EditorPlugin

var previous_script: Script = null
var interfaces: Dictionary[StringName, QIndexedScript] = {}

# ------
# Signals Recieved
# ------

func _enter_tree() -> void:
	EditorInterface.get_script_editor().editor_script_changed.connect(_editor_script_changed)
	resource_saved.connect(_resource_saved)
	var file_system := EditorInterface.get_resource_filesystem().get_filesystem()
	scan_entier_file_system(file_system, read_interface)
	scan_entier_file_system(file_system, check_script)


func _exit_tree() -> void:
	EditorInterface.get_script_editor().editor_script_changed.disconnect(_editor_script_changed)
	resource_saved.disconnect(_resource_saved)


func _editor_script_changed(new_script: Script):
	check_script(previous_script)
	previous_script = new_script
	check_script(new_script)


func _resource_saved(resource: Resource):
	if resource is Script:
		read_interface(resource)
		check_script(resource)


func scan_entier_file_system(dir: EditorFileSystemDirectory, action: Callable):
	for i in range(dir.get_subdir_count()):
		scan_entier_file_system(dir.get_subdir(i), action)
	for i in range(dir.get_file_count()):
		var file_path := dir.get_path() + dir.get_file(i)
		if not file_path.ends_with(".gd"): continue
		var file := load(file_path)
		action.call(file)


# ------
# Scripts Define Interface
# ------


func read_interface(script: Script):
	if not script.is_abstract(): return
	#var regmatch := RegEx.create_from_string("@abstract[\\n\\t ]*(#[\\t ]*@interface[\\n\\t ]*class_name|class_name[\\t ]*#[\\t ]*@interface)[\\t ]*\\n").search(script.source_code)
	var regmatch := RegEx.create_from_string("@abstract[\\n\\t ]*#[\\t ]*@interface[\\n\\t ]*class_name").search(script.source_code)
	if regmatch == null: return
	interfaces[script.get_global_name()] = QIndexedScript.new(script)
	#print(interfaces[script.get_global_name()])


# ------
# Scripts Use Interface
# ------


## see if a script fits within the interface rules
func check_script(script: Script):
	if script == null: return
	
	var interface_names = script_implements(script.source_code)
	if len(interface_names) == 0: return
	
	var indexed_script := QIndexedScript.new(script)
	var result = ""
	
	for interface in interface_names:
		result += check_interface(indexed_script, interface)
	
	if result != "":
		push_error("\nInterface errors: ", script.resource_path,  " \n", result.rstrip("\n"))


## mannually parse the source code to determine the interfaces that are implemented
func script_implements(source_code: String) -> Array[String]:
	# 1. find var implements
	var regexmatch := RegEx.create_from_string("(?:^|\\n)var[ \\t]+implements[ \\t:a-zA-Z\\[\\]]=[ \\t]+\\[").search(source_code)
	if regexmatch == null: return []
	var start = regexmatch.get_end() # find var implements = [
	var end = source_code.find("]", start)
	if end == -1: return []
	# 4. make substring
	var interfaces_source_code := source_code.substr(start, end - start)
	# 5. split
	var interfaces_large : PackedStringArray = interfaces_source_code.split(",")
	# 6. strip each
	var smaller_interfaces: Array[String] = []
	for string in interfaces_large:
		var stripped := string.strip_edges()
		if stripped != "":
			smaller_interfaces.append(stripped)
	var result = smaller_interfaces
	return result


## returning "" is match
## returning anything else is error message
func check_interface(indexed_script: QIndexedScript, interface_name: StringName) -> String:
	if interface_name in interfaces:
		var check_result := interfaces[interface_name].check_script(indexed_script)
		if check_result == "":
			return ""
		else:
			return str("|\tInterface '", interface_name, "' improperly implemented:\n", check_result, "\n")
		
	else:
		return str("|\tUnknown Interface '", interface_name, "'\n")


# ------
# Are X and Y the same
# ------


static func property_type_name(prop: Dictionary) -> String:
	if prop.class_name == &"":
		return type_string(prop.type)
	else:
		return prop.class_name


static func is_property_none(prop: Dictionary) -> bool:
	return (prop.type == Variant.Type.TYPE_NIL) and (len(prop.class_name) == 0)


## returning "" is match
## returning anything else is error message
static func are_properties_same(prop1: Dictionary, prop2: Dictionary, indentation: String) -> String:
	#print("\n\nprop1:", prop1)
	#print("\n\nprop2:", prop2)
	if prop1.type == prop2.type and prop1.class_name == prop2.class_name:
		return ""
	else:
		return str(indentation, "Expected: ", property_type_name(prop1), "\n", indentation, "Got:      ", property_type_name(prop2), "\n")


static func are_method_flag_same(method1: Dictionary, method2: Dictionary, flag: MethodFlags, message_true: String, message_false: String) -> String:
	if method1.flags & flag != method2.flags & flag:
		if method1.flags & flag == 0:
			return message_false
		else:
			return message_true
	return ""


## returning "" is match
## returning anything else is error message
static func are_methods_same(method1: Dictionary, method2: Dictionary) -> String:
	var result := ""
	# return
	var return_result := are_properties_same(method1.return, method2.return, "|\t|\t|\t|\t")
	if return_result != "": # error
		result += str("|\t|\t|\tIncorrect Return:\n", return_result)
	# args
	if len(method1.args) != len(method2.args): 
		result += str("|\t|\t|\tIncorrect Number of Arguments Expected: ", len(method1.args), " Got: ", len(method2.args), "\n")
	else:
		for i in range(len(method1.args)):
			var arg_check_result := are_properties_same(method1.args[i], method2.args[i], "|\t|\t|\t|\t")
			if len(arg_check_result) != 0: # error
				result += str("|\t|\t|\tIncorrect Argument #", i+1, ":\n", arg_check_result)
	# flags
	result += are_method_flag_same(method1, method2, MethodFlags.METHOD_FLAG_STATIC, "|\t|\t|\tExpected to be static\n", "|\t|\t|\tExpected to not be static\n")
	result += are_method_flag_same(method1, method2, MethodFlags.METHOD_FLAG_VARARG, "|\t|\t|\tExpected to take variadic arguments\n", "|\t|\t|\tExpected to not take variadic arguments\n")
	
	return result

static func are_constants_same(constant1: Variant, constant2: Variant) -> String:
	if typeof(constant1) != typeof(constant2):
		return str("|\t|\t|\tExpected: ", type_string(typeof(constant1)), "\n|\t|\t|\tGot:      ", type_string(typeof(constant2)), "\n")
	return ""

static func generate_method_signiture(type: String, method: Dictionary) -> String:
	var result = ""
	if method.flags & MethodFlags.METHOD_FLAG_STATIC != 0:
		result += "static "
	result += str(type, " ", method.name, "(")
	for arg in method.args:
		if is_property_none(arg):
			result += str(arg.name, ", ")
		else:
			result += str(arg.name, ": ", property_type_name(arg), ", ")
	if method.flags & MethodFlags.METHOD_FLAG_VARARG != 0:
		result += "...args"
	elif len(method.args) > 0:
		result = result.substr(0, len(result) - 2) # remove ", "
	result += ")"
	if not is_property_none(method.return):
		result += str(" -> ", property_type_name(method.return))
	return result

static func generate_property_signiture(property: Dictionary) -> String:
	var result = str("var ", property.name)
	if not is_property_none(property):
		result += str(": ", property_type_name(property))
	return result

static func generate_constant_signiture(name: StringName, value: Variant) -> String:
	return str("const ", name, ": ", type_string(typeof(value)), " = ", value)

# ------
# QIndexedScript
# ------


## Does main processing
## Holds the script's infos in a more useful format
## Has check_script which does the important stuff
class QIndexedScript:
	var property_list: Dictionary[StringName, Dictionary] = {}
	var method_list: Dictionary[StringName, Dictionary] = {}
	var signal_list: Dictionary[StringName, Dictionary] = {}
	var constant_map: Dictionary = {}
	func _init(script: Script = null):
		if script != null:
			property_list = index_array_of_dictionaries(script.get_script_property_list())
			method_list = index_array_of_dictionaries(script.get_script_method_list())
			signal_list = index_array_of_dictionaries(script.get_script_signal_list())
			constant_map = script.get_script_constant_map()
	
	static func index_array_of_dictionaries(input: Array[Dictionary]) ->  Dictionary[StringName, Dictionary]:
		var result: Dictionary[StringName, Dictionary] = {}
		for dict in input:
			result[dict.name] = dict
		return result
	
	func _to_string() -> String:
		return str("\nProperties:\n", property_list, "\n\nMethods:\n", method_list, "\n\nSignals:\n", signal_list, "\n\nConstants:\n", constant_map, "\n")
	
	## returning "" is valid
	## returning anything else is error message
	## use: interface_script.check_script(implementer_script)
	func check_script(script: QIndexedScript) -> String:
		var result = ""
		for property_name in property_list:
			if (property_list[property_name].usage & PropertyUsageFlags.PROPERTY_USAGE_SCRIPT_VARIABLE) == 0: continue # there are some properties that are not varribles - ignore those
			if not property_name in script.property_list:
				result += str("|\t|\tMissing: ", QInterfacePlugin.generate_property_signiture(property_list[property_name]), "\n")
				continue
			var check_result := QInterfacePlugin.are_properties_same(property_list[property_name], script.property_list[property_name], "|\t|\t|\t")
			if check_result != "":
				result += str("|\t|\tIncorrect: ", QInterfacePlugin.generate_property_signiture(property_list[property_name]), "\n", check_result)
		
		for method_name in method_list:
			if not method_name in script.method_list:
				result += str("|\t|\tMissing: ", QInterfacePlugin.generate_method_signiture("func", method_list[method_name]),"\n")
				continue
			var check_result := QInterfacePlugin.are_methods_same(method_list[method_name], script.method_list[method_name])
			if check_result != "":
				result += str("|\t|\tIncorrect: ", QInterfacePlugin.generate_method_signiture("func", method_list[method_name]),"\n", check_result)
		
		for signal_name in signal_list:
			if not signal_name in script.signal_list:
				result += str("|\t|\tMissing: ", QInterfacePlugin.generate_method_signiture("signal", signal_list[signal_name]), "\n")
				continue
			var check_result := QInterfacePlugin.are_methods_same(signal_list[signal_name], script.signal_list[signal_name])
			if check_result != "":
				result += str("|\t|\tIncorrect: ", QInterfacePlugin.generate_method_signiture("signal", signal_list[signal_name]),"\n", check_result)
		
		for constant_name in constant_map:
			if not constant_name in script.constant_map:
				result += str("|\t|\tMissing: ", QInterfacePlugin.generate_constant_signiture(constant_name, constant_map[constant_name]),"\n")
				continue
			var check_result := QInterfacePlugin.are_constants_same(constant_map[constant_name], script.constant_map[constant_name])
			if check_result != "":
				result += str("|\t|\tIncorrect: ", QInterfacePlugin.generate_constant_signiture(constant_name, constant_map[constant_name]), "\n", check_result)
		
		return result

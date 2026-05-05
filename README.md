# QInterface
Preforms in editor checking for interfaces.

Godot (currently) does not support interfaces or traits or multi-inherence - which would all solve the same issue more or less.

But with not we are forced to use`has_method` or excessive composition - both which arent great.

This bothered me enough to create this - which lets you:
- define interfaces
- then get error (without even running the game) to see what you need to fix to correctly implement the give interface.

[DEMO Video](https://youtu.be/43r1F9vf4NQ)

# How to add to your project
1. place the `plugin.cfg`, the `plugin.gd`, and the `qinterface.gd` in a folder in the godot project (recomeneded `res://addons/qinterface/`)
2. Project > Project Settings > Plugins > QInterface > Enabled

why is this not on the asset library?

cause dispite doing everything I set out for it to do, it could use some more upgrades before I feel like submitting it for review.

IDK if I will improve it further - probably will.

# Define an interface
File should start with
```gdscript
@abstract # @interface
class_name InterfaceName
```
where InterfaceName can be whatever you want

you can optionally put commonets above it and change the white space a bit

then this file is an interface - anything that implements it will need to also define those

# Implementing an Interface
create the varrible in the script as follows
`var implements = [InterfaceName1, InterfaceName2]`
or
```gdscript
var implements: Array = [
	InterfaceName1,
	InterfaceName2,
]
```
(dont place comments between the [ ])
(you can type it Array but dont give it a further type (like Array[Foo]))

now whenever you:
1. save this script
2. navigate to this script
3. naviage away from this script
4. open the project

the output will log error messages telling you if you have implemented the interface incorrectly

this way you can garentee that you have it implemented correctly everywhere

# Using that which has impelemented an Inteferface
Check if enemy has the interface Hittable with QInterface.implements(enemy, Hittable)

Have an array of objects that implement a given inteface: sorry there isnt a good way to do it - just use an Array[Object] or Array[Varient] or Array - then just check every element before you add it to the array

# Tips
You might want to consider a naming convention

naming interfaces starting with I_ - will make it so that you can autocomplete them easier but otherwise stay out of the way

naming properties and methods and signals within a given interface starting with i_interface_name_property_name will help you know what belongs to what and if something should be removed if you remove the interface

# Limitaitons
Does not support:
- static properties
- nested types
- difference between void/Nil and Varient (in both cases will leave untyped)

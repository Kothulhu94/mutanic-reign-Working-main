# uid://c1txl1fmrp17a
extends Resource
class_name DomainSpec

## Defines a skill domain with its associated primary and secondary attributes
## Domains group related skills and determine which attributes they train
## Load from .tres files in res://data/Domains/

@export var domain_id: StringName = StringName()
@export var display_name: String = ""
@export var primary_attribute: StringName = StringName()
@export var secondary_attribute: StringName = StringName()

## Validate that the domain has all required fields
func is_valid() -> bool:
	return domain_id != StringName() and \
		   display_name != "" and \
		   primary_attribute != StringName() and \
		   secondary_attribute != StringName()

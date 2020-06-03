module main

enum SymbolKind {
	file
	@module
	namespace
	package
	class
	method
	property
	field
	constructor
	@enum
	@interface
	function
	variable
	constant
	string
	number
	boolean
	array
	object
	key
	null
	enum_member
	@struct
	event
	operator
}

fn (sk SymbolKind) str() string {
	match sk {
		0  { return 'File' }
		1  { return 'Module' }
		2  { return 'Namespace' }
		3  { return 'Package' }
		4  { return 'Class' }
		5  { return 'Method' }
		6  { return 'Property' }
		7  { return 'Field' }
		8  { return 'Constructor' }
		9  { return 'Enum' }
		10 { return 'Interface' }
		11 { return 'Function' }
		12 { return 'Variable' }
		13 { return 'Constant' }
		14 { return 'String' }
		15 { return 'Number' }
		16 { return 'Boolean' }
		17 { return 'Array' }
		18 { return 'Object' }
		19 { return 'Key' }
		20 { return 'Null' }
		21 { return 'EnumMember' }
		22 { return 'Struct' }
		23 { return 'Event' }
		24 { return 'Operator' }
		25 { return 'TypeParameter' }
		else {return 'unknown symbol kind'}
	}
}

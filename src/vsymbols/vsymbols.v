module main

import v.pref
import v.parser
import v.ast
import v.table
import v.token
import os
import json
import crypto.md5

const (
	vs_temp_dir = os.join_path(os.temp_dir(), 'vsymbols')
	invalid_input_message = 'Failed to parse json, Please make sure that the input is a JSON string'
)

struct Context {
mut:
	file	File
}

struct File {
mut:
	temp_path		string	[skip]
	path			string
	modname			string
	symbols			[]SymbolInformation
	cidx			int	[skip] = -1 
	has_error		bool
	source			string	[skip]
}

struct SymbolInformation {
	name		string
	pos			token.Position
	kind		int
	pidx		int = -1
}

struct Input {
	filepath	string
	source		string
}

fn main() {
	args := os.args[1..]
	debug := '-debug' in args

	lines := os.get_lines_joined()
	input := json.decode(Input, lines) or {
		eprintln(invalid_input_message)
		return
	}

	// Create temp dir if not exist
	if !os.exists(vs_temp_dir) {
		os.mkdir(vs_temp_dir) or { panic(err) }
	}
	
	filename := create_temp_file(input.filepath, input.source)
	
	fscope := ast.Scope{ parent: 0 }
	prefs := pref.Preferences{
		skip_warnings: true
	}
	table := table.new_table()

	mut ctx := Context{
		file: File{ 
			path: input.filepath 
			temp_path: filename 
		}
	}

	parse_result := parser.parse_file(filename, table, .skip_comments, prefs, fscope)
	ctx.file.modname = parse_result.mod.name
	ctx.file.has_error = parse_result.errors.len > 0
	
	// Keep send response even has error
	if ctx.file.has_error {
		println(json.encode(ctx.file))
		return
	}

	ctx.file.process_stmts(parse_result.stmts, -1)
	ctx.file.source = input.source

	println(json.encode(ctx.file))
	
	if debug {
		for symbol in ctx.file.symbols {
			println(symbol_kind_str(symbol.kind)) 
			println(symbol)
		}
	}
}

fn (mut file File) process_stmts(stmts []ast.Stmt, pidx int) {
	for stmt in stmts {
		match stmt {
			ast.FnDecl {
				fndecl := stmt as ast.FnDecl
				if fndecl.is_method {
					file.process_method(fndecl)
				} else {
					file.process_fn(fndecl)
				}
			}
			ast.StructDecl { 
				file.process_struct(stmt) 
			}
			ast.ConstDecl { 
				file.process_const(stmt) 
			}
			ast.EnumDecl {
				file.process_enum(stmt)
			}
			ast.InterfaceDecl {
				file.process_interface(stmt)
			}
			else {}
		}
	}
}

/* --------------------------------- STRUCT --------------------------------- */
fn (mut file File) process_struct(stmt ast.Stmt) {
	structdecl := stmt as ast.StructDecl
	file.symbols << SymbolInformation{
		name: get_real_name(structdecl.name)
		pos: structdecl.pos
		kind: symbol_kind_struct
		// pidx: file.cidx
	}
if structdecl.fields.len > 0 {
		pidx := file.symbols.filter(symbol_isnt_children).len - 1
		for struct_field in structdecl.fields {
			file.symbols << SymbolInformation {
				name: get_real_name(struct_field.name)
				pos: struct_field.pos
				kind: symbol_kind_property
				pidx: pidx
			}
		}
	}
}

/* --------------------------------- CONST --------------------------------- */
fn (mut file File) process_const(stmt ast.Stmt) {
	constdecl := stmt as ast.ConstDecl
	for const_field in constdecl.fields {
		file.symbols << SymbolInformation{
			name: get_real_name(const_field.name)
			pos: const_field.pos
			kind: symbol_kind_constant
			// pidx: file.cidx
		}
	}
}

/* -------------------------------- FUNCTION -------------------------------- */
fn (mut file File) process_fn(fndecl ast.FnDecl) {
	file.symbols << SymbolInformation{
		name: get_real_name(fndecl.name)
		pos: fndecl.pos
		kind: symbol_kind_function
		// pidx: file.cidx
	}
	if fndecl.stmts.len > 0 { 
		file.process_stmts(fndecl.stmts, file.symbols.len)
	}
}

/* -------------------------------- METHOD -------------------------------- */
fn (mut file File) process_method(fndecl ast.FnDecl) {
	file.symbols << SymbolInformation{
		name: fndecl.name
		pos: fndecl.pos
		kind: symbol_kind_method
		pidx: file.cidx
	}
	// if fndecl.stmts.len > 0 {
	// TODO
	// }
}

/* ---------------------------------- ENUM ---------------------------------- */
fn (mut file File) process_enum(stmt ast.Stmt) {
	enumdecl := stmt as ast.EnumDecl
	file.symbols << SymbolInformation{
		name: get_real_name(enumdecl.name)
		pos: enumdecl.pos
		kind: symbol_kind_enum
		// pidx: file.cidx
	}
	if enumdecl.fields.len > 0 {
		pidx := file.symbols.filter(symbol_isnt_children).len - 1
		for enum_field in enumdecl.fields {
			file.symbols << SymbolInformation{
				name: enum_field.name
				pos: enum_field.pos
				kind: symbol_kind_enum_member
				pidx: pidx
			}
		}
	}
}

/* -------------------------------- INTERFACE ------------------------------- */
fn (mut file File) process_interface(stmt ast.Stmt) {
	ifacedecl := stmt as ast.InterfaceDecl
	file.symbols << SymbolInformation{
		name: get_real_name(ifacedecl.name)
		pos: ifacedecl.pos
		kind: symbol_kind_interface
	}
	if ifacedecl.methods.len > 0 {
		file.cidx = file.symbols.filter(symbol_isnt_children).len - 1
		for method in ifacedecl.methods {
			file.process_method(method)
		}
		file.cidx = -1
	}
}

fn (file File) get_signature(name string) string {
	return file.modname + '.' + name
}

/* ---------------------------------- UTILS --------------------------------- */
// fn (file File) get_real_position(pos token.Position) Position {
// 	source := file.source
// 	mut p := imax(0, imin(source.len - 1, pos.pos))
// 	if source.len > 0 {
// 		for ; p >= 0; p-- {
// 			if source[p] == `\r` || source[p] == `\n` {
// 				break
// 			}
// 		}
// 	}
// 	column := imax(0, pos.pos - p - 1)
// 	return Position { 
// 		line: pos.line_nr + 1
// 		column: imax(1, column) - 1 
// 	}
// }

fn get_real_name(name string) string {
	name_split := name.split('.')
	if name_split.len > 1 { 
		return name_split[name_split.len - 1] 
	}
	return name
}

fn create_temp_file(filename, content string) string {
	if content.len < 3 { return filename }
	hashed_name := md5.sum(filename.bytes()).hex()
	target := os.join_path(vs_temp_dir, hashed_name)
	os.write_file(target, content)
	return target
}

fn symbol_isnt_children(symbol SymbolInformation) bool {
	return symbol.pidx == -1
}

// [inline]
// fn imin(a, b int) int {
// 	return if a < b { a } else { b }
// }

// [inline]
// fn imax(a, b int) int {
// 	return if a > b { a } else { b }
// }

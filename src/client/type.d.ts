import { SymbolKind, Range } from "vscode";

export declare interface VSymbolInput {
	filepath: string;
	source: string;
}

export declare interface VTokenPosition {
	line_nr: number;
	pos: number;
	len: number;
}

export declare interface VSymbolFile {
	path: string;
	modname: string;
	symbols: VSymbolInfo[];
	has_error: boolean;
}

export declare interface VSymbolInfo {
	name: string;
	pos: VTokenPosition;
	kind: SymbolKind;
	parent_idx: number;
}

import { SymbolKind } from "vscode";

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
	err: boolean;
}

export declare interface VSymbolInfo {
	n: string;
	ps: VTokenPosition;
	k: SymbolKind;
	px: number;
}

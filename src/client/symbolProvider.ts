import {
	CancellationToken,
	DocumentSymbolProvider,
	TextDocument,
	Position,
	DocumentSymbol,
	Range,
	ExtensionContext,
} from "vscode";
// import { getCwd } from "./utils";
import { join } from "path";
import { spawn } from "child_process";
import { VSymbolInfo, VSymbolFile, VSymbolInput } from "./type";

// Store caching symbols here
const symbolsCache: Map<string, DocumentSymbol[]> = new Map();

class VDocumentSymbolProvider implements DocumentSymbolProvider {
	/** The location of `vsymbols` binary */
	vsymbolsExec: string;

	constructor(context: ExtensionContext) {
		this.vsymbolsExec = context.asAbsolutePath(join("bin", "vsymbols"));
	}

	public provideDocumentSymbols(document: TextDocument, token: CancellationToken): Thenable<DocumentSymbol[]> {
		return new Promise((resolve, reject) => {
			if (token.isCancellationRequested) {
				reject();
			}

			let symbols: DocumentSymbol[] = [];
			const documentUriString = document.uri.toString();

			// Request object for send to `vsymbols`
			const request: VSymbolInput = {
				filepath: document.fileName,
				source: document.getText(),
			};

			/** The string version of `request` object */
			const requestString = JSON.stringify(request);
			const child = spawn(this.vsymbolsExec, { detached: true });

			// Send/input request string to `vsymbols`
			child.stdin.write(requestString);

			// child.on("error", (err) => {
			// 	// Get cached symbols of this document if exist
			// 	if (symbolsCache.has(documentUriString)) {
			// 		resolve(symbolsCache.get(documentUriString) || []);
			// 	} else {
			// 		reject();
			// 	}
			// });

			child.stderr.on("data", (/* data */) => {
				// const datastring = data.toString();
				// Get cached symbols of this document if exist
				if (symbolsCache.has(documentUriString)) {
					resolve(symbolsCache.get(documentUriString) || []);
				} else {
					reject();
				}
			});

			child.stdout.on("data", (data) => {
				/** The response object from `vsymbols` */
				const response: VSymbolFile = JSON.parse(data.toString("utf8"));
				/** The symbols of this document */
				const vsymbols: VSymbolInfo[] = response.symbols;

				// Got parse error
				if (response.err && symbolsCache.has(documentUriString)) {
					// Get symbols from cache
					symbols = symbolsCache.get(documentUriString);
				} else {
					for (const symbol of vsymbols) {
						const start = new Position(symbol.ps.line_nr, 0);
						const end = new Position(symbol.ps.line_nr, symbol.ps.len);
						// TODO: Make a real full range
						const fullRange = new Range(start, end);
						const revealRange = new Range(fullRange.end, fullRange.end);

						// Current symbol is a children
						if (symbol.px > -1) {
							const parent = symbols[symbol.px];
							const child = new DocumentSymbol(symbol.n, "", symbol.k, fullRange, revealRange);
							parent.children.push(child);
						} else {
							const newSymbol = new DocumentSymbol(symbol.n, "", symbol.k, fullRange, revealRange);
							symbols.push(newSymbol);
						}
						symbolsCache.set(documentUriString, symbols);
					}
				}
			});

			child.on("close", () => resolve(symbols));

			// End the request/input to `vsymbols`
			child.stdin.end();
		});
	}
}

export default VDocumentSymbolProvider;

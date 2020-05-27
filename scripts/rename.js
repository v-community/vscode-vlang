#!/usr/bin/env node
// @ts-check
const os = require("os");
const fs = require("fs");
const path = require('path')

const platform = os.platform();
const files = fs.readdirSync(path.join(__dirname, '..'));

const vsix = files.find((file) => file.indexOf("vscode-vlang-") > -1);
let newvsixname = vsix.replace("vscode-vlang-", "vscode-vlang-v");
newvsixname = newvsixname.replace(".vsix", "-" + getOsReleaseName() + ".vsix");

console.log(newvsixname);

fs.renameSync("./" + vsix, newvsixname);

function getOsReleaseName() {
	if (platform === "linux") return platform;
	if (platform === "win32") return "windows";
	if (platform === "darwin") return "mac";
}

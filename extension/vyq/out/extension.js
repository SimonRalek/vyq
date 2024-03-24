"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.deactivate = exports.activate = void 0;
const vscode = require("vscode");
function activate(context) {
    console.log('Gratulejeme, vaše rozšíření "Vyq" je nyní aktivní!');
    // let disposable = vscode.commands.registerCommand('extension.helloWorld', () => {
    //     vscode.window.showInformationMessage('Hello World from VyQ Language Support!');
    // });
    // context.subscriptions.push(disposable);
}
exports.activate = activate;
function deactivate() { }
exports.deactivate = deactivate;
//# sourceMappingURL=extension.js.map
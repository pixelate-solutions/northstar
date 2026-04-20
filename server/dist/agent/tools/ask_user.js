"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.askUser = askUser;
async function askUser(args) {
    const question = args.question;
    return {
        observation: `Asking user: ${question}`,
        question,
        terminal: true,
    };
}

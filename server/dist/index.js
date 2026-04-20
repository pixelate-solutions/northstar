"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const fastify_1 = __importDefault(require("fastify"));
const account_1 = require("./routes/account");
const health_1 = require("./routes/health");
const runs_1 = require("./routes/runs");
const app = (0, fastify_1.default)({ logger: true });
app.register(health_1.healthRoutes);
app.register(account_1.accountRoutes);
app.register(runs_1.runRoutes);
const port = Number(process.env.PORT ?? 8080);
const host = '0.0.0.0';
app.listen({ port, host }, (err) => {
    if (err) {
        app.log.error(err);
        process.exit(1);
    }
});

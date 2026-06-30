// Edge-function entry point. The request handler lives in `app.ts` so it can be
// unit-tested without binding a socket (CI runs `deno test` with no `--allow-net`);
// here we just bind it to the runtime. Keep this file a thin shell — all routing,
// CORS, error-envelope and observability logic is in `app.ts`.
import { handleRequest } from "./app.ts";

Deno.serve((req) => handleRequest(req));

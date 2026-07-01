// Deployed-build revision, surfaced on `GET /health` so smoke checks can verify
// exactly which commit is live (Phase B: "add build/version metadata to /health").
//
// Resolution order (all lookups are DEFENSIVE — a missing permission or file must
// never break the handler or the `deno test` suite, which runs without
// `--allow-env`/`--allow-read`):
//   1. env  AKSHARA_BUILD_SHA / AKSHARA_BUILD_TIME  (set on the container)
//   2. file ./build_info.json                       (written next to this module
//      at deploy time by the deploy step; travels with the bind-mounted code)
//   3. "unknown"                                     (local dev / non-deployed)
//
// The result is cached after the first call, so `/health` stays cheap.

export interface BuildInfo {
  version: string;
  builtAt: string | null;
}

let cached: BuildInfo | null = null;

export function buildInfo(): BuildInfo {
  if (cached) return cached;

  let version = "unknown";
  let builtAt: string | null = null;

  // 1) Environment (preferred — set explicitly on the edge container).
  try {
    const sha = Deno.env.get("AKSHARA_BUILD_SHA");
    if (sha && sha.trim()) version = sha.trim();
    const at = Deno.env.get("AKSHARA_BUILD_TIME");
    if (at && at.trim()) builtAt = at.trim();
  } catch {
    // No --allow-env (e.g. `deno test`): fall through to the file/default.
  }

  // 2) Colocated build_info.json written at deploy time.
  if (version === "unknown") {
    try {
      const raw = Deno.readTextFileSync(
        new URL("./build_info.json", import.meta.url),
      );
      const parsed = JSON.parse(raw) as Partial<BuildInfo>;
      if (typeof parsed.version === "string" && parsed.version) {
        version = parsed.version;
      }
      if (typeof parsed.builtAt === "string" && parsed.builtAt) {
        builtAt = parsed.builtAt;
      }
    } catch {
      // No file / no --allow-read: keep "unknown".
    }
  }

  cached = { version, builtAt };
  return cached;
}

"""Question Paper Generation Engine — CLI.

Reads the local certified KIE (knowledge/kie/kie.db) READ-ONLY. Deterministic; AI is never
invoked unless --allow-ai-fill AND KIE_AI_AUTHORIZED=1 (and a governed provider is wired).

  python -m kie.qpgen.cli generate --exam NEET --subjects Physics,Chemistry \
      --blueprint objective_45 --seed 1 --format md --out paper.md
  python -m kie.qpgen.cli scope   --exam NEET --subjects Biology
  python -m kie.qpgen.cli presets
"""
from __future__ import annotations

import argparse
import json
import sys

from kie.qpgen import presets, scope as scope_mod
from kie.qpgen.engine import QpGenError, QuestionPaperEngine, _open_ro
from kie.qpgen.models import PaperRequest
from kie.qpgen.scope import ScopeError
from kie import config


def _request(args) -> PaperRequest:
    subjects = tuple(s.strip() for s in (args.subjects or "").split(",") if s.strip())
    chapters = tuple(s.strip() for s in (getattr(args, "chapters", "") or "").split(",") if s.strip())
    return PaperRequest(exam=args.exam, board=args.board, class_label=args.class_label,
                        subjects=subjects, chapters=chapters,
                        blueprint_preset=getattr(args, "blueprint", None),
                        title=getattr(args, "title", None), seed=getattr(args, "seed", 0),
                        allow_ai_fill=getattr(args, "allow_ai_fill", False))


def cmd_generate(args) -> int:
    eng = QuestionPaperEngine(db_path=args.db or config.DB_PATH)
    try:
        paper = eng.generate(_request(args))
    except (ScopeError, QpGenError) as exc:
        print(f"cannot generate: {exc}", file=sys.stderr)
        return 2
    out = eng.render_markdown(paper) if args.format == "md" else json.dumps(eng.render_json(paper), indent=2)
    if args.out:
        open(args.out, "w").write(out)
        print(f"wrote {args.out}  ({paper.total_questions} questions, {paper.total_marks} marks, "
              f"{paper.filled} filled / {paper.spec_only} spec)")
    else:
        print(out)
    return 0


def cmd_scope(args) -> int:
    conn = _open_ro(args.db or config.DB_PATH)
    try:
        sc = scope_mod.resolve_scope(conn, _request(args))
        print(json.dumps(sc.stats, indent=2))
    except ScopeError as exc:
        print(f"scope error: {exc}", file=sys.stderr)
        return 2
    finally:
        conn.close()
    return 0


def cmd_presets(args) -> int:
    print(json.dumps({
        "exam_profiles": {k: {"subjects": list(v["subjects"]), "grade_band": v["grade_band"]}
                          for k, v in presets.EXAM_PROFILES.items()},
        "blueprints": sorted(presets.BLUEPRINT_PRESETS),
    }, indent=2))
    return 0


def _common(p):
    p.add_argument("--db", default=None, help="KIE store path (default: knowledge/kie/kie.db, read-only)")
    p.add_argument("--exam", default=None)
    p.add_argument("--board", default=None)
    p.add_argument("--class-label", default=None, dest="class_label")
    p.add_argument("--subjects", default=None, help="comma-separated subset")


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(prog="kie.qpgen", description="Question Paper Generation Engine")
    sub = ap.add_subparsers(dest="cmd", required=True)

    g = sub.add_parser("generate", help="generate a question paper")
    _common(g)
    g.add_argument("--chapters", default=None, help="comma-separated chapter/topic filters")
    g.add_argument("--blueprint", default=None, help="preset name (else profile default)")
    g.add_argument("--title", default=None)
    g.add_argument("--seed", type=int, default=0)
    g.add_argument("--format", default="md", choices=("md", "json"))
    g.add_argument("--out", default=None)
    g.add_argument("--allow-ai-fill", action="store_true", dest="allow_ai_fill",
                   help="opt into the GATED AI fill (also needs KIE_AI_AUTHORIZED=1)")
    g.set_defaults(func=cmd_generate)

    s = sub.add_parser("scope", help="preview the resolved syllabus scope")
    _common(s)
    s.add_argument("--chapters", default=None)
    s.set_defaults(func=cmd_scope)

    p = sub.add_parser("presets", help="list exam profiles + blueprint presets")
    p.set_defaults(func=cmd_presets)

    args = ap.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())

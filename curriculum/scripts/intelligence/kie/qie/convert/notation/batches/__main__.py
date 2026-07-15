"""CLI entry: `python -m kie.qie.convert.notation.batches [batch] [--register]`."""
import sys

from kie.qie.convert.notation.batches import _main

raise SystemExit(_main(sys.argv[1:]))

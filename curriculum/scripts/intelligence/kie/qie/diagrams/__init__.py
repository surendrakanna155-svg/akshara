"""Certified Diagram Knowledge — a diagram is knowledge, not a pixel copy.

Deterministic, source-grounded figure catalog built from the born-digital source PDFs + the frozen chunk
index. Reads original PDFs (no re-OCR, no re-parse) and kie.db (read-only); writes only the derived
figure_catalog.db. Future-ready for SVG / labels / regions / arrows / axes without touching chunk structure.
"""

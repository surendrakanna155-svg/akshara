"""Question-Corpus STAGING lane — loss-minimising, isolated, resumable extraction.

RAW DOCUMENT -> LOSS-MINIMISING EXTRACTION -> STRUCTURED STAGING CORPUS. Non-certified,
non-production. Reuses kie.phase2_parse as the extraction primitive; never writes kie.db.
"""

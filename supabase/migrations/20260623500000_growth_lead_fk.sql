-- v11.4: Link growth inquiries to admissions leads for conversion tracking.
ALTER TABLE growth_inquiries
  ADD CONSTRAINT growth_inquiries_lead_id_fkey
  FOREIGN KEY (lead_id) REFERENCES admissions_leads (id)
  ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_growth_inquiries_lead
  ON growth_inquiries (lead_id)
  WHERE lead_id IS NOT NULL;

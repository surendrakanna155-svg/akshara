-- Batch 2 (real, safe login): support per-IP OTP rate limiting and delivery
-- auditing. Additive and nullable — safe to apply to a live otp_requests table.

ALTER TABLE otp_requests
  ADD COLUMN IF NOT EXISTS ip_address INET,
  ADD COLUMN IF NOT EXISTS delivery_channel TEXT;

-- Per-IP sliding-window counts during login throttling.
CREATE INDEX IF NOT EXISTS idx_otp_requests_ip_created
  ON otp_requests (ip_address, created_at DESC);

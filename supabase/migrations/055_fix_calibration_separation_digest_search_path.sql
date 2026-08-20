-- 055 — allow the calibration-separation guard to resolve pgcrypto digest safely.
ALTER FUNCTION public.nrfim_enforce_calibration_separation_v15()
SET search_path TO 'public','extensions','pg_temp';

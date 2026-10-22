.PHONY: e2e-backend

e2e-backend:
	powershell -NoProfile -ExecutionPolicy Bypass -File ./scripts/run_e2e.ps1

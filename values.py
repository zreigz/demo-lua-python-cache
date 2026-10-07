# Dynamic helm values (python phase).
# Copied to chart root by scripts/migrate-to-python.sh
values["engine"] = "python"
values["message"] = "rendered-by-python"
values["replicaCount"] = 3

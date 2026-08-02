# Emergency stop: create .claude\stop_now to bypass immediately
if (Test-Path ".claude\stop_now") {
    Remove-Item ".claude\stop_now" -Force
    exit 0
}

# Normal completion: Claude creates .claude\task_done when fully done
if (Test-Path ".claude\task_done") {
    Remove-Item ".claude\task_done" -Force
    exit 0
}

Write-Output "Task not yet complete. Keep working until the goal is fully achieved. When done, create the file '.claude\task_done' to allow stopping. For emergency stop, create '.claude\stop_now'."
exit 2

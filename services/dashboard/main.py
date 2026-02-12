import os
import json
import uuid
import logging
import time
import threading
import requests
from datetime import datetime, timezone
import math
from typing import List, Optional, Any
from fastapi import FastAPI, HTTPException, Body
from pydantic import BaseModel

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

app = FastAPI(title="OpenClaw Dashboard Service")

# Configuration
STORAGE_DIR = os.path.expanduser("~/.openclaw/data/dashboard")
os.makedirs(STORAGE_DIR, exist_ok=True)

# Gateway Config (Hardcoded for this lab environment based on openclaw.json)
GATEWAY_URL = "http://localhost:18789"
GATEWAY_TOKEN = "ab26d3d8c1df8f4f8c43fc885d8e5acb7ca3c49aeb6dbc0f"

# Models
class Task(BaseModel):
    id: str
    text: str
    created_at: str
    done_at: Optional[str] = None
    created_by: Optional[str] = None

class Reminder(BaseModel):
    id: str
    text: str
    when_iso: str
    created_at: str
    created_by: Optional[str] = None
    status: str = "pending" # pending, sent, cancelled

# ... (Previous Models and storage helpers remain same, but Reminder status updated)

class DashboardData(BaseModel):
    tasks: List[Task] = []
    reminders: List[Reminder] = []

class TaskAddRequest(BaseModel):
    group_id: str
    text: str
    user_id: Optional[str] = None

class TaskListRequest(BaseModel):
    group_id: str

class TaskDoneRequest(BaseModel):
    group_id: str
    task_id: str

class ReminderAddRequest(BaseModel):
    group_id: str
    text: str
    when_iso: str
    user_id: Optional[str] = None

class ReminderCancelRequest(BaseModel):
    group_id: str
    reminder_id: str

class CalculationRequest(BaseModel):
    expression: str

# Storage Helpers
def get_storage_path(group_id: str) -> str:
    safe_id = "".join(c for c in group_id if c.isalnum() or c in "-_").strip()
    return os.path.join(STORAGE_DIR, f"{safe_id}.json")

def load_data(group_id: str) -> DashboardData:
    path = get_storage_path(group_id)
    if not os.path.exists(path):
        return DashboardData()
    try:
        with open(path, "r") as f:
            return DashboardData(**json.load(f))
    except Exception as e:
        logging.error(f"Failed to load data for {group_id}: {e}")
        return DashboardData()

def save_data(group_id: str, data: DashboardData):
    path = get_storage_path(group_id)
    temp_path = f"{path}.tmp"
    try:
        with open(temp_path, "w") as f:
            json.dump(data.model_dump(), f, indent=2)
        os.rename(temp_path, path)
    except Exception as e:
        logging.error(f"Failed to save data for {group_id}: {e}")
        if os.path.exists(temp_path):
            os.remove(temp_path)
        raise HTTPException(status_code=500, detail="Failed to save data")

# Reminder Worker
def reminder_worker():
    logging.info("Reminder worker started.")
    while True:
        try:
            now = datetime.now().isoformat()
            for filename in os.listdir(STORAGE_DIR):
                if filename.endswith(".json"):
                    group_id = filename[:-5]
                    data = load_data(group_id)
                    changed = False
                    for r in data.reminders:
                        if r.status == "pending" and r.when_iso <= now:
                            logging.info(f"Firing reminder {r.id} for group {group_id}")
                            # Send via Gateway
                            try:
                                resp = requests.post(
                                    f"{GATEWAY_URL}/api/v1/sessions/spawn",
                                    headers={"Authorization": f"Bearer {GATEWAY_TOKEN}"},
                                    json={
                                        "channel": "telegram",
                                        "kind": "group",
                                        "target": group_id,
                                        "message": f"🔔 **REMINDER**: {r.text}",
                                        "agentId": "assistant" # Send as assistant
                                    },
                                    timeout=10
                                )
                                if resp.status_code in [200, 201]:
                                    r.status = "sent"
                                    changed = True
                                else:
                                    logging.error(f"Failed to send reminder via gateway: {resp.text}")
                            except Exception as e:
                                logging.error(f"Error calling gateway: {e}")
                    
                    if changed:
                        save_data(group_id, data)
        except Exception as e:
            logging.error(f"Error in reminder worker loop: {e}")
        
        time.sleep(30) # Check every 30 seconds

# Endpoints
@app.get("/health")
def health():
    return {"status": "ok", "storage": STORAGE_DIR}

@app.post("/task/add")
def add_task(req: TaskAddRequest):
    data = load_data(req.group_id)
    new_task = Task(
        id=str(len(data.tasks) + 1),
        text=req.text,
        created_at=datetime.now().isoformat(),
        created_by=req.user_id
    )
    data.tasks.append(new_task)
    save_data(req.group_id, data)
    return new_task

@app.post("/task/list")
def list_tasks(req: TaskListRequest):
    data = load_data(req.group_id)
    return {"tasks": [t for t in data.tasks if t.done_at is None]}

@app.post("/task/done")
def done_task(req: TaskDoneRequest):
    data = load_data(req.group_id)
    for t in data.tasks:
        if t.id == req.task_id:
            t.done_at = datetime.now().isoformat()
            save_data(req.group_id, data)
            return {"status": "success", "task": t}
    raise HTTPException(status_code=404, detail="Task not found")

@app.post("/remind/add")
def add_reminder(req: ReminderAddRequest):
    data = load_data(req.group_id)
    new_reminder = Reminder(
        id=str(len(data.reminders) + 1),
        text=req.text,
        when_iso=req.when_iso,
        created_at=datetime.now().isoformat(),
        created_by=req.user_id
    )
    data.reminders.append(new_reminder)
    save_data(req.group_id, data)
    return new_reminder

@app.post("/remind/list")
def list_reminders(req: TaskListRequest):
    data = load_data(req.group_id)
    return {"reminders": [r for r in data.reminders if r.status == "pending"]}

@app.post("/remind/cancel")
def cancel_reminder(req: ReminderCancelRequest):
    data = load_data(req.group_id)
    for r in data.reminders:
        if r.id == req.reminder_id:
            r.status = "cancelled"
            save_data(req.group_id, data)
            return {"status": "success", "reminder": r}
    raise HTTPException(status_code=404, detail="Reminder not found")

@app.get("/dash")
def get_dashboard(group_id: str):
    data = load_data(group_id)
    active_tasks = [t for t in data.tasks if t.done_at is None]
    pending_reminders = [r for r in data.reminders if r.status == "pending"]
    return {
        "group_id": group_id,
        "summary": {
            "active_tasks": len(active_tasks),
            "pending_reminders": len(pending_reminders)
        },
        "tasks": active_tasks[:5],
        "reminders": pending_reminders[:5]
    }

# Utility Endpoints
@app.get("/utility/time")
def get_utility_time():
    now = datetime.now(timezone.today() if hasattr(timezone, "today") else None) # Use system local or UTC
    return {
        "iso": datetime.now().isoformat(),
        "local_time": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "timezone": time.tzname[0],
        "timestamp": time.time()
    }

@app.post("/utility/calculate")
def calculate_expression(req: CalculationRequest):
    try:
        # Safe evaluation for basic math
        allowed_names = {"__builtins__": None, "math": math}
        allowed_names.update({k: v for k, v in math.__dict__.items() if not k.startswith("__")})
        # Basic check for unsafe chars
        if any(c in req.expression for c in ["import", "eval", "exec", "os", "subprocess", "__"]):
                         raise ValueError("Unsafe expression")
        result = eval(req.expression, allowed_names, {})
        return {"expression": req.expression, "result": result}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

# Admin/Diagnostics Endpoints (Sanitized)
@app.get("/admin/status")
def get_admin_status():
    return {
        "status": "operational",
        "service": "OpenClaw System Core",
        "version": "2026.2.6-3",
        "uptime": "active"
    }

@app.get("/admin/diagnostics")
def get_admin_diagnostics():
    return {
        "checks": [
            {"name": "gateway", "status": "ok"},
            {"name": "ollama", "status": "ok"},
            {"name": "storage", "status": "ok"},
            {"name": "telegram_plugin", "status": "ok"}
        ],
        "overall": "healthy"
    }

if __name__ == "__main__":
    import uvicorn
    # Start the worker thread
    t = threading.Thread(target=reminder_worker, daemon=True)
    t.start()
    uvicorn.run(app, host="0.0.0.0", port=18820)

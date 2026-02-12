import os
import datetime
import json
from typing import List, Optional
from fastapi import FastAPI, HTTPException, Query
from pydantic import BaseModel
from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError
from dateutil import tz
from dateutil.relativedelta import relativedelta

app = FastAPI(title="OpenClaw Calendar Service")

# If modifying these scopes, delete the file token.json.
SCOPES = ["https://www.googleapis.com/auth/calendar.readonly"]

SECRETS_DIR = os.path.expanduser("~/.openclaw/secrets")
TOKEN_PATH = os.path.join(SECRETS_DIR, "google_calendar_token.json")
CLIENT_SECRET_PATH = os.path.join(SECRETS_DIR, "google_client_secret.json")

def get_local_tz():
    return tz.tzlocal()

def get_calendar_service():
    creds = None
    if os.path.exists(TOKEN_PATH):
        creds = Credentials.from_authorized_user_file(TOKEN_PATH, SCOPES)
    
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            if not os.path.exists(CLIENT_SECRET_PATH):
                raise HTTPException(
                    status_code=401, 
                    detail="Auth required. Please place google_client_secret.json in ~/.openclaw/secrets/ and run setup."
                )
            
            # Auth flow logic would go here, but for automated service 
            # we expect the token to be present.
            raise HTTPException(
                status_code=401,
                detail="Token missing or invalid. Please run the setup command to authorize."
            )
        
        with open(TOKEN_PATH, "w") as token:
            token.write(creds.to_json())
            os.chmod(TOKEN_PATH, 0o600)

    return build("calendar", "v3", credentials=creds)

class Event(BaseModel):
    id: str
    summary: str
    start: str
    end: str
    location: Optional[str] = None

@app.get("/health")
def health():
    return {
        "status": "ok",
        "auth_ready": os.path.exists(TOKEN_PATH),
        "secrets_ready": os.path.exists(CLIENT_SECRET_PATH),
        "timezone": str(get_local_tz())
    }

@app.post("/list")
def list_events(
    range: str = Query(..., enum=["today", "week", "next"]),
    max_results: int = 10
):
    try:
        service = get_calendar_service()
        local_tz = get_local_tz()
        now = datetime.datetime.now(local_tz)
        
        if range == "today":
            time_min = now.replace(hour=0, minute=0, second=0, microsecond=0).isoformat()
            time_max = now.replace(hour=23, minute=59, second=59, microsecond=999999).isoformat()
        elif range == "week":
            time_min = now.isoformat()
            time_max = (now + datetime.timedelta(days=7)).isoformat()
        else: # next
            time_min = now.isoformat()
            time_max = None
            
        events_result = service.events().list(
            calendarId="primary",
            timeMin=time_min,
            timeMax=time_max,
            maxResults=max_results,
            singleEvents=True,
            orderBy="startTime"
        ).execute()
        
        events = events_result.get("items", [])
        return {"events": [_format_event(e) for e in events]}
    except HTTPException as he:
        raise he
    except HttpError as error:
        raise HTTPException(status_code=500, detail=f"Google API Error: {error}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/search")
def search_events(query: str = Query(...), max_results: int = 10):
    try:
        service = get_calendar_service()
        events_result = service.events().list(
            calendarId="primary",
            q=query,
            maxResults=max_results,
            singleEvents=True,
            orderBy="startTime"
        ).execute()
        
        events = events_result.get("items", [])
        return {"events": [_format_event(e) for e in events]}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

def _format_event(e):
    # Privacy minimization: start, end, title (summary), location
    return {
        "title": e.get("summary", "No Summary"),
        "start": e.get("start").get("dateTime") or e.get("start").get("date"),
        "end": e.get("end").get("dateTime") or e.get("end").get("date"),
        "location": e.get("location")
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=18821)

#!/usr/bin/env python3
import sys
import requests
import os

RAG_URL = "http://localhost:18791"

def ingest(path, tags=[]):
    abs_path = os.path.abspath(path)
    # The service expects the path relative to its own /data/documents mount
    # For simplicity in this home lab, we assume the user provides a path reachable by the container
    data = {
        "path": path,
        "tags": tags
    }
    response = requests.post(f"{RAG_URL}/ingest", json=data)
    print(response.json())

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: ingest.py <path_to_file_or_dir> [tag1,tag2,...]")
        sys.exit(1)
    
    path = sys.argv[1]
    tags = sys.argv[2].split(",") if len(sys.argv) > 2 else []
    ingest(path, tags)

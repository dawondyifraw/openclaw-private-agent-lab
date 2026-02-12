import os
import requests
from typing import List, Optional
from fastapi import FastAPI, HTTPException, Body
from pydantic import BaseModel
import chromadb
from chromadb.config import Settings
from langchain_text_splitters import RecursiveCharacterTextSplitter

app = FastAPI(title="OpenClaw RAG Service")

# Configuration
CHROMA_HOST = os.getenv("CHROMA_HOST", "chroma")
CHROMA_PORT = int(os.getenv("CHROMA_PORT", "8000"))
OLLAMA_HOST = os.getenv("OLLAMA_HOST", "ollama")
OLLAMA_PORT = int(os.getenv("OLLAMA_PORT", "11434"))
EMBED_MODEL = os.getenv("EMBED_MODEL", "nomic-embed-text")

# Initialize Chroma client
client = chromadb.HttpClient(host=CHROMA_HOST, port=CHROMA_PORT)
collection = client.get_or_create_collection(name="openclaw_knowledge")

class IngestRequest(BaseModel):
    path: str
    tags: Optional[List[str]] = []

class QueryRequest(BaseModel):
    query: str
    top_k: Optional[int] = 3
    filters: Optional[dict] = None

def get_embeddings(text: str) -> List[float]:
    url = f"http://{OLLAMA_HOST}:{OLLAMA_PORT}/api/embeddings"
    response = requests.post(url, json={"model": EMBED_MODEL, "prompt": text})
    if response.status_code != 200:
        raise HTTPException(status_code=500, detail="Failed to get embeddings from Ollama")
    return response.json()["embedding"]

@app.get("/health")
def health():
    try:
        client.heartbeat()
        return {"status": "ok", "chroma": "connected", "ollama": f"http://{OLLAMA_HOST}:{OLLAMA_PORT}"}
    except Exception as e:
        return {"status": "error", "detail": str(e)}

@app.post("/ingest")
def ingest(request: IngestRequest):
    if not os.path.exists(request.path):
        raise HTTPException(status_code=404, detail="File or directory not found")
    
    documents = []
    if os.path.isdir(request.path):
        for root, _, files in os.walk(request.path):
            for file in files:
                if file.endswith((".txt", ".md", ".json")):
                    documents.append(os.path.join(root, file))
    else:
        documents.append(request.path)

    text_splitter = RecursiveCharacterTextSplitter(chunk_size=1000, chunk_overlap=100)
    
    total_chunks = 0
    for doc_path in documents:
        with open(doc_path, "r", encoding="utf-8") as f:
            content = f.read()
            chunks = text_splitter.split_text(content)
            
            ids = [f"{doc_path}_{i}" for i in range(len(chunks))]
            embeddings = [get_embeddings(chunk) for chunk in chunks]
            metadatas = [{"source": doc_path, "tags": ",".join(request.tags or [])} for _ in chunks]
            
            collection.add(
                ids=ids,
                embeddings=embeddings,
                documents=chunks,
                metadatas=metadatas
            )
            total_chunks += len(chunks)
            
    return {"status": "success", "files_processed": len(documents), "total_chunks": total_chunks}

@app.post("/query")
def query(request: QueryRequest):
    query_embedding = get_embeddings(request.query)
    
    results = collection.query(
        query_embeddings=[query_embedding],
        n_results=request.top_k,
        where=request.filters
    )
    
    formatted_results = []
    for i in range(len(results["ids"][0])):
        formatted_results.append({
            "id": results["ids"][0][i],
            "document": results["documents"][0][i],
            "metadata": results["metadatas"][0][i],
            "distance": results["distances"][0][i]
        })
        
    return {"query": request.query, "results": formatted_results}

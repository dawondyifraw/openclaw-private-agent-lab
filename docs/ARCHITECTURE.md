# OpenClaw System Architecture

This diagram visualizes the logical and physical architecture of the OpenClaw Home Lab, illustrating the relationships between agents, model providers, support services, and persistent storage.

\`\`\`mermaid
graph TD
    %% Nodes
    subgraph "Host (Systemd)"
        Gateway[OpenClaw Gateway<br/>(Port 18789)]
        MainAgent[Main Agent<br/>(Orchestrator)]
        SubAgents[Sub-Agents<br/>(Coder, Moltd, etc.)]
    end

    subgraph "Docker Support Services"
        Ollama[Ollama<br/>(Local LLM Inference)]
        Chroma[ChromaDB<br/>(Vector Store)]
        RAG[RAG Service<br/>(FastAPI)]
        Amharic[Amharic Middleware<br/>(Translation)]
        Redis[Redis<br/>(Cache)]
        Mongo[MongoDB<br/>(Session State)]
    end

    subgraph "External Cloud Providers"
        Google[Google Gemini<br/>(Primary)]
        Kimi[Kimi (Moonshot)<br/>(Fallback #1)]
        Groq[Groq Llama<br/>(Fallback #2)]
        OpenRouter[OpenRouter<br/>(Fallback #3)]
    end

    subgraph "Persistent Storage (Volumes)"
        VolOllama[(ollama_models)]
        VolChroma[(chroma_data)]
        VolMongo[(mongo_data)]
    end

    %% Relationships
    Gateway --> MainAgent
    Gateway --> SubAgents
    
    MainAgent -- Routing --> SubAgents
    MainAgent -- "Primary" --> Google
    MainAgent -- "Fallback" --> Kimi
    MainAgent -- "Fallback" --> Groq
    MainAgent -- "Fallback" --> OpenRouter
    MainAgent -- "Final Fallback" --> Ollama

    SubAgents -- "Default" --> Ollama
    
    MainAgent -- "RAG Query" --> RAG
    RAG -- "Vector Search" --> Chroma
    RAG -- "Embeddings" --> Ollama
    
    Gateway -- "Translation" --> Amharic
    
    %% Persistence
    Ollama -.-> VolOllama
    Chroma -.-> VolChroma
    Mongo -.-> VolMongo
    
    %% Styles
    style Google fill:#e8f0fe,stroke:#4285f4,stroke-width:2px
    style Kimi fill:#e8f0fe,stroke:#4285f4,stroke-width:2px
    style Groq fill:#e8f0fe,stroke:#4285f4,stroke-width:2px
    style OpenRouter fill:#e8f0fe,stroke:#4285f4,stroke-width:2px
    style Ollama fill:#e6fffa,stroke:#38b2ac,stroke-width:2px
    
    note_storage[ Persistence critical:<br/>Do NOT prune these volumes ]
    note_storage -.-> VolOllama
    note_storage -.-> VolChroma
\`\`\`

## Key Components

1.  **Host-Based Agents**: The core OpenClaw runtime executes agents directly on the host via Systemd. The `Main Agent` acts as the orchestrator, routing tasks to specialized sub-agents.
2.  **Model Hierarchy**: 
    *   **Cloud First**: The Main Agent prioritizes Google Gemini, failing over to Kimi, Groq, and OpenRouter.
    *   **Local Fallback**: If all cloud providers fail, the system falls back to the local Ollama instance.
    *   **Local Default**: Sub-agents default to local execution via Ollama for cost efficiency and privacy.
3.  **Support Services**: Docker containers provide specialized capabilities (RAG, Vector Search, Translation) without executing agent logic directly.
4.  **Persistence**: Critical data (LLM weights, Vector Indexes, Session History) is stored in protected Docker volumes that persist across container restarts.

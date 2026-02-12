FROM python:3.9-slim

WORKDIR /app

RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

COPY services/rag-service/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY services/rag-service/main.py .

EXPOSE 18791

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "18791"]

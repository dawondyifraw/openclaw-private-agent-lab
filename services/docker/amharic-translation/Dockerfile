FROM python:3.9-slim

WORKDIR /app

RUN pip install --no-cache-dir flask requests

COPY services/amharic-translation /app

EXPOSE 18790

HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
  CMD curl -f http://localhost:18790/health || exit 1

CMD ["python3", "amharic_translation_service.py"]

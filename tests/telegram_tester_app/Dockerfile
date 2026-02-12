# Use Python 3.11 slim image
FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    make \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN useradd -m -u 1000 -s /bin/bash botrunner && \
    chown -R botrunner:botrunner /app

# Copy requirements first for better caching
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application files
COPY --chown=botrunner:botrunner . .

# Create necessary directories
RUN mkdir -p /app/test_reports /app/sessions && \
    chown -R botrunner:botrunner /app/test_reports /app/sessions

# Switch to non-root user
USER botrunner

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    TZ=UTC

# Default command
CMD ["python", "telegram_test_automation.py"]
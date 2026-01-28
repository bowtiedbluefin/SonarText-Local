FROM python:3.11-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN pip install --no-cache-dir \
    torch==2.4.1 torchaudio==2.4.1 --index-url https://download.pytorch.org/whl/cpu

RUN pip install --no-cache-dir \
    whisperx==3.3.2 \
    fastapi==0.115.0 \
    uvicorn[standard]==0.32.0 \
    python-multipart==0.0.12 \
    requests \
    matplotlib \
    pillow

COPY server.py .

EXPOSE 9000

ENV PYTHONUNBUFFERED=1
ENV HF_HOME=/app/.cache/huggingface

RUN mkdir -p /app/.cache/huggingface

CMD ["uvicorn", "server:app", "--host", "0.0.0.0", "--port", "9000"]

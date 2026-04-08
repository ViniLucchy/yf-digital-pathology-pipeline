# Multi-stage Dockerfile for YF digital pathology pipeline (LazySlide + Slideflow + nnU-Net)
# Build: DOCKER_BUILDKIT=1 docker build -t yf-pathology .
FROM python:3.13-slim AS builder

COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

ENV PYTHONUNBUFFERED=1 \
    PYTORCH_ENABLE_MPS_FALLBACK=1 \
    DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    default-jdk \
    build-essential \
    git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY pyproject.toml uv.lock README.md ./
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --extra all --no-install-project

# Nossas dependências específicas
RUN --mount=type=cache,target=/root/.cache/uv \
    uv pip install slideflow monai==1.4.* nnunetv2 torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128 \
    huggingface-hub timm

COPY src/ ./src/
RUN --mount=type=cache,target=/root/.cache/uv \
    uv build --wheel && uv pip install dist/*.whl

FROM python:3.13-slim AS runtime
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/

RUN apt-get update && apt-get install -y --no-install-recommends \
    default-jre-headless \
    libgl1 \
    libglib2.0-0 \
    libgomp1 \
    && rm -rf /var/lib/apt/lists/*

ENV PYTHONUNBUFFERED=1 \
    PATH="/app/.venv/bin:$PATH"

WORKDIR /app
COPY --from=builder /app/.venv /app/.venv

CMD ["/bin/bash"]

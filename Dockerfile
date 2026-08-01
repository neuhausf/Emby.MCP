# syntax=docker/dockerfile:1

# Emby.MCP – Docker image
# Runs the MCP server over SSE transport on port 12345.
#
# Build:  docker build -t emby-mcp .
# Run:    docker run -d -p 12345:12345 -v "$(pwd)/.env:/app/.env:ro" --name emby-mcp emby-mcp

FROM ghcr.io/astral-sh/uv:python3.13-bookworm-slim

# ── Environment ──────────────────────────────────────────────────────────────
ENV UV_PYTHON=python3.13 \
    UV_PYTHON_PREFERENCE=only-managed \
    # Keep bytecode out of the image layers
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# ── Dependencies ─────────────────────────────────────────────────────────────
# Copy only the files needed to resolve & install deps first (better layer caching).
COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --link-mode=copy --no-install-project

# ── Application source ────────────────────────────────────────────────────────
COPY emby_mcp_server.py lib_emby_functions.py lib_emby_debugging.py ./
COPY hotfixes/ hotfixes/

# ── Hotfix patches ────────────────────────────────────────────────────────────
# The Emby client SDK shipped on PyPI has minor bugs that prevent Emby.MCP from
# working correctly.  Apply the in-repo patches until an upstream fix is released.
RUN cp "hotfixes/emby/configuration.py" \
       ".venv/lib/python3.13/site-packages/emby_client/" && \
    cp "hotfixes/emby/user_service_api.py" \
       ".venv/lib/python3.13/site-packages/emby_client/api/"

# ── Non-root user ─────────────────────────────────────────────────────────────
RUN useradd --create-home --shell /bin/bash appuser \
    && chown -R appuser:appuser /app
USER appuser

# ── Runtime ───────────────────────────────────────────────────────────────────
EXPOSE 12345

# Credentials are expected via a .env file mounted at /app/.env at runtime.
# The .env file must NOT be baked into the image.
# Uses the MCP CLI to start the server with SSE transport so that MCP clients
# can connect over HTTP instead of stdio.
CMD ["uv", "run", "mcp", "run", "--transport", "sse", "--host", "0.0.0.0", "--port", "12345", "emby_mcp_server.py"]

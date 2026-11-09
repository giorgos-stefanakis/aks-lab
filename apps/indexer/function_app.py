"""Azure Functions entry point (Python v2 model). HTTP triggers only."""

import json

import azure.functions as func
from indexer.chunking import split_text
from indexer.settings import ConfigError, load_settings

app = func.FunctionApp(http_auth_level=func.AuthLevel.ANONYMOUS)
settings = load_settings()


def _json(body: dict, status: int = 200) -> func.HttpResponse:
    return func.HttpResponse(json.dumps(body), status_code=status, mimetype="application/json")


@app.route(route="index", methods=["POST"])
def index(req: func.HttpRequest) -> func.HttpResponse:
    """Split the posted document into chunks and return the count."""
    try:
        payload = req.get_json()
    except ValueError:
        payload = None
    text = payload.get("text") if isinstance(payload, dict) else None
    if not isinstance(text, str) or not text:
        return _json({"error": "body must be JSON with a non-empty 'text'"}, 400)
    try:
        size, overlap = settings.chunking()
    except ConfigError as error:
        return _json({"error": str(error)}, 503)
    return _json({"chunks": len(split_text(text, size, overlap)), "chunk_size": size, "chunk_overlap": overlap})


@app.route(route="health", methods=["GET"])
def health(req: func.HttpRequest) -> func.HttpResponse:
    """Report liveness and readiness."""
    return _json({"status": "ok"})

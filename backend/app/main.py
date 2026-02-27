import time
from collections import defaultdict, deque

from fastapi import FastAPI, UploadFile, File, HTTPException, Request
from starlette.responses import JSONResponse
from app.comparison import compare_xml
from app.schema_explorer import get_schema_summary, get_schema_tree
from app.validation import validate_xml

app = FastAPI()

MAX_UPLOAD_BYTES = 5 * 1024 * 1024
RATE_LIMIT_WINDOW_SECONDS = 60
RATE_LIMIT_MAX_REQUESTS = 20
RATE_LIMITED_PATHS = {"/api/validate", "/api/compare"}
request_buckets: dict[str, deque[float]] = defaultdict(deque)


def get_client_key(request: Request) -> str:
    x_forwarded_for = request.headers.get("x-forwarded-for")
    if x_forwarded_for:
        return x_forwarded_for.split(",")[0].strip()
    if request.client and request.client.host:
        return request.client.host
    return "unknown"


@app.middleware("http")
async def apply_rate_limit(request: Request, call_next):
    if request.method == "POST" and request.url.path in RATE_LIMITED_PATHS:
        now = time.time()
        client_key = get_client_key(request)
        bucket = request_buckets[client_key]

        while bucket and now - bucket[0] > RATE_LIMIT_WINDOW_SECONDS:
            bucket.popleft()

        if len(bucket) >= RATE_LIMIT_MAX_REQUESTS:
            return JSONResponse(
                status_code=429,
                content={
                    "error": "rate_limit_exceeded",
                    "message": "Too many requests. Please retry shortly.",
                },
                headers={"Retry-After": str(RATE_LIMIT_WINDOW_SECONDS)},
            )

        bucket.append(now)

    return await call_next(request)

@app.post("/api/validate")
async def validate(file: UploadFile = File(...)):
    content = await file.read()
    if len(content) > MAX_UPLOAD_BYTES:
        raise HTTPException(status_code=413, detail="Uploaded file is too large.")
    result = validate_xml(content)
    return result


@app.post("/api/compare")
async def compare(xml1: UploadFile = File(...), xml2: UploadFile = File(...)):
    xml1_content = await xml1.read()
    xml2_content = await xml2.read()
    if len(xml1_content) > MAX_UPLOAD_BYTES or len(xml2_content) > MAX_UPLOAD_BYTES:
        raise HTTPException(status_code=413, detail="Uploaded file is too large.")
    result = compare_xml(xml1_content, xml2_content)
    return result


@app.get("/api/schema/summary")
async def schema_summary():
    return get_schema_summary()


@app.get("/api/schema/tree")
async def schema_tree():
    return get_schema_tree()
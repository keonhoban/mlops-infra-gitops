from fastapi import APIRouter, Response
from prometheus_client import Counter, Histogram, generate_latest

router = APIRouter()

REQUEST_COUNT = Counter("predict_requests_total", "Total requests", ["variant"])
ERROR_COUNT   = Counter("predict_errors_total", "Total errors", ["variant"])
LATENCY       = Histogram("predict_latency_seconds", "Latency (seconds)", ["variant"])

@router.get("/metrics")
def metrics():
    return Response(generate_latest(), media_type="text/plain")

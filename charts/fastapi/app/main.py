from fastapi import FastAPI
from prometheus_fastapi_instrumentator import Instrumentator

from core.config import settings
from core.startup import init_app_state
from routes import predict, reload, health, models, root, ready

app = FastAPI(title="FastAPI Triton Gateway", version="2.0.0")

Instrumentator().instrument(app).expose(app, endpoint="/metrics", include_in_schema=False)

@app.on_event("startup")
def _startup():
    init_app_state(app)

app.include_router(root.router)
app.include_router(health.router)
app.include_router(ready.router)
app.include_router(models.router)
app.include_router(reload.router)
app.include_router(predict.router)


# main.py
from fastapi import FastAPI
from core.config import settings
from core.startup import register_startup_event
from utils.logger import setup_logger
from routes import predict, reload, health, root, models
from prometheus_fastapi_instrumentator import Instrumentator

setup_logger()

app = FastAPI()

Instrumentator().instrument(app).expose(app, endpoint="/metrics", include_in_schema=False)

register_startup_event(app)

app.include_router(predict.router)
app.include_router(reload.router)
app.include_router(health.router)
app.include_router(root.router)
app.include_router(models.router)

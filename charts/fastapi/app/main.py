# main.py
from fastapi import FastAPI
from core.config import settings
from core.startup import register_startup_event
from utils.logger import setup_logger
from routes import predict, reload, health, root, models

setup_logger()

app = FastAPI()
register_startup_event(app)

app.include_router(predict.router)
app.include_router(reload.router)
app.include_router(health.router)
app.include_router(root.router)
app.include_router(models.router)

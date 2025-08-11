from loguru import logger

def setup_logger():
    logger.add(
        "/app/logs/fastapi.log",
        rotation="5 MB",
        retention="7 days",
        level="INFO",
        enqueue=True,
        backtrace=True,
        diagnose=True,
    )

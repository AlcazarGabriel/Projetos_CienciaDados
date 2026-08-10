FROM python:3.14

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

COPY requirements.txt /app/requirements.txt

RUN python -m pip install \
    --no-cache-dir \
    -r /app/requirements.txt

COPY api /app/api
COPY models /app/models

EXPOSE 8000

CMD ["python", "-m", "uvicorn", "api.main:app", "--host", "0.0.0.0", "--port", "8000"]
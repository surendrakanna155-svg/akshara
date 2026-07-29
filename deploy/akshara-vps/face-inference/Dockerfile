# NIKSHA OS — face embedding service.
#
# The model is NOT baked into the image. It is mounted at /models, so the image
# carries no biometric model weights and can be rebuilt/pushed without moving
# 63 MB of AuraFace around. See fetch_model.sh.
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    # Belt-and-braces: even if a worker were misconfigured, keep BLAS from
    # spawning its own thread pool and oversubscribing a 1-vCPU box.
    OMP_NUM_THREADS=1 \
    OPENBLAS_NUM_THREADS=1 \
    MKL_NUM_THREADS=1

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .

# Run unprivileged: this process handles biometric data and needs no root.
RUN useradd --system --uid 10001 --no-create-home niksha
USER niksha

EXPOSE 8080

# WORKERS = one per vCPU. Measured: N single-threaded workers scale ~linearly
# (3.50x at 4) while intra-op threads scale 1.86x at 4. Do not "optimise" this
# into fewer workers with more threads — that halves throughput.
ENV WORKERS=1
CMD ["sh", "-c", "exec uvicorn app:app --host 0.0.0.0 --port 8080 --workers ${WORKERS} --no-access-log"]

FROM python:3.11-slim AS deps

ENV PYTHONDONTWRITEBYTECODE=1 \
	PYTHONUNBUFFERED=1

WORKDIR /app

COPY requirements.txt ./requirements.txt
RUN python -m venv /opt/venv \
	&& /opt/venv/bin/pip install --upgrade pip \
	&& /opt/venv/bin/pip install -r requirements.txt

FROM deps AS schematron-build

ENV PYTHONDONTWRITEBYTECODE=1 \
	PYTHONUNBUFFERED=1 \
	PATH="/opt/venv/bin:$PATH"

ARG SCHEMATRON_INCLUDE_GLOB=
ARG SCHEMATRON_BASE_INCLUDE_GLOB=schematron/rules/*.sch

WORKDIR /app

COPY tools/compile_schematron.py tools/compile_schematron.py
COPY schematron/ schematron/
COPY tests/rules/ tests/rules/

RUN mkdir -p app/generated/schematron \
	&& if find schematron tests/rules -type f -name '*.sch' | grep -q .; then \
		python tools/compile_schematron.py \
			--source-dir . \
			--output-dir app/generated/schematron \
			--compiler-xsl schematron/schxslt2-1.9/transpile.xsl \
			${SCHEMATRON_BASE_INCLUDE_GLOB:+ --include-glob "$SCHEMATRON_BASE_INCLUDE_GLOB"} \
			${SCHEMATRON_INCLUDE_GLOB:+ --include-glob "$SCHEMATRON_INCLUDE_GLOB"} \
			; \
	else \
		echo "No .sch files found. Skipping Schematron compilation."; \
	fi

FROM python:3.11-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
	PYTHONUNBUFFERED=1 \
	PATH="/opt/venv/bin:$PATH"

WORKDIR /app

COPY --from=deps /opt/venv /opt/venv
COPY --from=schematron-build /app/app/generated/schematron app/generated/schematron

COPY app/ app/
COPY schema/ schema/

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]

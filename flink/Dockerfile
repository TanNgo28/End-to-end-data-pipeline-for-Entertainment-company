FROM python:3.12.12-slim-bookworm AS connectors
COPY flink/connectors.lock scripts/fetch_connectors.py /tmp/
RUN python /tmp/fetch_connectors.py /tmp/connectors.lock /connectors

FROM flink:2.2.1-scala_2.12-java21
COPY --from=connectors --chmod=0644 /connectors/ /opt/flink/lib/

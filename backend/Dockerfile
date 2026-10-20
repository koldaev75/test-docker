FROM python:3.12-alpine
RUN pip install --no-cache-dir "psycopg[binary]==3.2.*" "redis==5.*"
WORKDIR /app
COPY app.py .
RUN adduser -D -u 10001 app
USER app
EXPOSE 8080
CMD ["python", "-u", "app.py"]

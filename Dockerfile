FROM python:3.11-slim

# set working directory
WORKDIR /app

# install dependencies first (better docker layer caching)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# copy the rest of the code
COPY . .

# expose the port
EXPOSE 8000

# run the app
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]

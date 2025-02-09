# cmdb-viewer

## Server

Create .env file with next env vars

- ANTHROPIC_API_KEY

Add file.json to server folder with AWS information

Setup

```shell
cd server

# Install deps
python3.12 -m venv venv
. venv/bin/activate
pip3 install -r requirements.txt

# Run app
cd ..
uvicorn server.main:app

```

## Client

```shell
cd client

# Install deps
npm install

# Run app

# dev
npm run dev

# prod
npm run build
npm run preview

# Go to browser

# dev
http://localhost:5173/


```

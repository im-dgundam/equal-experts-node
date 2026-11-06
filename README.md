# Gists API Server

A lightweight HTTP API that returns a GitHub user's public Gists. Built with Node.js and Express.

---

## Requirements

| Tool | Minimum version |
|------|----------------|
| Node.js | 20 |
| npm | 10 |
| Docker | 24 (for container usage) |

---

## Running locally

```bash
# Install dependencies
npm install

# Start the server (listens on port 8080 by default)
npm start
```

Then query it:

```bash
curl http://localhost:8080/octocat
```

### Optional – GitHub token

The GitHub REST API allows 60 unauthenticated requests per hour per IP. To raise that limit, export a personal access token before starting the server:

```bash
export GITHUB_TOKEN=ghp_your_token_here
npm start
```

### Custom port

```bash
PORT=3000 npm start
```

---

## Running tests

```bash
npm test
```

Tests use [nock](https://github.com/nock/nock) to intercept HTTP calls, so no real network access is required.

---

## Docker

### Build

```bash
docker build -t gists-api-server .
```

### Run

```bash
docker run --rm -p 8080:8080 gists-api-server
```

With a GitHub token:

```bash
docker run --rm -p 8080:8080 -e GITHUB_TOKEN=ghp_your_token_here gists-api-server
```

Then:

```bash
curl http://localhost:8080/octocat
```

---

## API reference

### `GET /<user>`

Returns all public Gists for a GitHub user.

**Example response**

```json
{
  "user": "octocat",
  "total": 8,
  "gists": [
    {
      "id": "6cad326836d38bd3a7ae",
      "description": "Hello World",
      "url": "https://gist.github.com/octocat/6cad326836d38bd3a7ae",
      "api_url": "https://api.github.com/gists/6cad326836d38bd3a7ae",
      "public": true,
      "created_at": "2010-04-14T02:15:15Z",
      "updated_at": "2011-06-20T11:34:15Z",
      "files": ["hello_world.rb"],
      "comments": 0,
      "forks_url": "https://api.github.com/gists/6cad326836d38bd3a7ae/forks"
    }
  ]
}
```

**Status codes**

| Code | Meaning |
|------|---------|
| 200 | Success |
| 400 | Invalid GitHub username |
| 404 | GitHub user not found |
| 502 | Upstream GitHub API error |
| 500 | Internal server error |

### `GET /health`

Returns `{"status":"ok"}` — useful for container health checks.

---

## CI pipeline

A GitHub Actions workflow lives at `.github/workflows/ci.yml`. It runs on every push and pull request and has two jobs:

1. **Test** – installs deps with `npm ci` and runs the full Jest suite.
2. **Build** – runs only after tests pass; builds the Docker image with Buildx and layer caching (GitHub Actions cache). The image is **not** pushed to a registry, matching the submission requirement.

To also push to a registry (e.g. GHCR), add a `registry-login` step and set `push: true` on the build job, passing your registry credentials as repository secrets.

---

## Design notes

- **No external HTTP client** – uses Node's built-in `https` module to keep the production dependency footprint minimal (only Express).
- **Pagination** – fetches all pages automatically before responding, so the `total` count and `gists` array are always complete.
- **Auth** – an optional `GITHUB_TOKEN` env var is forwarded as a Bearer token to avoid GitHub's 60 req/hour unauthenticated rate limit.
- **Docker** – multi-stage build keeps the final image small; the app runs as a non-root user.

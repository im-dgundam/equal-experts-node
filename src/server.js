'use strict';

const express = require('express');
const https = require('https');

const app = express();

const GITHUB_API_HOST = 'api.github.com';
const PER_PAGE = 30; // GitHub default; max 100

/**
 * Fetch all public gists for a GitHub username.
 * Handles pagination automatically, accumulating every page.
 *
 * @param {string} username
 * @param {number} page - page number (1-based)
 * @returns {Promise<Array>}
 */
function fetchGistsPage(username, page) {
  return new Promise((resolve, reject) => {
    const path = `/users/${encodeURIComponent(username)}/gists?per_page=${PER_PAGE}&page=${page}`;
    const options = {
      hostname: GITHUB_API_HOST,
      path,
      method: 'GET',
      headers: {
        'User-Agent': 'gists-api-server/1.0.0',
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
        ...(process.env.GITHUB_TOKEN
          ? { Authorization: `Bearer ${process.env.GITHUB_TOKEN}` }
          : {}),
      },
    };

    const req = https.request(options, (res) => {
      let body = '';
      res.on('data', (chunk) => { body += chunk; });
      res.on('end', () => {
        resolve({ statusCode: res.statusCode, body });
      });
    });

    req.on('error', reject);
    req.end();
  });
}

/**
 * Accumulate all pages of gists for a user.
 *
 * @param {string} username
 * @returns {Promise<{ statusCode: number, gists: Array }>}
 */
async function fetchAllGists(username) {
  let page = 1;
  let allGists = [];

  while (true) {
    const { statusCode, body } = await fetchGistsPage(username, page);

    if (statusCode !== 200) {
      let parsed;
      try { parsed = JSON.parse(body); } catch (_) { parsed = {}; }
      return { statusCode, gists: null, message: parsed.message || 'GitHub API error' };
    }

    const gists = JSON.parse(body);
    allGists = allGists.concat(gists);

    // If we received fewer items than a full page, we're done
    if (gists.length < PER_PAGE) break;

    page += 1;
  }

  return { statusCode: 200, gists: allGists };
}

/**
 * Shape a raw GitHub gist object into a clean response payload.
 *
 * @param {Object} gist
 * @returns {Object}
 */
function formatGist(gist) {
  return {
    id: gist.id,
    description: gist.description || '',
    url: gist.html_url,
    api_url: gist.url,
    public: gist.public,
    created_at: gist.created_at,
    updated_at: gist.updated_at,
    files: Object.keys(gist.files || {}),
    comments: gist.comments,
    forks_url: gist.forks_url,
  };
}

// ---------------------------------------------------------------------------
// Routes
// ---------------------------------------------------------------------------

app.get('/health', (_req, res) => {
  res.json({ status: 'ok' });
});

app.get('/:user', async (req, res) => {
  const { user } = req.params;

  // Basic sanity-check – GitHub usernames are 1–39 alphanumeric/-
  if (!/^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,37}[a-zA-Z0-9])?$/.test(user)) {
    return res.status(400).json({ error: 'Invalid GitHub username' });
  }

  try {
    const { statusCode, gists, message } = await fetchAllGists(user);

    if (statusCode === 404) {
      return res.status(404).json({ error: `GitHub user '${user}' not found` });
    }

    if (statusCode !== 200) {
      return res.status(502).json({ error: 'Upstream GitHub API error', detail: message });
    }

    return res.json({
      user,
      total: gists.length,
      gists: gists.map(formatGist),
    });
  } catch (err) {
    console.error('Unexpected error:', err);
    return res.status(500).json({ error: 'Internal server error' });
  }
});

// ---------------------------------------------------------------------------
// Start
// ---------------------------------------------------------------------------

const PORT = process.env.PORT || 8080;

/* istanbul ignore next */
if (require.main === module) {
  app.listen(PORT, () => {
    console.log(`Gists API server listening on port ${PORT}`);
  });
}

module.exports = app;

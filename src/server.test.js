'use strict';

const nock = require('nock');
const request = require('supertest');
const app = require('./server');

// Prevent any real network calls during tests
nock.disableNetConnect();
nock.enableNetConnect('127.0.0.1');

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

/** Build a minimal gist fixture that mirrors the GitHub API shape. */
function makeGist(overrides = {}) {
  return {
    id: 'abc123',
    description: 'A test gist',
    html_url: 'https://gist.github.com/octocat/abc123',
    url: 'https://api.github.com/gists/abc123',
    public: true,
    created_at: '2023-01-01T00:00:00Z',
    updated_at: '2023-06-01T00:00:00Z',
    files: { 'hello.js': {} },
    comments: 0,
    forks_url: 'https://api.github.com/gists/abc123/forks',
    ...overrides,
  };
}

// ---------------------------------------------------------------------------
// Health check
// ---------------------------------------------------------------------------

describe('GET /health', () => {
  it('returns 200 and status ok', async () => {
    const res = await request(app).get('/health');
    expect(res.status).toBe(200);
    expect(res.body).toEqual({ status: 'ok' });
  });
});

// ---------------------------------------------------------------------------
// Happy path – known user with gists
// ---------------------------------------------------------------------------

describe('GET /:user – octocat (known user)', () => {
  beforeEach(() => {
    nock('https://api.github.com')
      .get('/users/octocat/gists')
      .query({ per_page: '30', page: '1' })
      .reply(200, [makeGist({ id: 'g1', description: 'Gist one' }), makeGist({ id: 'g2', description: 'Gist two' })]);
  });

  afterEach(() => nock.cleanAll());

  it('returns 200 with correct user and total', async () => {
    const res = await request(app).get('/octocat');
    expect(res.status).toBe(200);
    expect(res.body.user).toBe('octocat');
    expect(res.body.total).toBe(2);
  });

  it('returns an array of gists', async () => {
    const res = await request(app).get('/octocat');
    expect(Array.isArray(res.body.gists)).toBe(true);
    expect(res.body.gists).toHaveLength(2);
  });

  it('each gist contains expected fields', async () => {
    const res = await request(app).get('/octocat');
    const gist = res.body.gists[0];
    expect(gist).toHaveProperty('id');
    expect(gist).toHaveProperty('description');
    expect(gist).toHaveProperty('url');
    expect(gist).toHaveProperty('api_url');
    expect(gist).toHaveProperty('public');
    expect(gist).toHaveProperty('created_at');
    expect(gist).toHaveProperty('updated_at');
    expect(gist).toHaveProperty('files');
    expect(gist).toHaveProperty('comments');
  });

  it('files is an array of filenames', async () => {
    const res = await request(app).get('/octocat');
    expect(Array.isArray(res.body.gists[0].files)).toBe(true);
    expect(res.body.gists[0].files).toContain('hello.js');
  });
});

// ---------------------------------------------------------------------------
// Pagination – user with more than one page of gists
// ---------------------------------------------------------------------------

describe('GET /:user – pagination', () => {
  const PAGE_SIZE = 30;

  beforeEach(() => {
    // First page: full page (30 items)
    const page1 = Array.from({ length: PAGE_SIZE }, (_, i) => makeGist({ id: `p1-${i}` }));
    // Second page: partial (5 items) → signals last page
    const page2 = Array.from({ length: 5 }, (_, i) => makeGist({ id: `p2-${i}` }));

    nock('https://api.github.com')
      .get('/users/manyuser/gists')
      .query({ per_page: String(PAGE_SIZE), page: '1' })
      .reply(200, page1)
      .get('/users/manyuser/gists')
      .query({ per_page: String(PAGE_SIZE), page: '2' })
      .reply(200, page2);
  });

  afterEach(() => nock.cleanAll());

  it('accumulates gists across multiple pages', async () => {
    const res = await request(app).get('/manyuser');
    expect(res.status).toBe(200);
    expect(res.body.total).toBe(PAGE_SIZE + 5);
    expect(res.body.gists).toHaveLength(PAGE_SIZE + 5);
  });
});

// ---------------------------------------------------------------------------
// User with no gists
// ---------------------------------------------------------------------------

describe('GET /:user – user with no gists', () => {
  beforeEach(() => {
    nock('https://api.github.com')
      .get('/users/emptyguy/gists')
      .query({ per_page: '30', page: '1' })
      .reply(200, []);
  });

  afterEach(() => nock.cleanAll());

  it('returns 200 with an empty gists array', async () => {
    const res = await request(app).get('/emptyguy');
    expect(res.status).toBe(200);
    expect(res.body.total).toBe(0);
    expect(res.body.gists).toEqual([]);
  });
});

// ---------------------------------------------------------------------------
// 404 – user does not exist
// ---------------------------------------------------------------------------

describe('GET /:user – unknown user', () => {
  beforeEach(() => {
    nock('https://api.github.com')
      .get('/users/thisuserdoesnotexist99999/gists')
      .query({ per_page: '30', page: '1' })
      .reply(404, { message: 'Not Found' });
  });

  afterEach(() => nock.cleanAll());

  it('returns 404 with a descriptive error', async () => {
    const res = await request(app).get('/thisuserdoesnotexist99999');
    expect(res.status).toBe(404);
    expect(res.body).toHaveProperty('error');
    expect(res.body.error).toMatch(/not found/i);
  });
});

// ---------------------------------------------------------------------------
// Upstream GitHub API error
// ---------------------------------------------------------------------------

describe('GET /:user – GitHub API 500', () => {
  beforeEach(() => {
    nock('https://api.github.com')
      .get('/users/someuser/gists')
      .query({ per_page: '30', page: '1' })
      .reply(500, { message: 'Internal Server Error' });
  });

  afterEach(() => nock.cleanAll());

  it('returns 502 bad gateway', async () => {
    const res = await request(app).get('/someuser');
    expect(res.status).toBe(502);
    expect(res.body).toHaveProperty('error');
  });
});

// ---------------------------------------------------------------------------
// Invalid username
// ---------------------------------------------------------------------------

describe('GET /:user – invalid username', () => {
  it('returns 400 for a username that is too long', async () => {
    // GitHub usernames are max 39 characters; this is 40
    const tooLong = 'a'.repeat(40);
    const res = await request(app).get(`/${tooLong}`);
    expect(res.status).toBe(400);
    expect(res.body).toHaveProperty('error');
  });

  it('returns 400 for a username starting with a hyphen', async () => {
    const res = await request(app).get('/-invalid-start');
    expect(res.status).toBe(400);
    expect(res.body).toHaveProperty('error');
  });
});

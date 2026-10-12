# Publishing checklist

The author has created [geeknees/outside_is_the_prompt](https://github.com/geeknees/outside_is_the_prompt) and published the [DEV article](https://dev.to/geeknees/outside-is-the-prompt-an-ai-that-needs-me-to-touch-grass-before-it-can-write-4i63). The local article source contains the repository URL. This file records the publication workflow and verification evidence.

## Deadline

The [official Week 1 page](https://dev.to/challenges/hacktoberfest-week1-2026-10-05) states **October 11, 2026, 11:59 PM PDT**, which is **October 12, 2026, 15:59 JST**. Eligibility depends on submitting during the official window. The page also requires disclosure in the README of commits made after the deadline.

## Repository publication workflow

1. Commit and push reviewed files on a feature branch, then verify the remote branch SHA against the local commit. Honor hooks and use unsigned commits; do not push directly to `main` or another protected branch.
2. Open the public repository and article to verify their links. The article's published content has not been independently fetched by the coding environment.
3. Keep the demo provenance statement: the track is real, the answers are illustrative, and the postcard is actual Gemma output. If replacing the answers with personal memories, rerun the CLI and update the article, README, and sample consistently.
4. Any later terminal recording should show the summary, three answers, and postcard without revealing coordinates or unrelated LM Studio logs. A video attachment has not been verified.

## Files to publish

```text
.gitignore
Gemfile
Gemfile.lock
LICENSE
README.md
DEV_SUBMISSION.md
PUBLISHING.md
bin/outside
lib/outside/
test/
examples/
```

Do not force-add the actual GPX or `output/`. The only public GPX is `test/fixtures/short-walk.gpx`, which is synthetic. The public postcard in `examples/` was deliberately copied from the verified generation using illustrative answers.

## Verification evidence

- Actual YAMAP recording: 2026-10-11; 366 points; 7.54 km; 16,678 seconds; elevation 1,586–2,057 m; smoothed gain approximately 552 m.
- Live generation: 2026-10-12, `google/gemma-4-e2b`, LM Studio OpenAI-compatible API, private LAN endpoint. The author ran `bin/outside` against the real GPX with `examples/demo-answers.txt`; the saved Markdown was read back and copied unchanged to `examples/outside-postcard.md`.
- Automated tests: 34 tests and 101 assertions passed, independently of an LLM.
- Before Git initialization, all 20 publication files passed the privacy scan and the ignore patterns excluded the actual route and local output. Staged-diff and remote-SHA checks belong to the commit/push workflow.

During initial publication preparation, the coding environment denied creation of `.git` and disallowed permission escalation. The GitHub connector could read the public repository, but its write request returned `403 Resource not accessible by integration`; that request created no commit. A normal terminal with the author's Git credentials is required for the Git workflow in that environment.

## Run again

```bash
bundle install
export LM_STUDIO_BASE_URL=http://localhost:1234/v1
export LM_STUDIO_MODEL=google/gemma-4-e2b
bin/outside /path/to/hike.gpx
```

For a private LAN server, set `LM_STUDIO_BASE_URL` to that server's `/v1` URL. `/api/v1/chat` is LM Studio's native API and is not the endpoint used by this CLI. If a restricted coding environment reports `Operation not permitted` while a normal terminal can connect, run the CLI from that normal terminal; changing API paths does not resolve the network restriction.

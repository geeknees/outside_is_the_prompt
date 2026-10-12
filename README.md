# Outside is the Prompt

**An AI that can't write your story until you go outside.**

> GPS knows where I went.
>
> AI knows countless stories about mountains.
>
> Neither knows what I experienced there.

## What it does

A small Ruby CLI turns a recorded outdoor walk and three brief observations into an **Outside Postcard** of at most 100 words.

1. Go outside and record a walk with YAMAP or another GPX recorder.
2. Ruby measures the track and shows what the machine knows.
3. Answer up to three questions about what the GPS could not capture. Enter skips a question; at least one memory is required.
4. Gemma reflects on those two sources through LM Studio. The postcard appears in the terminal and is saved to `output/outside-postcard.md`.

Three short answers, one postcard, then close the screen. There is no conversation to maintain, account to create, or feed to check.

## Why I built it

On October 11, 2026, I went hiking and recorded the route with YAMAP. The exported GPX held hundreds of measurements. It could tell me how far I had walked, but it could not tell me what I would remember.

That gap became the interface: **What can the machine know, and what still requires being there?**

The direction is **physical world → human experience → AI**. A model can help put an experience into words after the walk. The person who was there supplies the part the model cannot measure. The tool trusts those memories and the supplied recording; it does not authenticate physical presence.

## Demo

The parser was tested against the actual YAMAP GPX recorded on **2026-10-11**. These numbers were calculated from the file by Ruby:

```text
OUTSIDE IS THE PROMPT

THE MACHINE KNOWS

Distance:         7.54 km
Time outside:     4h 38m
Elevation gain:   ~552 m
Lowest point:     1,586 m
Highest point:    2,057 m
Track points:     366
Start (UTC):      2026-10-11T01:27:19Z
End (UTC):        2026-10-11T06:05:17Z

BUT THE GPS DOESN'T KNOW EVERYTHING.
```

Exact elapsed time: **16,678 seconds, or 4h 37m 58s**. The display rounds to the nearest minute and reports elapsed time including stops, rather than moving time.

The end-to-end CLI run on **2026-10-12** used `google/gemma-4-e2b` through LM Studio. Its unedited result is in [examples/outside-postcard.md](examples/outside-postcard.md). [Aggregate facts](examples/field-facts.json) and [terminal measurements](examples/field-summary.txt) are also included.

**Demo provenance:** the GPX is a real field recording. The three answers below are illustrative inputs from the project brief, not verified memories from that hike. The postcard is actual model output from those inputs. The private GPX is deliberately excluded from the repository.

## Architecture

```text
YAMAP GPX
    ↓
Ruby GPX parser (REXML)
    ↓
Deterministic facts: distance, time, elevation
    +
Human observations: up to three short answers
    ↓
Ruby HTTP client
    ↓
LM Studio OpenAI-compatible API
    ↓
google/gemma-4-e2b
    ↓
Outside Postcard → terminal + local Markdown
```

| Source | Role |
| --- | --- |
| GPS | Measurement |
| Human | Experience |
| Gemma | Reflection |

**Ruby does the measuring. Gemma does the reflecting.** The model receives a JSON object containing aggregate measurements and human memories. It never receives GPX XML, coordinates, track names, or individual track points. No parsing or arithmetic is delegated to it.

Distance uses the Haversine formula between consecutive points within each track segment. Separate segments are never joined. Duration uses GPX timestamps. Minimum and maximum elevation use recorded samples. Elevation gain sums positive changes after a three-point median filter within each segment, retaining the endpoints. This suppresses isolated spikes but can also smooth real narrow peaks; the gain is an estimate, not a calibrated hiking metric. Missing data remains unknown.

## Installation

Use Ruby **3.2 or later** and Bundler. Development and tests used Ruby 4.0.6. From the project directory:

```bash
bundle install
```

REXML is the only application gem. HTTP and JSON use Ruby's standard libraries; Minitest is used for tests. No SDK, framework, database, or cloud service is needed.

## LM Studio setup

1. Install and open [LM Studio](https://lmstudio.ai/).
2. Download and load `google/gemma-4-e2b`.
3. Start its Local Server, normally at `http://localhost:1234`.
4. Run `bin/outside /path/to/hike.gpx`.

The CLI checks `GET /v1/models` and sends one generation request to `POST /v1/chat/completions`, using LM Studio's [OpenAI-compatible API](https://lmstudio.ai/docs/developer/openai-compat). No external API key is needed for an unauthenticated local server. The native `/api/v1/models` endpoint is a different API; use `/v1` as this client's base path.

Both settings are configurable:

```bash
export LM_STUDIO_BASE_URL=http://localhost:1234/v1
export LM_STUDIO_MODEL=google/gemma-4-e2b
```

Use the exact model ID returned by `curl http://localhost:1234/v1/models`. The CLI also recognizes an unambiguous publisher-prefix difference. A visible model may still need loading when LM Studio's just-in-time loading is enabled.

A private LAN IP is supported through `LM_STUDIO_BASE_URL`. A URL without a path gets `/v1` appended. Public cloud hosts are rejected. Connection and model errors are shown without a stack trace.

## Usage

```bash
bin/outside /path/to/hike.gpx
# Equivalently:
bundle exec ruby bin/outside /path/to/hike.gpx
```

Answer one line per question. Blank answers skip a question. With no memories, no postcard is generated. Successful runs replace `output/outside-postcard.md`; unsuccessful model requests leave an existing postcard untouched.

To reproduce the illustrative demo with your private copy of the field recording:

```bash
bin/outside yamap_2026-10-11_10_26.gpx < examples/demo-answers.txt
```

For a public smoke test, use `test/fixtures/short-walk.gpx` instead. That fixture is entirely synthetic and is not the field recording.

## Example

These are the demo's illustrative answers:

```text
What did you notice that GPS couldn't?
> The wind became much stronger on the ridge.

What surprised you?
> My child kept collecting interesting stones.

What will you remember?
> The sky suddenly opened when we reached the ridge.
```

Actual, unedited Gemma output from the real track's aggregate facts and those answers:

> The traverse covered 7.54 km, spanning a duration of four hours and thirty-eight minutes. Elevation ranged from 1586m to 2057m, with a gain of 552 meters. GPS could not record that the wind became much stronger on the ridge. A memory recalls the sky suddenly opening when we reached the ridge.

The prompt asks for restrained prose, separate attribution, and no invented events. The CLI enforces the 100-word ceiling; the person should still review what the model writes. This sample also shows the small model's limits: its wording is fairly literal, and it leaves out one answer.

## Why local/open AI

A GPX file is detailed location history. The open-weight [Gemma model](https://lmstudio.ai/models/gemma-4) can run in LM Studio on a machine the person controls, so reflecting on a walk does not require sending that history to a cloud AI service.

The Ruby code is MIT licensed, the prompt is a short constant, and the model identifier is configurable. You can inspect the behavior, replace the model, or change the questions. After downloading the model and installing dependencies, the design supports local, offline-oriented use. The captured run used a private LAN endpoint; a fully disconnected run has not been separately verified.

LM Studio is the local inference runtime. This repository's MIT license covers the project code; model and runtime licenses are separate.

## Privacy

- Raw GPX stays in the Ruby process. Only aggregate facts and the entered observations reach the configured LM Studio server.
- With the default loopback endpoint, inference stays on the same machine. With a private LAN endpoint, the summary and memories travel to that selected machine; use a network and server you trust.
- There are no cloud AI calls, analytics, uploads, or external API keys in this CLI. Environment HTTP proxies are disabled for model requests.
- GPX files, generated `output/`, and local configuration files are ignored by Git. The one GPX exception is the synthetic test fixture.
- LM Studio may retain local request logs. Review both its logs and generated prose before sharing a screen or publishing an example.

## Tests

```bash
bundle exec ruby -Itest -e 'Dir["test/*_test.rb"].sort.each { |file| require_relative file }'
```

**34 tests, 101 assertions passing.** Coverage includes Haversine distance, GPX namespaces, duration and timezone offsets, segment boundaries, elevation smoothing, missing data, invalid XML, model discovery, HTTP request construction, connection errors, the three-question limit, and Markdown output. Tests use synthetic tracks and model responses; they require no LLM or network.

The real-field CLI run and saved Gemma output were verified separately from the automated tests.

## Hacktoberfest Challenge

Built for [Hacktoberfest Open-Source AI Challenge Week 1: Touch Grass](https://dev.to/challenges/hacktoberfest-week1-2026-10-05). The design aims to make the screen the shortest part of the experience: hours outside, three answers afterward, one small postcard.

Partner category: **Best Use of Gemma**. No other partner category is claimed.

Read the [published DEV article](https://dev.to/geeknees/outside-is-the-prompt-an-ai-that-needs-me-to-touch-grass-before-it-can-write-4i63) and find the code at [geeknees/outside_is_the_prompt](https://github.com/geeknees/outside_is_the_prompt). [DEV_SUBMISSION.md](DEV_SUBMISSION.md) is the local article source; [PUBLISHING.md](PUBLISHING.md) records publication status and verification.

The field recording is from October 11; implementation, tests, and live Gemma verification were completed on October 12 JST before the scheduled 15:59 JST deadline. The initial Git commit and push are separate publication steps: any commit timestamp after that deadline records later repository publication. Publication preparation updates article/repository links and status documentation; it does not change the verified CLI implementation.

## License

[MIT](LICENSE).

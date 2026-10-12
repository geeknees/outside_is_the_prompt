---
title: "Outside Is the Prompt: An AI That Needs Me to Touch Grass Before It Can Write"
published: true
tags: devchallenge, hf26challenge, ruby, ai
---

*This is a submission for the [Hacktoberfest Open-Source AI Challenge Week 1: Touch Grass](https://dev.to/challenges/hacktoberfest-week1-2026-10-05)*

## What I Built

AI knows a lot about mountains.

My GPS knows exactly where I walked.

Neither of them was there with me.

On October 11, 2026, I went hiking and recorded the route with YAMAP. When I exported the GPX, I had 366 track points: a sequence of positions, elevations, and times. A useful record, with an obvious absence. There was no field for what had caught my attention.

That led to the question behind this project:

> What if AI couldn't generate anything useful until I first went outside?

**Outside is the Prompt** is a small Ruby CLI for people who already record walks and want to keep something besides the route. It reads a GPX file, shows what the machine can measure, and asks three short questions about what it cannot. A local Gemma model then turns the measurements and answers into a postcard of at most 100 words.

The order matters: **physical world → human experience → AI**. The walk supplies the experience. The person decides what mattered. Only then does the model have enough to help.

## Demo

These measurements came from running the Ruby parser on my actual October 11 YAMAP recording:

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

The exact elapsed time is 4 hours, 37 minutes, and 58 seconds, including stops. The CLI rounds that to 4h 38m. Elevation gain is an estimate after a small median filter reduces isolated GPS spikes.

For a reproducible public demo, I paired those real measurements with three **illustrative answers**. These are demonstration inputs, not a claim that these events occurred on my hike:

```text
What did you notice that GPS couldn't?
> The wind became much stronger on the ridge.

What surprised you?
> My child kept collecting interesting stones.

What will you remember?
> The sky suddenly opened when we reached the ridge.
```

Here is the **actual, unedited output** from `google/gemma-4-e2b`, generated through LM Studio during the end-to-end CLI run:

> The traverse covered 7.54 km, spanning a duration of four hours and thirty-eight minutes. Elevation ranged from 1586m to 2057m, with a gain of 552 meters. GPS could not record that the wind became much stronger on the ridge. A memory recalls the sky suddenly opening when we reached the ridge.

The wording is plain. It also leaves out the stones. That is an honest small-model result, and a reason to read the postcard before keeping it. The useful part is the boundary it preserves: measurements come from the track; the wind and sky come from the supplied memories.

The CLI prints the result and saves `output/outside-postcard.md`. The repository includes the aggregate measurements, demo answers, and generated postcard. It excludes the private route.

## Code

[Outside is the Prompt on GitHub](https://github.com/geeknees/outside_is_the_prompt)

MIT licensed. Ruby, REXML, standard-library HTTP, and a few readable files. The tests run without an LLM.

## How I Built It

```text
YAMAP GPX
    ↓
Ruby
    ↓
Deterministic physical facts
    +
Human observations
    ↓
LM Studio
    ↓
google/gemma-4-e2b
    ↓
Outside Postcard
```

**Ruby does the measuring. Gemma does the reflecting.**

Ruby parses the GPX, calculates Haversine distance, reads timestamps, and summarizes elevation. It handles separate track segments without drawing imaginary connections between them. A three-point median filter makes the elevation-gain estimate less sensitive to isolated spikes.

Gemma receives two structured sources: `gps_measurements` and `human_memories`. No raw GPX or coordinates enter its prompt. It has no distance to calculate and no route to interpret.

The prompt asks for fewer than 101 words, clear attribution, restrained language, and no invented events. The final detail must come from a human answer. The program refuses to generate if every answer is empty.

There are 34 passing tests with 101 assertions, covering the measurements, model adapter, and CLI. The real hike was tested separately, including saving a postcard from a live Gemma response. I kept the interface to three fixed questions and one model request so that finishing the walk would not begin another long session at a screen.

## Why Does Open Innovation Matter?

A GPX file is personal location history. Sending it to a cloud model would add a disclosure to the simple act of remembering a walk.

Running an open-weight Gemma model through LM Studio gives this project a different starting point. The route stays with the Ruby process. With the default localhost setup, the observations and inference stay on the same machine too. The captured demo used a private LAN endpoint: only aggregate facts and demo answers traveled to that LM Studio server.

No cloud AI account or external API key is required. Once the model and dependencies are installed, the design can be used locally without a cloud service. The MIT Ruby code and short prompt can be inspected and changed, and the model identifier is configurable.

Those choices matter together. A person can keep their route private, decide which memories to share with their own model, and change the model's behavior. Local inference serves the same purpose as the three-question interface: give the person control over a small act of reflection.

## Taking It Outside

The field recording came from actually going outside on October 11, not from a generated route or test fixture. It represents almost five hours away from the keyboard. The intended interaction afterward is three lines and a short wait for a postcard.

I kept the raw route private and used clearly labeled demonstration memories for the public example. The actual sensory details remain something only the person who went can supply. That is the question the project keeps returning to: what can the machine know, and what still requires being there?

The GPS remembers the route.

Gemma helps me reflect on it.

But the experience still belongs to the person who went outside.

## My Agent Session

I used OpenAI Codex to help implement the Ruby CLI, verify the deterministic calculations, and prepare the documentation. I ran the live LM Studio demo from my terminal.

## Prize Categories

- **Best Use of Gemma** — `google/gemma-4-e2b` generates the postcard through LM Studio from measured facts and human observations.

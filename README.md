# AI Translator

Rails app inspired by Google Translate for style-focused rewrites/translations using LLM providers.

Current modes:
- `formal_english`
- `informal_english`
- `linkedin_style` (keeps the same source language)

Primary provider is Groq, with Nemotron as fallback.

## Stack

- Ruby `4.0.2`
- Rails `8.1`
- SQLite (development/test)
- Hotwire (Turbo + Stimulus)
- Minitest + Capybara/Selenium (system tests)

## Architecture

Request flow:
1. `TranslationsController#create` receives form input.
2. `TranslationForm` validates/normalizes text and mode.
3. `TranslateText.call` builds final prompt and dispatches provider call.
4. `Llm::ProviderRouter` calls Groq first, retries retryable failures, then falls back to Nemotron.
5. Response is rendered as Turbo Stream (or HTML fallback).

## Local Setup

```bash
bundle install
cp .env.example .env
bin/setup --skip-server
```

Run app:

```bash
bin/dev
```

Open: `http://localhost:3000`

## Environment Variables

Define in `.env`:

- `GROQ_API_KEY`
- `GROQ_MODEL` (default in `.env.example`)
- `GROQ_BASE_URL`
- `NEMOTRON_API_KEY`
- `NEMOTRON_MODEL` (default in `.env.example`)
- `NEMOTRON_BASE_URL`
- `LLM_TIMEOUT_SECONDS`
- `LLM_MAX_ATTEMPTS`

## Running Tests

Default test suite:

```bash
bin/rails test
```

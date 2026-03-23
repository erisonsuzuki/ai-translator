# Rails AI Translator - Implementation Blueprint (Stateless MVP)

## 1) Objective

Build a Rails application inspired by Google Translate with custom rewriting/translation modes powered by LLMs:

- Primary provider: **Groq**
- Fallback provider: **Nemotron**

Initial modes:

1. Formal English
2. Informal English
3. LinkedIn style in the same language as the user input

The system must be extensible so new modes can be added later with minimal code changes.

---

## 2) Scope and Constraints

### In scope (MVP)

- Single-page translation flow (input text + mode selector + output)
- Config-driven prompt management in a dedicated prompts directory
- Provider routing with retries and fallback
- Error handling and user-friendly messages
- Unit, request, and system tests

### Out of scope (for now)

- **No persistence of translations** (stateless execution)
- No user accounts/auth
- No translation history
- No analytics dashboard

---

## 3) Architecture Overview

### Presentation Layer

- `TranslationsController`
  - `new`: renders form
  - `create`: validates input, invokes service, renders result
- `app/views/translations/new.html.erb`
  - Text area for source text
  - Select for mode
  - Submit action
  - Output/error panel

### Application Layer

- `TranslateText` service
  - Loads prompt config for selected mode
  - Renders templates with runtime params
  - Calls provider router
  - Returns normalized response object

### Prompt Layer

- `config/prompts/defaults.yml`
- `config/prompts/modes/*.yml` (one file per mode)
- `PromptRepository`
  - Loads and validates YAML structure
- `PromptRenderer`
  - Interpolates placeholders (e.g., `{{source_text}}`, `{{style_label}}`)
  - Fails fast on missing variables

### LLM Layer

- `Llm::ProviderRouter`
  - Tries Groq first
  - Retries retryable errors
  - Falls back to Nemotron
- Provider adapters
  - `Llm::Providers::GroqAdapter`
  - `Llm::Providers::NemotronAdapter`
- Shared adapter contract
  - Input: rendered prompt payload + llm options
  - Output: normalized result (`text`, `provider`, `model`, usage optional)

### Observability Layer

- Structured logs
- `ActiveSupport::Notifications` events
- No DB writes for telemetry in MVP

---

## 4) Prompt System Design

## Why YAML for prompts

- Human-readable for product iteration
- Easy per-mode overrides
- Works well with Rails config loading
- Enables future expansion without controller/service rewrites

## Prompt directory

```text
config/
  prompts/
    defaults.yml
    modes/
      formal_english.yml
      informal_english.yml
      linkedin_style.yml
```

## Recommended YAML schema

```yaml
# config/prompts/defaults.yml
version: 1
defaults:
  system_template: |
    You are an English Language Specialist with deep knowledge of grammar,
    syntax, and stylistic adaptation. Your operation is ephemeral and stateless.
    Preserve meaning, improve clarity, and adapt style to {{style_label}}.
  user_template: |
    Analyze the source text sentence by sentence.
    Correct mistakes and preserve original intent.
    Translate Portuguese fragments contextually when needed.
    Return only the final rewritten text.
    Source text:
    {{source_text}}
  llm:
    temperature: 0.3
    max_tokens: 700

# config/prompts/modes/formal_english.yml
key: formal_english
label: "Formal English"
style_label: "formal professional English suitable for external communication"
user_template: |
  Rewrite the source text as polished Formal English.
  Keep respectful and structured tone for client-facing communication.
  Translate Portuguese fragments to natural English when needed.
  Return only the final rewritten text.
  Source text:
  {{source_text}}

# config/prompts/modes/informal_english.yml
key: informal_english
label: "Informal English"
style_label: "natural informal English for casual or internal communication"
user_template: |
  Rewrite the source text as clear Informal English.
  Use concise, direct language and contractions when natural.
  Translate Portuguese fragments to natural English when needed.
  Return only the final rewritten text.
  Source text:
  {{source_text}}
llm:
  temperature: 0.5

# config/prompts/modes/linkedin_style.yml
key: linkedin_style
label: "LinkedIn Style"
style_label: "polished LinkedIn voice with concise, professional, engaging tone"
user_template: |
  Rewrite in LinkedIn style using the SAME language as the source text.
  Do not translate to a different language.
  Keep it professional and readable, with light storytelling if appropriate.
  Source text:
  {{source_text}}
```

## Prompt inspiration mapping

- English mode prompts should be inspired by `docs/prompt_translation.md`:
  - keep specialist persona and stateless behavior
  - keep contextual Portuguese-to-English translation guidance
  - keep sentence-level correction mindset before final rewrite
- For MVP output, return only the final rewritten text (no corrections report).
- LinkedIn mode keeps same-language rewrite behavior and does not force English.

## Validation rules

- Unknown mode key raises `UnknownModeError`
- Missing `key` or duplicate mode keys raises config error
- Missing placeholder value raises `PromptTemplateError`
- No unresolved tokens allowed in final prompt
- Optional: boot-time validation test to prevent broken deploys

---

## 5) Provider Routing and Fallback

## Routing strategy

1. Attempt Groq
2. Retry on retryable failures (timeout, 429, 5xx)
3. If Groq exhausts retries, attempt Nemotron
4. Retry Nemotron with same policy
5. Return translated text if success; return controlled error if both fail

## Retry defaults

- `max_attempts`: 2 per provider
- backoff: exponential (e.g., 300ms then 900ms)
- request timeout configurable via initializer

## Error taxonomy

- `Llm::Errors::RetryableError`
- `Llm::Errors::NonRetryableError`
- `Llm::Errors::AllProvidersFailed`

## Normalized adapter output

```ruby
{
  text: "translated output",
  provider: "groq",
  model: "model-name",
  tokens_in: 123,      # optional
  tokens_out: 245,     # optional
  latency_ms: 820      # optional
}
```

---

## 6) Rails Components and File Plan

## Core files

- `config/routes.rb`
- `app/controllers/translations_controller.rb`
- `app/views/translations/new.html.erb`
- `app/services/translate_text.rb`
- `app/services/prompt_repository.rb`
- `app/services/prompt_renderer.rb`
- `app/services/llm/provider_router.rb`
- `app/services/llm/providers/base_adapter.rb`
- `app/services/llm/providers/groq_adapter.rb`
- `app/services/llm/providers/nemotron_adapter.rb`
- `config/prompts/defaults.yml`
- `config/prompts/modes/formal_english.yml`
- `config/prompts/modes/informal_english.yml`
- `config/prompts/modes/linkedin_style.yml`
- `config/initializers/llm.rb`

## Suggested routes

```ruby
Rails.application.routes.draw do
  root "translations#new"
  resources :translations, only: [:new, :create]
end
```

---

## 7) Request Flow (Stateless)

1. User opens `/` and sees the translation form
2. User enters source text and selects one mode
3. Controller calls `TranslateText.call(input_text:, mode:)`
4. Service loads mode config and renders final prompt payload
5. Router calls Groq; on retryable failure, falls back to Nemotron
6. Response rendered back in view (no DB write)
7. Logs/events emitted with provider and timing metadata

---

## 8) Test Strategy

## Unit tests

- `PromptRepository`
  - loads valid YAML
  - rejects unknown mode
- `PromptRenderer`
  - interpolates required placeholders
  - raises on missing placeholders
- `Llm::ProviderRouter`
  - success via Groq
  - fallback to Nemotron on retryable failure
  - raises `AllProvidersFailed` when both fail
- Provider adapters
  - response normalization
  - error mapping from HTTP/network failures

## Request/system tests

- `POST /translations` success path
- each of 3 modes returns response block
- provider failure path shows user-friendly error
- invalid mode submitted from tampered form handled safely

## Tooling

- HTTP stubbing via WebMock/VCR (or equivalent)
- fixture payloads for Groq and Nemotron responses

---

## 9) Configuration and Secrets

Use environment variables:

- `GROQ_API_KEY`
- `GROQ_MODEL` (default model name)
- `NEMOTRON_API_KEY`
- `NEMOTRON_MODEL`
- `LLM_TIMEOUT_SECONDS`
- `LLM_MAX_ATTEMPTS`

Never commit secrets. Add `.env.example` with variable names only.

---

## 10) Implementation Phases

## Phase 1 - App skeleton + basic UI

- Initialize Rails app
- Create `TranslationsController` and form view
- Add routes and local input validation

## Phase 2 - Prompt system

- Create `config/prompts/defaults.yml`
- Create `config/prompts/modes/*.yml` (one file per mode)
- Implement `PromptRepository` + `PromptRenderer`
- Add tests for mode loading and placeholder validation

## Phase 3 - LLM providers + fallback

- Implement Groq adapter
- Implement Nemotron adapter
- Implement router retry/fallback rules
- Add configuration initializer and error classes

## Phase 4 - Robustness and polish

- Improve UX for failures/loading
- Add instrumentation events/log fields
- Finish request/system failure-path tests

---

## 11) Execution Checklist

- [ ] Rails project initialized
- [ ] Stateless translation controller/view running
- [ ] Prompt defaults + per-mode YAML files created
- [ ] Prompt loading/render validation implemented
- [ ] Groq adapter implemented and tested
- [ ] Nemotron adapter implemented and tested
- [ ] Router fallback behavior implemented and tested
- [ ] Error handling and user messaging implemented
- [ ] Full test suite green for MVP scope

---

## 12) Future-Ready Extension Points

- Add new mode by adding a new file in `config/prompts/modes/` (no controller changes)
- Add new provider by creating another adapter class
- Add persistence later by introducing `TranslationRequest` model and writing controller/service hooks
- Add API endpoint (`/api/v1/translations`) reusing same service layer

---

## 13) Risks and Mitigations

1. **Provider API differences**
   - Mitigation: strict adapter contract + isolated response parsing
2. **Prompt config regressions**
   - Mitigation: schema/placeholder validation tests
3. **Latency spikes due to fallback**
   - Mitigation: bounded retries, conservative timeouts, logs for tuning

---

## 14) Immediate Next Step

Start with Phase 1 + Phase 2 together so the app can run end-to-end quickly with a mocked adapter before wiring real provider credentials.

<div align="center">

# Nextable

**Prompt-to-Production. An AI-native builder that turns natural language into deployable Next.js apps.**

![Next.js](https://img.shields.io/badge/Next.js-15.4-black?logo=next.js)
![React](https://img.shields.io/badge/React-19-61DAFB?logo=react)
![Prisma](https://img.shields.io/badge/Prisma-6.12-2D3748?logo=prisma)
![Inngest](https://img.shields.io/badge/Inngest-Agent--Kit-7C3AED)
![TypeScript](https://img.shields.io/badge/TypeScript-5-3178C6?logo=typescript)

</div>

---

## Table of Contents

- [Project Overview](#project-overview)
- [Key Features](#key-features)
- [Tech Stack](#tech-stack)
- [System Architecture](#system-architecture)
- [Database Schema](#database-schema)
- [Folder Structure](#folder-structure)
- [Getting Started](#getting-started)
- [Usage & Workflows](#usage--workflows)
- [Future Roadmap](#future-roadmap)
- [Contributing](#contributing)
- [License](#license)

---

## Project Overview

**Nextable** is a Next.js 15 AI application-generation platform — a "Lovable-style" prompt-to-production builder. A user signs in, types a natural-language description of the application they want, chooses a model (Grok, GPT-5 Codex, or Gemini 2.5 Flash), and Nextable spins up an isolated **E2B sandbox**, generates a live Next.js project inside it via an agentic coding loop, and streams the result back as an embeddable live preview plus a browsable file tree.

The problem it solves: most AI coding tools stop at the snippet. Nextable closes the loop between *intent* and *running artifact* — the model doesn't just *write* code, it *executes* `terminal`, `createOrUpdateFiles`, and `readFiles` tools against a real sandboxed runtime until the app compiles and serves. Combined with persistent conversation history, per-user credit metering, and a background-first execution model, it becomes a durable workspace rather than a one-shot generator.

## Key Features

**Platform / Backend**
- **Agentic code generation** via [`@inngest/agent-kit`](https://www.inngest.com/docs/agent-kit) — multi-iteration network with a routed coding agent (up to 15 iterations) plus dedicated *fragment title* and *response* summarizer agents.
- **E2B sandboxed execution** — every generation spins a fresh `utkarsh-lovable-test-1` sandbox with a 30-minute timeout; the agent writes files, runs shell commands, and exposes the resulting app on port 3000 as a public URL.
- **Durable background jobs** — prompt submission enqueues a `code-agent/run` event through Inngest so the HTTP request returns immediately; the long-running generation loop executes out-of-band with step-level retries.
- **Credit-based usage metering** — [`rate-limiter-flexible`](https://github.com/animir/node-rate-limiter-flexible) backed by Prisma's `Usage` table. `100` points per 30-day window for Free and Pro (Pro gated via Clerk `plan: "pro"`).
- **End-to-end typesafe API** — tRPC v11 with TanStack Query, Superjson, and `protectedProcedure` guards wired to Clerk `auth()`.
- **Three switchable models** — Grok 4 Fast (free), GPT-5 Codex, Gemini 2.5 Flash, all proxied through an OpenAI-compatible base URL.
- **Prisma Accelerate** connection pooling and edge-ready query caching.

**User Experience / Frontend**
- **Motion-heavy marketing surface** — GSAP, Framer Motion, Lenis smooth scroll, `ScrambledText`, `ScrollFloat`, `SplitText`, and tsParticles across the landing/features/guide pages.
- **Authenticated chat workspace** — `/projects/[projectId]` renders a resizable split pane: conversational message thread on the left, **live sandbox preview + file explorer** (with Prism-highlighted code view) on the right.
- **shadcn/ui component system** on Tailwind v4 with `next-themes` dark mode and a custom Clerk appearance (`#C96342` primary).
- **Model picker** rendered as a custom `liquid-radio` control inside the prompt form.
- **Usage dashboard** — live credit balance and reset timer surfaced in the project header.

## Tech Stack

| Layer | Technology |
|---|---|
| **Framework** | Next.js 15.4 (App Router, Turbopack), React 19 |
| **Language** | TypeScript 5 |
| **Auth** | Clerk (`@clerk/nextjs` 6.37) with route-level middleware protection |
| **Database** | PostgreSQL + Prisma 6.12 + `@prisma/extension-accelerate` |
| **API Layer** | tRPC 11 + TanStack Query 5 + Superjson |
| **Background Jobs** | Inngest 3.39 + `@inngest/agent-kit` 0.8 |
| **AI Execution** | E2B Code Interpreter (`@e2b/code-interpreter`) — custom `utkarsh-lovable-test-1` Next.js template |
| **Models** | `x-ai/grok-4-fast:free`, `openai/gpt-5-codex`, `google/gemini-2.5-flash` (OpenAI-compatible gateway) |
| **Rate Limiting** | `rate-limiter-flexible` (Prisma store) |
| **UI** | Tailwind CSS 4, shadcn/ui, Radix primitives, `lucide-react`, `phosphor-icons` |
| **Motion** | Framer Motion 12, GSAP 3, Lenis, `react-tsparticles` |
| **Forms / Validation** | `react-hook-form` + `@hookform/resolvers` + Zod |
| **Observability** | `@vercel/analytics` |

## System Architecture

```mermaid
flowchart TB
    subgraph Client["🖥️ Client (Browser)"]
        UI[Next.js 15 App Router UI<br/>Tailwind · shadcn · Framer Motion]
        Auth[Clerk SDK<br/>Session Cookie]
    end

    subgraph Edge["⚡ Next.js Runtime"]
        MW["middleware.ts<br/>clerkMiddleware · route guards"]
        TRPC["/api/trpc/[trpc]<br/>tRPC Router<br/>(projects · messages · usage)"]
        IngRoute["/api/inngest<br/>serve() handler"]
    end

    subgraph Data["🗄️ Persistence"]
        PG[(PostgreSQL)]
        Prisma[Prisma Client<br/>+ Accelerate]
    end

    subgraph Bg["🔁 Inngest (Background)"]
        Event["Event: code-agent/run<br/>{ value, projectId, model }"]
        Fn[codeAgentFunction]
        Net["agent-kit Network<br/>maxIter: 15"]
        CA["codeAgent<br/>tools: terminal,<br/>createOrUpdateFiles,<br/>readFiles"]
        Title[fragment-title-generator]
        Resp[response-generator]
    end

    subgraph Ext["🌐 External Services"]
        E2B["E2B Sandbox<br/>template: utkarsh-lovable-test-1<br/>exposes :3000"]
        LLM["OpenAI-compatible Gateway<br/>Grok · Codex · Gemini"]
    end

    UI -- "sign-in" --> Auth
    Auth -- "__session" --> MW
    UI -- "tRPC call<br/>(prompt + model)" --> MW
    MW -- "auth.protect()" --> TRPC
    TRPC -- "consumeCredits()" --> Prisma
    TRPC -- "create Project + USER Message" --> Prisma
    Prisma <--> PG
    TRPC -- "inngest.send()" --> Event
    Event --> Fn
    Fn -- "step.run: get-sandbox-id" --> E2B
    Fn -- "step.run: load last 5 msgs" --> Prisma
    Fn --> Net
    Net --> CA
    CA -- "LLM completions" --> LLM
    CA -- "exec commands · write files" --> E2B
    Net -- "summary ready" --> Title
    Net -- "summary ready" --> Resp
    Title --> LLM
    Resp --> LLM
    Fn -- "step.run: save-result<br/>(ASSISTANT Message + Fragment)" --> Prisma
    E2B -- "sandbox.getHost(3000)" --> Fn
    IngRoute -. "poll / webhook" .- Bg
    UI -- "useQuery(messages.getMany)" --> TRPC
    UI -- "iframe: sandboxUrl" --> E2B

    style Client fill:#1e293b,stroke:#64748b,color:#e2e8f0
    style Edge fill:#0f172a,stroke:#475569,color:#e2e8f0
    style Data fill:#312e81,stroke:#6366f1,color:#e2e8f0
    style Bg fill:#4c1d95,stroke:#8b5cf6,color:#e2e8f0
    style Ext fill:#134e4a,stroke:#14b8a6,color:#e2e8f0
```

## Database Schema

The schema is intentionally lean — Clerk owns user identity, and Nextable stores only the `userId` foreign reference. A `Message` may optionally own exactly one `Fragment` (the materialized artifact: sandbox URL + generated file tree). `Usage` is a standalone table driven by `rate-limiter-flexible`.

```mermaid
erDiagram
    CLERK_USER ||..o{ PROJECT : "owns (userId)"
    PROJECT ||--o{ MESSAGE : "contains"
    MESSAGE ||--o| FRAGMENT : "may produce"
    CLERK_USER ||..o| USAGE : "keyed by userId"

    CLERK_USER {
        string id PK "External · Clerk"
        string plan "free | pro"
    }

    PROJECT {
        string id PK "uuid"
        string name "random-word-slug"
        string userId "Clerk user id"
        datetime createdAt
        datetime updatedAt
    }

    MESSAGE {
        string id PK "uuid"
        string content
        MessageRole role "USER | ASSISTANT"
        MessageType type "RESULT | ERROR"
        string projectId FK
        datetime createdAt
        datetime updatedAt
    }

    FRAGMENT {
        string id PK "uuid"
        string messageId FK "UNIQUE — 1:1"
        string sandboxUrl "https://<host>:3000"
        string title "AI-generated"
        json files "{ path: content }"
        datetime createdAt
        datetime updatedAt
    }

    USAGE {
        string key PK "Clerk userId"
        int points "remaining credits"
        datetime expire "30d rolling"
    }
```

**Cascades:** `Message.projectId → Project.id` and `Fragment.messageId → Message.id` both use `onDelete: Cascade`, so deleting a project cleanly drops its message history and all materialized fragments.

## Folder Structure

```
Nextable/
├── prisma/
│   ├── schema.prisma              # Project · Message · Fragment · Usage models
│   └── migrations/                # 4 migrations (reset → projects → usage)
│
├── sandbox-templates/
│   └── nextjs/                    # E2B template: Dockerfile + compile_page.sh
│       ├── e2b.Dockerfile
│       └── e2b.toml
│
├── src/
│   ├── middleware.ts              # Clerk route protection (public/protected matcher)
│   │
│   ├── app/                       # Next.js 15 App Router
│   │   ├── layout.tsx             # ClerkProvider · TRPCReactProvider · ThemeProvider
│   │   ├── (home)/                # Marketing route group
│   │   │   ├── page.tsx           # Landing (GSAP + framer-motion hero)
│   │   │   ├── pricing/
│   │   │   ├── sign-in/[[...sign-in]]/
│   │   │   └── sign-up/[[...sign-up]]/
│   │   ├── features/ · guide/     # Static marketing pages
│   │   ├── projects/
│   │   │   ├── page.tsx           # Project list
│   │   │   └── [projectId]/page.tsx   # Authenticated workspace
│   │   └── api/
│   │       ├── inngest/route.ts   # serve({ functions: [codeAgentFunction] })
│   │       └── trpc/[trpc]/route.ts
│   │
│   ├── inngest/                   # Background jobs
│   │   ├── client.ts              # Inngest client (id: "lovable-clone")
│   │   ├── functions.ts           # codeAgentFunction — agent-kit network
│   │   ├── utils.ts               # getSandboxId · parseAgentOutput
│   │   └── types.ts               # SANDBOX_TIMEOUT (30m)
│   │
│   ├── trpc/                      # tRPC wiring
│   │   ├── init.ts                # createTRPCRouter · protectedProcedure (Clerk ctx)
│   │   ├── routers/_app.ts        # root router: projects · messages · usage
│   │   ├── client.tsx · server.tsx · query-client.ts
│   │
│   ├── modules/                   # Feature-sliced domain code
│   │   ├── home/                  # Landing · navbar · project-form · tagline
│   │   ├── projects/
│   │   │   ├── server/procedures.ts   # getOne · getMany · create (+ inngest.send)
│   │   │   └── ui/                    # project-view · message-card · fragment-web
│   │   ├── messages/server/procedures.ts
│   │   └── usage/server/procedures.ts
│   │
│   ├── lib/
│   │   ├── db.ts                  # Prisma singleton + Accelerate
│   │   ├── usage.ts               # consumeCredits · getUsageStatus · getUsageTracker
│   │   └── utils.ts
│   │
│   ├── components/
│   │   ├── ui/                    # shadcn-style primitives
│   │   ├── code-view/             # Prism-powered file viewer
│   │   ├── file-explorer.tsx · tree-view.tsx
│   │   └── 21stdev/               # Marketing UI (announcement, blur-text, …)
│   │
│   ├── hooks/                     # use-current-theme · use-mobile · use-scroll
│   ├── prompt.ts                  # PROMPT · FRAGMENT_TITLE_PROMPT · RESPONSE_PROMPT
│   └── types.ts
│
├── public/                        # Logos, marketing imagery
├── next.config.ts · components.json · eslint.config.mjs · postcss.config.mjs
└── package.json                   # scripts: dev (turbopack) · build · start · postinstall (prisma generate)
```

## Getting Started

### Prerequisites

| Tool | Version |
|---|---|
| **Node.js** | `>= 20.x` (required by `@types/node: ^20` and Next 15) |
| **npm / pnpm / bun** | any — lockfile is npm (`package-lock.json`) |
| **PostgreSQL** | `>= 14` (a Neon/Supabase/Railway instance works; Accelerate is used on top) |
| **Clerk account** | for authentication keys |
| **Inngest account** | for event keys + dev server |
| **E2B account** | to build/run the `utkarsh-lovable-test-1` sandbox template |
| **LLM gateway** | any OpenAI-compatible base URL (OpenRouter, Together, etc.) |

### Installation

```bash
# 1. Clone
git clone https://github.com/<your-org>/nextable.git
cd nextable

# 2. Install (postinstall runs `prisma generate` automatically)
npm install

# 3. Configure environment — see .env.example below
cp .env.example .env.local

# 4. Apply migrations
npx prisma migrate deploy
# or during development:
npx prisma migrate dev

# 5. (Optional) Build the E2B sandbox template
cd sandbox-templates/nextjs
e2b template build --name utkarsh-lovable-test-1
cd ../..

# 6. Run the dev stack in two terminals
npm run dev                 # Next.js + Turbopack on :3000
npx inngest-cli@latest dev  # Inngest Dev Server on :8288
```

Visit **http://localhost:3000** and **http://localhost:8288** (Inngest inspector) to verify both halves.

### `.env.example`

```dotenv
# ───── Database (Postgres) ─────
# Standard Postgres connection string. If using Prisma Accelerate, point this at
# the prisma:// URL; otherwise use postgresql://user:pass@host:5432/db
DATABASE_URL="postgresql://postgres:password@localhost:5432/nextable"

# ───── Clerk Authentication ─────
# Grab these from https://dashboard.clerk.com → API Keys
NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY="pk_test_..."
CLERK_SECRET_KEY="sk_test_..."

# Route configuration used by Clerk's App Router integration
NEXT_PUBLIC_CLERK_SIGN_IN_URL="/sign-in"
NEXT_PUBLIC_CLERK_SIGN_UP_URL="/sign-up"
NEXT_PUBLIC_CLERK_SIGN_IN_FALLBACK_REDIRECT_URL="/projects"
NEXT_PUBLIC_CLERK_SIGN_UP_FALLBACK_REDIRECT_URL="/projects"

# ───── Inngest (background job orchestration) ─────
# Leave blank locally — Inngest Dev Server auto-handles signing.
# In production, paste values from https://app.inngest.com → Apps → Keys
INNGEST_SIGNING_KEY="signkey-prod-..."
INNGEST_EVENT_KEY="..."

# ───── E2B (remote code-execution sandboxes) ─────
# From https://e2b.dev/dashboard. Used by @e2b/code-interpreter to spawn
# the utkarsh-lovable-test-1 template.
E2B_API_KEY="e2b_..."

# ───── LLM Gateway (OpenAI-compatible) ─────
# The agent-kit openai() provider is pointed at OPENAI_API_BASE so any
# OpenAI-compatible gateway (OpenRouter, Together, Groq, local vLLM) works.
# Model IDs used by the code agent are hard-coded in src/inngest/functions.ts:
#   grok   → x-ai/grok-4-fast:free
#   codex  → openai/gpt-5-codex
#   gemini → google/gemini-2.5-flash
OPENAI_API_KEY="sk-or-v1-..."
OPENAI_API_BASE="https://openrouter.ai/api/v1"

# Fallback model used by the fragment-title + response summarizer agents
OPENAI_FREE2_MODEL="x-ai/grok-4-fast:free"

# ───── Optional ─────
# Vercel Analytics — automatically wired when deployed on Vercel
# NEXT_PUBLIC_VERCEL_ANALYTICS_ID=""
```

## Usage & Workflows

**End-to-end generation flow:**

1. **Land → Sign in.** Unauthenticated users hit the motion-rich marketing home at `/`. Clerk middleware protects everything except the marketing route group, auth pages, `/api/trpc/*`, and `/api/inngest/*`.
2. **Create a project.** On `/projects`, the user types a prompt into `project-form`, picks a model via the `liquid-radio` control (Grok / Codex / Gemini), and submits.
3. **Server-side validation.** The `projects.create` tRPC mutation runs `consumeCredits()` (1 point per generation, 100/30d); on failure it throws `TOO_MANY_REQUESTS`. On success it creates the `Project` row (with a `random-word-slugs` name) and the first `USER` `Message` atomically via Prisma nested write.
4. **Event fan-out.** `inngest.send({ name: "code-agent/run", data: { value, projectId, model } })` hands off to the background worker and returns the project id immediately.
5. **Agentic generation.** `codeAgentFunction` spawns an E2B sandbox, loads the last 5 messages as conversation state, and runs an agent-kit **network** (`maxIter: 15`) where `codeAgent` iteratively invokes `terminal`, `createOrUpdateFiles`, and `readFiles` tools against the sandbox until it emits a `<task_summary>` block.
6. **Summarization.** Two lightweight agents — `fragment-title-generator` and `response-generator` — transform the raw summary into a user-facing title and chat reply.
7. **Persist fragment.** The function writes an `ASSISTANT` message with a nested `Fragment` (`sandboxUrl`, `title`, `files` JSON) to Postgres.
8. **UI reconciliation.** The `/projects/[projectId]` view polls `messages.getMany` via TanStack Query; the new fragment renders as an iframe preview beside the `file-explorer` with Prism-highlighted code.
9. **Iterate.** Subsequent messages replay the same path through `messages.create` — each one deducts a credit, re-uses the previous sandbox context (via the last-5-messages window), and appends another fragment.

## Future Roadmap

- [ ] **Streaming tool output** — surface `terminal` stdout line-by-line in the UI instead of waiting for `save-result`.
- [ ] **Fragment fork / branch** — let a user diverge from any historical message to explore alternative generations without blowing away state.
- [ ] **Per-model pricing tiers** — different `GENERATION_COST` for Codex vs. Grok; currently all models cost 1 point.
- [ ] **Persistent sandboxes** — reconnect to an existing `sandboxId` across sessions instead of re-creating per run.
- [ ] **Artifact export** — one-click "push to GitHub" / "deploy to Vercel" from a Fragment.
- [ ] **Observability** — structured logs, Inngest step timing metrics, and an admin dashboard for usage analytics.
- [ ] **Multi-agent specialization** — split `codeAgent` into planner / coder / reviewer roles inside the network.
- [ ] **Model persistence on `Message`** — currently the chosen model is passed through the event but not stored on the `Message` row (see `TODO` in `messages.create`).
- [ ] **Rate-limit UX** — surface remaining credits + reset window in the prompt form pre-submit instead of only on failure.

<div align="center">

Built with Next.js 15, Inngest, Clerk, Prisma, and E2B.

</div>

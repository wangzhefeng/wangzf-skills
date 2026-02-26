# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This repository contains projects related to Claude Code, including:
- `skills_tutorial/uigen/`: A Next.js UI generator application with AI chat, code editor, and preview pane
- `skills_tutorial/docs/`: Documentation (PDF guide "The Complete Guide to Building Skill for Claude")
- `skills_tutorial/your-skill-name/`: Template for creating custom Claude Code skills (includes scripts, assets, and reference materials)
- `model_change/`: Scripts for configuring Claude Code to use alternative AI providers (MiniMax, DeepSeek)

The primary project is the UI generator (`uigen`), a full‑stack application built with Next.js 15 (App Router), Prisma ORM, SQLite database, JWT‑based authentication, and AI‑driven component generation.

The root directory also holds:
- `.env`: API keys for Claude Code and AI providers (used by both the UI generator and Claude Code itself)
- `README.md`: Installation instructions for Claude Code
- `.claude/`: Claude Code settings and skills (auto‑generated)
- Auto memory directory: `C:\Users\Administrator\.claude\projects\E--llm-projects-claude-code\memory\` (persistent across sessions)

## Getting Started

### UI Generator (`skills_tutorial/uigen/`)

1. Navigate to the project directory:
   ```bash
   cd skills_tutorial/uigen
   ```

2. Install dependencies and set up the database:
   ```bash
   npm run setup
   ```
   This runs `npm install`, generates the Prisma client, and applies migrations.

3. Start the development server:
   ```bash
   npm run dev
   ```
   The app will be available at `http://localhost:3000`.

### Environment Variables

Create a `.env` file in the project root (`skills_tutorial/uigen/.env`) with the following variables:

```env
# JWT secret for session management (required)
JWT_SECRET=your-secret-key-here

# AI provider API keys (optional, needed for chat functionality)
ANTHROPIC_API_KEY=sk-ant-...        # Used by the UI generator's AI chat
CLAUDE_CODE_API_KEY=sk-ant-...      # Used by Claude Code CLI (root .env)
MINIMAX_API_KEY=sk-...              # Alternative provider key
DEEPSEEK_API_KEY=sk-...             # Alternative provider key
```

The root `.env` file already contains example keys for Claude Code and other providers; copy or reference them as needed. Note that the UI generator's chat functionality requires `ANTHROPIC_API_KEY` (or a mock provider will be used).

## Common Commands

### Development
- `npm run dev` – Start the development server with Turbopack
- `npm run dev:daemon` – Run dev server in background, logging to `logs.txt`

### Building & Deployment
- `npm run build` – Create a production build
- `npm run start` – Start the production server

### Code Quality
- `npm run lint` – Run Next.js ESLint (extends `"next"` config)
- `npm run test` – Run Vitest tests in watch mode (jsdom environment, React plugin, tsconfig‑paths)
- `npm run test -- --run` – Run tests once (no watch mode)
- `npm run test -- src/path/to/test.test.tsx` – Run a specific test file

### Database
- `npm run setup` – Install dependencies and migrate database
- `npm run db:reset` – Reset the SQLite database (force migrate reset)

## Project Architecture

### UI Generator (`skills_tutorial/uigen/`)

**Framework:** Next.js 15 with App Router and React 19. TypeScript with path alias `@/*` mapped to `./src/*`.

**Configuration Files:**
- `postcss.config.mjs` – Uses `@tailwindcss/postcss` plugin (Tailwind CSS v4)
- `vitest.config.mts` – Configures jsdom environment, React plugin, and tsconfig‑paths
- `.eslintrc.json` – Extends `"next"` configuration
- `components.json` – shadcn/ui configuration with aliases (`@/components`, `@/lib/utils`, `@/lib`, `@/hooks`)

**Data Layer:**
- Prisma ORM with SQLite (`prisma/schema.prisma`)
- Global Prisma client instance (`src/lib/prisma.ts`)
- Server Actions (`src/actions/`) for data mutations and authentication

**Authentication:**
- JWT‑based sessions using `jose` library (`src/lib/auth.ts`)
- Cookie‑based token storage with HTTP‑only flags
- Server Actions `signUp`, `signIn`, `signOut`, `getUser` (`src/actions/index.ts`)

**AI Chat & Component Generation:**
- **API Route:** `/api/chat/route.ts` – Core chat endpoint using AI SDK, virtual file system, and tool calls (maxDuration: 120 seconds)
- **Language Model Provider:** `src/lib/provider.ts` – Returns either Anthropic Claude Haiku model or a mock provider (when no API key is set). The mock provider generates example components (Counter, Form, Card) with step‑by‑step tool calls.
- **Tools:**
  - `src/lib/tools/str‑replace.ts` – String replacement editor for file modifications
  - `src/lib/tools/file‑manager.ts` – File creation/deletion operations
- **Virtual File System:** `src/lib/file‑system.ts` – In‑memory file system with serialization/deserialization
- **JSX Transformer:** `src/lib/transform/jsx‑transformer.ts` – Transforms JSX/TSX for browser preview using Babel; creates import maps and blob URLs
- **Generation Prompt:** `src/lib/prompts/generation.tsx` – System prompt that instructs the AI to create React components with Tailwind, use `@/` import aliases, and ensure a root `/App.jsx` file
- **Contexts:**
  - `src/lib/contexts/chat‑context.tsx` – React context for chat state and AI SDK integration
  - `src/lib/contexts/file‑system‑context.tsx` – Manages virtual file system state

**UI Components:**
- Shadcn/ui‑inspired components built with Radix primitives (`src/components/ui/`)
- Monaco editor integration (`src/components/editor/CodeEditor.tsx`)
- Resizable panels (`react‑resizable‑panels`)
- Chat interface components (`src/components/chat/`)
- Preview frame with live component rendering (`src/components/preview/PreviewFrame.tsx`)

**Anonymous Work Tracking:**
- `src/lib/anon‑work‑tracker.ts` – Tracks anonymous user sessions using `sessionStorage`; preserves unsaved work across page reloads.

**Testing:**
- Vitest with React Testing Library
- Test files co‑located with components and utilities (e.g., `__tests__/` folders)

### Model Configuration Scripts (`model_change/`)

Two scripts are provided to route Claude Code through alternative AI providers:

- `minimax‑m2.sh` – Configures Claude Code to use the MiniMax provider
- `deepseek.sh` – Configures Claude Code to use the DeepSeek provider

Usage (run before launching Claude Code):
```bash
source model_change/deepseek.sh   # or minimax-m2.sh
claude
```

### Skill Template (`skills_tutorial/your-skill-name/`)

A template for creating custom Claude Code skills. Includes:
- `SKILL.md` – Skill definition with steps, examples, and troubleshooting
- `scripts/` – Example Python and shell scripts (`process_data.py`, `validate.sh`)
- `assets/` and `references/` – Supporting materials

## Important Paths

- `skills_tutorial/uigen/src/actions/` – Server Actions for data operations
- `skills_tutorial/uigen/src/app/` – Next.js App Router pages and layouts
- `skills_tutorial/uigen/src/components/` – React components (UI, chat, editor, preview)
- `skills_tutorial/uigen/src/lib/` – Core utilities (auth, database, AI tools, file system, contexts, transforms)
- `skills_tutorial/uigen/prisma/` – Database schema and migrations

## Notes

- The SQLite database file is `skills_tutorial/uigen/prisma/dev.db`.
- The Prisma client is generated into `src/generated/prisma/`.
- All API keys are read from environment variables; never commit them.
- The project uses `node‑compat.cjs` to handle Node.js compatibility in Next.js (removes `localStorage`/`sessionStorage` globals during SSR).
- The root `.env` file contains API keys for Claude Code and AI providers; ensure it exists before running Claude Code in this repository.
- Test files are co‑located with components; run `npm run test` from the `skills_tutorial/uigen` directory.
- The mock language provider (`src/lib/provider.ts`) generates example components when no `ANTHROPIC_API_KEY` is set. It simulates a multi‑step tool‑call workflow for demonstration purposes.
- The utility `cn()` in `src/lib/utils.ts` merges Tailwind CSS classes using `clsx` and `tailwind‑merge`.
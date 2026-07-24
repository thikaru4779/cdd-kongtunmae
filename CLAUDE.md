@AGENTS.md

# CDD Kongtunmae — project spec

The authoritative project spec (business rules, RBAC, data model, roadmap) lives at
`Kongtunmae/claude.md`. Read it before making any product/architecture decision — it
overrides this file's Next.js boilerplate notes on anything product-related.

As of the Vercel + Supabase + GitHub migration (see the approved plan at
`C:\Users\Acer\.claude\plans\sequential-weaving-scroll.md`), the spec's "Tech Stack
(บังคับ)" and "Single File Component" sections are superseded: this is now a Next.js
App Router project on Vercel with Supabase Postgres, not Google Apps Script/Sheets.
Every other business rule in `Kongtunmae/claude.md` (RBAC 7 levels, score-freeze
formula, anti-spam, MOM Quest, Health Check, Ghost Mode, National Template Ready)
still applies.

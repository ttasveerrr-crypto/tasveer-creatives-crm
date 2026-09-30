# Tasveer Creatives CRM

A private agency CRM for clients, invoices, quotations, proposals, agreements, recurring payment schedules, payments, expenses, templates and editable WhatsApp reminders.

## Stack
Next.js + React + Tailwind + Supabase + @react-pdf/renderer.

## Setup
1. Create a Supabase project.
2. Run `supabase/schema.sql` in Supabase SQL Editor.
3. Copy `.env.example` to `.env.local` and add your Supabase URL and anon key.
4. Run `npm install` then `npm run dev`.
5. Open `/setup` for the first owner account.
6. Deploy to Netlify with the same environment variables. The included `netlify.toml` configures the build command and Node version.

## Authentication
The first user created through `/setup` becomes the owner. The app uses Supabase Auth email/password. Never hard-code a password.

## Storage
Logo, signature and client logos use a private Supabase Storage bucket. PDFs are generated on demand and are not permanently stored.

## Notes
This is a production-oriented starter implementation. Review legal agreement wording with a lawyer for your jurisdiction before relying on it as a legal contract.

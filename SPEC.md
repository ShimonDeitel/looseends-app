# Loose Ends — AI Brain Dump Sorter

**App Store Title:** Loose Ends - Brain Dump Sorter
**Subtitle:** Speak it out, watch it sort itself
**Category:** Productivity / ADHD

## Problem

People with ADHD (and plenty without it) carry a running loop of half-formed
tasks, appointments, groceries, and people to follow up with, and the mental
tax of *filing* each one — deciding what kind of thing it is and where it
goes — is often the actual blocker, not the doing. r/ADHD: "I wish there was
an app that would take the mental load of remembering everything" — 2,400
upvotes, 205 comments, the strongest single signal in this batch's research
pass. The App Store already has a swarm of very new, very thin attempts at
this (Offload ADHD Organizer, ADHD Notes: AI Brain Dump, BrainDump AI), each
sitting at 0-2 ratings — a validated niche with no established winner.

## What it is

One unstructured capture box. Speak or type whatever's cluttering your head
and hit capture — no menu, no category picker, no friction. Pro auto-triages
each fragment into the right bucket (reminder / calendar / shopping /
follow-up) with whatever structured details it can find (a date/time, an
item name, a person's name), with zero manual filing. Free tier still gets
the same capture box and the same satisfying snap-into-place animation, but
files each fragment into a bucket you pick yourself with a tap.

## Quirky feature — the honesty check

Loose Ends is only useful if closing a loop in the app matches actually
closing it in real life, so it checks. The next time you open the app after
a check-in period has quietly elapsed on a given item, it surfaces one
specific, direct yes/no question about that exact item — "Did you call the
dentist?" — generated in plain language by the AI proxy from what was
originally captured. Answering builds a lightweight, deliberately
un-gamified honesty streak: a current streak of consecutively-closed loops,
plus a plain "N closed, M let go" count. No badges, no confetti, no fake
rewards — just an honest number that goes up or resets based on what you
actually tell it.

## Free vs Pro

**Free:**
- Unlimited capture (type or speak)
- The full scattered-sticky-note-to-bin snap animation
- Manual filing — tap a captured fragment, pick one of the four buckets
  yourself
- All four bins, full history

**Loose Ends Pro — `com.shimondeitel.looseends.pro.monthly`, $5.99/month,
auto-renewable:**
- AI auto-triage — every captured fragment is classified and filed
  automatically, with extracted date/time, item name, and person's name
  where the text supports it, no manual filing step at all
- Proactive check-ins — the honesty-check questions described above
- The honesty-streak tracker

Pro status is read live from `Transaction.currentEntitlements` every time it
matters — never cached as a trusted flag.

## Screens

1. **Capture** (main) — a deep-charcoal canvas. A capture bar at the top
   (type or hold the mic to speak) and a lime "Capture" button. Below it, a
   loose scatter zone where every newly captured, not-yet-filed fragment
   appears as a rotated sticky note. Four bins run across the bottom —
   Reminders, Calendar, Shopping, Follow-ups — each showing its running
   count. Pro fragments auto-file within about a second of capture; free
   fragments wait for a tap, which opens a small four-way bucket picker.
   Either path ends the same way: the note's position and rotation animate
   to zero as it snaps into its bin with a spring.
2. **Bucket detail** (sheet, tap a bin) — every item filed in that bucket:
   raw text, extracted fields if any, capture date, and check-in status.
3. **Check-in** (sheet, surfaces automatically on open when something's
   due, Pro only) — one specific yes/no question at a time with Yes/No
   buttons; answering advances to the next due item or dismisses.
4. **Honesty** (sheet, tap the streak badge, Pro only) — current streak,
   total closed, total let go, in plain numerals, no charts or gamification.
5. **Paywall** (sheet) — benefit list, price, subscribe, restore.
6. **Settings** (gear sheet) — Pro section (CTA + restore), Data (erase
   all, on-device note), About (privacy link + version).

## Signature moment (animation hook)

A newly captured thought lands on the capture screen as a small, slightly
rotated, sticky-note-like fragment — dropped in at a loosely scattered
position with a subtle paper-fold corner and a soft shadow, just like a
real scrap of paper tossed onto a desk. Within about a second (immediately
for Pro once triage returns, on a tap for Free), that same fragment is
visibly pulled — like a magnet snapping a scrap of paper flat — into its
labeled bin at the bottom: a spring-driven animation that drives both its
screen position and its rotation to zero simultaneously. The chaos-to-order
snap *is* the payoff, not a side effect of navigating away.

## AI feature

Calls the shared, keyless proxy at
`https://apps-ai-proxy.s0533495227.workers.dev`.

- **Triage** (`POST /text`): the raw captured string (plus a reference
  timestamp) goes to the model with instructions to return a single JSON
  object — `bucket` (reminder/calendar/shopping/followup), `itemName`,
  `personName`, `date` — as plain text. The client parses leniently: it
  hunts for the outermost `{...}` even if the model wraps it in markdown,
  tolerates missing or unrecognized fields, and if parsing fails outright
  for any reason, the fragment is never lost — it defaults to the
  Follow-up bucket with no extracted fields rather than silently vanishing.
- **Check-in question** (`POST /text`, separate call): given one stored
  item's raw text and any extracted fields, the model writes one short,
  direct, plain-language yes/no question about it. If the network call
  fails, a client-built fallback question ("Did you take care of: ...?")
  is used instead so the check-in flow never stalls.

## Design

Electric lime green against deep charcoal — the most saturated, highest-
energy palette in this batch (every sibling app in the Animated Ten uses a
muted, desaturated palette by comparison). Shapes are literal sticky notes:
lime rounded rectangles with a folded top corner, a soft drop shadow, and a
few degrees of random rotation per card, scattered loosely across the
canvas until they snap into clean, rectangular, lime-outlined bins. Kinetic
and a little chaotic by design — the opposite of every other calm,
muted-palette app in this line.

- Background (deep charcoal): `#121214`
- Panel charcoal: `#1C1E21`
- Bin charcoal (unfilled bin fill): `#24272B`
- Hairline: `#33373C`
- Lime (primary accent, note fill, bin outlines): `#D7FF3E`
- Lime bright (glow / capture button / highlights): `#EAFF8C`
- Lime deep (fold shade, pressed state, shadow-on-lime): `#9FCC00`
- Ink (text on lime notes): `#14150F`
- Off-white (text on charcoal): `#F4F5F0`
- Muted text on charcoal: `#9BA39B`

Typography: bold system rounded for the capture button and bin labels,
regular system for body/note text — nothing serif, nothing delicate. This
is a kinetic, high-energy app, not a calm one.

## Data model

- `Item` (Codable): raw captured text, capture date, optional `Bucket`
  (nil while unfiled), optional extracted date/item name/person name,
  a `CheckInStatus` (none/asked/answeredYes/answeredNo) plus timestamps.
- Persisted via `UserDefaults` as JSON — no account, no server-side store.
  The AI proxy sees a single raw string per call and returns text; it does
  not retain anything.
- Pure logic, fully unit-tested:
  - `TriageParser` — lenient JSON-in-text parsing with the never-lose-it
    fallback.
  - `CheckInScheduler` — computes which items are due for a check-in given
    the current time (fixed default delay for undated items, a
    date-aware delay when an item carries an extracted date).
  - `HonestyEngine` — computes the current streak and closed/let-go totals
    from an ordered list of check-in answers.

## Permissions

Microphone + on-device speech recognition (to turn spoken capture into
text — transcription happens entirely on-device via `SFSpeechRecognizer`
with `requiresOnDeviceRecognition` where supported; only the resulting
text, never audio, is ever sent anywhere). No camera, location, contacts,
or push notifications.

## Distinctness note

Loose Ends owns "kinetic chaos-to-order": the only app in this batch where
the animation hook is itself the entire value proposition made visible, and
the only saturated, high-energy palette among nine otherwise muted sibling
apps (Driftwake's ember-indigo, Ebbline's aqua-teal, Skeinmap's mustard-
rust, Vantage's graphite-red, Furecast's sage-coral, Handoff's lavender-
stone, Dossier's beige-plum, Kitchenline's court blue-yellow, Stirline's
navy-neon).

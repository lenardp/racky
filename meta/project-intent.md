# Project Intent

Racky is an app where users store photos of their garments and get outfit suggestions. Outfit suggestions follow two principles:

- **High cohesion** — most pieces share a lot of tags in common
- **A little POP** — a few pieces sharply contrast with the rest

---

## Architecture Overview

Event-driven microservices, all dockerized. Stack: Ruby on Rails, Node.js, React.js, Python, Kafka, MySQL, AWS S3, Claude API.

### Services

| Service | Stack | Role |
|---|---|---|
| **racky-gateway** | Node.js / Express | Lean API gateway — all HTTP traffic goes through here |
| **racky-lookbook** | React.js | Frontend |
| **racky-monolith** | Ruby on Rails / MySQL | Core data, auth, outfit generation |
| **racky-tagger** | Python | Talks to Claude API to tag garments |

### Kafka Queues

- **Untagged Garments** — triggered when a new garment is uploaded
- **Tagged Garments** — triggered when racky-tagger finishes analyzing a garment

---

## racky-gateway

Thin Node.js/Express proxy. Routes:

- `GET/POST/PUT/DELETE /api/v1/garments` → racky-monolith
- `POST /api/v1/outfits/generate` → racky-monolith
- `/ping`
- Everything else → racky-lookbook

---

## racky-lookbook

React frontend using the "ducks" pattern with sagas (inspired by `../racky-old/racky-dover/`). Four pages:

- Login
- Home (links to garment upload and outfit generator)
- Garment upload (mobile-friendly photo upload)
- Outfit generator

---

## racky-monolith

Rails app organized by domain instead of the default Rails structure, so domains can be split into separate services later. Domains should barely touch each other's classes.

### Directory structure

```
apps/
  closets/
    controllers/
    models/
    services/
    tests/
  accounts/
    controllers/
    models/
    services/
    tests/
config/
lib/
db/
```

### Models

**closets domain**

- **Garment** — a piece of clothing
  - `id` (UUID), `image_url` (nullable), `name` (nullable), `layer` (1–4), `user_id`
  - Layer scale: 1 = base (t-shirt, leggings), 2 = standalone (button-up, dress), 3 = over layers (jacket), 4 = outerwear only (winter coat)
- **Tag** — a vibe descriptor (e.g. `blue`, `denim`, `punk`, `oversized`, `techwear`, `streetwear`, `90's`, `formal`, `dark`, `soft`, ...)
- **TagContrast** — pairs of contrasting tags (e.g. light/dark, cool/warm, formal/casual, tough/soft, oversized/skinny, wide/narrow)
- **GarmentTag** — join: Garment ↔ Tag
- **BodyZone** — `torso`, `legs`, `feet`, `head`, `neck`, `hands`
- **BodyZoneGarment** — join: Garment ↔ BodyZone

**accounts domain**

- **User** — standard auth fields (id, email, password digest, timestamps)
- **Session** / token handling as needed

### Behavior

**On `POST /api/v1/garments`:**
1. Create a bare Garment record (no tags, no body zones yet)
2. Push garment info to the **Untagged Garments** queue

**On `Tagged Garments` event:**
- Update the Garment with name, layer, tags, and body zones from the event

**On `POST /api/v1/outfits/generate`:**
Build an outfit from the user's wardrobe using tag logic (no AI — saving tokens):

- Must cover the basics: torso (layer 1 or 2), legs (layer 1 or 2), feet (layer 2+)
- **High cohesion** — many tags in common across pieces
- **A little POP** — a few pieces have tags that contrast (via TagContrast) with the dominant tags
- Accessories can be added to tune cohesion/POP balance
- Response lists all garments in the outfit

---

## racky-tagger

Python service that listens to the **Untagged Garments** queue. On each event:

1. Upload garment photo to S3
2. Send a Claude prompt with the photo, asking for:
   - Layer number
   - Applicable tags (from the known tag list)
   - Body zones covered
   - Response in JSON
3. Parse the response and publish to the **Tagged Garments** queue

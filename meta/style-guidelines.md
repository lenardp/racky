# Style Guidelines

## General

- Code should read like plain English.
- Max 3–5 lines per method wherever possible.
- Max 80 characters per line wherever possible.
- Prefer short, descriptive names over abbreviations or meaningless ones.
- Prefer composition over inheritance. Call things explicitly rather than pulling in behavior via `include` or `extend`.
- Never depend on invisible functionality. Behavior should be obvious to a first-time reader.
- Every method should illustrate what it does from start to end — no surprises, no side paths the reader has to hunt for.
- One thing per line. Split blocks over multiple lines unless the block content is trivial.
- Prefer early return over nested if/else.
- Prefer keyword arguments when a method takes more than one parameter.

## Objects and responsibilities

- Classes that represent things (models, value objects, etc.) should only expose simple facts about themselves.
- Any behavior that *does* something belongs in a service.

## Error handling

- Any method that calls a `!` method without rescuing must itself end in `!`. This propagates the signal that errors can escape, making it visible to callers without reading the implementation.

## Private method ordering

- Order private methods from highest to lowest level of abstraction. The highest-level methods are called directly by `call`/`call!`; the lowest-level ones call nothing else private.

## Services

- Service names are nouns describing what the service does.
- Public interface is the initializer and `call` (or `call!`) only.
- Use `call` if the service handles all errors internally. Use `call!` if errors can escape.
- `initialize` only assigns instance variables. It never does work.
- `call`/`call!` illustrates what the service does at a high level, start to end. It reads like plain English — no variables, no loops, no operators, no direct service calls, minimal conditionals.
- Max 100 lines per service. If a service grows beyond that, it can likely be split into smaller ones.
- Specs for a service test only `call`/`call!`. Everything else is a black box.

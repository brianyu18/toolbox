# Node.js Backend Conventions

## Stack overview

Node 20+, TypeScript, ESM modules. Web frameworks: Express (legacy), Fastify (preferred for new), Hono (edge/lightweight).

## Conventions

- **TypeScript strict mode on** (`"strict": true` in tsconfig).
- **ESM imports**, no CommonJS in new code.
- **Async/await everywhere**, no callback APIs in new code.
- **Validate at boundaries** — Zod / Valibot for request validation; trust internal calls.
- **Layer the app**: routes → handlers → services → repositories.
- **Centralized error handling** — middleware/hook that maps domain errors → HTTP responses.
- **Structured logging** (Pino) with request IDs; never console.log in prod paths.

## Anti-patterns

- **Don't put business logic in route handlers** — routes wire HTTP to services.
- **Don't catch-and-ignore** errors — log + rethrow or handle explicitly.
- **Don't `process.env.X` deep in code** — read once at startup, pass typed config.
- **Don't use synchronous fs/crypto in request paths** — blocks the event loop.
- **Don't mix promise chains and async/await** in the same function.

## Test patterns

- Vitest or Jest. Vitest preferred for ESM-native projects.
- Test public API of services, not private methods.
- Use real DB (test container or in-memory equivalent) over heavy mocking when possible.
- Integration tests for routes with supertest / fastify-inject.

## Common pitfalls

- Unhandled promise rejections crash modern Node — always `await` or `.catch`.
- `JSON.parse` on user input throws synchronously — wrap or validate.
- `process.exit()` in libraries — leave it to the entry point.

## References

- [Node.js docs](https://nodejs.org/docs/latest/api/)
- [Fastify docs](https://fastify.dev/docs/latest/)
- [Pino](https://getpino.io/)
- [Zod](https://zod.dev)

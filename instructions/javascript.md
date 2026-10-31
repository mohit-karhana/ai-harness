---
description: JavaScript and TypeScript standards for typing, modules, async code, configuration and dependencies.
globs: **/*.js,**/*.jsx,**/*.ts,**/*.tsx,**/*.mjs,**/*.cjs,**/package.json
alwaysApply: false
---
# JavaScript / TypeScript Standards

## Language choice
- If the project uses TypeScript, write all new code in TypeScript. Do not add new
  `.js` files to a TS codebase.
- Respect `tsconfig.json` strictness; never loosen compiler options to fix an error.
- Match the module system in use (ESM `import` vs CommonJS `require`); don't mix.

## Tooling
- Use the project's ESLint and Prettier config; fix lint errors instead of disabling
  rules. A disable comment needs a reason: `// eslint-disable-next-line no-console -- CLI output`.
- Use the package manager indicated by the lock file (`package-lock.json` → npm,
  `yarn.lock` → yarn, `pnpm-lock.yaml` → pnpm). Never commit a second lock file.

## Types
- No `any`. Use `unknown` and narrow, or define proper types.
- Model domain types explicitly; prefer union literal types over loose strings:
  `type PolicyStatus = "active" | "lapsed" | "cancelled"`.
- Validate external data at runtime (API responses, form input, env) with the project's
  schema library (zod, yup, io-ts) — TS types don't exist at runtime.
- Avoid non-null assertions (`!`) and `as` casts; narrow instead.

```ts
// Don't
const data: any = await res.json();
// Do
const data = PolicySchema.parse(await res.json());
```

## Code style
- `const` by default, `let` when reassigned, never `var`.
- Prefer immutability: spread/`map`/`filter` over mutating shared objects or arrays.
- Strict equality (`===`) only.
- Small pure functions; avoid classes unless the codebase uses them.
- Named exports preferred (unless the project convention is default exports).
- No magic strings for routes, keys or events; centralize constants.
- Use `Intl.NumberFormat`/the project helper for money; never do currency math with
  floating point — use integer minor units (paise/cents) or a decimal library.

## Async
- `async/await` over raw promise chains. Always handle rejections: `try/catch` at the
  boundary, or let the caller handle it deliberately.
- No floating promises; `await` them or explicitly `void` them with a comment.
- Use `Promise.all` for independent work; `Promise.allSettled` when partial failure is OK.
- Add timeouts/abort signals (`AbortController`) to network requests.

## Errors
- Throw `Error` subclasses, never strings. Preserve cause: `new Error("msg", { cause })`.
- Don't swallow errors in `catch {}`; log via the project logger without PII.

## Configuration and environment
- Read config from environment through a single validated config module.
- Frontend: only variables with the framework's public prefix (`VITE_`,
  `NEXT_PUBLIC_`, `REACT_APP_`) reach the browser — never put secrets there.
- Never commit `.env` files; update `.env.example` with placeholder values.

## Node.js services
- Validate request bodies at the edge; centralized error middleware.
- Never use `eval`, `new Function`, or `child_process.exec` with user input
  (`execFile` with args if a subprocess is necessary).
- Handle `SIGTERM` for graceful shutdown; close DB pools and servers.

## Dependencies
- Justify every new package (size, maintenance, license, alternatives). Prefer
  platform APIs (`fetch`, `structuredClone`, `Intl`) over utility packages.
- Install with exact/project-standard version ranges; commit the lock file.
- Run `npm audit` (or equivalent) for new/updated packages; don't add packages with
  known critical vulnerabilities.

## Testing
- Use the project's runner (Jest/Vitest/Mocha). Co-locate tests per project convention.
- Mock network at the boundary (MSW or the project's approach), not internal modules.

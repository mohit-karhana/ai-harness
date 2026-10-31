---
description: React standards for components, hooks, state, data fetching, accessibility and testing.
globs: **/*.jsx,**/*.tsx
alwaysApply: false
---
# React Standards

## Components
- Function components with hooks only; no new class components.
- One component per file for exported components; name file after component
  (`PolicyCard.tsx`). Follow the project's folder convention (feature folders vs
  `components/`).
- Keep components small and focused; extract subcomponents or custom hooks when a
  component mixes data fetching, business logic and presentation.
- Type props explicitly (TS interfaces/types or PropTypes per project). Avoid prop
  drilling beyond 2–3 levels; use composition or the project's context/state library.
- Use the project's design system/UI library before writing custom components.

## Hooks
- Follow the Rules of Hooks: top level only, never in conditions/loops.
- Keep `react-hooks/exhaustive-deps` satisfied; don't silence it — restructure instead.
- Extract reusable logic into `useXxx` hooks with clear inputs/outputs.

## State
- Colocate state with the component that uses it; lift only when shared.
- Don't store derived data in state; compute it during render.
- Server data belongs in the project's data-fetching cache (React Query/SWR/RTK Query),
  not duplicated into local state or global stores.
- Global state (Redux/Zustand/Context) only for truly global client state.

## Effects
- `useEffect` is for synchronizing with external systems, not for deriving state or
  handling events. Handle user actions in event handlers.
- Always clean up subscriptions, timers and listeners; abort in-flight requests.

```tsx
// Don't
const [fullName, setFullName] = useState("");
useEffect(() => setFullName(`${first} ${last}`), [first, last]);

// Do
const fullName = `${first} ${last}`;
```

## Data fetching
- Use the project's API client and fetching library; never call `fetch` ad hoc in
  components if a client layer exists.
- Always handle loading, error and empty states in the UI.
- Never put access tokens or PII in URLs, `localStorage`, or logs.

## Rendering and lists
- Stable, unique `key`s from data IDs — never array indexes for dynamic lists.
- Avoid inline object/array literals as props to memoized children only when it
  matters; don't sprinkle `useMemo`/`useCallback`/`React.memo` without a measured
  performance problem (use React DevTools Profiler).
- Lazy-load heavy routes/components with `React.lazy` + `Suspense`.

## Security
- Never use `dangerouslySetInnerHTML` with untrusted content. If HTML rendering is
  required, sanitize with the project's sanitizer (e.g. DOMPurify) and document why.
- Validate `href`s built from data (block `javascript:` URLs).
- No secrets in client code or env vars exposed to the bundle.
- Mask sensitive data (policy numbers, phone, ID numbers) in UI per product rules.

## Forms
- Use the project's form library (React Hook Form/Formik) and schema validation;
  validate on client for UX, but the server is the source of truth.
- Associate labels with inputs; show accessible error messages.

## Accessibility
- Semantic HTML first (`button`, `nav`, `main`, `label`), ARIA only to fill gaps.
- All interactive elements keyboard-accessible with visible focus.
- Images need meaningful `alt` (or `alt=""` if decorative).
- Sufficient color contrast; never convey meaning by color alone.

## Styling
- Follow the existing approach (CSS modules, Tailwind, styled-components). Do not
  introduce a new styling system.

## Testing
- React Testing Library: query by role/label/text as a user would
  (`getByRole("button", { name: /submit claim/i })`), not by class names or test IDs
  unless necessary.
- Use `user-event` for interactions; mock the network (MSW) rather than hooks.
- Test loading, error and empty states and permission-dependent UI.

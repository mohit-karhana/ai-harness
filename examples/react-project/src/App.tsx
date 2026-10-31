import { ClaimStatusBadge } from "./components/ClaimStatusBadge";

export default function App() {
  return (
    <main>
      <h1>My claims</h1>
      <ClaimStatusBadge status="in_review" />
    </main>
  );
}

export type ClaimStatus = "submitted" | "in_review" | "approved" | "rejected";

const LABELS: Record<ClaimStatus, string> = {
  submitted: "Submitted",
  in_review: "In review",
  approved: "Approved",
  rejected: "Rejected",
};

export function ClaimStatusBadge({ status }: { status: ClaimStatus }) {
  return (
    <span className={`badge badge--${status}`} role="status">
      {LABELS[status]}
    </span>
  );
}

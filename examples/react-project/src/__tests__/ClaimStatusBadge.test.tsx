import { render, screen } from "@testing-library/react";
import { expect, test } from "vitest";
import { ClaimStatusBadge } from "../components/ClaimStatusBadge";

test("renders a readable label for the status", () => {
  render(<ClaimStatusBadge status="in_review" />);
  expect(screen.getByRole("status").textContent).toBe("In review");
});

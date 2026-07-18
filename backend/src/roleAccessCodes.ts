import type { RoleName } from "./permissions.js";

/**
 * Static per-role signup codes. A captain hands the relevant code to a new
 * member (e.g. the team's Finance chair gets the FINANCE code) so they can
 * self-select that role during onboarding — every role requires one,
 * including Returner/Newbie, so signup is fully gated to people who were given
 * a code. Change these before sharing the app with the team, and rotate them
 * if a code leaks.
 */
export const ROLE_ACCESS_CODES: Record<RoleName, string> = {
  CAPTAIN: "RAGA-CAPTAIN",
  FINANCE: "RAGA-FINANCE",
  PRODUCTION: "RAGA-PRODUCTION",
  LOGISTICS: "RAGA-LOGISTICS",
  PR: "RAGA-PR",
  RETURNER: "RAGA-RETURNER",
  NEWBIE: "RAGA-NEWBIE",
};

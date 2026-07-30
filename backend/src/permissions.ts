// Central permission matrix for Ru RAGA. Every route imports from here rather
// than encoding role checks ad hoc — this file is the one place to audit or
// change the matrix. See team-app-prd.md's role-permission spec for the
// source rules.
//
// Two layers:
//   - Layer 1 (static): pure functions of role only.
//   - Layer 2 (contextual): need request-time data (the fetched record, or
//     the acting user's own id), so they take that data as explicit
//     arguments. Route handlers fetch the record, then call the guard, then
//     403 if it returns false — the DB fetch always has to happen anyway, so
//     there's no value hiding this behind middleware.
//
// Honest limitation: for rules that say a role shouldn't even know a feature
// exists (choreo/formation reminders), the server can only return a uniform
// 403/404 to any other role — it can't hide route existence from someone
// probing the API directly, since there's no real authentication yet to gate
// API discovery behind. True invisibility (no nav entry, no fetch issued) is
// enforced client-side. See ios/RagaApp/Views/Components/ChoreoReminderWidgetsView.swift.

export type RoleName = "CAPTAIN" | "FINANCE" | "PRODUCTION" | "LOGISTICS" | "PR" | "RETURNER" | "NEWBIE";

export const ALL_ROLES: RoleName[] = ["CAPTAIN", "FINANCE", "PRODUCTION", "LOGISTICS", "PR", "RETURNER", "NEWBIE"];

// --- Layer 1: static role -> capability facts -------------------------------

export function canManageFines(role: RoleName): boolean {
  return role === "CAPTAIN" || role === "FINANCE";
}

export function canManageQuotas(role: RoleName): boolean {
  return role === "CAPTAIN" || role === "FINANCE";
}

export function canManageFundraising(role: RoleName): boolean {
  return role === "CAPTAIN" || role === "FINANCE";
}

export function canManageFineSchedule(role: RoleName): boolean {
  return role === "CAPTAIN" || role === "FINANCE";
}

export function canAccessCompApplications(role: RoleName): boolean {
  return role === "CAPTAIN" || role === "LOGISTICS";
}

export function canAccessPracticePlanner(role: RoleName): boolean {
  return role === "CAPTAIN";
}

export function canAccessChoreoReminders(role: RoleName): boolean {
  return role === "CAPTAIN";
}

export function canEditTeamInfo(role: RoleName): boolean {
  return role === "CAPTAIN" || role === "FINANCE" || role === "PRODUCTION" || role === "LOGISTICS";
}

export function canManageRoles(role: RoleName): boolean {
  return role === "CAPTAIN";
}

export type PropsCostumesMode = "FULL" | "BUDGET_ONLY" | "OWN_ASSIGNMENTS_ONLY" | "NONE";

export function propsCostumesAccess(role: RoleName): PropsCostumesMode {
  switch (role) {
    case "CAPTAIN":
    case "PRODUCTION":
      return "FULL";
    case "FINANCE":
      return "BUDGET_ONLY";
    case "LOGISTICS":
      return "NONE";
    case "PR":
    case "RETURNER":
    case "NEWBIE":
      return "OWN_ASSIGNMENTS_ONLY";
  }
}

// --- Layer 2: contextual guards ---------------------------------------------

export type CategoryName = "FINANCE" | "PRACTICE" | "CAPTAINS" | "PRODUCTION" | "SOCIAL" | "LOGISTICS";

/** Categories on CalendarEvent that map to a role's "own" events. Other
 * categories (PRACTICE/CAPTAINS) are Captain-only to edit — there's
 * deliberately no separate `ownerRole` field on CalendarEvent; the category
 * itself is the single source of truth for both calendar-edit and
 * attendance-edit checks. PR owns SOCIAL (the PR/social chair role runs the
 * team's social calendar) rather than a same-named category. */
export function categoryOwnerRole(category: string): RoleName | null {
  if (category === "FINANCE" || category === "PRODUCTION" || category === "LOGISTICS") {
    return category;
  }
  if (category === "SOCIAL") return "PR";
  return null;
}

/** The single category a role "owns" for auto-scoping content it creates
 * (calendar events, reminders) — everyone else is either Captain (free pick
 * of any category) or has no create access at all. */
export function ownedCategory(role: RoleName): CategoryName | null {
  switch (role) {
    case "FINANCE": return "FINANCE";
    case "PRODUCTION": return "PRODUCTION";
    case "LOGISTICS": return "LOGISTICS";
    case "PR": return "SOCIAL";
    default: return null;
  }
}

/** Reminders (Roundup tab): Captains and board positions (Finance/Production/
 * Logistics/PR) can create; Returners/Newbies can only view and interact
 * (RSVP, mark done). */
export function canCreateReminder(role: RoleName): boolean {
  return role === "CAPTAIN" || role === "FINANCE" || role === "PRODUCTION" || role === "LOGISTICS" || role === "PR";
}

/** Any board position (Captain or Finance/Production/Logistics/PR) can
 * delete any notification — reminder or announcement, pinned or not,
 * regardless of who created it. Returners/Newbies can never delete,
 * matching their lack of create access. */
export function isBoardRole(role: RoleName): boolean {
  return role === "CAPTAIN" || role === "FINANCE" || role === "PRODUCTION" || role === "LOGISTICS" || role === "PR";
}

/** Pinning a chat message is a moderation action, same board-only bar as
 * deleting a notification — everyone can post/react in Chat, but only board
 * positions can pin/unpin. */
export function canPinChatMessage(role: RoleName): boolean {
  return isBoardRole(role);
}

/** The AI announcement-drafting assistant is a board tool (for writing
 * official team communications), same bar as pinning/deleting — everyone can
 * still post/react in Chat without it. */
export function canUseAiAssistant(role: RoleName): boolean {
  return isBoardRole(role);
}

/** `createdById`/`currentUserId` are only relevant for categories with no
 * role owner (currently just REMINDER, personal-reminder-linked events) —
 * the creator can always edit/delete their own event regardless of role. */
export function canEditCalendarEvent(
  role: RoleName,
  category: string,
  createdById?: string | null,
  currentUserId?: string
): boolean {
  if (role === "CAPTAIN") return true;
  if (categoryOwnerRole(category) === role) return true;
  return createdById != null && createdById === currentUserId;
}

export function canEditAttendance(role: RoleName, eventCategory: string): boolean {
  if (role === "CAPTAIN") return true;
  if (role === "PRODUCTION") return categoryOwnerRole(eventCategory) === "PRODUCTION";
  return false;
}

/** Practice attendance (present/absent/late) is Captain-only to mark —
 * Practice has no owning board role the way CalendarCategory does. */
export function canEditPracticeAttendance(role: RoleName): boolean {
  return role === "CAPTAIN";
}

export function canPostAnnouncement(role: RoleName, audienceRole: RoleName | null): boolean {
  if (role === "CAPTAIN") return true;
  if (role === "FINANCE" || role === "PRODUCTION" || role === "LOGISTICS") {
    return audienceRole === role;
  }
  return false;
}

export function canViewFine(role: RoleName, fine: { userId: string }, currentUserId: string): boolean {
  if (isBoardRole(role)) return true;
  return fine.userId === currentUserId;
}

export function canViewQuota(role: RoleName, quota: { userId: string }, currentUserId: string): boolean {
  if (isBoardRole(role)) return true;
  return quota.userId === currentUserId;
}

export type CompSection = "FINANCE" | "PRODUCTION" | "LOGISTICS";

export function canEditCompSection(role: RoleName, section: CompSection): boolean {
  if (role === "CAPTAIN") return true;
  return role === section;
}

export function editableCompSection(role: RoleName): CompSection | "ALL" | null {
  if (role === "CAPTAIN") return "ALL";
  if (role === "FINANCE") return "FINANCE";
  if (role === "PRODUCTION") return "PRODUCTION";
  if (role === "LOGISTICS") return "LOGISTICS";
  return null;
}

// --- Assembled capabilities for GET /me -------------------------------------
// Coarse, role-only shape used purely for nav/UI-affordance decisions (show
// or hide a menu row, show or hide a "+" button). Per-item mutation gating
// (e.g. "can I edit *this* calendar event") always goes through the Layer 2
// functions above on both client-embedded `canEdit` flags and server route
// checks, never through this object alone.

export interface Capabilities {
  calendar: { canEditAny: boolean; editableCategory: RoleName | null };
  attendance: { canEditAny: boolean; editableCategory: RoleName | null };
  practiceAttendance: { canManageAny: boolean };
  announcements: { canPostTeamWide: boolean; ownChannelRole: RoleName | null };
  videos: { canUpload: true };
  practicePlanner: { canAccess: boolean };
  choreoReminders: { canAccess: boolean };
  // Used by both the Chat composer and the Announcements composer's
  // "Draft with AI" button — kept top-level rather than nested under `chat`
  // since it isn't chat-specific.
  aiAssistant: { canAccess: boolean };
  propsCostumes: { mode: PropsCostumesMode };
  // Board roles (Captain/Finance/Production/Logistics/PR) can view every
  // record in these finance-area domains; everyone else falls back to
  // seeing only their own quota/fine, unchanged from before this field
  // existed (fundraising has no "own record" concept, so non-board members
  // see nothing there). Only Captain/Finance can create/edit regardless.
  fines: { canViewAny: boolean; canManageAny: boolean };
  quotas: { canViewAny: boolean; canManageAny: boolean };
  fundraising: { canViewAny: boolean; canManageAny: boolean };
  fineSchedule: { canViewAny: boolean; canManageAny: boolean };
  compApplications: { canAccess: boolean };
  competitionDashboard: { editableSection: CompSection | "ALL" | null; canViewSchedule: boolean };
  teamInfo: { canEdit: boolean };
  roleManagement: { canAccess: boolean };
  reminders: { canCreate: boolean; lockedCategory: CategoryName | null };
  notifications: { canDeleteAny: boolean };
  chat: { canPinAny: boolean };
}

export function buildCapabilities(role: RoleName): Capabilities {
  const ownChannelRole = role === "FINANCE" || role === "PRODUCTION" || role === "LOGISTICS" ? role : null;
  const editableCategory = categoryOwnerRoleForSelf(role);

  return {
    calendar: { canEditAny: role === "CAPTAIN", editableCategory },
    attendance: { canEditAny: role === "CAPTAIN", editableCategory: role === "PRODUCTION" ? "PRODUCTION" : editableCategory },
    practiceAttendance: { canManageAny: canEditPracticeAttendance(role) },
    announcements: { canPostTeamWide: role === "CAPTAIN", ownChannelRole },
    videos: { canUpload: true },
    practicePlanner: { canAccess: canAccessPracticePlanner(role) },
    choreoReminders: { canAccess: canAccessChoreoReminders(role) },
    aiAssistant: { canAccess: canUseAiAssistant(role) },
    propsCostumes: { mode: propsCostumesAccess(role) },
    fines: { canViewAny: isBoardRole(role), canManageAny: canManageFines(role) },
    quotas: { canViewAny: isBoardRole(role), canManageAny: canManageQuotas(role) },
    fundraising: { canViewAny: isBoardRole(role), canManageAny: canManageFundraising(role) },
    fineSchedule: { canViewAny: isBoardRole(role), canManageAny: canManageFineSchedule(role) },
    compApplications: { canAccess: canAccessCompApplications(role) },
    competitionDashboard: { editableSection: editableCompSection(role), canViewSchedule: true },
    teamInfo: { canEdit: canEditTeamInfo(role) },
    roleManagement: { canAccess: canManageRoles(role) },
    reminders: { canCreate: canCreateReminder(role), lockedCategory: ownedCategory(role) },
    notifications: { canDeleteAny: isBoardRole(role) },
    chat: { canPinAny: canPinChatMessage(role) },
  };
}

function categoryOwnerRoleForSelf(role: RoleName): RoleName | null {
  return role === "FINANCE" || role === "PRODUCTION" || role === "LOGISTICS" || role === "PR" ? role : null;
}

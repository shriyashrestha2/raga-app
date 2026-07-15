import type { CurrentUser } from "../middleware/currentUser.js";

declare global {
  namespace Express {
    interface Request {
      currentUser?: CurrentUser;
    }
  }
}

export {};

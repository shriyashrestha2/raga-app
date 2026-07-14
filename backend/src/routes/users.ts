import { Router } from "express";
import { prisma } from "../prisma.js";

export const usersRouter = Router();

// Dev-only helper: since the app uses a role toggle instead of real auth,
// the client asks for "the demo user for this role" rather than logging in.
usersRouter.get("/", async (_req, res) => {
  const users = await prisma.user.findMany({ orderBy: { name: "asc" } });
  res.json(users);
});

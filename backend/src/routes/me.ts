import { Router } from "express";
import { requireUser } from "../middleware/currentUser.js";
import { buildCapabilities } from "../permissions.js";

export const meRouter = Router();
meRouter.use(requireUser);

meRouter.get("/", async (req, res) => {
  const user = req.currentUser!;
  res.json({
    id: user.id,
    name: user.name,
    role: user.role,
    capabilities: buildCapabilities(user.role),
  });
});

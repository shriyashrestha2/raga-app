import { Router } from "express";
import { z } from "zod";
import { prisma } from "../prisma.js";
import { initialsOf } from "../util/initials.js";
import { ROLE_ACCESS_CODES } from "../roleAccessCodes.js";
import type { RoleName } from "../permissions.js";

export const authRouter = Router();

const CODE_TTL_MS = 10 * 60 * 1000;

function generateCode(): string {
  return String(Math.floor(100000 + Math.random() * 900000));
}

/**
 * Real SMS delivery needs a paid provider (Twilio or similar) with an
 * account SID/auth token/from-number — none configured yet. Disabled by
 * default: the code is logged to the console and returned in the response
 * instead of texted, so the flow is fully testable today. Flip
 * ENABLE_SMS=true and fill this in once you have provider credentials.
 */
async function sendCode(phone: string, code: string): Promise<void> {
  if (process.env.ENABLE_SMS === "true") {
    throw new Error("ENABLE_SMS=true but no SMS provider is wired up yet — see backend/README.md");
  }
  console.log(`[dev-sms] Verification code for ${phone}: ${code}`);
}

const requestCodeSchema = z.object({
  name: z.string().trim().min(1),
  phone: z.string().trim().min(7),
});

authRouter.post("/request-code", async (req, res) => {
  const parsed = requestCodeSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: parsed.error.flatten() });
  }
  const { name, phone } = parsed.data;
  const code = generateCode();
  const expiresAt = new Date(Date.now() + CODE_TTL_MS);

  await prisma.phoneVerification.upsert({
    where: { phone },
    create: { phone, name, code, expiresAt, verified: false },
    update: { name, code, expiresAt, verified: false },
  });

  await sendCode(phone, code);

  const devMode = process.env.ENABLE_SMS !== "true";
  res.json({ sent: true, devCode: devMode ? code : undefined });
});

const verifyCodeSchema = z.object({
  phone: z.string().trim().min(7),
  code: z.string().trim().min(1),
});

authRouter.post("/verify-code", async (req, res) => {
  const parsed = verifyCodeSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: parsed.error.flatten() });
  }
  const { phone, code } = parsed.data;

  const verification = await prisma.phoneVerification.findUnique({ where: { phone } });
  if (!verification || verification.code !== code) {
    return res.status(400).json({ error: "Incorrect code." });
  }
  if (verification.expiresAt < new Date()) {
    return res.status(400).json({ error: "This code has expired — request a new one." });
  }

  await prisma.phoneVerification.update({ where: { phone }, data: { verified: true } });

  const existingUser = await prisma.user.findUnique({ where: { phone } });
  res.json({ verified: true, user: existingUser });
});

const selectRoleSchema = z.object({
  phone: z.string().trim().min(7),
  role: z.enum(["CAPTAIN", "FINANCE", "PRODUCTION", "LOGISTICS", "PR", "RETURNER", "NEWBIE"]),
  accessCode: z.string().trim().min(1),
});

authRouter.post("/select-role", async (req, res) => {
  const parsed = selectRoleSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: parsed.error.flatten() });
  }
  const { phone, role, accessCode } = parsed.data;

  const verification = await prisma.phoneVerification.findUnique({ where: { phone } });
  if (!verification || !verification.verified) {
    return res.status(401).json({ error: "Verify your phone number first." });
  }

  if (accessCode !== ROLE_ACCESS_CODES[role as RoleName]) {
    return res.status(403).json({ error: "That access code isn't right for this role." });
  }

  const existingUser = await prisma.user.findUnique({ where: { phone } });
  if (existingUser) {
    return res.json(existingUser);
  }

  const user = await prisma.user.create({
    data: {
      name: verification.name,
      initials: initialsOf(verification.name),
      role,
      phone,
    },
  });
  res.status(201).json(user);
});

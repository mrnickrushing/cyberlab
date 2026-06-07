import { Router, type IRouter } from "express";
import OpenAI from "openai";
import { authenticate, type AuthRequest } from "../middleware/authenticate";
import { z } from "zod";

const router: IRouter = Router();

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY ?? "",
});

const AI_MODE_SYSTEM_PROMPTS: Record<string, string> = {
  general: `You are CyberLab AI, a cybersecurity assistant embedded in a personal lab management app.
You help users understand security concepts, interpret scan results, and learn about tools and techniques used in ethical hacking and defensive security.
You are clear, concise, and educational. You use technical terminology appropriately but always explain it.

SAFETY RULES (enforce strictly):
- You ONLY support authorized security testing — personal labs, owned networks, and systems with explicit written authorization.
- If asked about attacking systems the user does not own, decline politely and redirect to authorized lab practice.
- Do not provide step-by-step exploitation instructions for production systems.
- Always remind users that unauthorized scanning violates laws like the CFAA and Computer Misuse Act.
- Focus on understanding, detection, and remediation — not offensive exploitation.`,

  explain: `You are CyberLab AI in "Explain Finding" mode. A security scan has produced a finding and the user wants to understand it.
Your job is to explain:
1. What the vulnerability or issue is (plain English, 1-2 sentences)
2. Why it matters / what an attacker could do with it
3. CVSS context if a score is provided (what the number means)
4. Whether it's commonly exploited in the wild
Keep your explanation to 3-5 short paragraphs. Be direct and educational.
SAFETY: Only explain in the context of understanding and fixing — not exploiting.`,

  summarize: `You are CyberLab AI in "Report Summary" mode. You have been given a security report for a target system.
Write a concise executive summary (3-4 paragraphs) covering:
1. Overall risk posture (risk score and what it means)
2. The most critical issues that need immediate attention
3. Patterns or themes in the findings (e.g., "multiple high-severity web vulnerabilities")
4. A recommended prioritization order for remediation
Be professional and direct. Avoid generic filler text.`,

  remediation: `You are CyberLab AI in "Remediation Advisor" mode. You have been given one or more security findings.
For each finding, provide:
1. A clear, actionable fix (specific commands or configuration changes where possible)
2. Why this fix works
3. Any caveats or prerequisites
4. A verification step to confirm the fix worked
Be specific and practical. Prioritize by severity if multiple findings are present.`,

  study: `You are CyberLab AI in "Lab Study Helper" mode. You help users learn cybersecurity concepts and tools in the context of their personal lab environment.
You explain tools (nmap, nuclei, nikto, etc.), concepts (CVE, CVSS, attack surfaces, etc.), and techniques (reconnaissance, enumeration, exploitation in authorized labs).
Be a patient, encouraging tutor. Use analogies where helpful. Point to official docs or CTF resources when relevant.
SAFETY: Only discuss techniques in the context of authorized lab environments, CTFs, and owned systems.`,
};

const chatSchema = z.object({
  message: z.string().min(1).max(4000),
  mode: z.enum(["general", "explain", "summarize", "remediation", "study"]).default("general"),
  context: z
    .object({
      findingTitle: z.string().optional(),
      findingSeverity: z.string().optional(),
      findingCveId: z.string().optional(),
      findingCvssScore: z.number().optional(),
      findingDescription: z.string().optional(),
      findingRemediation: z.string().optional(),
      reportTargetName: z.string().optional(),
      reportRiskScore: z.number().optional(),
      reportRiskLabel: z.string().optional(),
      reportOpenFindings: z.number().optional(),
      reportBySeverity: z
        .object({
          critical: z.number(),
          high: z.number(),
          medium: z.number(),
          low: z.number(),
          info: z.number(),
        })
        .optional(),
      reportToolsUsed: z.array(z.string()).optional(),
      reportTopFindings: z
        .array(
          z.object({
            title: z.string(),
            severity: z.string(),
            cveId: z.string().nullable().optional(),
          })
        )
        .optional(),
    })
    .optional(),
  history: z
    .array(
      z.object({
        role: z.enum(["user", "assistant"]),
        content: z.string(),
      })
    )
    .max(20)
    .optional(),
});

function buildContextBlock(ctx: NonNullable<z.infer<typeof chatSchema>["context"]>): string {
  const lines: string[] = [];

  if (ctx.findingTitle) {
    lines.push("=== FINDING CONTEXT ===");
    lines.push(`Title: ${ctx.findingTitle}`);
    if (ctx.findingSeverity) lines.push(`Severity: ${ctx.findingSeverity.toUpperCase()}`);
    if (ctx.findingCveId) lines.push(`CVE: ${ctx.findingCveId}`);
    if (ctx.findingCvssScore != null) lines.push(`CVSS Score: ${ctx.findingCvssScore}`);
    if (ctx.findingDescription) lines.push(`Description: ${ctx.findingDescription}`);
    if (ctx.findingRemediation) lines.push(`Existing remediation note: ${ctx.findingRemediation}`);
  }

  if (ctx.reportTargetName) {
    lines.push("=== REPORT CONTEXT ===");
    lines.push(`Target: ${ctx.reportTargetName}`);
    if (ctx.reportRiskScore != null) lines.push(`Risk Score: ${ctx.reportRiskScore}/100 (${ctx.reportRiskLabel})`);
    if (ctx.reportOpenFindings != null) lines.push(`Open Findings: ${ctx.reportOpenFindings}`);
    if (ctx.reportBySeverity) {
      const b = ctx.reportBySeverity;
      lines.push(`By Severity: Critical ${b.critical}, High ${b.high}, Medium ${b.medium}, Low ${b.low}, Info ${b.info}`);
    }
    if (ctx.reportToolsUsed?.length) lines.push(`Tools Used: ${ctx.reportToolsUsed.join(", ")}`);
    if (ctx.reportTopFindings?.length) {
      lines.push("Top Findings:");
      for (const f of ctx.reportTopFindings.slice(0, 10)) {
        lines.push(`  - [${f.severity.toUpperCase()}] ${f.title}${f.cveId ? ` (${f.cveId})` : ""}`);
      }
    }
  }

  return lines.join("\n");
}

// POST /ai/chat
router.post("/ai/chat", authenticate, async (req: AuthRequest, res): Promise<void> => {
  if (!process.env.OPENAI_API_KEY) {
    res.status(503).json({ error: "OPENAI_API_KEY is not configured on this server." });
    return;
  }

  const parsed = chatSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "Invalid input", details: parsed.error.issues });
    return;
  }

  const { message, mode, context, history } = parsed.data;
  const systemPrompt = AI_MODE_SYSTEM_PROMPTS[mode];
  const contextBlock = context ? buildContextBlock(context) : "";

  const messages: OpenAI.Chat.ChatCompletionMessageParam[] = [
    { role: "system", content: systemPrompt },
  ];

  // Inject prior conversation turns
  if (history?.length) {
    for (const turn of history) {
      messages.push({ role: turn.role, content: turn.content });
    }
  }

  // Append context block to the user message if present
  const userContent = contextBlock ? `${contextBlock}\n\n---\n${message}` : message;
  messages.push({ role: "user", content: userContent });

  try {
    const completion = await openai.chat.completions.create({
      model: "gpt-4o-mini",
      messages,
      max_completion_tokens: 1500,
      temperature: 0.4,
    });

    const reply = completion.choices[0]?.message?.content ?? "No response generated.";
    const inputTokens = completion.usage?.prompt_tokens ?? 0;
    const outputTokens = completion.usage?.completion_tokens ?? 0;

    res.json({ reply, mode, inputTokens, outputTokens });
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : "OpenAI request failed";
    res.status(502).json({ error: msg });
  }
});

// GET /ai/status — check if AI is configured
router.get("/ai/status", authenticate, async (_req, res): Promise<void> => {
  res.json({ configured: !!process.env.OPENAI_API_KEY });
});

export default router;

import { Router, type IRouter } from "express";
import { db } from "@workspace/db";
import { notesTable, targetsTable } from "@workspace/db/schema";
import { eq, and, desc, ilike, sql } from "drizzle-orm";
import { authenticate, type AuthRequest } from "../middleware/authenticate";
import { z } from "zod";

const router: IRouter = Router();

const createNoteSchema = z.object({
  targetId: z.string().uuid(),
  title: z.string().max(200).optional(),
  body: z.string().min(1),
  tags: z.array(z.string()).default([]),
  attachmentUrls: z.array(z.string()).default([]),
});

const updateNoteSchema = createNoteSchema.partial().omit({ targetId: true });

router.get("/notes", authenticate, async (req: AuthRequest, res): Promise<void> => {
  const { targetId, search, tags } = req.query;

  const conditions = [eq(notesTable.userId, req.user!.sub)];
  if (targetId) conditions.push(eq(notesTable.targetId, targetId as string));
  if (search) conditions.push(ilike(notesTable.body, `%${search}%`));

  const notes = await db
    .select({
      note: notesTable,
      targetName: targetsTable.name,
      targetAddress: targetsTable.address,
    })
    .from(notesTable)
    .leftJoin(targetsTable, eq(notesTable.targetId, targetsTable.id))
    .where(and(...conditions))
    .orderBy(desc(notesTable.updatedAt));

  res.json(notes);
});

router.post("/notes", authenticate, async (req: AuthRequest, res): Promise<void> => {
  const parsed = createNoteSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "Invalid input", details: parsed.error.issues });
    return;
  }

  const target = await db
    .select({ id: targetsTable.id })
    .from(targetsTable)
    .where(and(eq(targetsTable.id, parsed.data.targetId), eq(targetsTable.userId, req.user!.sub)))
    .limit(1);

  if (!target.length) {
    res.status(404).json({ error: "Target not found" });
    return;
  }

  const [note] = await db
    .insert(notesTable)
    .values({ ...parsed.data, userId: req.user!.sub })
    .returning();

  res.status(201).json(note);
});

router.get("/notes/:id", authenticate, async (req: AuthRequest, res): Promise<void> => {
  const notes = await db
    .select()
    .from(notesTable)
    .where(and(eq(notesTable.id, req.params.id), eq(notesTable.userId, req.user!.sub)))
    .limit(1);

  if (!notes.length) {
    res.status(404).json({ error: "Note not found" });
    return;
  }
  res.json(notes[0]);
});

router.patch("/notes/:id", authenticate, async (req: AuthRequest, res): Promise<void> => {
  const parsed = updateNoteSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "Invalid input", details: parsed.error.issues });
    return;
  }

  const [updated] = await db
    .update(notesTable)
    .set({ ...parsed.data, updatedAt: new Date() })
    .where(and(eq(notesTable.id, req.params.id), eq(notesTable.userId, req.user!.sub)))
    .returning();

  if (!updated) {
    res.status(404).json({ error: "Note not found" });
    return;
  }
  res.json(updated);
});

router.delete("/notes/:id", authenticate, async (req: AuthRequest, res): Promise<void> => {
  const [deleted] = await db
    .delete(notesTable)
    .where(and(eq(notesTable.id, req.params.id), eq(notesTable.userId, req.user!.sub)))
    .returning({ id: notesTable.id });

  if (!deleted) {
    res.status(404).json({ error: "Note not found" });
    return;
  }
  res.status(204).send();
});

export default router;

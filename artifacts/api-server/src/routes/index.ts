import { Router, type IRouter } from "express";
import healthRouter from "./health";
import authRouter from "./auth";
import targetsRouter from "./targets";
import scansRouter from "./scans";
import auditRouter from "./audit";
import findingsRouter from "./findings";
import notesRouter from "./notes";
import dashboardRouter from "./dashboard";
import networksRouter from "./networks";
import reportsRouter from "./reports";
import aiRouter from "./ai";
import devicesRouter from "./devices";
import schedulesRouter from "./schedules";

const router: IRouter = Router();

router.use(healthRouter);
router.use(authRouter);
router.use(targetsRouter);
router.use(scansRouter);
router.use(auditRouter);
router.use(findingsRouter);
router.use(notesRouter);
router.use(dashboardRouter);
router.use(networksRouter);
router.use(reportsRouter);
router.use(aiRouter);
router.use(devicesRouter);
router.use(schedulesRouter);

export default router;

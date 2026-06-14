import { Router } from 'express';
import {
  computeStats,
  dailyStats,
  runPeriodAnalysis,
  type AnalysisPeriod,
} from '../../analytics/periodAnalysis.js';
import { getTaskStore } from '../../ingest/ingestHandler.js';

const router = Router();

router.get('/daily', (req, res) => {
  const date = req.query.date ? new Date(String(req.query.date)) : new Date();
  const stats = dailyStats(getTaskStore(), date);
  res.json({ stats });
});

router.get('/weekly', (req, res) => {
  const year = Number(req.query.year ?? new Date().getFullYear());
  const week = Number(req.query.week ?? 1);
  res.json({ stats: computeStats('week', year, week) });
});

router.get('/monthly', (req, res) => {
  const year = Number(req.query.year ?? new Date().getFullYear());
  const month = Number(req.query.month ?? 1);
  res.json({ stats: computeStats('month', year, undefined, month) });
});

router.get('/yearly', (req, res) => {
  const year = Number(req.query.year ?? new Date().getFullYear());
  res.json({ stats: computeStats('year', year) });
});

router.get('/insights', async (req, res) => {
  const period = String(req.query.period ?? 'week') as AnalysisPeriod;
  const year = Number(req.query.year ?? new Date().getFullYear());
  const week = req.query.week != null ? Number(req.query.week) : undefined;
  const month = req.query.month != null ? Number(req.query.month) : undefined;

  const result = await runPeriodAnalysis({
    period,
    year,
    week,
    month,
    trigger: 'manual',
  });
  res.json(result);
});

router.post('/analyze', async (req, res) => {
  const { period = 'week', year, week, month, pushDingTalk } = req.body as {
    period?: AnalysisPeriod;
    year?: number;
    week?: number;
    month?: number;
    pushDingTalk?: boolean;
  };
  const y = year ?? new Date().getFullYear();

  const result = await runPeriodAnalysis({
    period,
    year: y,
    week,
    month,
    trigger: 'manual',
    pushDingTalk,
  });
  res.json(result);
});

export default router;

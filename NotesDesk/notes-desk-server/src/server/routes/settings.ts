import { Router } from 'express';
import { settingsStore } from '../../store/settingsStore.js';

const router = Router();

router.get('/', (_req, res) => {
  res.json({ settings: settingsStore.get() });
});

router.put('/', (req, res) => {
  const settings = settingsStore.save(req.body);
  res.json({ settings });
});

export default router;

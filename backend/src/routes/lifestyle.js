const express = require('express');
const multer  = require('multer');
const path    = require('path');
const fs      = require('fs');
const { body, validationResult } = require('express-validator');
const router  = express.Router();
const { authenticate, requireAdmin } = require('../middleware/auth');
const {
  logMeal, getMeals,
  logWater, getWater,
  logFitness, getFitness,
  getLeaderboard,
  logPsychosocial, getPsychosocial,
  listPartners, createPartner, updatePartner, deletePartner,
  listPartnerVideos, createPartnerVideo, updatePartnerVideo, deletePartnerVideo,
} = require('../controllers/lifestyleController');

const validate = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) return res.status(400).json({ message: errors.array()[0].msg });
  next();
};

const mealsDir = path.join(__dirname, '../../uploads/meals');
if (!fs.existsSync(mealsDir)) fs.mkdirSync(mealsDir, { recursive: true });

const mealStorage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, mealsDir),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname);
    cb(null, `meal-${Date.now()}-${Math.random().toString(36).substr(2, 6)}${ext}`);
  },
});
const mealUpload = multer({
  storage: mealStorage,
  limits: { fileSize: 10 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    const allowed = /jpeg|jpg|png|webp/;
    const ok = allowed.test(path.extname(file.originalname).toLowerCase()) &&
               allowed.test(file.mimetype);
    if (ok) cb(null, true); else cb(new Error('Only image files are allowed'));
  },
});

// Meals
router.post('/meal',  authenticate, mealUpload.single('photo'), logMeal);
router.post('/meals', authenticate, mealUpload.single('photo'), logMeal);
router.get('/meals',  authenticate, getMeals);

// Water
router.post('/water', authenticate, logWater);
router.get('/water',  authenticate, getWater);

// Fitness
router.post('/fitness', authenticate, [
  body('activity_type').notEmpty().isString().trim().withMessage('Activity type is required'),
  body('duration_minutes').optional().isInt({ min: 0 }),
  body('steps').optional().isInt({ min: 0 }),
], validate, logFitness);
router.get('/fitness',  authenticate, getFitness);

// Leaderboard
router.get('/leaderboard', authenticate, getLeaderboard);

// Psychosocial
router.post('/psychosocial', authenticate, logPsychosocial);
router.get('/psychosocial',  authenticate, getPsychosocial);

// Partners  (videos route BEFORE :id to avoid conflict)
router.get('/partners',           authenticate, listPartners);
router.get('/partners/:id/videos',authenticate, listPartnerVideos);
router.post('/partners/:id/videos',   authenticate, requireAdmin, createPartnerVideo);
router.put('/partners/videos/:videoId',    authenticate, requireAdmin, updatePartnerVideo);
router.delete('/partners/videos/:videoId', authenticate, requireAdmin, deletePartnerVideo);
router.post('/partners',          authenticate, requireAdmin, createPartner);
router.put('/partners/:id',       authenticate, requireAdmin, updatePartner);
router.delete('/partners/:id',    authenticate, requireAdmin, deletePartner);

module.exports = router;

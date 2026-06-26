// src/app.js
// Point d'entrée principal du serveur FlashGo
// C'est ici que tout commence quand on lance le serveur

require('dotenv').config();
const express    = require('express');
const helmet     = require('helmet');
const cors       = require('cors');
const rateLimit  = require('express-rate-limit');

// Import des routes
const authRoutes      = require('./routes/auth');
const ordersRoutes    = require('./routes/orders');
const locationsRoutes = require('./routes/locations');
const walletRoutes    = require('./routes/wallet');

const app = express();

// ── Sécurité de base ──────────────────────────────────────
app.use(helmet());   // Protège contre les attaques courantes
app.use(cors());     // Autorise Flutter à parler à ce serveur
app.use(express.json()); // Permet de lire le JSON des requêtes

// ── Limite le nombre de requêtes (anti-spam) ──────────────
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100,                  // max 100 requêtes par IP
  message: { error: 'Trop de requêtes. Réessaie dans 15 minutes.' }
});
app.use(limiter);

// ── Routes ────────────────────────────────────────────────
app.use('/auth',      authRoutes);
app.use('/orders',    ordersRoutes);
app.use('/locations', locationsRoutes);
app.use('/wallet',    walletRoutes);

// ── Route de test (pour vérifier que le serveur tourne) ───
app.get('/', (req, res) => {
  res.json({
    message: '⚡ Serveur FlashGo opérationnel !',
    version: '1.0.0',
    status: 'OK'
  });
});

// ── Gestion globale des erreurs ───────────────────────────
app.use((err, req, res, next) => {
  console.error('Erreur serveur :', err.message);
  res.status(500).json({
    error: 'Erreur interne du serveur',
    message: err.message
  });
});

// ── Démarrage du serveur ──────────────────────────────────
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`⚡ FlashGo API démarrée sur http://localhost:${PORT}`);
});
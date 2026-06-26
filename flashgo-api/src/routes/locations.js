// src/routes/locations.js
const express    = require('express');
const router     = express.Router();
const supabase   = require('../supabase');
const verifyJWT  = require('../middleware/auth');

// ── PUT /locations/driver ──────────────────────────────────
// Le livreur envoie sa position GPS toutes les 100m
router.put('/driver', verifyJWT, async (req, res) => {
  try {
    const { driver_id, lat, lng } = req.body;

    if (!lat || !lng) {
      return res.status(400).json({ error: 'Coordonnées GPS manquantes' });
    }

    // Upsert = insert si n'existe pas, update si existe déjà
    const { error } = await supabase
      .from('driver_locations')
      .upsert({
        driver_id:  driver_id,
        geom:       `POINT(${lng} ${lat})`,
        updated_at: new Date().toISOString()
      });

    if (error) return res.status(500).json({ error: error.message });

    res.json({ message: 'Position mise à jour', lat, lng });

  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
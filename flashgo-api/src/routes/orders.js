// src/routes/orders.js
const express      = require('express');
const router       = express.Router();
const supabase     = require('../supabase');
const verifyJWT    = require('../middleware/auth');
const checkQuota   = require('../middleware/checkQuota');
const crypto       = require('crypto');

// Calcul du tarif selon la distance
function calculerTarif(distanceMetres) {
  const km = distanceMetres / 1000;
  const base = parseInt(process.env.TARIF_BASE_FCFA) || 500;
  const parKm = parseInt(process.env.TARIF_PAR_KM_FCFA) || 100;
  return Math.round(base + km * parKm);
}

// Calcul distance simple entre 2 points GPS (formule Haversine)
function distanceHaversine(lat1, lng1, lat2, lng2) {
  const R = 6371000; // rayon Terre en mètres
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLng = (lng2 - lng1) * Math.PI / 180;
  const a = Math.sin(dLat/2) * Math.sin(dLat/2) +
            Math.cos(lat1 * Math.PI/180) * Math.cos(lat2 * Math.PI/180) *
            Math.sin(dLng/2) * Math.sin(dLng/2);
  return Math.round(R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a)));
}

// ── POST /orders ───────────────────────────────────────────
// Créer une nouvelle commande
router.post('/', verifyJWT, checkQuota('create_order'), async (req, res) => {
  try {
    const {
      shop_lat, shop_lng,
      client_address, client_lat, client_lng,
      client_phone, cargo_type, device_id
    } = req.body;

    const vendor_id = req.user.id;

    // Calculer la distance et le prix
    const distance_m = distanceHaversine(shop_lat, shop_lng, client_lat, client_lng);
    const prix_fcfa  = calculerTarif(distance_m);

    // Insérer la commande
    const { data: order, error } = await supabase
      .from('orders')
      .insert({
        vendor_id,
        client_address,
        client_phone,
        client_geom: `POINT(${client_lng} ${client_lat})`,
        cargo_type,
        prix_fcfa,
        distance_m,
        status: 'pending'
      })
      .select()
      .single();

    if (error) return res.status(500).json({ error: error.message });

    res.status(201).json({
      message: 'Commande créée !',
      order,
      prix_fcfa,
      distance_km: (distance_m / 1000).toFixed(1)
    });

  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ── GET /orders/nearby ─────────────────────────────────────
// Commandes disponibles dans un rayon de 5km
router.get('/nearby', verifyJWT, async (req, res) => {
  try {
    const { lat, lng } = req.query;

    if (!lat || !lng) {
      return res.status(400).json({ error: 'Paramètres lat et lng requis' });
    }

    const { data, error } = await supabase.rpc('get_orders_in_zone', {
      p_lat: parseFloat(lat),
      p_lng: parseFloat(lng)
    });

    if (error) return res.status(500).json({ error: error.message });

    res.json({ orders: data, count: data.length });

  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ── GET /orders/mine ───────────────────────────────────────
// Mes commandes (vendeur)
router.get('/mine', verifyJWT, async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('orders')
      .select('*')
      .eq('vendor_id', req.user.id)
      .order('created_at', { ascending: false });

    if (error) return res.status(500).json({ error: error.message });

    res.json({ orders: data });

  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ── PATCH /orders/:id/accept ───────────────────────────────
// Le livreur accepte une course
router.patch('/:id/accept', verifyJWT, checkQuota('accept_order'), async (req, res) => {
  try {
    const { id } = req.params;
    const driver_id = req.user.id;

    // Générer l'OTP et son hash
    const otp      = Math.floor(10000 + Math.random() * 90000).toString();
    const otp_hash = crypto.createHash('sha256').update(otp).digest('hex');

    const { data: order, error } = await supabase
      .from('orders')
      .update({ driver_id, status: 'accepted', otp_hash })
      .eq('id', id)
      .eq('status', 'pending')
      .select()
      .single();

    if (error || !order) {
      return res.status(400).json({ error: 'Commande indisponible ou déjà acceptée' });
    }

    res.json({
      message: 'Course acceptée !',
      order,
      otp_hash  // envoyé à l'app livreur pour stockage local chiffré
    });

  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ── PATCH /orders/:id/arrived ──────────────────────────────
// Le livreur est arrivé à la boutique
router.patch('/:id/arrived', verifyJWT, async (req, res) => {
  try {
    const { error } = await supabase
      .from('orders')
      .update({ status: 'arrived' })
      .eq('id', req.params.id)
      .eq('driver_id', req.user.id);

    if (error) return res.status(500).json({ error: error.message });

    res.json({ message: 'Statut mis à jour : livreur arrivé à la boutique' });

  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ── PATCH /orders/:id/dispatch ─────────────────────────────
// Vendeur remet le colis → passage en transit
router.patch('/:id/dispatch', verifyJWT, async (req, res) => {
  try {
    const { error } = await supabase
      .from('orders')
      .update({ status: 'in_transit' })
      .eq('id', req.params.id)
      .eq('vendor_id', req.user.id);

    if (error) return res.status(500).json({ error: error.message });

    // TODO Sprint 3 : envoyer le SMS au client avec le lien de tracking

    res.json({ message: 'Colis en transit ! SMS envoyé au client.' });

  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ── PATCH /orders/:id/validate-otp ────────────────────────
// Valider la livraison avec le code OTP
router.patch('/:id/validate-otp', verifyJWT, async (req, res) => {
  try {
    const { id } = req.params;
    const { otp_input, driver_id } = req.body;

    // Vérifier les tentatives
    const { data: attempt } = await supabase
      .from('otp_attempts')
      .select('attempts, is_blocked')
      .eq('order_id', id)
      .eq('driver_id', driver_id)
      .single();

    if (attempt?.is_blocked) {
      return res.status(429).json({
        error: 'Compte bloqué',
        message: 'Trop de tentatives incorrectes. Contacte le support FlashGo.'
      });
    }

    // Récupérer le hash OTP de la commande
    const { data: order } = await supabase
      .from('orders')
      .select('otp_hash')
      .eq('id', id)
      .single();

    // Hasher la saisie et comparer
    const inputHash = crypto.createHash('sha256').update(otp_input).digest('hex');

    if (inputHash !== order.otp_hash) {
      const newAttempts = (attempt?.attempts || 0) + 1;
      await supabase.from('otp_attempts').upsert({
        order_id:   id,
        driver_id,
        attempts:   newAttempts,
        is_blocked: newAttempts >= 3
      });

      return res.status(400).json({
        error: 'Code incorrect',
        remaining: Math.max(0, 3 - newAttempts)
      });
    }

    // OTP correct → livraison validée (le trigger SQL gère le paiement)
    await supabase
      .from('orders')
      .update({ status: 'delivered' })
      .eq('id', id);

    res.json({ message: '✅ Livraison validée ! Paiement effectué.' });

  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
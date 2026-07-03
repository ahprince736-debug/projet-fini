// src/routes/orders.js
const express      = require('express');
const router       = express.Router();
const supabase     = require('../supabase');
const verifyJWT    = require('../middleware/auth');
const checkQuota   = require('../middleware/checkQuota');
const { distanceHaversine, calculerTarif } = require('../lib/pricing');
const { hashOtp, verifyOtp, computeAttemptState, generateOtp } = require('../lib/otp');

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
    // Pagination : `page` commence à 1, `limit` max 50 par appel.
    // Avant cette correction, toutes les commandes étaient renvoyées en
    // un seul bloc — un vendeur actif avec 200+ commandes recevait un
    // payload énorme à chaque chargement du dashboard.
    const page  = Math.max(1, parseInt(req.query.page)  || 1);
    const limit = Math.min(50, parseInt(req.query.limit) || 20);
    const from  = (page - 1) * limit;
    const to    = from + limit - 1;

    // Sélection de colonnes restreinte : on ne renvoie que ce que le
    // dashboard affiche réellement (évite de transporter des champs
    // lourds comme les geom PostGIS sur chaque appel).
    const { data, error, count } = await supabase
      .from('orders')
      .select('id, status, client_address, prix_fcfa, driver_id, created_at', { count: 'exact' })
      .eq('vendor_id', req.user.id)
      .order('created_at', { ascending: false })
      .range(from, to);

    if (error) return res.status(500).json({ error: error.message });

    res.json({
      orders:    data,
      page,
      limit,
      total:     count,
      has_more:  to < (count - 1),
    });

  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ── GET /orders/:id ────────────────────────────────────────
// Récupère une commande. Deux modes :
//  - Authentifié (vendeur/livreur de la commande) : détails complets
//  - Public, sans token (page de tracking ouverte via lien SMS) :
//    champs limités uniquement — l'UUID de la commande agit comme
//    secret d'accès (non énumérable), comme un lien de paiement Stripe.
//    Jamais de otp_hash ni de données financières dans ce mode.
router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const authHeader = req.headers['authorization'];

    let authenticatedUserId = null;
    if (authHeader && authHeader.startsWith('Bearer ')) {
      const { data } = await supabase.auth.getUser(authHeader.split(' ')[1]);
      authenticatedUserId = data?.user?.id || null;
    }

    const { data: order, error } = await supabase
      .from('orders')
      .select('id, vendor_id, driver_id, status, client_address, client_phone, cargo_type, prix_fcfa, created_at')
      .eq('id', id)
      .single();

    if (error || !order) {
      return res.status(404).json({ error: 'Commande introuvable' });
    }

    const isParticipant = authenticatedUserId &&
      (authenticatedUserId === order.vendor_id || authenticatedUserId === order.driver_id);

    // Numéro WhatsApp du livreur — nécessaire pour les boutons "Appeler"/
    // "WhatsApp" de la page de tracking. Avant ce correctif, ce champ
    // n'était jamais récupéré : ces boutons utilisaient par erreur le
    // numéro du CLIENT (client_phone), c'est-à-dire la personne qui
    // consulte la page elle-même — les boutons ne pouvaient donc jamais
    // réellement joindre le livreur.
    let driverWhatsapp = null;
    if (order.driver_id) {
      const { data: driverProfile } = await supabase
        .from('profiles')
        .select('whatsapp')
        .eq('id', order.driver_id)
        .single();
      driverWhatsapp = driverProfile?.whatsapp ?? null;
    }

    if (isParticipant) {
      // Coordonnées GPS du client ajoutées uniquement ici — jamais en
      // mode public, pour protéger la vie privée de l'adresse du client.
      // Nécessaires par exemple à deliver_route_screen.dart pour calculer
      // une vraie distance de proximité plutôt que de la supposer.
      const { data: coords } = await supabase
        .rpc('get_order_client_coords', { p_order_id: id })
        .single();

      return res.json({
        order: {
          ...order,
          client_lat: coords?.client_lat ?? null,
          client_lng: coords?.client_lng ?? null,
          driver_whatsapp: driverWhatsapp,
        }
      });
    }

    // Mode public restreint : on retire les données sensibles/financières
    const { vendor_id, prix_fcfa, ...publicOrder } = order;
    return res.json({ order: { ...publicOrder, driver_whatsapp: driverWhatsapp } });
  } catch (err) {
    console.error('Erreur GET /orders/:id', err);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

// ── PATCH /orders/:id/accept ───────────────────────────────
// Le livreur accepte une course
router.patch('/:id/accept', verifyJWT, checkQuota('accept_order'), async (req, res) => {
  try {
    const { id } = req.params;
    const driver_id = req.user.id;

    // Générer l'OTP et son hash (module testé — voir src/lib/otp.js)
    const otp      = generateOtp();
    const otp_hash = hashOtp(otp);

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
    const { otp_input } = req.body;

    // Sécurité : le driver_id vient du JWT vérifié, jamais du body.
    // Avant ce correctif, un driver_id arbitraire envoyé par le client
    // permettait de réinitialiser le compteur de tentatives à chaque essai
    // et donc de brute-forcer le code OTP (5 chiffres) sans jamais être bloqué.
    const driver_id = req.user.id;

    // Récupérer la commande et vérifier qu'elle est bien assignée à ce livreur
    const { data: order } = await supabase
      .from('orders')
      .select('otp_hash, driver_id')
      .eq('id', id)
      .single();

    if (!order || order.driver_id !== driver_id) {
      return res.status(403).json({
        error: 'Accès refusé',
        message: 'Cette commande ne t\'est pas assignée.'
      });
    }

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

    // Hasher la saisie et comparer via le module otp.js (source unique
    // de vérité, testée unitairement — voir src/lib/otp.js)
    if (!verifyOtp(otp_input, order.otp_hash)) {
      const { newAttempts, isBlocked, remaining } = computeAttemptState(attempt?.attempts || 0);
      await supabase.from('otp_attempts').upsert({
        order_id:   id,
        driver_id,
        attempts:   newAttempts,
        is_blocked: isBlocked
      });

      return res.status(400).json({
        error: 'Code incorrect',
        remaining
      });
    }

    // OTP correct → livraison validée (le trigger SQL gère le paiement)
    //
    // Garde anti race-condition : la mise à jour n'a lieu QUE si la commande
    // est encore au statut 'in_transit'. Si deux requêtes arrivent en
    // parallèle (ex : la synchronisation hors-ligne qui rejoue une validation
    // pendant que le livreur la refait en direct après reconnexion), seule
    // la première réussit réellement — Postgres garantit l'atomicité au
    // niveau ligne. Ça évite un double déclenchement du trigger de paiement.
    const { data: updated, error: updateError } = await supabase
      .from('orders')
      .update({ status: 'delivered' })
      .eq('id', id)
      .eq('status', 'in_transit')
      .select()
      .maybeSingle();

    if (updateError) {
      return res.status(500).json({ error: updateError.message });
    }

    if (!updated) {
      // Soit déjà validée par un appel concurrent (cas attendu et inoffensif
      // avec la sync hors-ligne → on répond succès pour que la file
      // d'attente côté app se vide normalement), soit la commande n'était
      // pas dans un état permettant la livraison.
      const { data: current } = await supabase
        .from('orders')
        .select('status')
        .eq('id', id)
        .single();

      if (current?.status === 'delivered') {
        return res.json({
          message: '✅ Livraison déjà validée.',
          alreadyValidated: true
        });
      }

      return res.status(409).json({
        error: 'Statut invalide',
        message: 'Cette commande n\'est pas dans un état permettant la validation.'
      });
    }

    res.json({ message: '✅ Livraison validée ! Paiement effectué.' });

  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
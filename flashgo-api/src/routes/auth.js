 // src/routes/auth.js
const express  = require('express');
const router   = express.Router();
const supabase = require('../supabase');

// ── POST /auth/register-vendor ─────────────────────────────
router.post('/register-vendor', async (req, res) => {
  try {
    const { shop_name, full_name, whatsapp, password } = req.body;

    if (!shop_name || !full_name || !whatsapp || !password) {
      return res.status(400).json({ error: 'Tous les champs sont obligatoires' });
    }

    if (password.length < 8) {
      return res.status(400).json({ error: 'Mot de passe trop court. Minimum 8 caractères' });
    }

    // Créer avec email fictif basé sur WhatsApp
    const email = `${whatsapp.replace('+', '')}@flashgo.bj`;

    const { data: authData, error: authError } = await supabase.auth.admin.createUser({
      email,
      password,
      email_confirm: true
    });

    if (authError) {
      console.log('Auth error:', authError);
      return res.status(400).json({ error: authError.message });
    }

    const { data: profile, error: profileError } = await supabase
      .from('profiles')
      .insert({
        id:        authData.user.id,
        role:      'vendor',
        full_name,
        whatsapp,
        shop_name
      })
      .select()
      .single();

    if (profileError) {
      console.log('Profile error:', profileError);
      return res.status(400).json({ error: profileError.message });
    }

    res.status(201).json({
      message: 'Compte vendeur créé avec succès !',
      profile
    });

  } catch (err) {
    console.log('Server error:', err);
    res.status(500).json({ error: err.message });
  }
});

// ── POST /auth/register-driver ─────────────────────────────
router.post('/register-driver', async (req, res) => {
  try {
    const { full_name, whatsapp, password } = req.body;

    if (!full_name || !whatsapp || !password) {
      return res.status(400).json({ error: 'Tous les champs sont obligatoires' });
    }

    if (password.length < 8) {
      return res.status(400).json({ error: 'Mot de passe trop court. Minimum 8 caractères' });
    }

    const email = `${whatsapp.replace('+', '')}@flashgo.bj`;

    const { data: authData, error: authError } = await supabase.auth.admin.createUser({
      email,
      password,
      email_confirm: true
    });

    if (authError) {
      return res.status(400).json({ error: authError.message });
    }

    const { data: profile, error: profileError } = await supabase
      .from('profiles')
      .insert({
        id:          authData.user.id,
        role:        'driver',
        full_name,
        whatsapp,
        is_approved: false
      })
      .select()
      .single();

    if (profileError) {
      return res.status(400).json({ error: profileError.message });
    }

    res.status(201).json({
      message: 'Dossier soumis. En attente de validation par FlashGo.',
      profile
    });

  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ── POST /auth/login ───────────────────────────────────────
router.post('/login', async (req, res) => {
  try {
    const { whatsapp, password } = req.body;

    if (!whatsapp || !password) {
      return res.status(400).json({ error: 'WhatsApp et mot de passe requis' });
    }

    // Chercher d'abord le profil pour récupérer l'email exact
    const { data: profile, error: profileError } = await supabase
      .from('profiles')
      .select('*')
      .eq('whatsapp', whatsapp)
      .single();

    if (profileError || !profile) {
      return res.status(401).json({
        error: 'Connexion échouée',
        message: 'Numéro ou mot de passe incorrect.'
      });
    }

    // Récupérer l'email depuis auth.users via l'ID
    const { data: authUser, error: authUserError } = await supabase.auth.admin.getUserById(
      profile.id
    );

    if (authUserError || !authUser?.user?.email) {
      return res.status(401).json({
        error: 'Connexion échouée',
        message: 'Compte introuvable. Réinscris-toi.'
      });
    }

    // Connexion avec l'email récupéré
    const { data, error } = await supabase.auth.signInWithPassword({
      email:    authUser.user.email,
      password: password
    });

    if (error) {
      return res.status(401).json({
        error: 'Connexion échouée',
        message: 'Numéro ou mot de passe incorrect.'
      });
    }

    // Bloquer livreur non validé
    if (profile.role === 'driver' && !profile.is_approved) {
      return res.status(403).json({
        error:    'Compte non validé',
        message:  'Ton dossier est en cours de vérification par FlashGo.',
        redirect: 'waiting'
      });
    }

    res.json({
      message: 'Connexion réussie !',
      token:   data.session.access_token,
      profile
    });

  } catch (err) {
    console.log('Login error:', err);
    res.status(500).json({ error: err.message });
  }
});

// ── GET /auth/me ───────────────────────────────────────────
router.get('/me', async (req, res) => {
  try {
    const authHeader = req.headers['authorization'];
    if (!authHeader) return res.status(401).json({ error: 'Token manquant' });

    const token = authHeader.split(' ')[1];
    const { data, error } = await supabase.auth.getUser(token);

    if (error) return res.status(401).json({ error: 'Token invalide' });

    const { data: profile } = await supabase
      .from('profiles')
      .select('*')
      .eq('id', data.user.id)
      .single();

    res.json({ profile });

  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
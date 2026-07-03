// src/routes/wallet.js
const express   = require('express');
const router    = express.Router();
const supabase  = require('../supabase');
const verifyJWT = require('../middleware/auth');

// ── GET /wallet ────────────────────────────────────────────
// Voir son solde et historique
router.get('/', verifyJWT, async (req, res) => {
  try {
    const user_id = req.user.id;

    const { data: wallet } = await supabase
      .from('driver_wallets')
      .select('balance')
      .eq('driver_id', user_id)
      .single();

    const { data: transactions } = await supabase
      .from('wallet_transactions')
      .select('*')
      .eq('driver_id', user_id)
      .order('created_at', { ascending: false })
      .limit(20);

    res.json({
      balance:      wallet?.balance || 0,
      transactions: transactions || []
    });

  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ── POST /wallet/withdraw ──────────────────────────────────
// Demander un retrait MoMo
router.post('/withdraw', verifyJWT, async (req, res) => {
  try {
    const user_id = req.user.id;
    const { momo_number, network } = req.body;

    const MINIMUM = parseInt(process.env.RETRAIT_MINIMUM_FCFA) || 500;

    if (!momo_number || !network) {
      return res.status(400).json({ error: 'Numéro MoMo et réseau requis' });
    }

    // Vérifier le solde
    const { data: wallet } = await supabase
      .from('driver_wallets')
      .select('balance')
      .eq('driver_id', user_id)
      .single();

    if (!wallet || wallet.balance < MINIMUM) {
      return res.status(400).json({
        error: 'Solde insuffisant',
        message: `Minimum de retrait : ${MINIMUM} FCFA. Ton solde : ${wallet?.balance || 0} FCFA`
      });
    }

    // Sécurité : le montant retiré est TOUJOURS le solde réel du serveur,
    // jamais une valeur envoyée par le client. Avant ce correctif, le body
    // acceptait un `amount` arbitraire sans jamais le comparer au solde
    // réel — un livreur avec 600 FCFA aurait pu demander un retrait de
    // n'importe quel montant, y compris bien supérieur à son solde.
    const amount = wallet.balance;

    // Créer la demande
    const { data: request } = await supabase
      .from('withdrawal_requests')
      .insert({ driver_id: user_id, amount, momo_number, network })
      .select()
      .single();

    res.json({
      message: 'Demande enregistrée. Virement prévu à 19h00.',
      request
    });

  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
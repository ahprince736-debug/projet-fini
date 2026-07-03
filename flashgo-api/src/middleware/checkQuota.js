// src/middleware/checkQuota.js
// Vérifie si l'utilisateur a encore des actions gratuites
// ou s'il doit payer avant de continuer

const supabase = require('../supabase');

module.exports = function checkQuota(action_type) {
  return async function (req, res, next) {
    const user_id = req.user.id;
    const device_id = req.body.device_id;

    if (!device_id) {
      return res.status(400).json({
        error: 'device_id manquant',
        message: 'L\'identifiant de l\'appareil est requis.'
      });
    }

    // 1. Vérifier si l'utilisateur a un abonnement actif
    const { data: sub } = await supabase
      .from('subscriptions')
      .select('status')
      .eq('user_id', user_id)
      .eq('status', 'active')
      .single();

    // Abonné = pas de quota, on laisse passer
    if (sub) return next();

    // 2. Compter les actions gratuites du jour sur cet appareil
    const { data: count } = await supabase
      .rpc('count_daily_actions', {
        p_device_id: device_id,
        p_action_type: action_type
      });

    const QUOTA = parseInt(process.env.QUOTA_GRATUIT_JOUR) || 3;

    if (count >= QUOTA) {
      // Débit atomique via RPC Postgres — corrige une race condition où
      // deux requêtes simultanées pouvaient lire le même solde et se
      // débiter deux fois (voir src/routes/wallet.js pour le même
      // principe appliqué au retrait MoMo).
      const COUT_UNITAIRE = 100; // 100 FCFA par action

      const { data: debitResult, error: debitError } = await supabase
        .rpc('debit_prepaid_balance', {
          p_user_id: user_id,
          p_amount:  COUT_UNITAIRE
        })
        .single();

      if (debitError || !debitResult?.success) {
        return res.status(402).json({
          error: 'Quota gratuit épuisé',
          message: `Tu as utilisé tes ${QUOTA} actions gratuites du jour. Abonne-toi ou recharge ton compte.`,
          redirect: 'paywall',
          remaining: 0
        });
      }
    }

    // 5. Enregistrer l'action
    await supabase
      .from('device_quotas')
      .insert({ device_id, user_id, action_type });

    next();
  };
};
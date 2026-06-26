// src/middleware/auth.js
// Ce middleware vérifie que l'utilisateur est bien connecté
// Il lit le token JWT envoyé par Flutter et vérifie qu'il est valide

const supabase = require('../supabase');

module.exports = async function verifyJWT(req, res, next) {
  // Récupérer le token dans le header "Authorization: Bearer TOKEN"
  const authHeader = req.headers['authorization'];

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({
      error: 'Non autorisé',
      message: 'Token manquant. Connecte-toi d\'abord.'
    });
  }

  const token = authHeader.split(' ')[1];

  // Vérifier le token avec Supabase
  const { data, error } = await supabase.auth.getUser(token);

  if (error || !data.user) {
    return res.status(401).json({
      error: 'Token invalide',
      message: 'Ta session a expiré. Reconnecte-toi.'
    });
  }

  // Injecter l'utilisateur dans la requête pour les routes suivantes
  req.user = data.user;
  next();
};
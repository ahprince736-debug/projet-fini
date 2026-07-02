// src/lib/pricing.js
//
// Logique pure de calcul de distance et de tarif — extraite de orders.js
// pour être testable unitairement sans dépendre de Supabase ou d'Express.
//
// Toute modification du barème tarifaire doit passer par ce fichier
// (source unique de vérité), jamais être dupliquée ailleurs.

/**
 * Distance entre deux points GPS via la formule Haversine.
 * @returns {number} distance en mètres, arrondie à l'entier.
 */
function distanceHaversine(lat1, lng1, lat2, lng2) {
  const R = 6371000; // rayon de la Terre en mètres
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLng = (lng2 - lng1) * Math.PI / 180;
  const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
            Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
            Math.sin(dLng / 2) * Math.sin(dLng / 2);
  return Math.round(R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a)));
}

/**
 * Calcule le tarif FCFA à partir d'une distance en mètres.
 *
 * @param {number} distanceMetres
 * @param {object} [config] - Permet de surcharger la config pour les tests.
 *   Sans argument, lit process.env comme avant (comportement inchangé).
 * @param {number} [config.base] - Tarif de base FCFA
 * @param {number} [config.parKm] - Tarif par km FCFA
 */
function calculerTarif(distanceMetres, config = {}) {
  const km    = distanceMetres / 1000;
  const base  = config.base  ?? (parseInt(process.env.TARIF_BASE_FCFA)  || 500);
  const parKm = config.parKm ?? (parseInt(process.env.TARIF_PAR_KM_FCFA) || 100);
  return Math.round(base + km * parKm);
}

module.exports = { distanceHaversine, calculerTarif };

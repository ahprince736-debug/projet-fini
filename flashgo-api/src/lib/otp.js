// src/lib/otp.js
//
// Logique pure de génération, hachage et vérification des codes OTP,
// ainsi que la logique de blocage anti brute-force — extraite de
// orders.js pour être testable unitairement.
//
// C'est la zone la plus sensible du projet : une erreur ici peut soit
// bloquer des livraisons légitimes, soit laisser un code se faire
// deviner par brute-force. D'où l'importance des tests.

const crypto = require('crypto');

const MAX_ATTEMPTS = 3;

/** Génère un code OTP à 5 chiffres (10000–99999). */
function generateOtp() {
  return Math.floor(10000 + Math.random() * 90000).toString();
}

/** Hash SHA-256 d'un code OTP — jamais stocker le code en clair. */
function hashOtp(otp) {
  return crypto.createHash('sha256').update(otp).digest('hex');
}

/**
 * Vérifie qu'un code saisi correspond au hash stocké.
 * @returns {boolean}
 */
function verifyOtp(otpInput, storedHash) {
  if (!otpInput || !storedHash) return false;
  return hashOtp(otpInput) === storedHash;
}

/**
 * Calcule le nouvel état de tentatives après un échec de validation.
 *
 * @param {number} currentAttempts - Nombre de tentatives déjà enregistrées
 * @returns {{ newAttempts: number, isBlocked: boolean, remaining: number }}
 */
function computeAttemptState(currentAttempts = 0) {
  const newAttempts = currentAttempts + 1;
  const isBlocked    = newAttempts >= MAX_ATTEMPTS;
  const remaining     = Math.max(0, MAX_ATTEMPTS - newAttempts);
  return { newAttempts, isBlocked, remaining };
}

module.exports = { generateOtp, hashOtp, verifyOtp, computeAttemptState, MAX_ATTEMPTS };

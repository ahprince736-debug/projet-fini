// src/services/sms.js
// Pour l'instant on simule l'envoi SMS (on branchera Twilio plus tard)

async function sendTrackingLink(phoneNumber, orderId, otpCode) {
  const trackingUrl = `http://${process.env.APP_DOMAIN}/track/${orderId}`;
  const message = `Votre colis FlashGo est en route ! Suivez-le ici : ${trackingUrl} | Code de réception : ${otpCode} | Donnez ce code UNIQUEMENT quand vous tiendrez le colis.`;

  // TODO Sprint 3 : brancher Twilio ici
  console.log(`📱 SMS simulé vers ${phoneNumber} : ${message}`);

  return { success: true, message };
}

module.exports = { sendTrackingLink };
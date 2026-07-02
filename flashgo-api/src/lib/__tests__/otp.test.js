// src/lib/__tests__/otp.test.js
//
// Tests unitaires de la logique OTP : génération, hachage, vérification,
// et surtout la logique anti brute-force (blocage après 3 tentatives).
//
// Zone la plus sensible du projet : un bug ici peut soit bloquer des
// livraisons légitimes, soit laisser un code se faire deviner.

const { generateOtp, hashOtp, verifyOtp, computeAttemptState, MAX_ATTEMPTS } = require('../otp');

describe('generateOtp', () => {
  test('génère toujours un code de 5 chiffres', () => {
    for (let i = 0; i < 50; i++) {
      const otp = generateOtp();
      expect(otp).toMatch(/^\d{5}$/);
    }
  });

  test('génère un code dans la plage 10000–99999', () => {
    for (let i = 0; i < 50; i++) {
      const otp = parseInt(generateOtp());
      expect(otp).toBeGreaterThanOrEqual(10000);
      expect(otp).toBeLessThanOrEqual(99999);
    }
  });

  test('génère des codes différents à chaque appel (pas de valeur figée)', () => {
    const codes = new Set();
    for (let i = 0; i < 30; i++) codes.add(generateOtp());
    // Sur 30 tirages, on doit avoir une bonne variété (pas de doublon massif)
    expect(codes.size).toBeGreaterThan(25);
  });
});

describe('hashOtp', () => {
  test('produit un hash SHA-256 valide (64 caractères hexadécimaux)', () => {
    const hash = hashOtp('12345');
    expect(hash).toMatch(/^[a-f0-9]{64}$/);
  });

  test('même code produit toujours le même hash (déterministe)', () => {
    expect(hashOtp('54321')).toBe(hashOtp('54321'));
  });

  test('codes différents produisent des hash différents', () => {
    expect(hashOtp('11111')).not.toBe(hashOtp('22222'));
  });

  test('ne stocke jamais le code en clair dans le hash', () => {
    const otp  = '99999';
    const hash = hashOtp(otp);
    expect(hash).not.toContain(otp);
  });
});

describe('verifyOtp', () => {
  test('code correct correspondant au hash → true', () => {
    const otp  = '45678';
    const hash = hashOtp(otp);
    expect(verifyOtp(otp, hash)).toBe(true);
  });

  test('code incorrect → false', () => {
    const hash = hashOtp('45678');
    expect(verifyOtp('00000', hash)).toBe(false);
  });

  test('code vide → false (jamais un accès par défaut)', () => {
    const hash = hashOtp('45678');
    expect(verifyOtp('', hash)).toBe(false);
  });

  test('hash manquant → false (jamais un accès sans vérification)', () => {
    expect(verifyOtp('45678', null)).toBe(false);
    expect(verifyOtp('45678', undefined)).toBe(false);
  });

  test('les deux valeurs manquantes → false', () => {
    expect(verifyOtp(null, null)).toBe(false);
  });

  test('sensible à un seul chiffre différent (pas de faux positif partiel)', () => {
    const hash = hashOtp('12345');
    expect(verifyOtp('12346', hash)).toBe(false);
  });
});

describe('computeAttemptState — logique anti brute-force', () => {
  test('première tentative échouée : 1 tentative, pas bloqué, 2 restantes', () => {
    const result = computeAttemptState(0);
    expect(result).toEqual({ newAttempts: 1, isBlocked: false, remaining: 2 });
  });

  test('deuxième tentative échouée : 2 tentatives, pas bloqué, 1 restante', () => {
    const result = computeAttemptState(1);
    expect(result).toEqual({ newAttempts: 2, isBlocked: false, remaining: 1 });
  });

  test('troisième tentative échouée : 3 tentatives, BLOQUÉ, 0 restante', () => {
    const result = computeAttemptState(2);
    expect(result).toEqual({ newAttempts: 3, isBlocked: true, remaining: 0 });
  });

  test('tentative au-delà du seuil reste bloquée (pas de déblocage accidentel)', () => {
    const result = computeAttemptState(5);
    expect(result.isBlocked).toBe(true);
    expect(result.remaining).toBe(0);
  });

  test('le seuil de blocage est exactement MAX_ATTEMPTS (3)', () => {
    expect(MAX_ATTEMPTS).toBe(3);
  });

  test('remaining ne devient jamais négatif', () => {
    const result = computeAttemptState(10);
    expect(result.remaining).toBeGreaterThanOrEqual(0);
  });

  test('paramètre par défaut (aucun argument) = première tentative', () => {
    const result = computeAttemptState();
    expect(result.newAttempts).toBe(1);
    expect(result.isBlocked).toBe(false);
  });
});

describe('Scénario bout-en-bout : cycle de vie complet d\'un OTP', () => {
  test('génération → hachage → vérification correcte → succès', () => {
    const otp  = generateOtp();
    const hash = hashOtp(otp);
    expect(verifyOtp(otp, hash)).toBe(true);
  });

  test('3 tentatives incorrectes consécutives déclenchent le blocage', () => {
    const otp  = generateOtp();
    const hash = hashOtp(otp);
    let attempts = 0;
    let blocked  = false;

    // Simule 3 saisies incorrectes d'affilée
    for (let i = 0; i < 3; i++) {
      const isCorrect = verifyOtp('00000', hash); // toujours faux (sauf coïncidence 1/100000)
      expect(isCorrect).toBe(false);
      const state = computeAttemptState(attempts);
      attempts = state.newAttempts;
      blocked  = state.isBlocked;
    }

    expect(attempts).toBe(3);
    expect(blocked).toBe(true);
  });

  test('un code correct après 2 échecs débloque quand même la livraison (pas de blocage prématuré)', () => {
    const otp  = generateOtp();
    const hash = hashOtp(otp);

    // 2 échecs
    let state = computeAttemptState(0);
    state = computeAttemptState(state.newAttempts);
    expect(state.isBlocked).toBe(false);

    // 3ème tentative = le bon code
    expect(verifyOtp(otp, hash)).toBe(true);
    // Puisque c'est correct, computeAttemptState n'est jamais appelé
    // pour cette tentative (la route ne l'appelle qu'en cas d'échec)
  });
});

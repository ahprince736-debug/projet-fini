// src/lib/__tests__/pricing.test.js
//
// Tests unitaires du calcul de tarif et de distance.
// Zone critique : une erreur ici facture le mauvais prix à chaque
// commande, silencieusement — d'où l'importance de couvrir les cas
// limites (distance nulle, très longue, coordonnées identiques).

const { distanceHaversine, calculerTarif } = require('../pricing');

describe('distanceHaversine', () => {
  test('distance nulle entre deux points identiques', () => {
    expect(distanceHaversine(6.3703, 2.3912, 6.3703, 2.3912)).toBe(0);
  });

  test('distance réaliste entre deux quartiers de Cotonou (~1 à 2 km)', () => {
    // Akpakpa (6.3703, 2.3912) → Cadjèhoun (approx 6.3600, 2.4100)
    const distance = distanceHaversine(6.3703, 2.3912, 6.3600, 2.4100);
    expect(distance).toBeGreaterThan(1500);
    expect(distance).toBeLessThan(3000);
  });

  test('distance symétrique (A→B doit égaler B→A)', () => {
    const aVersB = distanceHaversine(6.3703, 2.3912, 6.4200, 2.4300);
    const bVersA = distanceHaversine(6.4200, 2.4300, 6.3703, 2.3912);
    expect(aVersB).toBe(bVersA);
  });

  test('distance connue vérifiable (Cotonou → Porto-Novo, ~30km à vol d\'oiseau)', () => {
    // Cotonou centre (6.3703, 2.3912) → Porto-Novo centre (6.4969, 2.6289)
    const distance = distanceHaversine(6.3703, 2.3912, 6.4969, 2.6289);
    const km = distance / 1000;
    // Tolérance large car "à vol d'oiseau" diffère de la route réelle
    expect(km).toBeGreaterThan(25);
    expect(km).toBeLessThan(35);
  });

  test('résultat toujours positif ou nul, jamais négatif', () => {
    const distance = distanceHaversine(6.5, 2.5, 6.3, 2.3);
    expect(distance).toBeGreaterThanOrEqual(0);
  });
});

describe('calculerTarif', () => {
  const config = { base: 500, parKm: 100 }; // valeurs par défaut du projet

  test('distance nulle = tarif de base uniquement', () => {
    expect(calculerTarif(0, config)).toBe(500);
  });

  test('1 km = base + 1×parKm', () => {
    expect(calculerTarif(1000, config)).toBe(600); // 500 + 1×100
  });

  test('5 km = base + 5×parKm', () => {
    expect(calculerTarif(5000, config)).toBe(1000); // 500 + 5×100
  });

  test('distance non-entière de km (2.5 km) est correctement calculée', () => {
    expect(calculerTarif(2500, config)).toBe(750); // 500 + 2.5×100
  });

  test('résultat toujours un entier arrondi (jamais de centimes FCFA)', () => {
    const prix = calculerTarif(1234, config);
    expect(Number.isInteger(prix)).toBe(true);
  });

  test('utilise les valeurs par défaut (500/100) si aucune config fournie', () => {
    // Test du comportement legacy : sans config, lit process.env avec fallback
    delete process.env.TARIF_BASE_FCFA;
    delete process.env.TARIF_PAR_KM_FCFA;
    expect(calculerTarif(1000)).toBe(600);
  });

  test('respecte une config personnalisée différente des valeurs par défaut', () => {
    const configPromo = { base: 300, parKm: 50 };
    expect(calculerTarif(2000, configPromo)).toBe(400); // 300 + 2×50
  });

  test('tarif toujours croissant avec la distance (pas de régression illogique)', () => {
    const prix1km = calculerTarif(1000, config);
    const prix5km = calculerTarif(5000, config);
    const prix10km = calculerTarif(10000, config);
    expect(prix5km).toBeGreaterThan(prix1km);
    expect(prix10km).toBeGreaterThan(prix5km);
  });
});

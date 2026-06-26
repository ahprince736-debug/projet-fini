// src/supabase.js
// Ce fichier crée la connexion avec notre base de données Supabase
// On utilise la clé service_role qui a accès à tout (uniquement côté serveur)

require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_KEY
);

module.exports = supabase;
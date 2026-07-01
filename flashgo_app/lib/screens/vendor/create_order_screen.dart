// lib/screens/vendor/create_order_screen.dart
// Formulaire de création d'un colis — avec GPS automatique

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import '../../services/local_storage.dart';
import '../../services/geocoding_service.dart';
import '../../widgets/flashgo_button.dart';
import '../../widgets/flashgo_textfield.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

class CreateOrderScreen extends StatefulWidget {
  const CreateOrderScreen({super.key});
  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen> {
  final _formKey     = GlobalKey<FormState>();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl   = TextEditingController();

  // GPS boutique (détecté automatiquement)
  double? _shopLat;
  double? _shopLng;
  bool    _isLocating = false;
  String? _locationError;

  // Géocodage adresse client (Nominatim)
  double? _clientLat;
  double? _clientLng;
  String? _geocodedAddress;      // adresse formatée confirmée par Nominatim
  bool    _isGeocoding  = false;
  String? _geocodeError;
  Timer?  _debounceTimer;        // debounce : attend 800ms après la dernière frappe

  String  _cargoType    = 'other';
  bool    _isLoading    = false;
  String? _errorMessage;

  final List<Map<String, dynamic>> _cargoTypes = [
    {'value': 'liquid',  'label': '🥤 Liquide',    'color': AppColors.accent},
    {'value': 'food',    'label': '🍔 Nourriture',  'color': AppColors.cta},
    {'value': 'fragile', 'label': '🔮 Cassable',    'color': AppColors.warning},
    {'value': 'other',   'label': '📦 Autre',       'color': Colors.white38},
  ];

  @override
  void initState() {
    super.initState();
    // GPS boutique — détection automatique dès l'ouverture
    _detectShopLocation();
    // Géocodage client — se déclenche 800ms après chaque frappe
    _addressCtrl.addListener(_onAddressChanged);
  }

  // ── Debounce géocodage ─────────────────────────────────
  // Sans debounce, on appellerait Nominatim à chaque lettre tapée,
  // ce qui dépasserait immédiatement la limite de 1 req/sec.
  void _onAddressChanged() {
    _debounceTimer?.cancel();
    final address = _addressCtrl.text.trim();

    // Réinitialiser si champ vidé
    if (address.isEmpty) {
      setState(() {
        _clientLat      = null;
        _clientLng      = null;
        _geocodedAddress = null;
        _geocodeError   = null;
      });
      return;
    }

    // N'essayer de géocoder que si l'adresse a au moins 6 caractères
    // (évite les requêtes inutiles sur "Rue" ou "A")
    if (address.length < 6) return;

    _debounceTimer = Timer(const Duration(milliseconds: 800), () {
      _geocodeClientAddress(address);
    });
  }

  Future<void> _geocodeClientAddress(String address) async {
    setState(() {
      _isGeocoding  = true;
      _geocodeError = null;
    });

    final result = await GeocodingService.geocode(address);

    if (!mounted) return;

    if (result != null) {
      setState(() {
        _clientLat       = result.lat;
        _clientLng       = result.lng;
        _geocodedAddress = result.displayName;
        _geocodeError    = null;
        _isGeocoding     = false;
      });
    } else {
      setState(() {
        _clientLat       = null;
        _clientLng       = null;
        _geocodedAddress = null;
        _geocodeError    = 'Adresse non trouvée. Essaie d\'être plus précis\n(ex: "Rue 1200, Akpakpa, Cotonou")';
        _isGeocoding     = false;
      });
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  // ── Détection GPS automatique ──────────────────────────
  Future<void> _detectShopLocation() async {
    setState(() { _isLocating = true; _locationError = null; });

    try {
      // Vérifie d'abord si le GPS est activé sur le téléphone
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _locationError = 'GPS désactivé — active-le dans les paramètres.');
        return;
      }

      // Vérifie les permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _locationError = 'Permission GPS refusée.');
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        setState(() => _locationError = 'GPS bloqué — autorise FlashGo dans les paramètres.');
        return;
      }

      // Position actuelle (timeout de 10s pour les zones à signal faible)
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('GPS trop lent — réessaie en extérieur.'),
      );

      setState(() {
        _shopLat = position.latitude;
        _shopLng = position.longitude;
      });
    } catch (e) {
      setState(() => _locationError = e.toString().replaceAll('Exception: ', ''));
    } finally {
      setState(() => _isLocating = false);
    }
  }

  // ── Création de la commande ────────────────────────────
  Future<void> _submitOrder() async {
    if (!_formKey.currentState!.validate()) return;

    if (_shopLat == null || _shopLng == null) {
      setState(() => _errorMessage = 'Position GPS boutique non détectée. Appuie sur "Réessayer".');
      return;
    }

    // Si le géocodage est encore en cours, on attend
    if (_isGeocoding) {
      setState(() => _errorMessage = 'Géocodage de l\'adresse en cours, patiente un instant...');
      return;
    }

    // Si le géocodage a échoué, utiliser la position boutique comme fallback
    // avec un avertissement clair plutôt que de bloquer la commande.
    final clientLat = _clientLat ?? _shopLat!;
    final clientLng = _clientLng ?? _shopLng!;
    final usingFallback = _clientLat == null;

    if (usingFallback) {
      // Demander confirmation si on utilise le fallback
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text('Adresse non géolocalisée', style: AppTypography.displaySmall.copyWith(fontSize: 16)),
          content: Text(
            'Nominatim n\'a pas trouvé les coordonnées de cette adresse.\n\n'
            'Le tarif sera estimé depuis ta boutique. Continuer quand même ?',
            style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Corriger l\'adresse',
                style: AppTypography.label.copyWith(color: AppColors.accent)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Continuer',
                style: AppTypography.label.copyWith(color: AppColors.danger)),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      final token    = await LocalStorage.getToken();
      final userId   = await LocalStorage.getUserId();
      final deviceId = await LocalStorage.getDeviceId() ?? 'device_$userId';

      final response = await http.post(
        Uri.parse(ApiConfig.orders),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({
          'shop_lat':       _shopLat,
          'shop_lng':       _shopLng,
          'client_address': _addressCtrl.text.trim(),
          'client_lat':     clientLat,
          'client_lng':     clientLng,
          'client_phone':   _phoneCtrl.text.trim(),
          'cargo_type':     _cargoType,
          'device_id':      deviceId,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        if (!mounted) return;
        _showConfirmation(data);
      } else if (response.statusCode == 402) {
        if (!mounted) return;
        context.push('/paywall');
      } else {
        setState(() => _errorMessage = data['message'] ?? data['error']);
      }
    } catch (_) {
      setState(() => _errorMessage = 'Impossible de joindre le serveur.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showConfirmation(Map data) {
    showModalBottomSheet(
      context:         context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            // Icône succès
            Container(
              padding:    const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:  AppColors.success.withOpacity(0.1),
                shape:  BoxShape.circle,
                border: Border.all(color: AppColors.success.withOpacity(0.3)),
              ),
              child: const Icon(Icons.check, color: AppColors.success, size: 28),
            ),
            const SizedBox(height: 16),
            Text('Colis créé !', style: AppTypography.displayMedium),
            Text('Un livreur va bientôt accepter ta course.',
              style: AppTypography.bodyMedium.copyWith(color: AppColors.textDisabled),
              textAlign: TextAlign.center),
            const SizedBox(height: 24),
            // Stats prix + distance
            Container(
              padding:    const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:        AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatItem(
                    value: '${data['prix_fcfa']} F',
                    label: 'Prix course',
                    color: AppColors.cta,
                  ),
                  Container(width: 1, height: 40, color: Colors.white10),
                  _StatItem(
                    value: '${data['distance_km']} km',
                    label: 'Distance',
                    color: AppColors.accent,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FlashGoButton(
              label:     'Voir mes livraisons',
              icon:      Icons.arrow_forward,
              onPressed: () { Navigator.pop(ctx); context.go('/vendor/dashboard'); },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon:      const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: Text('Nouveau colis', style: AppTypography.displaySmall),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── GPS boutique automatique ───────────────
              _GpsTile(
                isLocating:    _isLocating,
                lat:           _shopLat,
                lng:           _shopLng,
                errorMessage:  _locationError,
                onRetry:       _detectShopLocation,
              ),
              const SizedBox(height: 20),

              // ── Infos client ───────────────────────────
              Text('Destinataire', style: AppTypography.label.copyWith(
                color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              FlashGoTextField(
                label:      'Adresse de livraison',
                hint:       'ex: Rue 1200, Akpakpa, Cotonou',
                controller: _addressCtrl,
                prefix:     const Icon(Icons.location_on, color: AppColors.accent, size: 18),
                validator:  (v) => v!.trim().isEmpty ? 'Adresse obligatoire' : null,
              ),

              // ── Feedback géocodage en temps réel ────────
              _GeocodeTile(
                isGeocoding:     _isGeocoding,
                geocodedAddress: _geocodedAddress,
                errorMessage:    _geocodeError,
                hasInput:        _addressCtrl.text.trim().length >= 6,
              ),
              const SizedBox(height: 4),
              FlashGoTextField(
                label:        'Téléphone du client',
                hint:         '+22960000000',
                controller:   _phoneCtrl,
                keyboardType: TextInputType.phone,
                prefix:       const Icon(Icons.phone, color: AppColors.accent, size: 18),
                validator: (v) {
                  if (v!.trim().isEmpty) return 'Téléphone obligatoire';
                  if (!RegExp(r'^\+\d{10,15}$').hasMatch(v.trim())) {
                    return 'Format : +22960000000';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // ── Type de marchandise ────────────────────
              Text('Type de marchandise', style: AppTypography.label.copyWith(
                color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10, runSpacing: 10,
                children: _cargoTypes.map((type) {
                  final isSelected = _cargoType == type['value'];
                  final color      = type['color'] as Color;
                  return GestureDetector(
                    onTap: () => setState(() => _cargoType = type['value'] as String),
                    child: AnimatedContainer(
                      duration:   const Duration(milliseconds: 180),
                      padding:    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color:        isSelected ? color.withOpacity(0.15) : AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                        border:       Border.all(
                          color: isSelected ? color : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        type['label'] as String,
                        style: AppTypography.label.copyWith(
                          color:      isSelected ? color : AppColors.textTertiary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Attribution OpenStreetMap — obligatoire selon les CGU Nominatim
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Row(children: [
                  const Icon(Icons.map_outlined, color: AppColors.textFaint, size: 13),
                  const SizedBox(width: 6),
                  Text(
                    'Géocodage © OpenStreetMap contributors',
                    style: AppTypography.label.copyWith(
                      color:    AppColors.textFaint,
                      fontSize: 10,
                    ),
                  ),
                ]),
              ),

              // Message erreur
              if (_errorMessage != null) ...[
                Container(
                  padding:    const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:        AppColors.danger.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border:       Border.all(color: AppColors.danger.withOpacity(0.5)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline, color: AppColors.danger, size: 15),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_errorMessage!,
                      style: AppTypography.label.copyWith(color: AppColors.danger))),
                  ]),
                ),
                const SizedBox(height: 16),
              ],

              FlashGoButton(
                label:     'Calculer le prix et créer le colis',
                icon:      Icons.flash_on,
                onPressed: _isLocating ? null : _submitOrder,
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Widget feedback géocodage ─────────────────────────────
//
// Affiche en temps réel l'état du géocodage Nominatim sous
// le champ d'adresse client :
//  - En attente de frappe       → invisible
//  - En cours                   → spinner + "Recherche..."
//  - Trouvée                    → adresse confirmée en vert
//  - Non trouvée                → message d'aide en orange
class _GeocodeTile extends StatelessWidget {
  final bool    isGeocoding;
  final String? geocodedAddress;
  final String? errorMessage;
  final bool    hasInput;

  const _GeocodeTile({
    required this.isGeocoding,
    required this.geocodedAddress,
    required this.errorMessage,
    required this.hasInput,
  });

  @override
  Widget build(BuildContext context) {
    // Pas d'affichage si l'utilisateur n'a pas encore assez saisi
    if (!hasInput && geocodedAddress == null && errorMessage == null) {
      return const SizedBox.shrink();
    }

    final Color  color;
    final IconData icon;
    final String label;

    if (isGeocoding) {
      color = AppColors.accent;
      icon  = Icons.search;
      label = 'Recherche sur OpenStreetMap…';
    } else if (geocodedAddress != null) {
      color = AppColors.success;
      icon  = Icons.check_circle_outline;
      // Tronquer l'adresse longue retournée par Nominatim
      final parts  = geocodedAddress!.split(',');
      label = parts.take(3).join(',').trim();
    } else if (errorMessage != null) {
      color = AppColors.warning;
      icon  = Icons.help_outline;
      label = errorMessage!;
    } else {
      return const SizedBox.shrink();
    }

    return AnimatedContainer(
      duration:   const Duration(milliseconds: 250),
      margin:     const EdgeInsets.only(bottom: 12),
      padding:    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color:        color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          isGeocoding
              ? SizedBox(
                  width: 14, height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5, color: color,
                  ),
                )
              : Icon(icon, color: color, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: AppTypography.label.copyWith(color: color, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}
class _GpsTile extends StatelessWidget {
  final bool    isLocating;
  final double? lat, lng;
  final String? errorMessage;
  final VoidCallback onRetry;

  const _GpsTile({
    required this.isLocating,
    required this.lat,
    required this.lng,
    required this.errorMessage,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:    const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: errorMessage != null
            ? AppColors.danger.withOpacity(0.07)
            : lat != null
                ? AppColors.success.withOpacity(0.07)
                : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: errorMessage != null
              ? AppColors.danger.withOpacity(0.3)
              : lat != null
                  ? AppColors.success.withOpacity(0.3)
                  : Colors.white12,
        ),
      ),
      child: Row(
        children: [
          // Icône d'état
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: isLocating
                ? const SizedBox(
                    key:    ValueKey('loading'),
                    width:  20, height: 20,
                    child:  CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.accent,
                    ),
                  )
                : Icon(
                    key:   ValueKey(errorMessage ?? (lat != null ? 'ok' : 'wait')),
                    errorMessage != null
                        ? Icons.gps_off
                        : lat != null
                            ? Icons.gps_fixed
                            : Icons.gps_not_fixed,
                    color: errorMessage != null
                        ? AppColors.danger
                        : lat != null ? AppColors.success : AppColors.textDisabled,
                    size: 20,
                  ),
          ),
          const SizedBox(width: 12),
          // Texte
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Position de ta boutique',
                  style: AppTypography.label.copyWith(
                    color:      AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  isLocating
                      ? 'Détection GPS en cours...'
                      : errorMessage != null
                          ? errorMessage!
                          : lat != null
                              ? '${lat!.toStringAsFixed(5)}, ${lng!.toStringAsFixed(5)}'
                              : 'En attente...',
                  style: AppTypography.label.copyWith(
                    color: errorMessage != null
                        ? AppColors.danger
                        : lat != null ? AppColors.success : AppColors.textDisabled,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          // Bouton réessayer si erreur
          if (errorMessage != null && !isLocating)
            TextButton(
              onPressed: onRetry,
              child: Text('Réessayer',
                style: AppTypography.label.copyWith(color: AppColors.accent, fontSize: 11)),
            ),
        ],
      ),
    );
  }
}

// ── Widget stat modal confirmation ───────────────────────
class _StatItem extends StatelessWidget {
  final String value, label;
  final Color  color;
  const _StatItem({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Column(children: [
    Text(value, style: AppTypography.codeInline.copyWith(color: color, fontSize: 22)),
    const SizedBox(height: 4),
    Text(label, style: AppTypography.label.copyWith(color: AppColors.textDisabled, fontSize: 11)),
  ]);
}

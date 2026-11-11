import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Interfaz abstracta para el puente de monetización con portales web/móvil.
///
/// Implementaciones:
/// - [OfflineSandboxPortalBridge]: Activa por defecto, simula todo localmente (tests, desarrollo).
/// - [NutakuPortalBridge], [ItchIoPortalBridge], [CrazyGamesPortalBridge], [GooglePlayBillingBridge]:
///   Implementaciones reales que inyectan el SDK del portal correspondiente.
abstract interface class MonetizationPortalBridge {
  /// Inicializa el SDK del portal (llaves, usuario, entorno).
  Future<void> initialize();

  /// Si el usuario tiene una compra no consumible activa (p.ej. "Starter Pack" o "Remove Ads").
  Future<bool> hasEntitlement(String skuId);

  /// Restaura compras no consumibles (llama a restorePurchases del SDK).
  Future<void> restorePurchases();

  /// Compra no consumible (desbloqueo permanente).
  Future<PurchaseResult> purchaseNonConsumable(String skuId);

  /// Compra consumible (pack de esquirlas, oro, energía).
  Future<PurchaseResult> purchaseConsumable(String skuId);

  /// Oráculo Abisal - Rewarded Boost Diario (límite 3/día).
  ///
  /// Otorga +100% Oro y Esquirlas por 15 min O Revivir con 50% HP al caer contra un Jefe.
  /// Retorna el tipo de recompensa otorgada.
  Future<AbyssalOracleReward?> showAbyssalOracle();

  /// Verifica si el Oráculo Abisal está disponible (carga de anuncio + límite diario).
  Future<bool> isAbyssalOracleAvailable();

  /// Límite diario restante del Oráculo (0-3).
  Future<int> abyssalOracleRemainingToday();

  /// Catálogo de SKUs estructurado para BrimstoneShopModal.
  Future<List<ShopSku>> getShopCatalog();

  /// Registra un evento de atribución (para analytics del portal).
  Future<void> logEvent(String eventName, Map<String, dynamic> params);

  /// Obtiene el ID de usuario del portal (para sincronización cross-device).
  Future<String?> getPortalUserId();

  /// Abre la página de gestión de suscripciones del portal (si aplica).
  Future<void> openSubscriptionManagement();

  /// Notifica al portal que el juego está en primer plano (para tracking de sesión).
  Future<void> onResume();

  /// Notifica al portal que el juego pasó a segundo plano.
  Future<void> onPause();
}

/// Resultado de una compra.
class PurchaseResult {
  final bool success;
  final String? transactionId;
  final String? skuId;
  final String? errorMessage;
  final bool isRestored; // true si venía de restorePurchases

  const PurchaseResult({
    required this.success,
    this.transactionId,
    this.skuId,
    this.errorMessage,
    this.isRestored = false,
  });

  factory PurchaseResult.success(
          {required String transactionId,
          required String skuId,
          bool isRestored = false}) =>
      PurchaseResult(
          success: true,
          transactionId: transactionId,
          skuId: skuId,
          isRestored: isRestored);

  factory PurchaseResult.failure(
          {required String skuId, required String errorMessage}) =>
      PurchaseResult(success: false, skuId: skuId, errorMessage: errorMessage);
}

/// Recompensa del Oráculo Abisal.
enum AbyssalOracleRewardType {
  doubleGoldShards, // +100% Oro y Esquirlas por 15 min
  reviveHalfHp, // Revivir una vez con 50% HP contra Jefe
}

class AbyssalOracleReward {
  final AbyssalOracleRewardType type;
  final DateTime expiresAt; // para boost temporal

  const AbyssalOracleReward({required this.type, required this.expiresAt});

  String get description => switch (type) {
        AbyssalOracleRewardType.doubleGoldShards =>
          '+100% Oro y Esquirlas (15 min)',
        AbyssalOracleRewardType.reviveHalfHp => 'Revivir con 50% HP (1 uso)',
      };
}

/// SKU del catálogo de la tienda.
class ShopSku {
  final String id;
  final String nameKey;
  final String descKey;
  final ShopSkuType type;
  final int
      priceMicros; // precio en micros de la moneda local (USD * 1_000_000)
  final String currencyCode; // 'USD', 'EUR', etc.
  final String formattedPrice; // ej. "$4.99"
  final Map<String, dynamic>
      payload; // datos extra: {shards: 5000, gold: 100000, ...}
  final bool isSubscription;
  final String? subscriptionPeriod; // 'monthly', 'yearly'

  const ShopSku({
    required this.id,
    required this.nameKey,
    required this.descKey,
    required this.type,
    required this.priceMicros,
    required this.currencyCode,
    required this.formattedPrice,
    required this.payload,
    this.isSubscription = false,
    this.subscriptionPeriod,
  });

  /// Clave de localización para el tipo.
  String get typeLabelKey => switch (type) {
        ShopSkuType.shards => 'shop.type.shards',
        ShopSkuType.gold => 'shop.type.gold',
        ShopSkuType.energy => 'shop.type.energy',
        ShopSkuType.starterPack => 'shop.type.starter_pack',
        ShopSkuType.removeAds => 'shop.type.remove_ads',
        ShopSkuType.battlePass => 'shop.type.battle_pass',
        ShopSkuType.cosmetic => 'shop.type.cosmetic',
      };
}

enum ShopSkuType {
  shards, // Pack de esquirlas (consumible)
  gold, // Pack de oro (consumible)
  energy, // Pack de energía (consumible)
  starterPack, // Paquete inicial (no consumible)
  removeAds, // Quitar anuncios (no consumible)
  battlePass, // Pase de batalla (suscripción)
  cosmetic, // Cosmético (no consumible)
}

/// Firma de integridad para validar recibos localmente (offline-first).
/// En producción, el backend del portal validaría el receipt con Google/Apple/portal.
class IntegritySigner {
  static const String _secret = 'brimstone_summoning_v11_offline_secret';

  /// Genera una firma HMAC-SHA256 simple para el recibo local.
  static String signReceipt({
    required String skuId,
    required String transactionId,
    required int timestamp,
    required String portalUserId,
  }) {
    final data = '$skuId|$transactionId|$timestamp|$portalUserId|$_secret';
    // Simple hash para integridad local (no criptográficamente seguro, solo anti-tamper básico)
    int hash = 0;
    for (int i = 0; i < data.length; i++) {
      hash = (hash * 31 + data.codeUnitAt(i)) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  /// Verifica una firma de recibo.
  static bool verifyReceipt({
    required String skuId,
    required String transactionId,
    required int timestamp,
    required String portalUserId,
    required String signature,
  }) {
    final expected = signReceipt(
      skuId: skuId,
      transactionId: transactionId,
      timestamp: timestamp,
      portalUserId: portalUserId,
    );
    return expected == signature;
  }
}

/// Implementación OFFLINE/SANDBOX por defecto.
///
/// Simula todo localmente sin SDK externo. Útil para:
/// - Desarrollo y tests
/// - Builds sin portal (web standalone, desktop)
/// - QA sin credenciales de tienda
class OfflineSandboxPortalBridge implements MonetizationPortalBridge {
  final Map<String, bool> _entitlements = {};
  final Map<String, int> _consumableCounts = {};
  int _oracleUsedToday = 0;
  DateTime _oracleDate = DateTime.now();
  final bool _oracleAdLoaded = true; // En sandbox siempre "cargado"

  @override
  Future<void> initialize() async {
    // En sandbox, cargar entitlements guardados localmente
    // (En implementación real, esto vendría de SharedPreferences/SQLite)
    _entitlements['starter_pack'] = false;
    _entitlements['remove_ads'] = false;
  }

  @override
  Future<bool> hasEntitlement(String skuId) async =>
      _entitlements[skuId] ?? false;

  @override
  Future<void> restorePurchases() async {
    // En sandbox, simular restauración
    _entitlements['starter_pack'] = true;
    _entitlements['remove_ads'] = true;
  }

  @override
  Future<PurchaseResult> purchaseNonConsumable(String skuId) async {
    await Future.delayed(const Duration(milliseconds: 300)); // Simular red
    _entitlements[skuId] = true;
    return PurchaseResult.success(
      transactionId:
          'sandbox_${skuId}_${DateTime.now().millisecondsSinceEpoch}',
      skuId: skuId,
    );
  }

  @override
  Future<PurchaseResult> purchaseConsumable(String skuId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _consumableCounts[skuId] = (_consumableCounts[skuId] ?? 0) + 1;
    return PurchaseResult.success(
      transactionId:
          'sandbox_${skuId}_${DateTime.now().millisecondsSinceEpoch}',
      skuId: skuId,
    );
  }

  @override
  Future<AbyssalOracleReward?> showAbyssalOracle() async {
    if (!await isAbyssalOracleAvailable()) return null;

    _oracleUsedToday++;
    // 50/50 entre las dos recompensas
    final type = math.Random().nextBool()
        ? AbyssalOracleRewardType.doubleGoldShards
        : AbyssalOracleRewardType.reviveHalfHp;

    return AbyssalOracleReward(
      type: type,
      expiresAt: type == AbyssalOracleRewardType.doubleGoldShards
          ? DateTime.now().add(const Duration(minutes: 15))
          : DateTime.now()
              .add(const Duration(hours: 24)), // revive dura hasta que se use
    );
  }

  @override
  Future<bool> isAbyssalOracleAvailable() async {
    _checkDateRollOver();
    return _oracleAdLoaded && _oracleUsedToday < 3;
  }

  @override
  Future<int> abyssalOracleRemainingToday() async {
    _checkDateRollOver();
    return (3 - _oracleUsedToday).clamp(0, 3);
  }

  void _checkDateRollOver() {
    final now = DateTime.now();
    if (now.day != _oracleDate.day ||
        now.month != _oracleDate.month ||
        now.year != _oracleDate.year) {
      _oracleDate = now;
      _oracleUsedToday = 0;
    }
  }

  @override
  Future<List<ShopSku>> getShopCatalog() async {
    return [
      // Consumibles
      ShopSku(
        id: 'shards_small',
        nameKey: 'shop.sku.shards_small.name',
        descKey: 'shop.sku.shards_small.desc',
        type: ShopSkuType.shards,
        priceMicros: 990000, // $0.99
        currencyCode: 'USD',
        formattedPrice: '\$0.99',
        payload: {'shards': 500},
      ),
      ShopSku(
        id: 'shards_medium',
        nameKey: 'shop.sku.shards_medium.name',
        descKey: 'shop.sku.shards_medium.desc',
        type: ShopSkuType.shards,
        priceMicros: 4990000, // $4.99
        currencyCode: 'USD',
        formattedPrice: '\$4.99',
        payload: {'shards': 3000},
      ),
      ShopSku(
        id: 'shards_large',
        nameKey: 'shop.sku.shards_large.name',
        descKey: 'shop.sku.shards_large.desc',
        type: ShopSkuType.shards,
        priceMicros: 9990000, // $9.99
        currencyCode: 'USD',
        formattedPrice: '\$9.99',
        payload: {'shards': 7000},
      ),
      ShopSku(
        id: 'gold_pack',
        nameKey: 'shop.sku.gold_pack.name',
        descKey: 'shop.sku.gold_pack.desc',
        type: ShopSkuType.gold,
        priceMicros: 2990000, // $2.99
        currencyCode: 'USD',
        formattedPrice: '\$2.99',
        payload: {'gold': 100000},
      ),
      ShopSku(
        id: 'energy_pack',
        nameKey: 'shop.sku.energy_pack.name',
        descKey: 'shop.sku.energy_pack.desc',
        type: ShopSkuType.energy,
        priceMicros: 1990000, // $1.99
        currencyCode: 'USD',
        formattedPrice: '\$1.99',
        payload: {'energy': 50},
      ),
      // No consumibles
      ShopSku(
        id: 'starter_pack',
        nameKey: 'shop.sku.starter_pack.name',
        descKey: 'shop.sku.starter_pack.desc',
        type: ShopSkuType.starterPack,
        priceMicros: 4990000, // $4.99
        currencyCode: 'USD',
        formattedPrice: '\$4.99',
        payload: {'shards': 5000, 'gold': 50000, 'artifact': 'void_compass'},
      ),
      ShopSku(
        id: 'remove_ads',
        nameKey: 'shop.sku.remove_ads.name',
        descKey: 'shop.sku.remove_ads.desc',
        type: ShopSkuType.removeAds,
        priceMicros: 2990000, // $2.99
        currencyCode: 'USD',
        formattedPrice: '\$2.99',
        payload: {},
      ),
      ShopSku(
        id: 'battle_pass',
        nameKey: 'shop.sku.battle_pass.name',
        descKey: 'shop.sku.battle_pass.desc',
        type: ShopSkuType.battlePass,
        priceMicros: 4990000, // $4.99
        currencyCode: 'USD',
        formattedPrice: '\$4.99',
        payload: {},
      ),
    ];
  }

  @override
  Future<void> logEvent(String eventName, Map<String, dynamic> params) async {
    // En sandbox, no-op (sin telemetría real)
  }

  @override
  Future<String?> getPortalUserId() async =>
      'sandbox_user_${math.Random().nextInt(1000000)}';

  @override
  Future<void> openSubscriptionManagement() async {
    // No-op en sandbox
  }

  @override
  Future<void> onResume() async {}

  @override
  Future<void> onPause() async {}
}

/// Provider para inyección de dependencias (Riverpod).
/// En main.dart / bootstrap.dart se hace override con la implementación real por flavor.
final monetizationPortalBridgeProvider =
    Provider<MonetizationPortalBridge>((ref) {
  throw UnimplementedError(
      'MonetizationPortalBridge must be overridden in bootstrap.dart per flavor');
});

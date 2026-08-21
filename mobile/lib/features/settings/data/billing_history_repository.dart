import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/data/clients/api_client.dart';

/// What a billing entry was for.
enum BillingEntryKind { subscription, gift }

/// Settlement state of a billing entry.
enum BillingEntryStatus { settled, refunded, revoked, pendingRedemption, expired }

/// One row of the user's billing history.
class BillingTransaction {
  /// Payment or record identifier shown to the user and printed on the invoice.
  final String id;

  final String productName;
  final DateTime date;

  /// Amount in the smallest currency unit (paise for INR). Null when the amount
  /// was never recorded for this entry.
  final int? amountMinorUnits;
  final String currency;

  final BillingEntryStatus status;
  final BillingEntryKind kind;

  /// True when [amountMinorUnits] came from the plan's current list price
  /// rather than from a stored amount. The `entitlements` table records what
  /// was granted but not what was charged, and the backend has exactly two
  /// hardcoded plan prices with no historical price table — so for a
  /// subscription the list price is the charged price, but it would silently
  /// go stale if prices ever change. Surfaced in the UI rather than hidden.
  final bool amountIsListPrice;

  const BillingTransaction({
    required this.id,
    required this.productName,
    required this.date,
    required this.amountMinorUnits,
    required this.currency,
    required this.status,
    required this.kind,
    this.amountIsListPrice = false,
  });

  bool get isSettled => status == BillingEntryStatus.settled;

  /// Formatted amount, or a dash when no amount was recorded.
  String get amountLabel {
    final minor = amountMinorUnits;
    if (minor == null) return '—';
    final symbol = currency.toUpperCase() == 'INR' ? '₹' : '$currency ';
    return '$symbol${(minor / 100).toStringAsFixed(2)}';
  }

  String get statusLabel {
    switch (status) {
      case BillingEntryStatus.settled:
        return 'SUCCESS';
      case BillingEntryStatus.refunded:
        return 'REFUNDED';
      case BillingEntryStatus.revoked:
        return 'REVOKED';
      case BillingEntryStatus.pendingRedemption:
        return 'UNREDEEMED';
      case BillingEntryStatus.expired:
        return 'EXPIRED';
    }
  }

  String get statusDetailLabel {
    switch (status) {
      case BillingEntryStatus.settled:
        return 'SETTLED & CAPTURED';
      case BillingEntryStatus.refunded:
        return 'REFUNDED TO SOURCE';
      case BillingEntryStatus.revoked:
        return 'ENTITLEMENT REVOKED';
      case BillingEntryStatus.pendingRedemption:
        return 'GIFT CODE NOT REDEEMED';
      case BillingEntryStatus.expired:
        return 'GIFT CODE EXPIRED';
    }
  }
}

/// Current list prices in paise, mirroring `CreateOrder` in
/// `backend/internal/handlers/premium_handler.go` (29900 / 99900). Kept in one
/// place so the mismatch is obvious if the backend prices ever change.
const _planListPricePaise = <String, int>{
  'nitro_basic': 29900,
  'nitro_full': 99900,
};

const _planDisplayNames = <String, String>{
  'nitro_basic': 'FLICKO PLUS (BASIC)',
  'nitro_full': 'FLICKO PLUS (FULL)',
};

/// The signed-in user's billing history, newest first.
///
/// Assembled from the two tables that actually record purchases:
///
///   * `entitlements` — premium grants. `source` distinguishes a paid grant
///     from a gift redemption or a manual grant; `source_id` holds the Razorpay
///     payment id for paid ones.
///   * `gift_transactions` — gift purchases, the only rows with a real stored
///     amount (`price_cents`).
///
/// This replaces a hardcoded six-entry list (`TXN_FLK_9281A4`, "WARP DRIP
/// COSMETIC FUSION", a VISA •••• 4242, a ₹399 refund) that every account saw
/// identically — and that the invoice generator would happily render into a
/// downloadable PDF for a purchase that never happened.
final billingHistoryProvider =
    FutureProvider.autoDispose<List<BillingTransaction>>((ref) async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  if (user == null) return const [];

  final entries = <BillingTransaction>[];

  final entitlements = await client
      .from('entitlements')
      .select('id, type, source, source_id, granted_at, expires_at, revoked')
      .eq('user_id', user.id)
      .order('granted_at', ascending: false);

  for (final row in (entitlements as List).cast<Map<String, dynamic>>()) {
    final grantedAt = DateTime.tryParse(row['granted_at']?.toString() ?? '');
    if (grantedAt == null) continue;

    final plan = row['type']?.toString() ?? '';
    final source = row['source']?.toString() ?? '';
    final revoked = row['revoked'] == true;

    // Only paid grants belong in a billing history. Gift redemptions and
    // manual/admin grants cost the user nothing, so listing them as
    // transactions would imply a charge that never happened.
    if (source != 'payment') continue;

    entries.add(BillingTransaction(
      id: row['source_id']?.toString() ?? row['id']?.toString() ?? '—',
      productName: _planDisplayNames[plan] ?? plan.toUpperCase(),
      date: grantedAt.toLocal(),
      amountMinorUnits: _planListPricePaise[plan],
      currency: 'INR',
      status:
          revoked ? BillingEntryStatus.revoked : BillingEntryStatus.settled,
      kind: BillingEntryKind.subscription,
      amountIsListPrice: _planListPricePaise.containsKey(plan),
    ));
  }

  final gifts = await client
      .from('gift_transactions')
      .select('id, plan, price_cents, currency, status, created_at, gift_code')
      .eq('purchaser_id', user.id)
      .order('created_at', ascending: false);

  for (final row in (gifts as List).cast<Map<String, dynamic>>()) {
    final createdAt = DateTime.tryParse(row['created_at']?.toString() ?? '');
    if (createdAt == null) continue;

    final plan = row['plan']?.toString() ?? '';
    entries.add(BillingTransaction(
      id: row['gift_code']?.toString() ?? row['id']?.toString() ?? '—',
      productName:
          'GIFT — ${_planDisplayNames[plan] ?? plan.toUpperCase()}',
      date: createdAt.toLocal(),
      amountMinorUnits: (row['price_cents'] as num?)?.toInt(),
      currency: row['currency']?.toString() ?? 'INR',
      status: _giftStatus(row['status']?.toString()),
      kind: BillingEntryKind.gift,
    ));
  }

  entries.sort((a, b) => b.date.compareTo(a.date));
  return entries;
});

BillingEntryStatus _giftStatus(String? raw) {
  switch (raw) {
    case 'redeemed':
      return BillingEntryStatus.settled;
    case 'refunded':
      return BillingEntryStatus.refunded;
    case 'expired':
      return BillingEntryStatus.expired;
    default:
      // A purchased-but-unredeemed gift was still paid for; it just has not
      // been claimed yet.
      return BillingEntryStatus.pendingRedemption;
  }
}

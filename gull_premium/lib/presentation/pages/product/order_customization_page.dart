import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../controllers/controllers.dart';
import '../../../core/services/whatsapp_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/price_format_utils.dart';
import '../../../data/models/add_on_model.dart';
import '../../../data/models/flower_model.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/common/app_cached_image.dart';
import '../../widgets/common/order_via_whatsapp_button.dart';
import '../../widgets/layout/app_scaffold.dart';
import 'add_on_variant_selection_page.dart';

/// Product Details & Customization (Upsell) page.
/// Flow: Order via WhatsApp -> this page -> user picks add-ons -> ORDER VIA WHATSAPP opens WhatsApp.
class OrderCustomizationPage extends ConsumerStatefulWidget {
  final String flowerId;

  const OrderCustomizationPage({super.key, required this.flowerId});

  @override
  ConsumerState<OrderCustomizationPage> createState() =>
      _OrderCustomizationPageState();
}

class _OrderCustomizationPageState extends ConsumerState<OrderCustomizationPage> {
  static const Color _luxuryGold = AppColors.accentGold;
  final TextEditingController _promoCodeController = TextEditingController();
  AddOnModel? _selectedVase;
  AddOnModel? _selectedChocolate;
  AddOnModel? _selectedCard;
  bool _isApplyingPromo = false;
  String? _appliedPromoCode;
  double? _appliedPromoDiscountPercentage;

  @override
  void dispose() {
    _promoCodeController.dispose();
    super.dispose();
  }

  void _onAddOnSelected(AddOnModel addOn) {
    setState(() {
      switch (addOn.type) {
        case AddOnType.vase:
          _selectedVase = addOn;
          break;
        case AddOnType.chocolate:
          _selectedChocolate = addOn;
          break;
        case AddOnType.card:
          _selectedCard = addOn;
          break;
        case AddOnType.teddyBear:
          // Not in the three cards; could extend later.
          break;
      }
    });
  }

  int _totalPriceIqd(FlowerModel bouquet) {
    var total = bouquet.priceIqd;
    if (_selectedVase != null) total += _selectedVase!.priceIqd;
    if (_selectedChocolate != null) total += _selectedChocolate!.priceIqd;
    if (_selectedCard != null) total += _selectedCard!.priceIqd;
    return total;
  }

  int _discountedTotalPriceIqd(FlowerModel bouquet) {
    final total = _totalPriceIqd(bouquet);
    final discount = _appliedPromoDiscountPercentage;
    if (discount == null || discount <= 0) return total;
    final discounted = total * ((100 - discount) / 100);
    return discounted.round();
  }

  Future<void> _applyPromoCode(FlowerModel bouquet) async {
    if (_isApplyingPromo) return;
    final code = _promoCodeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      _showPromoSnack('Please enter a promo code.');
      return;
    }

    setState(() => _isApplyingPromo = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('coupons')
          .where('code', isEqualTo: code)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        _showPromoSnack('This promo code is invalid.');
        return;
      }

      final data = snapshot.docs.first.data();
      final isActive = data['isActive'] == true;
      final expiryTs = data['expiryDate'] as Timestamp?;
      final discount = (data['discountPercentage'] is num)
          ? (data['discountPercentage'] as num).toDouble()
          : -1.0;
      final isExpired =
          expiryTs == null || expiryTs.toDate().isBefore(DateTime.now());

      if (!isActive || isExpired || discount <= 0 || discount > 100) {
        _showPromoSnack('This promo code is inactive or expired.');
        return;
      }

      if (!mounted) return;
      setState(() {
        _appliedPromoCode = code;
        _appliedPromoDiscountPercentage = discount;
      });

      final discounted = _discountedTotalPriceIqd(bouquet);
      _showPromoSnack(
        'Promo applied! You now pay ${l10nCurrency(discounted)}.',
        isError: false,
      );
    } catch (_) {
      _showPromoSnack('Unable to verify promo code right now.');
    } finally {
      if (mounted) {
        setState(() => _isApplyingPromo = false);
      }
    }
  }

  String l10nCurrency(int amount) {
    final l10n = AppLocalizations.of(context)!;
    return '${l10n.currencyIqd} ${formatPriceIqd(amount)}';
  }

  void _showPromoSnack(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? const Color(0xFF8B1E3F) : const Color(0xFF1F6E43),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  List<AddOnModel> _selectedAddOnsList() {
    return [
      if (_selectedVase != null) _selectedVase!,
      if (_selectedChocolate != null) _selectedChocolate!,
      if (_selectedCard != null) _selectedCard!,
    ];
  }

  Stream<List<_ReviewItem>> _reviewsStream(String productId) {
    return FirebaseFirestore.instance
        .collection('reviews')
        .where('productId', isEqualTo: productId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map(_ReviewItem.fromFirestore).toList());
  }

  Future<String> _resolveUserDisplayName(User user) async {
    final fromAuth = user.displayName?.trim() ?? '';
    if (fromAuth.isNotEmpty) return fromAuth;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = doc.data();
      if (data == null) return 'Valued Customer';
      final fullName = data['fullName']?.toString().trim() ?? '';
      if (fullName.isNotEmpty) return fullName;
      final displayName = data['displayName']?.toString().trim() ?? '';
      if (displayName.isNotEmpty) return displayName;
    } catch (_) {}
    final emailName = (user.email ?? '').split('@').first.trim();
    return emailName.isNotEmpty ? emailName : 'Valued Customer';
  }

  Future<void> _showWriteReviewSheet({
    required String productId,
    required String productName,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please sign in to write a review.'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    final commentController = TextEditingController();
    var selectedRating = 5.0;
    var isSubmitting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(24)),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.shadow.withValues(alpha: 0.14),
                        blurRadius: 24,
                        offset: const Offset(0, -8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Write a Review',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        productName,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.inkMuted,
                            ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          final starValue = index + 1.0;
                          final selected = selectedRating >= starValue;
                          return IconButton(
                            onPressed: isSubmitting
                                ? null
                                : () => setModalState(() {
                                      selectedRating = starValue;
                                    }),
                            icon: Icon(
                              selected ? Icons.star : Icons.star_border,
                              color: selected ? _luxuryGold : AppColors.border,
                              size: 30,
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: commentController,
                        maxLines: 3,
                        maxLength: 300,
                        decoration: InputDecoration(
                          hintText: 'Share your experience with this product...',
                          filled: true,
                          fillColor: AppColors.background,
                          contentPadding: const EdgeInsets.all(14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: AppColors.accentGold),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  final sheetNavigator = Navigator.of(sheetContext);
                                  final messenger = ScaffoldMessenger.of(this.context);
                                  final comment = commentController.text.trim();
                                  if (comment.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text(
                                            'Please add a short review comment.'),
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                    );
                                    return;
                                  }

                                  setModalState(() => isSubmitting = true);
                                  try {
                                    final userName =
                                        await _resolveUserDisplayName(user);
                                    await FirebaseFirestore.instance
                                        .collection('reviews')
                                        .add({
                                      'productId': productId,
                                      'userId': user.uid,
                                      'userName': userName,
                                      'rating': selectedRating,
                                      'comment': comment,
                                      'createdAt': FieldValue.serverTimestamp(),
                                    });
                                    if (!mounted) return;
                                    sheetNavigator.pop();
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: const Text(
                                            'Thank you! Your review has been submitted.'),
                                        behavior: SnackBarBehavior.floating,
                                        backgroundColor:
                                            const Color(0xFF1F6E43),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                    );
                                  } catch (_) {
                                    if (!mounted) return;
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: const Text(
                                            'Could not submit review. Please try again.'),
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                    );
                                    setModalState(() => isSubmitting = false);
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.ink,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(isSubmitting
                              ? 'Submitting...'
                              : 'Submit Review'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    commentController.dispose();
  }

  void _openAddOnSheet(AddOnType type, List<AddOnModel> addOns) {
    final filtered =
        addOns.where((a) => a.type == type && a.isActive).toList();
    if (filtered.isEmpty) return;
    AddOnVariantSelectionPage.open(
      context,
      categoryType: type,
      variants: filtered,
    ).then((selected) {
      if (selected != null && mounted) {
        _onAddOnSelected(selected);
      }
    });
  }

  void _orderViaWhatsApp(FlowerModel bouquet) {
    final l10n = AppLocalizations.of(context)!;
    final productUrl = '${Uri.base.origin}/p/${widget.flowerId}';
    launchOrderWhatsApp(
      flowerName: bouquet.name,
      flowerPrice: formatPriceWithCurrency(bouquet.priceIqd, l10n.currencyIqd),
      flowerId: widget.flowerId,
      flowerImageUrl: bouquet.imageUrls.isNotEmpty
          ? bouquet.imageUrls.first
          : '',
      bouquetCode:
          bouquet.bouquetCode.isNotEmpty ? bouquet.bouquetCode : null,
      selectedAddOns: _selectedAddOnsList().isEmpty ? null : _selectedAddOnsList(),
      totalPriceIqd: _totalPriceIqd(bouquet),
      promoCode: _appliedPromoCode,
      promoDiscountPercentage: _appliedPromoDiscountPercentage,
      discountedTotalPriceIqd: _discountedTotalPriceIqd(bouquet),
      productUrl: productUrl,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bouquetAsync = ref.watch(bouquetDetailProvider(widget.flowerId));
    final addOnsAsync = ref.watch(addOnsProvider(null));
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;

    return AppScaffold(
      child: bouquetAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Product not found',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.pop(),
                child: const Text('Go back'),
              ),
            ],
          ),
        ),
        data: (bouquet) {
          if (bouquet == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Product not found',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => context.pop(),
                    child: const Text('Go back'),
                  ),
                ],
              ),
            );
          }

          final imageUrl = bouquet.imageUrls.isNotEmpty
              ? bouquet.imageUrls.first
              : 'https://images.unsplash.com/photo-1490750967868-88aa4486c946?auto=format&fit=crop&w=800&q=80';
          final addOns = addOnsAsync.maybeWhen(
              data: (list) => list, orElse: () => <AddOnModel>[]);
          final total = _totalPriceIqd(bouquet);
          final discountedTotal = _discountedTotalPriceIqd(bouquet);
          final hasPromo =
              _appliedPromoCode != null && _appliedPromoDiscountPercentage != null;

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsetsDirectional.fromSTEB(24, 24, 24, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Top: large image + name + base price
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: AspectRatio(
                          aspectRatio: 4 / 5,
                          child: AppCachedImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            memCacheWidth: 800,
                            memCacheHeight: 1000,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        bouquet.name,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: AppColors.ink,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 8),
                      StreamBuilder<List<_ReviewItem>>(
                        stream: _reviewsStream(widget.flowerId),
                        builder: (context, snapshot) {
                          final reviews = snapshot.data ?? const <_ReviewItem>[];
                          final count = reviews.length;
                          final average = count == 0
                              ? 0.0
                              : reviews
                                      .map((r) => r.rating)
                                      .reduce((a, b) => a + b) /
                                  count;
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.badgeGoldBackground,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: AppColors.accentGold.withValues(alpha: 0.45),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  size: 18,
                                  color: _luxuryGold,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  count == 0
                                      ? 'No reviews yet'
                                      : '${average.toStringAsFixed(1)} ($count ${count == 1 ? 'Review' : 'Reviews'})',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: AppColors.ink,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        iqdPriceString(bouquet.priceIqd),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: AppColors.ink,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 30),
                      _CustomerReviewsSection(
                        productId: widget.flowerId,
                        onWriteReviewPressed: () => _showWriteReviewSheet(
                          productId: widget.flowerId,
                          productName: bouquet.name,
                        ),
                      ),
                      const SizedBox(height: 28),
                      // Make it Special
                      Text(
                        l10n.makeItSpecialSectionTitle,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink,
                            ),
                      ),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isNarrow = constraints.maxWidth < 400;
                          if (isNarrow) {
                            return Column(
                              children: [
                                _AddOnCard(
                                  type: AddOnType.vase,
                                  selected: _selectedVase,
                                  locale: locale,
                                  onTap: () =>
                                      _openAddOnSheet(AddOnType.vase, addOns),
                                ),
                                const SizedBox(height: 12),
                                _AddOnCard(
                                  type: AddOnType.chocolate,
                                  selected: _selectedChocolate,
                                  locale: locale,
                                  onTap: () => _openAddOnSheet(
                                      AddOnType.chocolate, addOns),
                                ),
                                const SizedBox(height: 12),
                                _AddOnCard(
                                  type: AddOnType.card,
                                  selected: _selectedCard,
                                  locale: locale,
                                  onTap: () =>
                                      _openAddOnSheet(AddOnType.card, addOns),
                                ),
                              ],
                            );
                          }
                          return Row(
                            children: [
                              Expanded(
                                child: _AddOnCard(
                                  type: AddOnType.vase,
                                  selected: _selectedVase,
                                  locale: locale,
                                  onTap: () => _openAddOnSheet(
                                      AddOnType.vase, addOns),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _AddOnCard(
                                  type: AddOnType.chocolate,
                                  selected: _selectedChocolate,
                                  locale: locale,
                                  onTap: () => _openAddOnSheet(
                                      AddOnType.chocolate, addOns),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _AddOnCard(
                                  type: AddOnType.card,
                                  selected: _selectedCard,
                                  locale: locale,
                                  onTap: () => _openAddOnSheet(
                                      AddOnType.card, addOns),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              // Bottom fixed bar
              Container(
                padding: const EdgeInsetsDirectional.fromSTEB(24, 16, 24, 24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.shadow.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.shadow.withValues(alpha: 0.06),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _promoCodeController,
                                    textCapitalization: TextCapitalization.characters,
                                    decoration: InputDecoration(
                                      hintText: 'Enter Promo Code',
                                      isDense: true,
                                      filled: true,
                                      fillColor: AppColors.background,
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 12,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: AppColors.border,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: AppColors.border,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: AppColors.rosePrimary,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                SizedBox(
                                  height: 46,
                                  child: ElevatedButton(
                                    onPressed: _isApplyingPromo
                                        ? null
                                        : () => _applyPromoCode(bouquet),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.ink,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: Text(_isApplyingPromo ? '...' : 'Apply'),
                                  ),
                                ),
                              ],
                            ),
                            if (hasPromo) ...[
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Icon(
                                    Icons.verified_rounded,
                                    size: 18,
                                    color: const Color(0xFF166534),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Promo ${_appliedPromoCode!} (-${_appliedPromoDiscountPercentage!.toStringAsFixed(_appliedPromoDiscountPercentage! % 1 == 0 ? 0 : 1)}%) applied',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: const Color(0xFF166534),
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            l10n.totalPriceLabel,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: AppColors.inkMuted,
                                  fontWeight: FontWeight.w600,
                                ),
                            textDirection: Directionality.of(context),
                          ),
                          hasPromo
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${l10n.currencyIqd} ${formatPriceIqd(total)}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: AppColors.inkMuted,
                                            decoration:
                                                TextDecoration.lineThrough,
                                          ),
                                      textDirection: Directionality.of(context),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${l10n.currencyIqd} ${formatPriceIqd(discountedTotal)}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            color: const Color(0xFF166534),
                                            fontWeight: FontWeight.w800,
                                          ),
                                      textDirection: Directionality.of(context),
                                    ),
                                  ],
                                )
                              : Text(
                                  '${l10n.currencyIqd} ${formatPriceIqd(total)}',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        color: AppColors.ink,
                                        fontWeight: FontWeight.w700,
                                      ),
                                  textDirection: Directionality.of(context),
                                ),
                        ],
                      ),
                      const SizedBox(height: 16),
SizedBox(
                          width: double.infinity,
                          child: OrderViaWhatsAppButton(
                            label: l10n.orderViaWhatsApp,
                            onPressed: () {
                              ref.read(analyticsServiceProvider).logClickWhatsApp(
                                    itemId: bouquet.id,
                                    itemName: bouquet.name,
                                );
                            _orderViaWhatsApp(bouquet);
                          },
                          enabled: ref.watch(connectivityStatusProvider).value ?? true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CustomerReviewsSection extends StatelessWidget {
  const _CustomerReviewsSection({
    required this.productId,
    required this.onWriteReviewPressed,
  });

  static const Color _luxuryGold = AppColors.accentGold;
  final String productId;
  final VoidCallback onWriteReviewPressed;

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = FirebaseAuth.instance.currentUser != null;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('reviews')
          .where('productId', isEqualTo: productId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? const [];
        final reviews = docs.map(_ReviewItem.fromFirestore).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Customer Reviews',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                if (isLoggedIn)
                  OutlinedButton.icon(
                    onPressed: onWriteReviewPressed,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.ink,
                      side: BorderSide(
                        color: _luxuryGold.withValues(alpha: 0.75),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.rate_review_outlined, size: 18),
                    label: const Text(
                      'Write a Review',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            if (snapshot.connectionState == ConnectionState.waiting)
              const Center(child: CircularProgressIndicator())
            else if (reviews.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  'Be the first to review this product.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.inkMuted,
                      ),
                ),
              )
            else
              Column(
                children: reviews
                    .map(
                      (review) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ReviewCard(review: review),
                      ),
                    )
                    .toList(),
              ),
          ],
        );
      },
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final _ReviewItem review;

  @override
  Widget build(BuildContext context) {
    final dateLabel = review.createdAt == null
        ? 'Just now'
        : MaterialLocalizations.of(context)
            .formatMediumDate(review.createdAt!.toLocal());
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  review.userName,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              Text(
                dateLabel,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.inkMuted,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(5, (index) {
              final filled = review.rating >= index + 1;
              return Icon(
                filled ? Icons.star_rounded : Icons.star_border_rounded,
                size: 18,
                color: filled ? AppColors.accentGold : AppColors.border,
              );
            }),
          ),
          const SizedBox(height: 10),
          Text(
            review.comment,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.ink,
                  height: 1.45,
                ),
          ),
        ],
      ),
    );
  }
}

class _ReviewItem {
  const _ReviewItem({
    required this.userName,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  final String userName;
  final double rating;
  final String comment;
  final DateTime? createdAt;

  factory _ReviewItem.fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final rawRating = data['rating'];
    final rating = rawRating is num ? rawRating.toDouble() : 0.0;
    final clamped = rating.clamp(1.0, 5.0).toDouble();
    final ts = data['createdAt'] as Timestamp?;
    final rawName = data['userName']?.toString().trim() ?? '';
    return _ReviewItem(
      userName: rawName.isEmpty ? 'Valued Customer' : rawName,
      rating: clamped,
      comment: data['comment']?.toString().trim() ?? '',
      createdAt: ts?.toDate(),
    );
  }
}

class _AddOnCard extends StatelessWidget {
  final AddOnType type;
  final AddOnModel? selected;
  final String locale;
  final VoidCallback onTap;

  const _AddOnCard({
    required this.type,
    required this.selected,
    required this.locale,
    required this.onTap,
  });

  IconData get _icon {
    switch (type) {
      case AddOnType.vase:
        return Icons.local_florist_outlined;
      case AddOnType.chocolate:
        return Icons.card_giftcard_outlined;
      case AddOnType.card:
        return Icons.celebration_outlined;
      case AddOnType.teddyBear:
        return Icons.pets_outlined;
    }
  }

  String _label(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (type) {
      case AddOnType.vase:
        return l10n.addVaseLabel;
      case AddOnType.chocolate:
        return l10n.addChocolateLabel;
      case AddOnType.card:
        return l10n.addCardLabel;
      case AddOnType.teddyBear:
        return 'Teddy';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSelected = selected != null;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.rosePrimary : AppColors.border,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isSelected && selected!.imageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: AppCachedImage(
                      imageUrl: selected!.imageUrl,
                      fit: BoxFit.cover,
                      errorIcon: _icon,
                      errorIconSize: 40,
                    ),
                  ),
                )
              else
                Icon(_icon, size: 40, color: AppColors.inkMuted),
              const SizedBox(height: 8),
              Text(
                _label(context),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                textDirection: Directionality.of(context),
              ),
              if (isSelected)
                Text(
                  '${AppLocalizations.of(context)!.currencyIqd} ${formatPriceIqd(selected!.priceIqd)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.inkMuted,
                      ),
                  textAlign: TextAlign.center,
                  textDirection: Directionality.of(context),
                )
              else
                Text(
                  AppLocalizations.of(context)!.selectLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.inkMuted,
                      ),
                  textAlign: TextAlign.center,
                  textDirection: Directionality.of(context),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

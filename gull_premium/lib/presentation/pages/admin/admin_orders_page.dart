import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/whatsapp_order_parser.dart';
import '../../../controllers/controllers.dart';
import '../../../data/models/flower_model.dart';
import '../../../data/models/order_model.dart';
import '../../../data/models/vendor_list_model.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/common/app_cached_image.dart';
import '../../widgets/common/primary_button.dart';
import '../../widgets/oms/oms_order_card.dart';

/// Shared input decoration for admin order form fields.
InputDecoration _adminInputDecoration({
  required String hintText,
  Widget? prefixIcon,
  bool alignLabelWithHint = false,
}) {
  const border = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(16)),
    borderSide: BorderSide(color: AppColors.border),
  );
  return InputDecoration(
    hintText: hintText,
    prefixIcon: prefixIcon,
    alignLabelWithHint: alignLabelWithHint,
    filled: true,
    fillColor: Colors.white,
    border: border,
    enabledBorder: border,
    focusedBorder: border.copyWith(
      borderSide: const BorderSide(color: AppColors.rose),
    ),
  );
}

Widget _labeledField(
  BuildContext context,
  String label,
  TextEditingController controller, {
  String? hint,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: controller,
        decoration: _adminInputDecoration(hintText: hint ?? ''),
        maxLines: label.toLowerCase().contains('link') ? 2 : 1,
      ),
    ],
  );
}

/// Admin OMS: Create Order (search by bouquet code + form) and Order Tracking (tabs by status).
class AdminOrdersPage extends ConsumerStatefulWidget {
  const AdminOrdersPage({super.key});

  @override
  ConsumerState<AdminOrdersPage> createState() => _AdminOrdersPageState();
}

class _AdminOrdersPageState extends ConsumerState<AdminOrdersPage> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addonsController = TextEditingController();
  final TextEditingController _whatsAppPasteController = TextEditingController();
  final TextEditingController _bouquetDetailsController = TextEditingController();
  final TextEditingController _totalPriceController = TextEditingController();
  final TextEditingController _voiceMessageLinkController = TextEditingController();
  final TextEditingController _deliveryLocationLinkController = TextEditingController();
  final TextEditingController _orderDateController = TextEditingController();

  FlowerModel? _foundBouquet;
  String? _vendorName;
  VendorListModel? _selectedVendor;
  bool _isLoadingBouquet = false;
  bool _isSubmitting = false;
  bool _didPreSelectVendor = false;

  @override
  void dispose() {
    _searchController.dispose();
    _phoneController.dispose();
    _addonsController.dispose();
    _whatsAppPasteController.dispose();
    _bouquetDetailsController.dispose();
    _totalPriceController.dispose();
    _voiceMessageLinkController.dispose();
    _deliveryLocationLinkController.dispose();
    _orderDateController.dispose();
    super.dispose();
  }

  void _onAutoExtract() {
    final extract = parseWhatsAppOrderMessage(_whatsAppPasteController.text);
    _phoneController.text = extract.customerPhone;
    _orderDateController.text = extract.orderDate;
    _bouquetDetailsController.text = extract.bouquetDetails;
    _searchController.text = extract.bouquetCode;
    _totalPriceController.text = extract.totalPriceRaw;
    _voiceMessageLinkController.text = extract.voiceMessageLink;
    _deliveryLocationLinkController.text = extract.deliveryLocationLink;
    setState(() {});
    _fetchBouquetByCode();
  }

  Future<void> _fetchBouquetByCode() async {
    final code = _searchController.text.trim();
    if (code.isEmpty) {
      setState(() {
        _foundBouquet = null;
        _vendorName = null;
        _isLoadingBouquet = false;
      });
      return;
    }
    setState(() {
      _isLoadingBouquet = true;
      _foundBouquet = null;
      _vendorName = null;
      _didPreSelectVendor = false;
      _selectedVendor = null;
    });
    try {
      final bouquetRepo = ref.read(bouquetRepositoryProvider);
      final bouquet = await bouquetRepo.getByBouquetCode(code);
      String? vendorName;
      if (bouquet != null && bouquet.vendorId != null && bouquet.vendorId!.isNotEmpty) {
        final authRepo = ref.read(authRepositoryProvider);
        final vendor = await authRepo.getVendorById(bouquet.vendorId!);
        vendorName = vendor?.shopName;
      }
      if (mounted) {
        setState(() {
          _foundBouquet = bouquet;
          _vendorName = vendorName;
          _isLoadingBouquet = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _foundBouquet = null;
          _vendorName = null;
          _isLoadingBouquet = false;
        });
      }
    }
  }

  void _maybePreSelectVendor(List<VendorListModel> vendors) {
    if (_didPreSelectVendor || _selectedVendor != null) return;
    final vendorId = _foundBouquet?.vendorId;
    if (vendorId == null || vendorId.isEmpty) return;
    for (final v in vendors) {
      if (v.id == vendorId) {
        _didPreSelectVendor = true;
        setState(() => _selectedVendor = v);
        return;
      }
    }
  }

  Future<void> _sendForPreparation() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter customer phone number.')),
      );
      return;
    }
    final vendor = _selectedVendor;
    if (vendor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a vendor.')),
      );
      return;
    }
    final bouquetCode = _searchController.text.trim();
    if (bouquetCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bouquet code is required.')),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final repo = ref.read(omsOrderRepositoryProvider);
      final orderId = repo.generateOrderId();
      final extractedPrice = parseTotalPriceFromRaw(_totalPriceController.text.trim());
      final bouquet = _foundBouquet;
      final price = extractedPrice > 0
          ? extractedPrice
          : (bouquet != null
              ? (bouquet.discountPrice != null && bouquet.discountPrice! > 0
                  ? bouquet.discountPrice!
                  : bouquet.priceIqd)
              : 0);
      await repo.createOmsOrder(
        orderId: orderId,
        data: CreateOmsOrderData(
          bouquetId: bouquet?.id ?? '',
          bouquetCode: bouquet?.bouquetCode ?? bouquetCode,
          vendorId: vendor.id,
          customerPhone: phone,
          addons: _addonsController.text.trim(),
          totalPrice: price,
          bouquetName: bouquet?.name ?? bouquetCode,
          vendorName: vendor.shopName,
          bouquetImageUrl: bouquet?.listingImageUrl ?? '',
          bouquetDetails: _bouquetDetailsController.text.trim(),
          voiceMessageLink: _voiceMessageLinkController.text.trim(),
          deliveryLocationLink: _deliveryLocationLinkController.text.trim(),
          orderDate: _orderDateController.text.trim(),
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Order $orderId created and sent for preparation.')),
        );
        _phoneController.clear();
        _addonsController.clear();
        _bouquetDetailsController.clear();
        _totalPriceController.clear();
        _voiceMessageLinkController.clear();
        _deliveryLocationLinkController.clear();
        _orderDateController.clear();
        _searchController.clear();
        setState(() {
          _isSubmitting = false;
          _foundBouquet = null;
          _vendorName = null;
          _selectedVendor = null;
          _didPreSelectVendor = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create order: $e')),
        );
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final vendorsAsync = ref.watch(vendorsListProvider);
    final isMobile = MediaQuery.sizeOf(context).width < kAdminShellDrawerBreakpoint;
    final spacing = isMobile ? 16.0 : 24.0;
    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order Management',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
          ),
          SizedBox(height: spacing / 2),
          Text(
            'Create orders from WhatsApp requests and track status.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.inkMuted,
                ),
          ),
          SizedBox(height: spacing),
          TabBar(
              labelColor: AppColors.rosePrimary,
              unselectedLabelColor: AppColors.inkMuted,
              indicatorColor: AppColors.rosePrimary,
              tabs: const [
                Tab(text: 'Create Order'),
                Tab(text: 'Order Tracking'),
              ],
            ),
            SizedBox(height: spacing),
            Expanded(
              child: TabBarView(
                children: [
                  _BuildCreateOrderTab(
                    searchController: _searchController,
                    phoneController: _phoneController,
                    addonsController: _addonsController,
                    whatsAppPasteController: _whatsAppPasteController,
                    bouquetDetailsController: _bouquetDetailsController,
                    totalPriceController: _totalPriceController,
                    voiceMessageLinkController: _voiceMessageLinkController,
                    deliveryLocationLinkController: _deliveryLocationLinkController,
                    orderDateController: _orderDateController,
                    foundBouquet: _foundBouquet,
                    vendorName: _vendorName,
                    vendorsAsync: vendorsAsync,
                    selectedVendor: _selectedVendor,
                    onVendorSelected: (v) => setState(() => _selectedVendor = v),
                    onVendorsLoadedForPreSelect: _maybePreSelectVendor,
                    isLoadingBouquet: _isLoadingBouquet,
                    isSubmitting: _isSubmitting,
                    onAutoExtract: _onAutoExtract,
                    onSendForPreparation: _sendForPreparation,
                    l10n: l10n,
                  ),
                  const _OrderTrackingTab(),
                ],
              ),
            ),
          ],
        ),
    );
  }
}

class _BuildCreateOrderTab extends StatelessWidget {
  final TextEditingController searchController;
  final TextEditingController phoneController;
  final TextEditingController addonsController;
  final TextEditingController whatsAppPasteController;
  final TextEditingController bouquetDetailsController;
  final TextEditingController totalPriceController;
  final TextEditingController voiceMessageLinkController;
  final TextEditingController deliveryLocationLinkController;
  final TextEditingController orderDateController;
  final FlowerModel? foundBouquet;
  final String? vendorName;
  final AsyncValue<List<VendorListModel>> vendorsAsync;
  final VendorListModel? selectedVendor;
  final ValueChanged<VendorListModel?> onVendorSelected;
  final void Function(List<VendorListModel>)? onVendorsLoadedForPreSelect;
  final bool isLoadingBouquet;
  final bool isSubmitting;
  final VoidCallback onAutoExtract;
  final VoidCallback onSendForPreparation;
  final AppLocalizations l10n;

  const _BuildCreateOrderTab({
    required this.searchController,
    required this.phoneController,
    required this.addonsController,
    required this.whatsAppPasteController,
    required this.bouquetDetailsController,
    required this.totalPriceController,
    required this.voiceMessageLinkController,
    required this.deliveryLocationLinkController,
    required this.orderDateController,
    required this.foundBouquet,
    required this.vendorName,
    required this.vendorsAsync,
    required this.selectedVendor,
    required this.onVendorSelected,
    this.onVendorsLoadedForPreSelect,
    required this.isLoadingBouquet,
    required this.isSubmitting,
    required this.onAutoExtract,
    required this.onSendForPreparation,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ----- Paste WhatsApp message & Auto-Extract -----
                Text(
                  'Paste WhatsApp Message Here',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.inkMuted,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: whatsAppPasteController,
                  maxLines: 6,
                  decoration: _adminInputDecoration(
                    hintText: 'Paste the full WhatsApp order message (Flower:, Bouquet Code:, Total Price:, etc.)',
                    prefixIcon: null,
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onAutoExtract,
                    icon: const Text('✨'),
                    label: const Text('Auto-Extract Information'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.rosePrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                // ----- Individual extracted fields -----
                _labeledField(context, 'Customer Phone', phoneController, hint: '+964... or Not provided'),
                const SizedBox(height: 16),
                _labeledField(context, 'Order Date', orderDateController, hint: 'e.g. 2026-03-09 14:30'),
                const SizedBox(height: 16),
                _labeledField(context, 'Bouquet Details', bouquetDetailsController, hint: 'e.g. Bouquet - IQD 35,000'),
                const SizedBox(height: 16),
                _labeledField(context, 'Bouquet Code', searchController, hint: 'e.g. AN-2 or #BQT-102'),
                const SizedBox(height: 12),
                _BouquetImagePreview(
                  isLoading: isLoadingBouquet,
                  imageUrl: foundBouquet?.listingImageUrl,
                  hasCode: searchController.text.trim().isNotEmpty,
                ),
                const SizedBox(height: 16),
                _labeledField(context, 'Total Price', totalPriceController, hint: 'e.g. IQD 35,000'),
                const SizedBox(height: 16),
                _labeledField(context, 'Voice Message Link', voiceMessageLinkController, hint: 'https://...'),
                const SizedBox(height: 16),
                _labeledField(context, 'Delivery Location Link', deliveryLocationLinkController, hint: 'http://...'),
                const SizedBox(height: 24),
                Text(
                  'Select Vendor',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                ),
                const SizedBox(height: 8),
                vendorsAsync.when(
                  loading: () => _VendorDropdownLoading(),
                  error: (_, __) => _VendorDropdownError(),
                  data: (vendors) {
                    if (onVendorsLoadedForPreSelect != null &&
                        foundBouquet != null &&
                        selectedVendor == null) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        onVendorsLoadedForPreSelect!(vendors);
                      });
                    }
                    return _VendorSearchDropdown(
                      vendors: vendors,
                      selectedVendor: selectedVendor,
                      onVendorSelected: onVendorSelected,
                    );
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  'Requested Add-ons (Notes)',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: addonsController,
                  maxLines: 3,
                  decoration: _adminInputDecoration(
                    hintText: 'e.g. Vase, card message...',
                    prefixIcon: null,
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: PrimaryButton(
                    label: isSubmitting
                        ? 'Creating...'
                        : 'Send the bouquet For preparation',
                    onPressed: isSubmitting ? () {} : onSendForPreparation,
                    variant: PrimaryButtonVariant.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Minimalist bouquet image preview below Bouquet Code (loading / image / not found).
class _BouquetImagePreview extends StatelessWidget {
  final bool isLoading;
  final String? imageUrl;
  final bool hasCode;

  const _BouquetImagePreview({
    required this.isLoading,
    this.imageUrl,
    required this.hasCode,
  });

  @override
  Widget build(BuildContext context) {
    if (!hasCode) return const SizedBox.shrink();
    const size = 140.0;
    const radius = 16.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: isLoading
            ? Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.rose.withValues(alpha: 0.8),
                  ),
                ),
              )
            : (imageUrl != null && imageUrl!.isNotEmpty)
                ? AppCachedImage(
                    imageUrl: imageUrl!,
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                    memCacheWidth: 280,
                    memCacheHeight: 280,
                    borderRadius: BorderRadius.circular(radius),
                  )
                : Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.image_not_supported_outlined,
                          size: 32,
                          color: AppColors.inkMuted.withValues(alpha: 0.6),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Image not found',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.inkMuted,
                              ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}

/// Loading placeholder for the vendor dropdown.
class _VendorDropdownLoading extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.rose),
          ),
          const SizedBox(width: 12),
          Text(
            'Loading vendors...',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.inkMuted,
                ),
          ),
        ],
      ),
    );
  }
}

/// Error placeholder for the vendor dropdown.
class _VendorDropdownError extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        'Could not load vendors.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.inkMuted,
            ),
      ),
    );
  }
}

/// Searchable dropdown that shows all vendors; filters by search text.
class _VendorSearchDropdown extends StatelessWidget {
  final List<VendorListModel> vendors;
  final VendorListModel? selectedVendor;
  final ValueChanged<VendorListModel?> onVendorSelected;

  const _VendorSearchDropdown({
    required this.vendors,
    required this.selectedVendor,
    required this.onVendorSelected,
  });

  void _openPicker(BuildContext context) {
    if (vendors.isEmpty) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => _VendorPickerSheet(
        vendors: vendors,
        initialSearch: '',
        selectedVendor: selectedVendor,
        onSelected: (v) {
          onVendorSelected(v);
          Navigator.of(ctx).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEmpty = vendors.isEmpty;
    return InkWell(
      onTap: isEmpty ? null : () => _openPicker(context),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.store_outlined, color: AppColors.inkMuted, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                selectedVendor?.shopName ?? (isEmpty ? 'No vendors' : 'Select vendor...'),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: selectedVendor != null ? AppColors.ink : AppColors.inkMuted,
                    ),
              ),
            ),
            if (!isEmpty)
              Icon(Icons.arrow_drop_down, color: AppColors.inkMuted, size: 28),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet content: search field + filtered vendor list.
class _VendorPickerSheet extends StatefulWidget {
  final List<VendorListModel> vendors;
  final String initialSearch;
  final VendorListModel? selectedVendor;
  final ValueChanged<VendorListModel?> onSelected;

  const _VendorPickerSheet({
    required this.vendors,
    required this.initialSearch,
    required this.selectedVendor,
    required this.onSelected,
  });

  @override
  State<_VendorPickerSheet> createState() => _VendorPickerSheetState();
}

class _VendorPickerSheetState extends State<_VendorPickerSheet> {
  late TextEditingController _searchController;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialSearch);
    _query = widget.initialSearch;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<VendorListModel> _filterVendors(String query) {
    if (query.isEmpty) return widget.vendors;
    final lower = query.toLowerCase();
    return widget.vendors
        .where((v) => v.shopName.toLowerCase().contains(lower))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filterVendors(_query);
    final screenHeight = MediaQuery.sizeOf(context).height;
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: 400,
            maxHeight: screenHeight * 0.6,
          ),
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Select vendor',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Search vendors...',
                    prefixIcon: const Icon(Icons.search, color: AppColors.inkMuted),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.rose)),
                  ),
                  onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: filtered.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            'No vendors match your search.',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppColors.inkMuted,
                                ),
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final v = filtered[index];
                          final isSelected = widget.selectedVendor?.id == v.id;
                          return ListTile(
                            leading: Icon(
                              Icons.store,
                              color: isSelected ? AppColors.rosePrimary : AppColors.inkMuted,
                              size: 22,
                            ),
                            title: Text(
                              v.shopName,
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                color: isSelected ? AppColors.rosePrimary : AppColors.ink,
                              ),
                            ),
                            onTap: () => widget.onSelected(v),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderTrackingTab extends ConsumerStatefulWidget {
  const _OrderTrackingTab();

  @override
  ConsumerState<_OrderTrackingTab> createState() => _OrderTrackingTabState();
}

class _OrderTrackingTabState extends ConsumerState<_OrderTrackingTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AdminPillTabBar(controller: _tabController),
        const SizedBox(height: 16),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              _AdminOrderListByStatus(status: OmsOrderStatus.pending),
              _AdminOrderListByStatus(status: OmsOrderStatus.preparing),
              _AdminOrderListByStatus(status: OmsOrderStatus.ready),
              _AdminOrderListByStatus(status: OmsOrderStatus.delivered),
            ],
          ),
        ),
      ],
    );
  }
}

/// Pill-shaped segmented control for admin order status tabs (matches vendor_orders_page style).
/// Scrollable so all 4 tabs fit on narrow screens.
class _AdminPillTabBar extends StatelessWidget {
  final TabController controller;

  const _AdminPillTabBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TabBar(
        controller: controller,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicator: BoxDecoration(
          color: AppColors.rosePrimary.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppColors.rosePrimary.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: AppColors.rosePrimary,
        unselectedLabelColor: AppColors.inkMuted,
        labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
        unselectedLabelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w500,
            ),
        labelPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        tabs: const [
          Tab(text: 'Pending'),
          Tab(text: 'Bouquet Preparation'),
          Tab(text: 'Ready Bouquets'),
          Tab(text: 'Delivered'),
        ],
      ),
    );
  }
}

class _AdminOrderListByStatus extends ConsumerStatefulWidget {
  final OmsOrderStatus status;

  const _AdminOrderListByStatus({required this.status});

  @override
  ConsumerState<_AdminOrderListByStatus> createState() => _AdminOrderListByStatusState();
}

class _AdminOrderListByStatusState extends ConsumerState<_AdminOrderListByStatus> {
  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(omsOrdersForAdminStreamProvider);
    return ordersAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.rose),
      ),
      error: (_, __) => Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 56),
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.inkMuted.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.cloud_off_outlined,
                  size: 48,
                  color: AppColors.inkMuted.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Unable to load orders.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.inkMuted,
                      fontWeight: FontWeight.w500,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
      data: (allOrders) {
        final orders = allOrders.where((o) => o.status == widget.status).toList();
        if (orders.isEmpty) {
          return Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 56),
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.inkMuted.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.inbox_outlined,
                      size: 48,
                      color: AppColors.inkMuted.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _emptyLabel(widget.status),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.inkMuted,
                          fontWeight: FontWeight.w500,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 24),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            return OmsOrderCard(
              order: orders[index],
              showVendorLine: true,
              showOrderIdInSubtitle: true,
            );
          },
        );
      },
    );
  }

  static String _emptyLabel(OmsOrderStatus s) {
    switch (s) {
      case OmsOrderStatus.pending:
        return 'No pending orders.';
      case OmsOrderStatus.preparing:
        return 'No orders in preparation.';
      case OmsOrderStatus.ready:
        return 'No ready bouquets.';
      case OmsOrderStatus.delivered:
        return 'No delivered orders.';
    }
  }
}


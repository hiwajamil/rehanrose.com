import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/price_format_utils.dart';
import '../../../controllers/controllers.dart';
import '../../../data/models/flower_model.dart';
import '../../../data/models/order_model.dart';
import '../../../data/models/vendor_list_model.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/common/primary_button.dart';
import '../../widgets/layout/app_scaffold.dart';
import '../../widgets/layout/section_container.dart';
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

  FlowerModel? _foundBouquet;
  String? _vendorName;
  VendorListModel? _selectedVendor;
  bool _isSearching = false;
  bool _isSubmitting = false;
  bool _didPreSelectVendor = false;

  @override
  void dispose() {
    _searchController.dispose();
    _phoneController.dispose();
    _addonsController.dispose();
    super.dispose();
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

  Future<void> _searchBouquet() async {
    final code = _searchController.text.trim();
    if (code.isEmpty) return;
    setState(() {
      _isSearching = true;
      _foundBouquet = null;
      _vendorName = null;
      _selectedVendor = null;
      _didPreSelectVendor = false;
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
        _didPreSelectVendor = false;
        setState(() {
          _foundBouquet = bouquet;
          _vendorName = vendorName;
          _isSearching = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _foundBouquet = null;
          _vendorName = null;
          _selectedVendor = null;
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _sendForPreparation() async {
    final bouquet = _foundBouquet;
    if (bouquet == null) return;
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
        const SnackBar(content: Text('Please select a vendor from the dropdown.')),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final repo = ref.read(omsOrderRepositoryProvider);
      final orderId = repo.generateOrderId();
      final price = bouquet.discountPrice != null && bouquet.discountPrice! > 0
          ? bouquet.discountPrice!
          : bouquet.priceIqd;
      await repo.createOmsOrder(
        orderId: orderId,
        data: CreateOmsOrderData(
          bouquetId: bouquet.id,
          bouquetCode: bouquet.bouquetCode,
          vendorId: vendor.id,
          customerPhone: phone,
          addons: _addonsController.text.trim(),
          totalPrice: price,
          bouquetName: bouquet.name,
          vendorName: vendor.shopName,
          bouquetImageUrl: bouquet.listingImageUrl,
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Order $orderId created and assigned to vendor.')),
        );
        _phoneController.clear();
        _addonsController.clear();
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
    return AppScaffold(
      child: DefaultTabController(
        length: 2,
        child: SectionContainer(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Order Management',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const Spacer(),
                PrimaryButton(
                  label: 'Back to Dashboard',
                  onPressed: () => context.go('/admin'),
                  variant: PrimaryButtonVariant.outline,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Create orders from WhatsApp requests and track status.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.inkMuted,
                  ),
            ),
            const SizedBox(height: 24),
            TabBar(
              labelColor: AppColors.rosePrimary,
              unselectedLabelColor: AppColors.inkMuted,
              indicatorColor: AppColors.rosePrimary,
              tabs: const [
                Tab(text: 'Create Order'),
                Tab(text: 'Order Tracking'),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: (MediaQuery.sizeOf(context).height - 280).clamp(400.0, 1000.0),
              child: TabBarView(
                children: [
                  _BuildCreateOrderTab(
                    searchController: _searchController,
                    phoneController: _phoneController,
                    addonsController: _addonsController,
                    foundBouquet: _foundBouquet,
                    vendorName: _vendorName,
                    vendorsAsync: vendorsAsync,
                    selectedVendor: _selectedVendor,
                    onVendorSelected: (v) => setState(() => _selectedVendor = v),
                    onVendorsLoadedForPreSelect: _maybePreSelectVendor,
                    isSearching: _isSearching,
                    isSubmitting: _isSubmitting,
                    onSearch: _searchBouquet,
                    onSendForPreparation: _sendForPreparation,
                    l10n: l10n,
                  ),
                  const _OrderTrackingTab(),
                ],
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

class _BuildCreateOrderTab extends StatelessWidget {
  final TextEditingController searchController;
  final TextEditingController phoneController;
  final TextEditingController addonsController;
  final FlowerModel? foundBouquet;
  final String? vendorName;
  final AsyncValue<List<VendorListModel>> vendorsAsync;
  final VendorListModel? selectedVendor;
  final ValueChanged<VendorListModel?> onVendorSelected;
  final void Function(List<VendorListModel>)? onVendorsLoadedForPreSelect;
  final bool isSearching;
  final bool isSubmitting;
  final VoidCallback onSearch;
  final VoidCallback onSendForPreparation;
  final AppLocalizations l10n;

  const _BuildCreateOrderTab({
    required this.searchController,
    required this.phoneController,
    required this.addonsController,
    required this.foundBouquet,
    required this.vendorName,
    required this.vendorsAsync,
    required this.selectedVendor,
    required this.onVendorSelected,
    this.onVendorsLoadedForPreSelect,
    required this.isSearching,
    required this.isSubmitting,
    required this.onSearch,
    required this.onSendForPreparation,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Search by bouquet code (e.g. #BQT-102)',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.inkMuted,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: searchController,
                  decoration: _adminInputDecoration(
                    hintText: '#BQT-102',
                    prefixIcon: const Icon(Icons.search, color: AppColors.inkMuted),
                  ),
                  onSubmitted: (_) => onSearch(),
                ),
              ),
              const SizedBox(width: 12),
              PrimaryButton(
                label: isSearching ? 'Searching...' : 'Search',
                onPressed: isSearching ? () {} : onSearch,
              ),
            ],
          ),
          const SizedBox(height: 32),
          if (foundBouquet != null) ...[
            _BouquetCard(
              bouquet: foundBouquet!,
              vendorName: vendorName ?? '—',
              l10n: l10n,
            ),
            const SizedBox(height: 24),
            Text(
              'Assign to vendor',
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
              'Customer Phone Number',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: _adminInputDecoration(
                hintText: '+964... or local number',
                prefixIcon: const Icon(Icons.phone_outlined, color: AppColors.inkMuted),
              ),
            ),
            const SizedBox(height: 16),
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
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: PrimaryButton(
                label: isSubmitting
                    ? 'Creating...'
                    : 'Send The Bouquet For Preparation',
                onPressed: isSubmitting ? () {} : onSendForPreparation,
                variant: PrimaryButtonVariant.primary,
              ),
            ),
          ] else if (isSearching)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(48),
                child: CircularProgressIndicator(color: AppColors.rose),
              ),
            )
          else
            Center(
              child: Padding(
                padding: const EdgeInsets.all(48),
                child: Column(
                  children: [
                    Icon(Icons.search, size: 64, color: AppColors.inkMuted),
                    const SizedBox(height: 16),
                    Text(
                      'Enter a bouquet code and tap Search.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppColors.inkMuted,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
        ],
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
        border: Border.all(color: AppColors.border),
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
        border: Border.all(color: AppColors.border),
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
          border: Border.all(color: AppColors.border),
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

class _BouquetCard extends StatelessWidget {
  final FlowerModel bouquet;
  final String vendorName;
  final AppLocalizations l10n;

  const _BouquetCard({
    required this.bouquet,
    required this.vendorName,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final price = bouquet.discountPrice != null && bouquet.discountPrice! > 0
        ? bouquet.discountPrice!
        : bouquet.priceIqd;
    final priceStr = '${l10n.currencyIqd} ${formatPriceIqd(price)}';
    final imageUrl = bouquet.listingImageUrl;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                imageUrl,
                width: 120,
                height: 120,
                fit: BoxFit.cover,
                cacheWidth: 240,
                cacheHeight: 240,
                errorBuilder: (_, __, ___) => Container(
                  width: 120,
                  height: 120,
                  color: AppColors.border,
                  child: const Icon(Icons.local_florist, size: 48, color: AppColors.inkMuted),
                ),
              ),
            ),
          if (imageUrl.isNotEmpty) const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bouquet.name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Code: #${bouquet.bouquetCode}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.inkMuted,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Vendor: $vendorName',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.ink,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  priceStr,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.rosePrimary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderTrackingTab extends ConsumerWidget {
  const _OrderTrackingTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TabBar(
            isScrollable: true,
            labelColor: AppColors.rosePrimary,
            unselectedLabelColor: AppColors.inkMuted,
            indicatorColor: AppColors.rosePrimary,
            tabs: const [
              Tab(text: 'Pending'),
              Tab(text: 'Bouquet Preparation'),
              Tab(text: 'Ready Bouquets'),
              Tab(text: 'Delivered'),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: TabBarView(
              children: [
                _AdminOrderListByStatus(status: OmsOrderStatus.pending),
                _AdminOrderListByStatus(status: OmsOrderStatus.preparing),
                _AdminOrderListByStatus(status: OmsOrderStatus.ready),
                _AdminOrderListByStatus(status: OmsOrderStatus.delivered),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminOrderListByStatus extends ConsumerWidget {
  final OmsOrderStatus status;

  const _AdminOrderListByStatus({required this.status});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(omsOrdersForAdminStreamProvider);
    return ordersAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.rose),
      ),
      error: (e, _) => Center(
        child: Text(
          'Unable to load orders.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.inkMuted,
              ),
        ),
      ),
      data: (allOrders) {
        final orders = allOrders.where((o) => o.status == status).toList();
        if (orders.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inbox_outlined,
                  size: 48,
                  color: AppColors.inkMuted,
                ),
                const SizedBox(height: 16),
                Text(
                  _emptyLabel(status),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.inkMuted,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 24),
          itemCount: orders.length,
          itemBuilder: (context, index) => OmsOrderCard(
            order: orders[index],
            showVendorLine: true,
            showOrderIdInSubtitle: true,
          ),
        );
      },
    );
  }

  String _emptyLabel(OmsOrderStatus s) {
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


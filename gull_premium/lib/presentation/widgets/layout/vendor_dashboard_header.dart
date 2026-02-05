import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/breakpoints.dart';
import '../../../core/theme/app_colors.dart';

/// Premium vendor dashboard header: brand, search, online/offline toggle,
/// notifications, profile dropdown. Responsive (mobile + desktop).
/// [leading] is shown at the start on mobile (e.g. drawer menu icon).
class VendorDashboardHeader extends StatefulWidget {
  final String vendorName;
  final int unreadNotificationCount;
  final VoidCallback? onProfile;
  final VoidCallback? onShopSettings;
  final VoidCallback? onLogout;
  final ValueChanged<bool>? onShopStatusChanged;
  /// Optional leading widget (e.g. menu icon for drawer). Shown before brand on small screens.
  final Widget? leading;

  const VendorDashboardHeader({
    super.key,
    this.vendorName = 'Vendor',
    this.unreadNotificationCount = 0,
    this.onProfile,
    this.onShopSettings,
    this.onLogout,
    this.onShopStatusChanged,
    this.leading,
  });

  @override
  State<VendorDashboardHeader> createState() => _VendorDashboardHeaderState();
}

class _VendorDashboardHeaderState extends State<VendorDashboardHeader> {
  bool _isOnline = false;
  bool _searchExpanded = false;
  bool _showProfileMenu = false;
  bool _showNotificationsMenu = false;
  final FocusNode _searchFocusNode = FocusNode();
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _closeOverlays() {
    setState(() {
      _searchExpanded = false;
      _showProfileMenu = false;
      _showNotificationsMenu = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width <= kMobileBreakpoint;
    final horizontalPadding = isMobile ? 16.0 : 32.0;
    final showOverlay = _showProfileMenu || _showNotificationsMenu;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: AppColors.border)),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 0,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 56,
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: Row(
                  children: [
                    if (widget.leading != null) widget.leading!,
                    _buildBrand(context),
                    if (!isMobile) Expanded(child: _buildCenterSearch(context)),
                    const Spacer(),
                    if (isMobile) _buildMobileSearchTrigger(context),
                    if (!isMobile) _buildStatusToggle(context),
                    _buildNotificationBell(context),
                    _buildProfileButton(context, isMobile),
                  ],
                ),
              ),
              if (isMobile && _searchExpanded) _buildMobileSearchBar(context),
            ],
          ),
        ),
        if (showOverlay) _buildOverlay(context),
      ],
    );
  }

  Widget _buildOverlay(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      bottom: -400,
      child: GestureDetector(
        onTap: _closeOverlays,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            if (_showProfileMenu) _buildProfileDropdown(context),
            if (_showNotificationsMenu) _buildNotificationsDropdown(context),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationsDropdown(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 56 + 8, right: 16),
      child: Material(
        elevation: 8,
        shadowColor: AppColors.shadow,
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
        child: Container(
          width: 280,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            'No new notifications.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.inkMuted,
                ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrand(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go('/'),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Text(
          'Rehan Rose',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.ink,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
        ),
      ),
    );
  }

  void _submitBouquetSearch(BuildContext context) {
    final code = _searchController.text.trim();
    _closeOverlays();
    if (code.isEmpty) {
      context.go('/vendor/bouquets');
      return;
    }
    context.go('/vendor/bouquets?code=${Uri.encodeComponent(code)}');
  }

  Widget _buildCenterSearch(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: TextField(
          controller: _searchController,
          onSubmitted: (_) => _submitBouquetSearch(context),
          decoration: InputDecoration(
            hintText: 'Search by bouquet code...',
            hintStyle: TextStyle(color: AppColors.inkMuted, fontSize: 14),
            prefixIcon: Icon(Icons.search, size: 20, color: AppColors.inkMuted),
            suffixIcon: IconButton(
              icon: Icon(Icons.search, size: 20, color: AppColors.inkMuted),
              onPressed: () => _submitBouquetSearch(context),
              tooltip: 'Search',
            ),
            filled: true,
            fillColor: AppColors.background,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.rose, width: 1),
            ),
          ),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.ink,
                fontSize: 14,
              ),
        ),
      ),
    );
  }

  Widget _buildMobileSearchTrigger(BuildContext context) {
    return IconButton(
      onPressed: () => setState(() => _searchExpanded = true),
      icon: Icon(Icons.search, color: AppColors.inkMuted, size: 22),
      style: IconButton.styleFrom(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.inkMuted,
      ),
      tooltip: 'Search',
    );
  }

  Widget _buildMobileSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              autofocus: true,
              focusNode: _searchFocusNode,
              onSubmitted: (_) => _submitBouquetSearch(context),
              decoration: InputDecoration(
                hintText: 'Search by bouquet code...',
                hintStyle: TextStyle(color: AppColors.inkMuted, fontSize: 14),
                prefixIcon: Icon(Icons.search, size: 20, color: AppColors.inkMuted),
                filled: true,
                fillColor: AppColors.background,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.rose, width: 1),
                ),
              ),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.ink,
                    fontSize: 14,
                  ),
            ),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: () => _submitBouquetSearch(context),
            child: Text(
              'Search',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          TextButton(
            onPressed: _closeOverlays,
            child: Text(
              'Cancel',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.inkMuted,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusToggle(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _isOnline ? 'Online' : 'Offline',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.inkMuted,
                  fontWeight: FontWeight.w500,
                ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              setState(() => _isOnline = !_isOnline);
              widget.onShopStatusChanged?.call(_isOnline);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 24,
              decoration: BoxDecoration(
                color: _isOnline ? const Color(0xFF10B981) : AppColors.border,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isOnline ? const Color(0xFF10B981) : AppColors.border,
                ),
              ),
              child: Align(
                alignment: _isOnline ? Alignment.centerRight : Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.shadow,
                          blurRadius: 2,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationBell(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: () {
            setState(() {
              _showNotificationsMenu = !_showNotificationsMenu;
              _showProfileMenu = false;
            });
          },
          icon: Icon(Icons.notifications_none, color: AppColors.inkMuted, size: 22),
          style: IconButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: AppColors.inkMuted,
          ),
          tooltip: 'Notifications',
        ),
        if (widget.unreadNotificationCount > 0)
          Positioned(
            top: 6,
            right: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              constraints: const BoxConstraints(minWidth: 16),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                widget.unreadNotificationCount > 99
                    ? '99+'
                    : '${widget.unreadNotificationCount}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProfileButton(BuildContext context, bool isMobile) {
    final initial = widget.vendorName.isNotEmpty
        ? widget.vendorName[0].toUpperCase()
        : 'V';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _showProfileMenu = !_showProfileMenu;
            _showNotificationsMenu = false;
          });
        },
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.rose.withValues(alpha: 0.2),
                child: Text(
                  initial,
                  style: TextStyle(
                    color: AppColors.rose,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              if (!isMobile) ...[
                const SizedBox(width: 8),
                Text(
                  widget.vendorName,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w500,
                      ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.keyboard_arrow_down, size: 20, color: AppColors.inkMuted),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileDropdown(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 56 + 8, right: 16),
      child: Material(
        elevation: 8,
        shadowColor: AppColors.shadow,
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
        child: Container(
          width: 200,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _dropdownItem(context, 'Profile', Icons.person_outline, widget.onProfile),
              _dropdownItem(context, 'Shop Settings', Icons.settings_outlined, widget.onShopSettings),
              const Divider(height: 16),
              _dropdownItem(context, 'Logout', Icons.logout, widget.onLogout, isDestructive: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dropdownItem(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback? onTap, {
    bool isDestructive = false,
  }) {
    final color = isDestructive ? Colors.red : AppColors.ink;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          _closeOverlays();
          onTap?.call();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 12),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

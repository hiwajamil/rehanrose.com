import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';

/// Modal bottom sheet to add or edit a user occasion (name, date, relation).
class AddOccasionSheet extends StatefulWidget {
  const AddOccasionSheet({
    super.key,
    required this.titleText,
    required this.submitText,
    required this.successText,
    required this.onSave,
    required this.l10n,
    this.initialName,
    this.initialDate,
    this.initialRelation,
  });

  final String titleText;
  final String submitText;
  final String successText;
  final Future<void> Function(String name, DateTime date, String relation) onSave;
  final AppLocalizations l10n;
  final String? initialName;
  final DateTime? initialDate;
  final String? initialRelation;

  @override
  State<AddOccasionSheet> createState() => _AddOccasionSheetState();
}

class _AddOccasionSheetState extends State<AddOccasionSheet> {
  static const List<String> _relationOptions = <String>[
    'Wife',
    'Husband',
    'Mother',
    'Friend',
    'Other',
  ];

  final _nameController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String _selectedRelation = 'Other';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final initialName = widget.initialName?.trim();
    if (initialName != null && initialName.isNotEmpty) {
      _nameController.text = initialName;
    }
    if (widget.initialDate != null) {
      _selectedDate = widget.initialDate!;
    }
    final initialRelation = widget.initialRelation?.trim();
    if (initialRelation != null && initialRelation.isNotEmpty) {
      _selectedRelation = _relationOptions.contains(initialRelation)
          ? initialRelation
          : 'Other';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.forestGreen,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) setState(() => _selectedDate = picked);
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an occasion name.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.onSave(name, _selectedDate, _selectedRelation);
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.successText),
          backgroundColor: AppColors.forestGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: 24 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.creamBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.titleText,
            style: GoogleFonts.playfairDisplay(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: AppColors.inkCharcoal,
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Occasion name (e.g. Birthday, Anniversary)',
              hintText: 'Birthday, Anniversary, Mother\'s Day…',
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.forestGreen, width: 1.5),
              ),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 20),
          Text(
            'Who is this for?',
            style: GoogleFonts.montserrat(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.inkCharcoal,
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _relationOptions.map((relation) {
                final isSelected = _selectedRelation == relation;
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: ChoiceChip(
                    label: Text(relation),
                    selected: isSelected,
                    onSelected: _saving
                        ? null
                        : (selected) {
                            if (!selected || _selectedRelation == relation) return;
                            HapticFeedback.lightImpact();
                            setState(() => _selectedRelation = relation);
                          },
                    labelStyle: GoogleFonts.montserrat(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? AppColors.inkCharcoal : AppColors.inkMuted,
                    ),
                    selectedColor: AppColors.badgeGoldBackground,
                    backgroundColor: AppColors.surface,
                    side: BorderSide(
                      color: isSelected ? AppColors.accentGold : AppColors.border,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                    visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),
          InkWell(
            onTap: _saving ? null : _pickDate,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_rounded, color: AppColors.forestGreen, size: 22),
                  const SizedBox(width: 14),
                  Text(
                    DateFormat.yMMMd().format(_selectedDate),
                    style: GoogleFonts.montserrat(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.inkCharcoal,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.chevron_right_rounded, color: AppColors.inkMuted),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    side: BorderSide(color: AppColors.border),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: _saving ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.forestGreen,
                    foregroundColor: AppColors.surface,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(widget.submitText),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

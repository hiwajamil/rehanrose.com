import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';

/// Fair Process: Admin must select a rejection reason before rejecting a bouquet.
const List<String> rejectionReasons = [
  'Image quality is too low',
  'Price is unreasonable',
  'Incomplete product details',
  'Other (Provide notes)',
];

/// Result of the reject dialog: reason and optional note.
typedef RejectDialogResult = ({String reason, String note});

/// Dialog for selecting a rejection reason and optional note when rejecting a bouquet.
class RejectBouquetDialog extends StatefulWidget {
  const RejectBouquetDialog({super.key});

  @override
  State<RejectBouquetDialog> createState() => _RejectBouquetDialogState();
}

class _RejectBouquetDialogState extends State<RejectBouquetDialog> {
  String _selectedReason = rejectionReasons.first;
  final _noteController = TextEditingController();
  final _noteFocus = FocusNode();

  @override
  void dispose() {
    _noteController.dispose();
    _noteFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final montserrat = GoogleFonts.montserrat();
    final playfair = GoogleFonts.playfairDisplay();
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'Select Reason for Rejection',
        style: playfair.copyWith(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.ink),
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RadioGroup<String>(
                groupValue: _selectedReason,
                onChanged: (v) => setState(() => _selectedReason = v ?? _selectedReason),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: rejectionReasons
                      .map((reason) => RadioListTile<String>(
                            value: reason,
                            title: Text(reason, style: montserrat.copyWith(fontSize: 14, color: AppColors.ink)),
                            activeColor: AppColors.rosePrimary,
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Additional notes (optional)',
                style: montserrat.copyWith(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.inkMuted),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _noteController,
                focusNode: _noteFocus,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Add details to help the vendor fix the issue...',
                  hintStyle: montserrat.copyWith(fontSize: 13, color: AppColors.inkMuted),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                style: montserrat.copyWith(fontSize: 14, color: AppColors.ink),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel', style: montserrat.copyWith(color: AppColors.inkMuted)),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop((
            reason: _selectedReason,
            note: _noteController.text.trim(),
          )),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFC62828),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text('Reject', style: montserrat.copyWith(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

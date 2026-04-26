import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../l10n/app_localizations.dart';

/// Premium bottom sheet: "Who is this for?" and "Occasion?" chips, then Generate with mock delay.
Future<String?> showAiMagicGreetingSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _AiMagicGreetingContent(),
  );
}

class _AiMagicGreetingContent extends StatefulWidget {
  const _AiMagicGreetingContent();

  @override
  State<_AiMagicGreetingContent> createState() => _AiMagicGreetingContentState();
}

class _AiMagicGreetingContentState extends State<_AiMagicGreetingContent> {
  static const List<String> _whoChips = [
    'Partner',
    'Parent',
    'Friend',
    'Colleague',
  ];
  static const List<String> _occasionChips = [
    'Birthday',
    'Anniversary',
    'Thank you',
    'Congratulations',
    'Just because',
  ];

  late String _selectedWho;
  late String _selectedOccasion;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _selectedWho = _whoChips.first;
    _selectedOccasion = _occasionChips.first;
  }

  static String _buildMockGreeting(String who, String occasion) {
    final whoLine = switch (who) {
      'Partner' => 'my dearest',
      'Parent' => 'a wonderful parent and guiding light',
      'Friend' => 'a true friend who brightens every room',
      'Colleague' => 'a valued colleague and kind soul',
      _ => 'someone who means the world to us',
    };

    return switch (occasion) {
      'Birthday' => 'For you, $whoLine, on this special day—\n\n'
          'May these blooms carry the warmth of a hundred candles and the joy of a sky full of wishes. Wishing you a birthday as beautiful and rare as you are. With love and soft petals ✨',
      'Anniversary' => 'To you, $whoLine—\n\n'
          'May this anniversary be wrapped in the same tenderness these flowers were chosen with. Here is to the moments you have shared, and the many still to unfold. With admiration 🌷',
      'Thank you' => 'For you, $whoLine—\n\n'
          'Words are small for all you have given; we hope this bouquet speaks in color and scent what gratitude holds in the heart. Thank you, truly, from the bottom of ours. ✨',
      'Congratulations' => 'For you, $whoLine—\n\n'
          'This milestone deserves a chorus of celebration. May these flowers mark the start of a chapter as vibrant and full of promise as you are. Congratulations—and every good wish for what comes next ✨',
      'Just because' => 'For you, $whoLine—\n\n'
          'Sometimes the best reason is no reason at all—just a wish to make you smile. May this little garden of petals bring a moment of stillness, joy, and being cherished. With love 🌸',
      _ => 'For you, $whoLine—\n\n'
          'May this bouquet carry a whisper of care, a touch of beauty, and our warmest wishes for your $occasion. With all good thoughts ✨',
    };
  }

  Future<void> _onGenerate() async {
    if (_isGenerating) return;
    HapticFeedback.mediumImpact();
    setState(() => _isGenerating = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    final text = _buildMockGreeting(_selectedWho, _selectedOccasion);
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final titleStyle = GoogleFonts.montserrat(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: AppColors.ink,
    );
    final sectionStyle = GoogleFonts.montserrat(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: AppColors.inkMuted,
    );
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 24,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.badgeGoldBackground,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.accentGold.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Icon(
                        Icons.auto_fix_high_rounded,
                        size: 22,
                        color: AppColors.accentGold,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.aiGreetingSheetTitle,
                        style: titleStyle,
                      ),
                    ),
                    IconButton(
                      onPressed: _isGenerating
                          ? null
                          : () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.whoIsThisFor, style: sectionStyle),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _whoChips.map((w) {
                          final selected = w == _selectedWho;
                          return FilterChip(
                            label: Text(w),
                            selected: selected,
                            onSelected: _isGenerating
                                ? null
                                : (_) {
                                    HapticFeedback.selectionClick();
                                    setState(() => _selectedWho = w);
                                  },
                            selectedColor: AppColors.blush.withValues(alpha: 0.5),
                            checkmarkColor: AppColors.rosePrimary,
                            labelStyle: GoogleFonts.montserrat(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: selected ? AppColors.ink : AppColors.inkMuted,
                            ),
                            side: BorderSide(
                              color: selected
                                  ? AppColors.rosePrimary.withValues(alpha: 0.6)
                                  : AppColors.border,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                      Text(l10n.occasionLabel, style: sectionStyle),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _occasionChips.map((o) {
                          final selected = o == _selectedOccasion;
                          return FilterChip(
                            label: Text(o),
                            selected: selected,
                            onSelected: _isGenerating
                                ? null
                                : (_) {
                                    HapticFeedback.selectionClick();
                                    setState(() => _selectedOccasion = o);
                                  },
                            selectedColor: AppColors.blush.withValues(alpha: 0.5),
                            checkmarkColor: AppColors.rosePrimary,
                            labelStyle: GoogleFonts.montserrat(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: selected ? AppColors.ink : AppColors.inkMuted,
                            ),
                            side: BorderSide(
                              color: selected
                                  ? AppColors.rosePrimary.withValues(alpha: 0.6)
                                  : AppColors.border,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(24, 8, 24, 16 + bottom),
                child: Material(
                  color: AppColors.accentGold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    onTap: _isGenerating ? null : _onGenerate,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.accentGold.withValues(alpha: 0.55),
                        ),
                      ),
                      child: _isGenerating
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: AppColors.accentGold,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  l10n.aiGreetingGenerating,
                                  style: GoogleFonts.montserrat(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.ink,
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.auto_awesome_rounded,
                                  color: AppColors.accentGold,
                                  size: 22,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  l10n.generateGreeting,
                                  style: GoogleFonts.montserrat(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.ink,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

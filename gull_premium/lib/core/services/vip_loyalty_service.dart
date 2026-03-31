class VipTierProgress {
  const VipTierProgress({
    required this.currentTier,
    required this.nextTier,
    required this.progressToNextTier,
    required this.remainingToNextTierIqd,
  });

  final VipTier currentTier;
  final VipTier? nextTier;
  final double progressToNextTier;
  final double remainingToNextTierIqd;
}

enum VipTier {
  silver,
  gold,
  platinum,
}

class VipLoyaltyService {
  static const double silverUpperBound = 250000;
  static const double goldUpperBound = 500000;

  static VipTier resolveTier(double totalSpent) {
    if (totalSpent >= goldUpperBound) {
      return VipTier.platinum;
    }
    if (totalSpent >= silverUpperBound) {
      return VipTier.gold;
    }
    return VipTier.silver;
  }

  static VipTierProgress progressFor(double totalSpent) {
    final tier = resolveTier(totalSpent);
    switch (tier) {
      case VipTier.silver:
        final safeSpent = totalSpent.clamp(0, silverUpperBound).toDouble();
        final progress = (safeSpent / silverUpperBound).clamp(0.0, 1.0);
        return VipTierProgress(
          currentTier: tier,
          nextTier: VipTier.gold,
          progressToNextTier: progress,
          remainingToNextTierIqd: (silverUpperBound - safeSpent).clamp(0, silverUpperBound),
        );
      case VipTier.gold:
        final spentInGold = (totalSpent - silverUpperBound).clamp(0, goldUpperBound - silverUpperBound);
        final progress = (spentInGold / (goldUpperBound - silverUpperBound)).clamp(0.0, 1.0);
        return VipTierProgress(
          currentTier: tier,
          nextTier: VipTier.platinum,
          progressToNextTier: progress,
          remainingToNextTierIqd: (goldUpperBound - totalSpent).clamp(0, goldUpperBound),
        );
      case VipTier.platinum:
        return const VipTierProgress(
          currentTier: VipTier.platinum,
          nextTier: null,
          progressToNextTier: 1,
          remainingToNextTierIqd: 0,
        );
    }
  }
}

import 'package:flutter/material.dart';

import 'theme.dart';

class IosTabItem {
  final Widget icon;
  final Widget selectedIcon;
  final String label;
  const IosTabItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

/// شريط سفلي عائم بتصميم آبل:
/// حافة مستديرة بالكامل، ظلّ ناعم، إظهار مع حركة سلسة للخانة النشطة.
class IosBottomBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  final List<IosTabItem> items;
  const IosBottomBar({
    super.key,
    required this.index,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Container(
        height: 62,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xF7FFFFFF),
          borderRadius: BorderRadius.circular(31),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x16000000),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: List.generate(items.length, (i) {
            final selected = i == index;
            final item = items[i];
            return Expanded(
              child: InkWell(
                onTap: () => onTap(i),
                borderRadius: BorderRadius.circular(28),
                splashColor: AppColors.primarySoft,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      height: 34,
                      width: selected ? 52 : 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected ? AppColors.primarySoft : Colors.transparent,
                        borderRadius: BorderRadius.circular(17),
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 150),
                        child: selected ? item.selectedIcon : item.icon,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.label,
                      style: selected
                          ? AppText.bold(10).copyWith(color: AppColors.primary)
                          : AppText.muted(10),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
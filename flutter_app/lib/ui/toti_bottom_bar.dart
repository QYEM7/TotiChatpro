import 'package:flutter/material.dart';

import 'toti_theme.dart';

/// Custom five-action bar. It is deliberately not Material NavigationBar:
/// the centered create action is a real room-creation flow.
class TotiBottomBar extends StatelessWidget {
  const TotiBottomBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.onCreateRoom,
  });
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onCreateRoom;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Container(
      margin: const EdgeInsets.fromLTRB(12, 3, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(27),
        border: Border.all(color: TotiColors.outline),
        boxShadow: const [
          BoxShadow(color: Color(0x1D514887),
            blurRadius: 22, offset: Offset(0, 8)),
        ],
      ),
      child: Row(children: [
        _destination(Icons.home_rounded, 'الرئيسية', 0),
        _destination(Icons.travel_explore_rounded, 'اكتشف', 1),
        Expanded(child: Semantics(
          label: 'إنشاء غرفة',
          button: true,
          child: InkWell(
            key: const ValueKey('toti-create-room-action'),
            onTap: onCreateRoom,
            borderRadius: BorderRadius.circular(22),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 49, height: 48,
                decoration: BoxDecoration(
                  gradient: TotiColors.heroGradient,
                  borderRadius: BorderRadius.circular(17),
                  boxShadow: const [
                    BoxShadow(color: Color(0x338C6FBF),
                      blurRadius: 11, offset: Offset(0, 5)),
                  ],
                ),
                child: const Icon(Icons.add_rounded,
                  color: Colors.white, size: 31),
              ),
              const SizedBox(height: 3),
              const Text('غرفة', style: TextStyle(fontSize: 10,
                color: TotiColors.ink, fontWeight: FontWeight.w700)),
            ]),
          ),
        )),
        _destination(Icons.chat_bubble_outline_rounded, 'الرسائل', 2),
        _destination(Icons.person_outline_rounded, 'ملفي', 4),
      ]),
    ),
  );

  Widget _destination(IconData icon, String label, int index) {
    final active = selectedIndex == index;
    return Expanded(child: Semantics(
      label: label,
      selected: active,
      button: true,
      child: InkWell(
        onTap: () => onDestinationSelected(index),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: active ? TotiColors.lavender : Colors.transparent,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, size: 23,
                color: active ? TotiColors.plum : TotiColors.muted),
            ),
            const SizedBox(height: 3),
            Text(label, maxLines: 1,
              style: TextStyle(fontSize: 10,
                fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                color: active ? TotiColors.plum : TotiColors.muted)),
          ]),
        ),
      ),
    ));
  }
}

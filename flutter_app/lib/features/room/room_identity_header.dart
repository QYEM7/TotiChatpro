import 'package:flutter/material.dart';

import '../../ui/toti_theme.dart';

/// Shared visual header for the real room and the isolated Flutter review.
/// It never fabricates room activity, members, gifts or welcome messages.
class RoomIdentityHeader extends StatelessWidget {
  const RoomIdentityHeader({
    super.key,
    required this.title,
    this.welcomeMessage,
  });

  final String title;
  final String? welcomeMessage;

  @override
  Widget build(BuildContext context) {
    final welcome = welcomeMessage?.trim();
    return SizedBox(
      height: 133,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(27),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
              colors: [TotiColors.plum, Color(0xFF5948AE)],
            ),
          ),
          child: Stack(
            children: [
              const Positioned(
                top: -60,
                left: -40,
                child: _SoftOrb(size: 158, color: Color(0x337A70DE)),
              ),
              const Positioned(
                bottom: -62,
                right: -32,
                child: _SoftOrb(size: 142, color: Color(0x99ED8EBD)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 19, vertical: 14,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4,
                          ),
                          child: Text(
                            'VOICE ROOM',
                            style: TextStyle(
                              color: TotiColors.plum,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.start,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 5),
                    if (welcome != null && welcome.isNotEmpty)
                      Text(
                        welcome,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.92),
                          fontSize: 11,
                        ),
                      )
                    else
                      const SizedBox(height: 15),
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

class _SoftOrb extends StatelessWidget {
  const _SoftOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    ),
  );
}

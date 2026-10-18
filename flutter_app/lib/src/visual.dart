import 'package:flutter/material.dart';

/// Extracted from the approved React source, not from retired TotiChat designs.
abstract final class ApprovedPalette {
  static const emerald = Color(0xFF25BE8E);
  static const emeraldDeep = Color(0xFF17976E);
  static const mint = Color(0xFF26D0B2);
  static const ink = Color(0xFF064E3B);
  static const cream = Color(0xFFFAF8F5);
  static const paper = Color(0xFFFDFBF7);
  static const gold = Color(0xFFFBBF24);
  static const room = Color(0xFF13082A);
  static const violet = Color(0xFF211540);
  static const violetStroke = Color(0xFF9457C7);
}

const _sourceRoot = 'https://raw.githubusercontent.com/mrbalmain11-star/-/main';

String approvedAsset(String path) => '$_sourceRoot/$path';

class ApprovedNetworkImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  const ApprovedNetworkImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });
  @override
  Widget build(BuildContext context) => Image.network(
        url,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => Container(
          color: ApprovedPalette.violet,
          alignment: Alignment.center,
          child: const Icon(Icons.image_not_supported_outlined,
              color: ApprovedPalette.gold),
        ),
      );
}

class GoldBorder extends StatelessWidget {
  final Widget child;
  final Color color;
  const GoldBorder({super.key, required this.child, this.color = ApprovedPalette.room});
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: [color, Color.lerp(color, Colors.black, 0.55)!]),
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: ApprovedPalette.gold.withOpacity(0.8), width: 1.5),
      boxShadow: const [BoxShadow(color: Color(0x33251A07), blurRadius: 10, offset: Offset(0, 4))],
    ),
    child: child,
  );
}

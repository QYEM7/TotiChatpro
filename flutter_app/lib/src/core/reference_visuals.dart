import 'package:flutter/material.dart';

/// The 2026 approved illustrated TotiChat boards define these proportions.
/// Not a generic Material card kit: dedicated branded components for the
/// illustrated mint / evergreen / brass identity.
abstract final class ReferencePalette {
  static const canvas = Color(0xFFF4FFF9);
  static const ink = Color(0xFF092F28);
  static const deep = Color(0xFF003E33);
  static const teal = Color(0xFF008B6C);
  static const bright = Color(0xFF19B991);
  static const mint = Color(0xFFDDF7EC);
  static const paleMint = Color(0xFFEAFAF2);
  static const gold = Color(0xFFD6A64F);
  static const paleGold = Color(0xFFFFE9B7);
}

class ReferenceBrand extends StatelessWidget {
  const ReferenceBrand({super.key, this.compact = false});
  final bool compact;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min,
    textDirection: TextDirection.ltr, children: [
        ClipOval(
          child: Image.asset(
            'assets/images/reference_approved_falcon.webp',
            width: compact ? 30 : 37,
            height: compact ? 30 : 37,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Icon(Icons.headphones,
              size: compact ? 25 : 34, color: ReferencePalette.deep),
          ),
        ),
        const SizedBox(width: 8),
        Text('TotiChat',
          style: TextStyle(
            color: ReferencePalette.ink,
            fontWeight: FontWeight.w900,
            letterSpacing: -.8,
            fontSize: compact ? 20 : 24,
          )),
      ]);
}

/// The geometric mosque, arches and suspended lantern ornaments correspond
/// to the approved dark-gold Welcome illustration, without using fake banners.
class WelcomeIllumination extends CustomPainter {
  const WelcomeIllumination();
  @override
  void paint(Canvas canvas, Size size) {
    final gold = Paint()..color = const Color(0xFFD4A65C).withValues(alpha: .62)
      ..strokeWidth = 1.3..style = PaintingStyle.stroke;
    final faint = Paint()..color = const Color(0xFFC1934A).withValues(alpha: .18);
    final glow = Paint()..shader = const RadialGradient(
        colors: [Color(0x64EEC173), Color(0x00F4C87E)],
      ).createShader(Rect.fromCircle(center: Offset(size.width * .16, size.height * .5), radius: 120));
    canvas.drawRect(Offset.zero & size, glow);
    for (var i = 0; i < 17; i++) {
      final x = (i * 79 + 31) % size.width;
      final y = (i * 47 + 9) % size.height;
      canvas.drawCircle(Offset(x.toDouble(),y.toDouble()),
        i % 3 == 0 ? 1.6 : .7,
        Paint()..color = const Color(0xFFFDE3A6).withValues(alpha: .45));
    }
    // Mosque silhouettes and domes on the right-hand edge.
    final city = Path()
      ..moveTo(size.width * .73, size.height)
      ..lineTo(size.width * .73, size.height * .78)
      ..quadraticBezierTo(size.width * .79, size.height * .58,
          size.width * .85, size.height * .78)
      ..lineTo(size.width * .85,size.height)
      ..close();
    canvas.drawPath(city, faint);
    for (final fraction in [.79,.93,.98]) {
      final x = size.width * fraction;
      final top = size.height * (fraction == .93 ? .2 : .48);
      canvas.drawRect(Rect.fromLTWH(x,top,5,size.height-top),faint);
      final spire = Path()..moveTo(x-3,top)..lineTo(x+2.5,top-19)
        ..lineTo(x+8,top)..close();
      canvas.drawPath(spire,faint);
    }
    // Pendant lanterns, asymmetric just like the reference illustration.
    for (final x in [size.width * .15, size.width * .93]) {
      final top = x < size.width*.5 ? size.height*.19 : size.height*.34;
      canvas.drawLine(Offset(x,0),Offset(x,top),gold);
      final lantern = Path()
        ..moveTo(x,top)..lineTo(x-13,top+17)
        ..lineTo(x-10,top+41)..lineTo(x,top+49)
        ..lineTo(x+10,top+41)..lineTo(x+13,top+17)..close();
      canvas.drawPath(lantern,
        Paint()..color=const Color(0xFFFFD38A).withValues(alpha:.15));
      canvas.drawPath(lantern,gold);
      canvas.drawCircle(Offset(x,top+27),4.2,
        Paint()..color=const Color(0xFFF9CC77).withValues(alpha:.8));
    }
    canvas.drawLine(Offset(0,size.height-1),Offset(size.width,size.height-1),
      Paint()..color=ReferencePalette.gold.withValues(alpha:.15));
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ReferenceWelcomeHero extends StatelessWidget {
  const ReferenceWelcomeHero({
    super.key,
    required this.title,
    required this.subtitle,
  });
  final String title;
  final String subtitle;

  /// The image below is a verified crop from the exact concept sheet
  /// approved by the user, rather than a new generic visual approximation.
  @override
  Widget build(BuildContext context) => Container(
    height: 146,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(22),
      boxShadow: const [
        BoxShadow(color: Color(0x33045640),blurRadius:16,offset:Offset(0,8)),
      ],
    ),
    child: Semantics(
      label: '$title. $subtitle',
      child: Image.asset(
        'assets/images/reference_approved_welcome.webp',
        fit: BoxFit.fill,
        width: double.infinity,
        errorBuilder: (context,error,stackTrace) => Stack(children: [
          const Positioned.fill(child:ColoredBox(color:ReferencePalette.deep)),
          const Positioned.fill(child:CustomPaint(painter:WelcomeIllumination())),
          Center(child:Padding(
            padding:const EdgeInsets.symmetric(horizontal:42),
            child:Column(mainAxisSize:MainAxisSize.min,children:[
              Text(title,textAlign:TextAlign.center,
                style:const TextStyle(fontWeight:FontWeight.w900,
                  color:Colors.white,fontSize:18)),
              const SizedBox(height:7),
              Text(subtitle,textAlign:TextAlign.center,
                style:const TextStyle(color:ReferencePalette.paleGold,fontSize:13)),
            ]),
          )),
        ]),
      ),
    ),
  );
}

class ReferenceCategory extends StatelessWidget {
  const ReferenceCategory({super.key,required this.icon,required this.label,
    required this.color,required this.background,required this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final Color background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap:onTap,
    borderRadius:BorderRadius.circular(18),
    child:Column(mainAxisSize:MainAxisSize.min,children:[
      Container(
        width:58,height:58,
        decoration:BoxDecoration(color:background,borderRadius:BorderRadius.circular(19)),
        child:Icon(icon,color:color,size:28),
      ),
      const SizedBox(height:5),
      Text(label,maxLines:1,overflow:TextOverflow.ellipsis,
        textAlign:TextAlign.center,
        style:const TextStyle(fontSize:11,fontWeight:FontWeight.w700,color:ReferencePalette.ink)),
    ]),
  );
}

class ReferenceSection extends StatelessWidget {
  const ReferenceSection({super.key,required this.title,this.actionLabel,this.onAction});
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Row(children:[
    Expanded(child:Text(title,style:const TextStyle(
      fontSize:19,fontWeight:FontWeight.w900,color:ReferencePalette.ink,
    ))),
    if(actionLabel!=null) TextButton(
      onPressed:onAction,
      child:Text(actionLabel!,style:const TextStyle(
        fontSize:12,fontWeight:FontWeight.w800,color:ReferencePalette.teal)),
    ),
  ]);
}

class ReferenceRoomThumbnail extends StatelessWidget {
  const ReferenceRoomThumbnail({super.key,required this.title,this.coverUrl,this.onTap,
    this.membersLabel,this.badge});
  final String title;
  final String? coverUrl;
  final String? membersLabel;
  final String? badge;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius:BorderRadius.circular(17),
    child:Material(color:ReferencePalette.deep,child:InkWell(
      onTap:onTap,
      child:Stack(fit:StackFit.expand,children:[
        if(coverUrl!=null)
          Image.network(coverUrl!,fit:BoxFit.cover,
            errorBuilder:(_,_,_)=>const CustomPaint(painter:WelcomeIllumination()))
        else const CustomPaint(painter:WelcomeIllumination()),
        const DecoratedBox(decoration:BoxDecoration(
          gradient:LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,
            stops:[.2,1],colors:[Color(0x00000000),Color(0xD8001713)]),
        )),
        if(badge!=null)
          Positioned(top:9,right:9,child:Container(
            decoration:BoxDecoration(color:ReferencePalette.paleGold,
              borderRadius:BorderRadius.circular(12)),
            padding:const EdgeInsets.symmetric(horizontal:8,vertical:4),
            child:Text(badge!,style:const TextStyle(fontSize:10,
              fontWeight:FontWeight.w900,color:ReferencePalette.ink)),
          )),
        Positioned(bottom:10,left:11,right:11,
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisSize:MainAxisSize.min,
          children:[
            Text(title,maxLines:2,overflow:TextOverflow.ellipsis,
              style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w900,fontSize:16,
                shadows:[Shadow(color:Colors.black87,blurRadius:6)])),
            if(membersLabel!=null) ...[
              const SizedBox(height:4),
              Row(children:[
                const Icon(Icons.people_alt_rounded,color:ReferencePalette.paleGold,size:13),
                const SizedBox(width:4),
                Text(membersLabel!,style:const TextStyle(color:Colors.white70,fontSize:11)),
              ]),
            ],
          ])),
      ]),
    )),
  );
}

/// Premium section when there are genuinely no public rooms. Unlike the
/// AI concept poster, no fictitious accounts, coin balances or rooms appear.
class ReferenceEmptyRooms extends StatelessWidget {
  const ReferenceEmptyRooms({super.key,required this.title,required this.subtitle,
    required this.actionLabel,required this.onAction});
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;
  @override
  Widget build(BuildContext context) => Container(
    width:double.infinity,
    padding:const EdgeInsets.fromLTRB(20,21,20,21),
    decoration:BoxDecoration(
      color:ReferencePalette.paleMint,borderRadius:BorderRadius.circular(19),
      border:Border.all(color:const Color(0xFFCAECDA))),
    child:Column(children:[
      Container(
        width:54,height:54,
        decoration:const BoxDecoration(shape:BoxShape.circle,color:Color(0xFFCCF1E0)),
        child:const Icon(Icons.headphones_rounded,color:ReferencePalette.teal,size:28)),
      const SizedBox(height:10),
      Text(title,style:const TextStyle(fontSize:15,fontWeight:FontWeight.w900,color:ReferencePalette.ink)),
      const SizedBox(height:5),
      Text(subtitle,textAlign:TextAlign.center,style:const TextStyle(
        color:Color(0xFF63847C),fontSize:12)),
      const SizedBox(height:12),
      FilledButton.icon(onPressed:onAction,
        icon:const Icon(Icons.add_circle_outline,size:18),
        label:Text(actionLabel)),
    ]),
  );
}

class ReferenceVipStrip extends StatelessWidget {
  const ReferenceVipStrip({super.key,required this.title,required this.description,
    this.onTap,this.trailing});
  final String title;
  final String description;
  final VoidCallback? onTap;
  final Widget? trailing;
  @override
  Widget build(BuildContext context)=>Container(
    padding:const EdgeInsets.symmetric(horizontal:16,vertical:14),
    decoration:BoxDecoration(
      borderRadius:BorderRadius.circular(18),
      gradient:const LinearGradient(colors:[
        Color(0xFF2D2718),Color(0xFF987039),Color(0xFF382A1A)]),
      border:Border.all(color:ReferencePalette.paleGold.withValues(alpha:.75)),
    ),
    child:Row(children:[
      const Icon(Icons.workspace_premium_rounded,color:ReferencePalette.paleGold,size:37),
      const SizedBox(width:10),
      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(title,style:const TextStyle(color:ReferencePalette.paleGold,
          fontSize:17,fontWeight:FontWeight.w900)),
        Text(description,style:const TextStyle(color:Colors.white70,fontSize:11)),
      ])),
      if(trailing!=null)trailing! else if(onTap!=null)
        IconButton(onPressed:onTap,icon:const Icon(Icons.chevron_left,color:Colors.white)),
    ]),
  );
}

class ReferenceInfoTile extends StatelessWidget {
  const ReferenceInfoTile({super.key,required this.title,required this.icon,
    this.onTap,this.subtitle});
  final String title;
  final IconData icon;
  final String? subtitle;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Container(
    margin:const EdgeInsets.only(bottom:7),
    decoration:BoxDecoration(
      borderRadius:BorderRadius.circular(15),
      color:Colors.white,
      border:Border.all(color:const Color(0xFFE6F3EC)),
    ),
    child:Material(type:MaterialType.transparency,child:ListTile(
      leading:Container(
        width:38,height:38,
        decoration:BoxDecoration(
          color:ReferencePalette.mint,
          borderRadius:BorderRadius.circular(12)),
        child:Icon(icon,color:ReferencePalette.teal)),
      title:Text(title,style:const TextStyle(
        fontSize:13,fontWeight:FontWeight.w800,color:ReferencePalette.ink)),
      subtitle:subtitle==null?null:Text(subtitle!,style:const TextStyle(fontSize:11)),
      trailing:onTap==null?null:const Icon(Icons.chevron_left,size:20),
      onTap:onTap,
    )),
  );
}

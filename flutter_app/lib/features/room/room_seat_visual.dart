import 'package:flutter/material.dart';
import '../../models/room_models.dart';
import '../../models/room_seat_decoration.dart';
import '../../ui/toti_theme.dart';

/// Shows only authenticated server-sourced decoration metadata.
class RoomSeatVisual extends StatelessWidget {
  const RoomSeatVisual({super.key, required this.member,
    required this.isOwner, this.decoration});
  final RoomMember? member;
  final bool isOwner;
  final RoomSeatDecoration? decoration;

  @override
  Widget build(BuildContext context) {
    final occupied=member!=null;
    final vip=decoration?.vipTier??0;
    final frameName=decoration?.frameName?.trim();
    final hasFrame=frameName!=null && frameName.isNotEmpty;
    final avatar=member?.avatarUrl;
    return Container(
      width:double.infinity,
      decoration:BoxDecoration(
        color:occupied?const Color(0xFF6D5AA6):const Color(0xFF423A5A),
        borderRadius:BorderRadius.circular(16),
        border:Border.all(
          color:vip>0||hasFrame?TotiColors.gold:
            occupied?Colors.white54:Colors.white24,
          width:vip>0?2:1)),
      child:Stack(fit:StackFit.expand,children:[
        Center(child:occupied && avatar?.startsWith('https://')==true
          ?ClipRRect(borderRadius:BorderRadius.circular(13),
            child:Image.network(avatar!,fit:BoxFit.cover,
              errorBuilder:(_,_,_)=>
                const Icon(Icons.person,color:Colors.white)))
          :Icon(occupied?Icons.person_rounded:Icons.add_rounded,
            color:Colors.white70)),
        if(vip>0)Positioned(left:1,top:1,child:_SeatLabel(
          text:'VIP $vip',background:const Color(0xFF4D367D))),
        if(occupied && isOwner)
          const Positioned(right:1,top:1,
            child:Icon(Icons.workspace_premium_rounded,
              size:15,color:TotiColors.gold)),
        if(hasFrame)Positioned(right:1,top:isOwner?17:1,
          child:Tooltip(message:'Equipped frame: $frameName',
            child:const Icon(Icons.auto_awesome_rounded,
              size:12,color:TotiColors.gold))),
        if(decoration!=null)Positioned(left:1,bottom:1,child:_SeatLabel(
          text:'🎁 ${decoration!.receivedGifts}',
          background:const Color(0xCC201A33))),
        if(member?.isMuted==true)Positioned(right:1,bottom:1,
          child:Container(
            padding:const EdgeInsets.all(2),
            decoration:const BoxDecoration(color:Color(0xEE29233E),
              shape:BoxShape.circle),
            child:const Icon(Icons.mic_off_rounded,
              size:12,color:Colors.white))),
      ]),
    );
  }
}

class _SeatLabel extends StatelessWidget {
  const _SeatLabel({required this.text,required this.background});
  final String text;
  final Color background;

  @override
  Widget build(BuildContext context)=>Container(
    padding:const EdgeInsets.symmetric(horizontal:2,vertical:1),
    decoration:BoxDecoration(color:background,
      borderRadius:BorderRadius.circular(5)),
    child:Text(text,maxLines:1,overflow:TextOverflow.ellipsis,
      style:const TextStyle(fontSize:8,fontWeight:FontWeight.w800,
        color:Colors.white)),
  );
}

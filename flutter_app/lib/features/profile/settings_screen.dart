import 'package:flutter/material.dart';
import '../../data/totichat_repository.dart';
import '../../data/totichat_services.dart';
import '../../ui/server_panel.dart';
import 'push_preferences_screen.dart';

class ProfileSettings extends StatefulWidget {
  const ProfileSettings({super.key,required this.repository});
  final TotiChatRepository repository;
  @override State<ProfileSettings> createState()=>_ProfileSettingsState();
}
class _ProfileSettingsState extends State<ProfileSettings>{
  late Future<Map<String,dynamic>?> _profile;
  bool _busy=false;String? _deletionRequestId;
  final _name=TextEditingController(),_bio=TextEditingController();
  bool _seeded=false;
  @override void initState(){super.initState();_refresh();}
  void _refresh()=>setState(()=>_profile=widget.repository.ownProfile());

  Future<void> _update() async{
    final name=_name.text.trim(),bio=_bio.text.trim();
    if(_busy)return;
    if(name.length<2||name.length>60||bio.length>300){
      showApiError(context,'اسم العرض بين 2 و60 حرفاً، والنبذة لا تتجاوز 300.');
      return;
    }
    setState(()=>_busy=true);
    try{
      final uid=widget.repository.currentUserId;
      final result=await widget.repository.client.from('profiles')
        .update({'display_name':name,'bio':bio}).eq('id',uid)
        .select('id').single();
      if(result['id']!=uid)throw StateError('Profile change not confirmed');
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text('تم تحديث ملفك الحقيقي')));
      _refresh();
    }catch(e){if(mounted)showApiError(context,e);}
    finally{if(mounted)setState(()=>_busy=false);}
  }

  Future<void> _deleteRequest() async{
    if(_busy)return;
    final approved=await showDialog<bool>(context:context,builder:(ctx)=>
      AlertDialog(title:const Text('طلب حذف حساب TotiChat'),
        content:const Text('هذا طلب مراجعة وحذف رسمي، وليس تصفيراً فورياً للمحافظ. '
          'سيتحقق الدعم من الهوية والاحتفاظ بالسجلات المطلوبة قانونياً.'),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('إلغاء')),
          FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('إرسال الطلب')),
        ]));
    if(approved!=true||!mounted)return;
    setState(()=>_busy=true);
    _deletionRequestId??=TotiChatServices.requestId();
    try{
      final ticket=await TotiChatServices(widget.repository.client).supportRequest(
        category:'account',subject:'Account and personal data deletion request',
        message:'I request deletion of my TotiChat account and associated personal data. '
          'Please verify identity and confirm lawful completion.',
        requestId:_deletionRequestId!,
      );
      _deletionRequestId=null;
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content:Text('تم تسجيل طلب حذف الحساب: $ticket')));
    }catch(e){if(mounted)showApiError(context,e);}
    finally{if(mounted)setState(()=>_busy=false);}
  }

  @override void dispose(){_name.dispose();_bio.dispose();super.dispose();}

  @override Widget build(BuildContext context)=>Directionality(
    textDirection:TextDirection.rtl,
    child:Scaffold(appBar:AppBar(title:const Text('الحساب والخصوصية')),
      body:ServerPanel<Map<String,dynamic>?>(
        future:_profile,retry:_refresh,builder:(context,profile){
          if(profile==null)return const NoRecords('لا يوجد ملف شخصي على الخادم.');
          if(!_seeded){
            _seeded=true;
            _name.text=profile['display_name']?.toString()??'';
            _bio.text=profile['bio']?.toString()??'';
          }
          return ListView(padding:const EdgeInsets.all(18),children:[
            const Text('ملفي الشخصي',style:TextStyle(fontSize:20,fontWeight:FontWeight.w800)),
            const SizedBox(height:12),
            TextField(controller:_name,maxLength:60,
              decoration:const InputDecoration(labelText:'الاسم الظاهر')),
            TextField(controller:_bio,maxLength:300,maxLines:3,
              decoration:const InputDecoration(labelText:'نبذة عني')),
            FilledButton(onPressed:_busy?null:_update,child:const Text('حفظ عبر الخادم')),
            const SizedBox(height:32),
            const Text('الخصوصية وإدارة البيانات',
              style:TextStyle(fontWeight:FontWeight.w800,fontSize:18)),
            const SizedBox(height:12),
            const Text('بإمكانك طلب حذف حسابك وبياناته المرتبطة به عبر تذكرة دعم رسمية.'),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PushPreferencesScreen(
                    api: TotiChatServices(widget.repository.client)),
                ),
              ),
              icon: const Icon(Icons.notifications_active_outlined),
              label: const Text('إشعارات الجهاز والخصوصية'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(onPressed:_busy?null:_deleteRequest,
              icon:const Icon(Icons.delete_forever_outlined),
              label:const Text('طلب حذف الحساب والبيانات')),
          ]);
        }),
    ),
  );
}

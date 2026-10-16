import 'package:flutter/material.dart';
import '../../data/totichat_services.dart';
import '../../ui/server_panel.dart';
import 'host_agency_admin_screen.dart';
import 'host_month_evidence_screen.dart';
import 'owner_treasury_screen.dart';
import 'owner_banner_screen.dart';
import '../community/support_tickets_screen.dart';
import 'support_staff_screen.dart';

bool canOpenAdmin(Map<String,dynamic> a) =>
  a['isOwner']==true || a['isMainPartner']==true ||
  a['canReadReports']==true || a['canManageCatalogs']==true ||
  a['role']=='db' || a['role']=='admin' || a['role']=='customer_service';

class AdminScreen extends StatefulWidget{
  const AdminScreen({super.key,required this.api});final TotiChatServices api;
  @override State<AdminScreen> createState()=>_AdminScreenState();
}
class _AdminScreenState extends State<AdminScreen>{
  late Future<Map<String,dynamic>> _role;
  late Future<Map<String,dynamic>> _supportRights;
  Future<Map<String,dynamic>>? _report;
  @override void initState(){super.initState();_refresh();}
  void _refresh()=>setState((){
    _role=widget.api.authority();
    _supportRights=widget.api.supportTicketPage();
  });
  @override Widget build(BuildContext context)=>Directionality(
    textDirection:TextDirection.rtl,child:Scaffold(
      appBar:AppBar(title:const Text('مركز الإدارة')),
      body:ServerPanel<Map<String,dynamic>>(future:_role,retry:_refresh,
        builder:(context,a){
          if(!canOpenAdmin(a)) {
            // Support-only staff can access tickets, never other admin pages.
            // The capability comes from phase3.support_handler(), not role text.
            return ServerPanel<Map<String,dynamic>>(
              future:_supportRights,
              retry:_refresh,
              builder:(context,rights) => rights['canHandle']==true
                ?ListView(padding:const EdgeInsets.all(18),children:[
                    const Text('Official support desk',
                      style:TextStyle(fontSize:21,
                        fontWeight:FontWeight.w800)),
                    const SizedBox(height:12),
                    const Text('Ticket handling only. Financial, agencies, '
                      'banners and Owner operations are not available.'),
                    recordCard(context,title:'Support tickets',
                      icon:Icons.support_agent_outlined,
                      onTap:()=>Navigator.of(context).push(
                        MaterialPageRoute(builder:(_)=>
                          SupportTicketListScreen(
                            api:widget.api,staff:true)))),
                  ])
                :const NoRecords('No admin or support permissions found.'),
            );
          }
          final owner=a['isOwner']==true,partner=a['isMainPartner']==true;
          final reports=a['canReadReports']==true||owner||partner;
          final catalog=a['canManageCatalogs']==true||owner||partner;
          // Never infer Host Agencies permission from just "super admin" role.
          return ListView(padding:const EdgeInsets.all(18),children:[
            const Icon(Icons.admin_panel_settings_rounded,size:54),
            const SizedBox(height:10),
            Text('صلاحية الحساب: ${a['role']??'admin'}',
              textAlign:TextAlign.center,style:const TextStyle(
                fontSize:20,fontWeight:FontWeight.w800)),
            const SizedBox(height:12),
            const Text('القوائم حسب صلاحيات الخادم. الإجراءات الحساسة تُفحص خادمياً.'),
            FutureBuilder<Map<String,dynamic>>(
              future:_supportRights,
              builder:(context,access) => access.data?['canHandle']==true
                ?recordCard(context,
                  title:'Official support tickets',
                  description:'Read verified reports and reply with server permissions.',
                  icon:Icons.support_agent_outlined,
                  onTap:()=>Navigator.of(context).push(MaterialPageRoute(
                    builder:(_)=>SupportTicketListScreen(
                      api:widget.api,staff:true))))
                :const SizedBox.shrink()),
            if(reports)recordCard(context,title:'التقارير المالية والإدارية',
              icon:Icons.analytics_outlined,
              onTap:()=>setState(()=>_report=widget.api.report())),
            if(catalog)recordCard(context,title:'صلاحية إدارة الكتالوج',
              description:'عرض الصلاحية فقط؛ التعديل غير متاح في هذه الواجهة.',
              icon:Icons.inventory_2_outlined),
            if(owner)recordCard(context,
              title:'Manage support staff',
              description:'Grant or revoke verified support handlers.',
              icon:Icons.manage_accounts_outlined,
              onTap:()=>Navigator.of(context).push(MaterialPageRoute(
                builder:(_)=>SupportStaffScreen(api:widget.api)))),
            if(owner)recordCard(context,
              title:'Official banners',
              description:'Upload, review, publish or archive real promotions.',
              icon:Icons.view_carousel_outlined,
              onTap:()=>Navigator.of(context).push(MaterialPageRoute(
                builder:(_)=>OwnerBannerScreen(api:widget.api)))),
            if(owner)recordCard(context,title:'إدارة وكالات المضيفين',
              description:'مراجعة طلبات الوكالات المسجلة بالخادم.',
              icon:Icons.business_center_outlined,
              onTap:()=>Navigator.of(context).push(MaterialPageRoute(
                builder:(_)=>HostAgencyAdminScreen(api:widget.api)))),
            if(owner)recordCard(context,
              title:'Owner treasury',
              description:'Documented issuance and agent allocations.',
              icon:Icons.account_balance_wallet_outlined,
              onTap:()=>Navigator.of(context).push(MaterialPageRoute(
                builder:(_)=>OwnerTreasuryScreen(api:widget.api)))),
            if(owner)recordCard(context,
              title:'Host monthly accrual evidence',
              description:'Read-only closed-month evidence; no payroll or reset.',
              icon:Icons.history_edu_outlined,
              onTap:()=>Navigator.of(context).push(MaterialPageRoute(
                builder:(_)=>HostMonthEvidenceScreen(api:widget.api)))),
            if(_report!=null)ServerPanel<Map<String,dynamic>>(
              future:_report!,retry:()=>setState(()=>_report=widget.api.report()),
              builder:(context,report)=>Card(child:Padding(
                padding:const EdgeInsets.all(16),
                child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                  const Text('ملخص تقرير الخادم',style:TextStyle(fontWeight:FontWeight.w800)),
                  const SizedBox(height:12),
                  ...report.entries.take(12).map((entry)=>Padding(
                    padding:const EdgeInsets.symmetric(vertical:4),
                    child:Text('${entry.key}: ${entry.value}',
                      maxLines:5,overflow:TextOverflow.ellipsis))),
                ])))),
          ]);
        }),
    ));
}

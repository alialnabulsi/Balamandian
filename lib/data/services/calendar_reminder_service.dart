import 'dart:io';
import 'package:flutter/services.dart';
import '../../domain/models/calendar_models.dart';
abstract interface class CalendarReminderService {
 Future<bool> permission({bool request=false});
 Future<void> replace(String? owner,List<CampusEvent> events);
 Future<Map<String,String>?> initialLink();
 void onLink(void Function(Map<String,String>)? callback);
}
class AndroidCalendarReminders implements CalendarReminderService {
 AndroidCalendarReminders({this.channel=const MethodChannel('balamandian/calendar-reminders')});
 final MethodChannel channel;
 @override Future<bool> permission({bool request=false})async=>Platform.isAndroid?(await channel.invokeMethod<bool>(request?'requestPermission':'permission')??false):false;
 @override Future<void> replace(String? owner,List<CampusEvent> events)async{if(!Platform.isAndroid)return;await channel.invokeMethod<void>('replace',{'owner':owner,'events':[for(final e in events)if(e.reminderAt!=null){'id':e.id,'at':e.reminderAt!.millisecondsSinceEpoch,'title':e.title}]});}
 @override Future<Map<String,String>?> initialLink()async{if(!Platform.isAndroid)return null;final r=await channel.invokeMapMethod<String,String>('initialLink');return r;}
 @override void onLink(void Function(Map<String,String>)? callback){channel.setMethodCallHandler(callback==null?null:(call)async{if(call.method=='notificationOpened')callback(Map<String,String>.from(call.arguments as Map));});}
}

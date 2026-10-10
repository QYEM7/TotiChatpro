/* Configure Android deep-link for real Supabase Auth PKCE callbacks.
 * Must run after "npx cap add android"; no URL credentials in the manifest.
 */
import {readFile,writeFile} from 'node:fs/promises';
const path='android/app/src/main/AndroidManifest.xml';
let xml=await readFile(path,'utf8');
if(!xml.includes('android:scheme="com.totichat.beta"')){
 const anchor='<activity';
 const start=xml.indexOf(anchor);
 const tail=xml.indexOf('>',start);
 if(start<0||tail<0)throw Error('No MainActivity in Android Manifest');
 const filter=`
            <intent-filter>
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="com.totichat.beta" android:host="auth" android:path="/callback" />
            </intent-filter>
`;
 // First activity is Capacitor's MainActivity. Place auth return link inside.
 const close=xml.indexOf('</activity>',tail);
 if(close<0)throw Error('MainActivity closing tag missing');
 xml=xml.slice(0,close)+filter+xml.slice(close);
 await writeFile(path,xml,'utf8');
}
// WebRTC / LiveKit microphone access requires an Android declaration.
if(!xml.includes('android.permission.RECORD_AUDIO')){
  const position=xml.indexOf('<application');
  if(position<0)throw Error('Android Manifest application element missing');
  xml=xml.slice(0,position)+
    '<uses-permission android:name="android.permission.RECORD_AUDIO" />\n    '+
    xml.slice(position);
  await writeFile(path,xml,'utf8');
}
if(!xml.includes('android.permission.RECORD_AUDIO'))throw Error('Microphone permission declaration missing');
if(!xml.includes('android:scheme="com.totichat.beta"'))throw Error('Auth deep link missing');
console.log('PASS: OAuth callback and WebRTC microphone manifest permission configured');

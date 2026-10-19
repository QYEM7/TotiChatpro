import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.57.0/+esm';

// Public browser key only. Never place service-role/secret keys in this page.
const URL = 'https://rziaedugbdwefbefcxjt.supabase.co';
const KEY = 'sb_publishable_vVYku5VtyohuiGgehC3EdA_rSDGOUKB';
const STORAGE_KEY = 'totichat-staging-login-qa-pkce';

const el = (id) => document.getElementById(id);
const ui = {
  login: el('login'), logout: el('logout'), recheck: el('recheck'),
  message: el('message'), identity: el('identity'),
  google: el('google-status'), backend: el('backend-status'),
};
const client = createClient(URL, KEY, {
  auth: {
    flowType: 'pkce',
    detectSessionInUrl: false,
    persistSession: true,
    autoRefreshToken: false,
    storage: window.sessionStorage,
    storageKey: STORAGE_KEY,
  },
});
let busy = false;
let signedIn = false;

function status(message, kind = '') {
  ui.message.textContent = message;
  ui.message.className = 'notice ' + kind;
}
function controls() {
  ui.login.disabled = busy || signedIn;
  ui.login.hidden = signedIn;
  ui.logout.hidden = !signedIn;
  ui.logout.disabled = busy;
  ui.recheck.hidden = !signedIn;
  ui.recheck.disabled = busy;
}
function cleanUrl() {
  window.history.replaceState({}, document.title, window.location.pathname);
}
function maskEmail(email) {
  if (!email || !email.includes('@')) return 'غير معروض';
  const [name, domain] = email.split('@');
  return (name[0] || '*') + '***@' + domain;
}
function fail(code) {
  status('تعذّر إكمال الفحص (' + code + '). راجع إعدادات Google وRedirect URLs في Staging.', 'bad');
}
async function verify() {
  busy = true; controls();
  ui.google.textContent = 'جاري التحقق...';
  ui.backend.textContent = 'جاري التحقق...';
  ui.identity.hidden = true;
  try {
    const { data: userData, error: userError } = await client.auth.getUser();
    if (userError || !userData?.user) {
      signedIn = false;
      ui.google.textContent = 'لم تُثبت الجلسة';
      ui.backend.textContent = 'غير متاح';
      status('لا توجد جلسة Google صالحة في هذا التبويب. سجّل الدخول للفحص.', '');
      return;
    }
    signedIn = true;
    ui.google.textContent = 'نجح — جلسة حقيقية';
    const user = userData.user;
    ui.identity.textContent = 'الحساب: ' + maskEmail(user.email) + ' | معرف داخلي: …' + user.id.slice(-6);
    ui.identity.hidden = false;

    const { data: verifiedId, error: rpcError } = await client.rpc('phase4_verified_session');
    if (rpcError || String(verifiedId) !== user.id) {
      ui.backend.textContent = 'لم يُقبل التحقق';
      fail('BACKEND_SESSION_CHECK');
      return;
    }
    ui.backend.textContent = 'نجح — هوية مطابقة';
    status('تم تسجيل الدخول الحقيقي عبر Google والتحقق من الجلسة من خادم Staging بنجاح.', 'ok');
  } catch (_) {
    if (!signedIn) {
      ui.google.textContent = 'غير مؤكد';
      ui.backend.textContent = 'غير متاح';
    } else {
      ui.backend.textContent = 'تعذّر الاتصال';
    }
    fail('NETWORK_OR_AUTH');
  } finally {
    busy = false; controls();
  }
}
async function beginLogin() {
  if (busy) return;
  busy = true; controls();
  status('جاري فتح تسجيل Google الحقيقي...');
  try {
    const redirectTo = window.location.origin + window.location.pathname;
    const { error } = await client.auth.signInWithOAuth({
      provider: 'google',
      options: { redirectTo },
    });
    if (error) throw error;
  } catch (_) {
    fail('GOOGLE_OAUTH_START');
    busy = false; controls();
  }
}
async function logout() {
  if (busy) return;
  busy = true; controls();
  try {
    const { error } = await client.auth.signOut({ scope: 'local' });
    if (error) throw error;
    signedIn = false;
    ui.identity.hidden = true;
    ui.google.textContent = 'تم تسجيل الخروج';
    ui.backend.textContent = 'لم يتم الاختبار';
    status('تم إنهاء جلسة هذا التبويب. يمكنك إعادة الاختبار.');
  } catch (_) {
    fail('SIGN_OUT');
  } finally {
    busy = false; controls();
  }
}

ui.login.addEventListener('click', beginLogin);
ui.logout.addEventListener('click', logout);
ui.recheck.addEventListener('click', verify);

async function start() {
  if (window.location.protocol !== 'https:' &&
      !['localhost', '127.0.0.1'].includes(window.location.hostname)) {
    fail('HTTPS_REQUIRED'); return;
  }
  const query = new URLSearchParams(window.location.search);
  const oauthError = query.get('error');
  const code = query.get('code');
  // Always strip query, including OAuth authorization codes and error descriptions.
  if (oauthError || code) cleanUrl();
  if (oauthError) {
    ui.google.textContent = 'رفض Google أو رابط الرجوع';
    ui.backend.textContent = 'لم يتم الاختبار';
    fail('GOOGLE_CALLBACK'); controls(); return;
  }
  if (code) {
    status('وصل رد Google. يجري استبدال رمز OAuth بجلسة آمنة...');
    try {
      const { error } = await client.auth.exchangeCodeForSession(code);
      if (error) throw error;
    } catch (_) {
      ui.google.textContent = 'تعذّر تبادل الرمز';
      ui.backend.textContent = 'لم يتم الاختبار';
      fail('PKCE_EXCHANGE'); controls(); return;
    }
  }
  await verify();
}
controls();
start();

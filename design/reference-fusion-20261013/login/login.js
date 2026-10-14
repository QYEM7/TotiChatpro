/* TotiChat Login Screen 01: Google-only, isolated from live app layout.
 * Does not implement OAuth or store tokens. Reuses the staging auth adapter.
 * Screen is a review candidate, not owner-approved or beta-verified.
 */
(function initTotiLoginReview(){
  'use strict';

  const allowedHosts = new Set(['totichat-login-review-20261013.vercel.app']);
  const isApprovedHost = location.protocol === 'https:' && allowedHosts.has(location.hostname);
  const nativeAndroidHost = location.protocol === 'https:' && location.hostname === 'localhost'
    && Boolean(window.Capacitor?.Plugins?.App && window.Capacitor?.Plugins?.Browser);
  const canStartOAuth = isApprovedHost || nativeAndroidHost;
  const auth = window.TotiPhase2Auth;
  const googleButton = document.getElementById('google-button');
  const authMessage = document.getElementById('auth-message');
  const signedOutPanel = document.getElementById('signed-out-panel');
  const signedInPanel = document.getElementById('signed-in-panel');
  const accountSummary = document.getElementById('account-summary');
  const signoutButton = document.getElementById('signout-button');
  const continueLink = document.getElementById('continue-link');

  if (!googleButton || !authMessage || !signedOutPanel || !signedInPanel) return;

  // CSP-safe image fallback: no inline event handlers that could weaken script policy.
  const logoImage = document.querySelector('.falcon-original');
  if (logoImage) logoImage.addEventListener('error', () => {
    logoImage.hidden = true;
    const fallback = logoImage.nextElementSibling;
    if (fallback) fallback.hidden = false;
  });
  // When a user opened the Home preview directly, return there only after
  // the existing adapter verifies the SAME-ORIGIN real Google session.
  const HOME_RETURN_FLAG='totichat.review.returnHome.v1';
  try {
    if(new URLSearchParams(location.search).get('returnTo')==='home')
      sessionStorage.setItem(HOME_RETURN_FLAG,'1');
  } catch(_) {}
  function returnToHomeOnceVerified(){
    try{
      if(sessionStorage.getItem(HOME_RETURN_FLAG)!=='1')return;
      sessionStorage.removeItem(HOME_RETURN_FLAG);
      location.replace('./home/?review=home02');
    }catch(_){}
  }
  let busy = false;
  let lastValidation = 0;
  let providerReady = false;

  function setStatus(message, kind) {
    authMessage.textContent = String(message || '').slice(0, 220);
    authMessage.dataset.kind = kind || 'info';
  }
  function setBusy(nextBusy) {
    busy = Boolean(nextBusy);
    googleButton.disabled = busy;
    googleButton.setAttribute('aria-busy', String(busy));
  }
  function showSignedOut() {
    signedInPanel.hidden = true;
    signedOutPanel.hidden = false;
    accountSummary.textContent = '';
  }
  function showVerified(user) {
    if (!user || typeof user.id !== 'string') return;
    signedOutPanel.hidden = true;
    signedInPanel.hidden = false;
    accountSummary.textContent = user.email || 'Authenticated Google account';
    // This independent review origin cannot share sessionStorage with the live app origin.
    // Never suggest an authenticated app handoff that would silently lose the session.
    // The Home review is now on the same HTTPS origin and uses this verified session.
    continueLink.hidden = false;
  }
  function isSameUser(expectedId) {
    return expectedId && auth?.state()?.signedIn === true
      && auth?.state()?.user?.id === expectedId;
  }
  let validationInFlight = null;
  let validationUserId = '';

  async function validateSession() {
    if (!auth) return false;
    const initial = auth.state();
    if (!initial?.signedIn || !initial.user?.id) {
      lastValidation++;
      validationUserId = '';
      showSignedOut();
      return false;
    }
    const expectedId = initial.user.id;
    // readProfile() emits totichat-phase2-auth. Re-entering validation on that
    // event would trigger unbounded user/profile RPCs without this guard.
    if (validationInFlight && validationUserId === expectedId) {
      return validationInFlight;
    }
    const requested = ++lastValidation;
    validationUserId = expectedId;
    const task = (async () => {
      try {
        // Confirm on the server that the cached browser session is valid.
        await auth.securityState();
        if (requested !== lastValidation || !isSameUser(expectedId)) return false;
        // Only fetch the profile if it is missing. The adapter broadcasts
        // profile reads, so never refetch an already loaded matching profile.
        if (auth.state().profile?.id !== expectedId) {
          await auth.readProfile();
        }
        if (requested !== lastValidation || !isSameUser(expectedId)
            || auth.state().profile?.id !== expectedId) return false;
        showVerified(auth.state().user);
        return true;
      } catch (error) {
        if (requested === lastValidation) {
          showSignedOut();
          setStatus('Your sign-in could not be verified. Check your connection and retry.', 'error');
        }
        return false;
      }
    })();
    validationInFlight = task;
    try {
      return await task;
    } finally {
      if (validationInFlight === task) {
        validationInFlight = null;
        validationUserId = '';
      }
    }
  }
  async function checkProvider() {
    if (!auth) {
      setStatus('Preview mode: the staging authentication adapter is not loaded.', 'info');
      return false;
    }
    if (!canStartOAuth) {
      setStatus('Visual review only. Sign-in requires an approved staging HTTPS callback.', 'info');
      return false;
    }
    try {
      const providers = await auth.providers();
      providerReady = providers.google === true;
      if (!providerReady) {
        setStatus('Google sign-in is not enabled for this staging environment.', 'error');
      }
      return providerReady;
    } catch (error) {
      providerReady = false;
      setStatus('Unable to reach the Google sign-in service. Please retry.', 'error');
      return false;
    }
  }

  googleButton.addEventListener('click', async () => {
    if (busy) return;
    if (!navigator.onLine) {
      setStatus('You are offline. Reconnect to continue.', 'error');
      return;
    }
    setBusy(true);
    setStatus('');
    try {
      if (!canStartOAuth) throw new Error('Staging HTTPS preview URL has not been authorized for Google login.');
      if (!auth) throw new Error('Authentication adapter is unavailable on this visual preview.');
      if (!providerReady && !(await checkProvider())) return;
      // The existing adapter enforces PKCE, provider status and callback validation.
      // Do not create success state here; only verified session may do so.
      await auth.signInWithProvider('google');
    } catch (error) {
      setStatus(error?.message || 'Unable to start Google sign-in.', 'error');
    } finally {
      setBusy(false);
    }
  });

  signoutButton.addEventListener('click', async () => {
    if (!auth || busy) return;
    signoutButton.disabled = true;
    lastValidation++;
    try {
      await auth.signOut();
      showSignedOut();
      setStatus('You are signed out.', 'info');
    } catch (error) {
      showSignedOut();
      setStatus(error?.message || 'Signed out locally, but server sign-out could not be confirmed.', 'error');
    } finally {
      signoutButton.disabled = false;
    }
  });

  // Handoff is visible only after a backend-verified session.
  continueLink.addEventListener('click', (event) => {
    if (!auth?.state()?.signedIn || signedInPanel.hidden) event.preventDefault();
  });
  window.addEventListener('totichat-phase2-auth', () => { void validateSession(); });
  window.addEventListener('totichat-auth-error', (event) => {
    showSignedOut();
    setStatus(String(event.detail || 'Google sign-in could not be completed.'), 'error');
  });
  window.addEventListener('online', () => {
    if (!auth?.state()?.signedIn) { setStatus(''); void checkProvider(); }
  });
  window.addEventListener('offline', () => {
    if (!auth?.state()?.signedIn) setStatus('You are offline. Reconnect to continue.', 'error');
  });

  // Never attempt a sign-in redirect, fake account or seed from initial render.
  showSignedOut();
  void checkProvider();
  void validateSession();
})();

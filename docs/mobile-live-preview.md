# Mobile live preview — TotiChatpro

This is a **non-production** preview setup for `QYEM7/TotiChatpro`. It does not change the approved UI, the backend, existing GitHub Pages, Android, or Supabase.

## Open on an Android phone

1. Open [the TotiChatpro Codespace setup](https://codespaces.new/QYEM7/TotiChatpro/tree/setup/mobile-live-preview-20261010?quickstart=1) in Chrome while signed in to GitHub.
2. Choose **Create codespace**. The dev container installs `live-server` and launches a web server on port **3000**.
3. Open the **PORTS** tab, find port **3000**, and select **Preview in Editor** if it did not open automatically.
4. Open `index.html` in the editor. On landscape orientation, choose **Split Editor Right** to keep code and the live preview side-by-side.
5. Save local changes to `index.html`, CSS, or JS. `live-server` reloads the open preview automatically. To inspect the connected home-banner prototype, open `/app/` in the preview.
6. These local edits are only in your Codespace until you explicitly commit and push them. Editing in a separate ChatGPT/GitHub session does not show in the Codespace until Git sync is performed.

## Important

- `/` is the preserved visual design preview. `/app/` uses the read-only banner integration; **the rest is not a fully functioning backend-backed application**.
- Codespaces and the forwarded-port preview may require GitHub sign-in. Do not expose private access links publicly.
- Codespaces use may be subject to quotas/fees.
- No app or production credentials are required for the static root preview. Do not put secret keys into this repository.
- The existing approved GitHub Pages page remains [https://qyem7.github.io/TotiChatpro/](https://qyem7.github.io/TotiChatpro/).
- Do not merge UI changes or edit approved reference artwork without explicit approval.

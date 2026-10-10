# T23: Genuine saved song references and room queue metadata

- New pending SQL (never applied to production) creates per-user saved music bookmarks with strict RLS.
- A user may add a song title and artist, optionally a HTTPS reference, and retain it on their own account across sessions. This is a bookmark, **not a licensed audio stream**.
- The actual room Owner can add one of their saved references to the room queue; all current members can read the queue metadata, outsiders/anonymous cannot. Other members cannot modify the queue.
- The approved room UI keeps every element, button, VIP frame and microphone seat; a small music tool accesses an inline queue sheet without navigating out of the voice room or interrupting the mic.
- The original music page remains styled identically and gets real save/list/delete controls for signed-in live accounts.
- No fake song listings, streaming subscriptions, downloaded copyrighted media, or automatic background playback. T23 **remains partial** until a rights-cleared audio source and synchronized multi-device playback are connected, then tested on two real phones.
- Validation: local two-JWT Auth and REST operation tests with denied IDOR/room outsider access, SQL RLS assertion, Android/Browser regression, migration replay. All production data is unchanged.


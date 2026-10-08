1. **Fix icon replacement on loading for the empty state spawn button**
   - The empty state "Spawn Conversation" button currently uses `phx-disable-with` with text, which replaces the whole button content, causing layout shift and removing the icon.
   - We will replace `phx-disable-with` with `phx-click-loading` utility classes to hide the existing `hero-plus` icon and show a `hero-arrow-path` spinning icon during loading state.
   - We will also disable the button natively using `phx-click-loading:opacity-50 phx-click-loading:cursor-not-allowed`.

2. **Fix icon replacement on loading for the main spawn conversation button**
   - We will do the same fix for the main "Spawn Conversation" button at the top.

3. **Fix icon replacement on loading for the "Send Customer Message" button**
   - Update the button to use an animated loading spinner instead of `phx-disable-with="Sending..."`.

4. **Update tests**
   - Update `test/convo_sim_web/live/dashboard_live_test.exs` to remove assertions on `phx-disable-with` for the modified buttons.

5. **Complete pre commit steps**
   - Complete pre-commit steps to ensure proper testing, verification, review, and reflection are done.

# P05 source checkpoint: NOT a hydrated runnable Git checkout

This branch preserves P05 reviewed text/code and design documentation. P05 binary art is **not** uploaded on this branch yet: remote Git LFS authentication/object upload has not been verified. The P04 ordinary blobs inherited from the earlier branch are NOT the P05 artwork and can mismatch the P05 manifest. Do not run/export a partial checkout or assume this branch is the playable release before the exact new assets are restored. No dangling LFS pointers were committed.

The exact, complete P05 Godot source archive was saved for the owner separately, SHA256 24e306cf49cea5921b3d37bdd88bac8bf104a8e30120fb05eb1d0420b746341d. The actual P05 Web build passed export and was uploaded to the existing private itch Draft, SHA256 1c29f45f75a608f49b9e0efabfc65ade7a29195bdf00eb456e90f109fe6b1a82.

After authorized Git client authentication and confirmed free LFS quota: restore P05 binary content from exact archive, remove only new/changed-path exemptions, add via LFS installed client, verify object availability using a fresh clone, then run the complete tests. Keep main and P04 untouched.

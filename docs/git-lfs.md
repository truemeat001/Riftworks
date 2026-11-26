# Git LFS policy

New binary graphics, source art, audio and video assets are tracked by `.gitattributes` with Git LFS; text (Godot scripts, JSON, import metadata, Markdown) and generated Web/build output are not tracked by LFS. Install the client before adding new binary assets:

```sh
git lfs install
git lfs track
git lfs ls-files
```

P04 already uploaded 13 verified regular raster blobs. Their exact paths are temporarily exempted to keep this snapshot directly check-outable; future assets use LFS. To migrate an existing exempt path without rewriting history, first ensure remote write authentication and approved LFS quota, remove that path's exemption, re-add the file through the LFS filter, verify `git lfs ls-files` and `git lfs status`, then push the new commit and verify a fresh clone hydrates the exact content. Do not commit a bare pointer without its LFS object; do not rewrite existing commits or force-push. Avoid paid storage and CI without permission. The project does not require any real-money service.

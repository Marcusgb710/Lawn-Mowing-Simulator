# Studio curation tools

These are the scripts used to pick models for the game. One stands each current model beside its Creator Store candidates in Studio so you can compare them side by side. The other flies the camera past each row so you can take a screenshot of every comparison. A tiny local server hands the scripts to Studio and collects what they report.

## Run it

From the repo root, start the server and leave it running:

    python -I scripts/serve-studio.py

It serves this folder on `127.0.0.1:8765`. If something already answers on 8765, stop it first. Nothing outside your machine can reach it. Stop it with Ctrl+C. The scripts and the one-liner below call port 8765. If you start the server with `--port`, search the two Lua scripts and the one-liner for 8765 and change it in each.

The one-liner turns on `HttpService.HttpEnabled` itself, so there is no Game Settings step.

Then paste this into the Studio command bar:

    local H=game:GetService("HttpService");H.HttpEnabled=true;local n=(H:GetAsync("http://127.0.0.1:8765/mode.txt"):gsub("%s",""));local f,e=loadstring(H:GetAsync("http://127.0.0.1:8765/"..n..".lua"));if f then f() else warn(e) end

The one-liner never changes. It reads `mode.txt`, fetches the script that file names, and runs it.

## mode.txt

`mode.txt` holds one word, `lineup` or `camera`. Create it next to this README, then edit it to switch what the one-liner runs. Run `lineup` first to build the scene, then switch to `camera` to walk through it.

## pairs.json

`pairs.json` lists the rows for `lineup`. Copy `pairs.example.json` to `pairs.json` and edit it. It is an array with one object per row:

| Field | Meaning |
| --- | --- |
| `name` | Label for the row, used in the camera report. |
| `now` | Where the current model lives under `ServerStorage.Assets`, for example `Tools/ReelMower`. |
| `store` | Creator Store asset ids to compare against it, in the order they appear. |
| `gap` | Studs between the models in the row. Defaults to 14. |
| `step` | Studs between this row and the next. Defaults to 60. |

A row can also set `dist`, a minimum camera distance for that row's stop. The camera backs off further on its own when the row is wide or tall.

## What lineup does

It deletes any old `Lineup` folder in Workspace and builds a new one. A grass slab 600 studs up holds one row per entry in `pairs.json`, so nothing in the real map gets in the way. In each row the current model comes first, labelled NOW in amber, then the candidates labelled #1, #2 and so on in green. Scripts and sounds are stripped from every model and its parts are anchored.

If a store asset turns out to be a set of three or more models, only the first one by name is kept, and the names in the set go in the report.

For each row it also works out a camera stop and saves all of them as JSON in the `Stops` attribute of the `Lineup` folder. Each stop is the row name, then the camera position, then the point it looks at.

## What camera does

It reads the `Stops` attribute, fixes the camera, turns off depth of field, bloom and sun rays, waits two seconds, then moves to each stop six seconds apart. Take your screenshot during each pause. It needs the `Lineup` folder, so run `lineup` first.

## The report

Both scripts post a plain-text report to the server when they finish. It is appended to `log.txt` in this folder, with `---` between runs. `lineup` reports each model it placed with its part count and size, a warning for any model that failed to load, and `LINEUP DONE rows N` at the end. If it hits an error, the error is in the report instead of the last line. `camera` reports the stops it visited, once it has been through all of them.

`log.txt`, `pairs.json` and `mode.txt` are git-ignored. Only the scripts, the example and this README are committed.

# AMENDMENT SEMÁNTICO — @investigacionNRFI — 2026-08-02

RUN_ID: `INVNRFI-20260802-AMEND-A1`  

PARENT_RUN_ID: `INVNRFI-20260802-6c2a8e91`  

RUN_TYPE: `AMENDMENT`  

SYSTEM_VERSION: `INVESTIGACION-NRFI-HISTORICAL-V1.0`  

KERNEL_VERSION: `INVESTIGACION-NRFI-KERNEL-0.2-SEMANTIC-COMPLETENESS`


## EXECUTION_SUMMARY


Official finalized universe: 15 games. Official GUMBO captured for 15/15 games in GitHub commit `fd601c07056266452ae1a551ff0c71bb8a11cf47`. The original shallow certification is withdrawn. This amendment reconstructs the first inning from play/pitch objects and persists semantic objects required by F1–F5. Historical descriptive outcomes in the captured universe: NRFI=9; YRFI=6; total first-inning runs=12; 0-run games=9; 1-run=1; 2-run=4; 3+-run=1. These are retrospective counts only.


## F1 — CAPTURA FORENSE


Every GAME_PK is tied to the official MLB GUMBO endpoint and raw SHA-256. The amendment stores scheduled/actual first pitch, venue, starters, lineup/catcher when recovered from the official boxscore, source lineage and a postgame evidence lane. Any lineup/catcher parsing limitation is preserved as an explicit bounded gap rather than silently omitted.


## F2 — RECONSTRUCCIÓN PROFUNDA


The following 15 GAME BLOCKS contain both half innings, every first-inning plate appearance retained in GUMBO, pitch sequences, run mechanism, exposure and starter first-inning process. This is the material reconstruction that the withdrawn original lacked.

## GAME BLOCK 824807 — Philadelphia Phillies @ Baltimore Orioles

**Identity.** GAME_PK 824807; venue Oriole Park at Camden Yards; scheduled 2026-08-02T17:35:00Z; first pitch observed 2026-08-02T17:36:52.133Z; starters Zack Wheeler (away) / Kyle Bradish (home). Source: official MLB GUMBO `https://statsapi.mlb.com/api/v1.1/game/824807/feed/live`; capture SHA-256 `761ebacc0bb0adcb6a0e54a93e4f7cd89ffe39586f22902800eb4c7c01383784`.

**First-inning outcome.** Top 0, bottom 0, total 0; descriptive outcome **NRFI**. Top path `NO_RUN_PATH`; bottom path `NO_RUN_PATH`. This is a historical observation, not a forecast or betting probability.

### Top 1st — Half-Inning Card

BF=3; pitches=10; runs=0; hits=0; singles=0; XBH=0; BB=0; HBP=0; K=2; HR=0; B4/B5/B6 exposed=False/False/False; leadoff reach=False; two-out extension=False; 3-up-3-down=True. Exact PA-level sequence follows.

- PA 1 — Trea Turner vs Kyle Bradish: field_out; outs 0→1; runs=0; pitches=1. Sequence: 1:SI In play, out(s) 95.9 mph. Description: Trea Turner grounds out, third baseman Christian Encarnacion-Strand to first baseman Pete Alonso.
- PA 2 — Kyle Schwarber vs Kyle Bradish: strikeout; outs 1→2; runs=0; pitches=4. Sequence: 1:FF Called Strike 95.5 mph; 2:CU Ball 85.6 mph; 3:CU Swinging Strike 85.5 mph; 4:FF Called Strike 95.8 mph. Description: Kyle Schwarber called out on strikes.
- PA 3 — Bryce Harper vs Kyle Bradish: strikeout; outs 2→3; runs=0; pitches=5. Sequence: 1:SI Called Strike 96.1 mph; 2:FF Swinging Strike 96.2 mph; 3:SI Foul 96.6 mph; 4:SI Ball 96.8 mph; 5:CU Swinging Strike (Blocked) 87.0 mph. Description: Bryce Harper strikes out swinging.

### Bottom 1st — Half-Inning Card

BF=4; pitches=20; runs=0; hits=1; singles=1; XBH=0; BB=0; HBP=0; K=2; HR=0; B4/B5/B6 exposed=True/False/False; leadoff reach=False; two-out extension=False; 3-up-3-down=False. Exact PA-level sequence follows.

- PA 1 — Dylan Beavers vs Zack Wheeler: strikeout; outs 0→1; runs=0; pitches=5. Sequence: 1:FF Called Strike 95.3 mph; 2:FC Ball 90.2 mph; 3:FF Called Strike 94.2 mph; 4:FF Foul 95.2 mph; 5:CU Swinging Strike 80.7 mph. Description: Dylan Beavers strikes out swinging.
- PA 2 — Pete Alonso vs Zack Wheeler: single; outs 1→1; runs=0; pitches=8. Sequence: 1:FF Called Strike 96.0 mph; 2:ST Ball 81.4 mph; 3:ST Called Strike 81.9 mph; 4:SI Ball 95.3 mph; 5:FF Foul 96.2 mph; 6:SI Ball 96.0 mph; 7:FS Foul 88.9 mph; 8:ST In play, no out 82.1 mph. Description: Pete Alonso singles on a ground ball to center fielder Justin Crawford.
- PA 3 — Gunnar Henderson vs Zack Wheeler: field_out; outs 1→2; runs=0; pitches=3. Sequence: 1:FF Called Strike 95.1 mph; 2:FF Swinging Strike 94.9 mph; 3:CU In play, out(s) 80.0 mph. Description: Gunnar Henderson flies out to center fielder Justin Crawford.
- PA 4 — Taylor Ward vs Zack Wheeler: strikeout; outs 2→3; runs=0; pitches=4. Sequence: 1:SI Ball 94.5 mph; 2:FF Swinging Strike 95.0 mph; 3:ST Foul 80.6 mph; 4:SI Called Strike 94.6 mph. Description: Taylor Ward called out on strikes.

### Pitch-level process and starter context

First-inning process objects: `{"680694":{"pitch_count_first_inning":10,"pitch_mix_first_inning":{"SI":4,"FF":3,"CU":3},"avg_release_speed_first_inning":93.1,"whiffs":3,"swings":5,"contacts":2},"554430":{"pitch_count_first_inning":20,"pitch_mix_first_inning":{"FF":8,"FC":1,"CU":2,"ST":4,"SI":4,"FS":1},"avg_release_speed_first_inning":90.41,"whiffs":3,"swings":9,"contacts":6}}`. These are calculated from the pitch events retained in the official first-inning GUMBO. Full-start boxscore context is retained separately in `STARTER_CONTEXT`; prior-start L3/L5/L10/L15/L20, season and career first-inning sequences are explicitly `BOUNDED_GAP` in this repair rather than fabricated. The gap does not alter the observed first-inning reconstruction.

### Feature and reliability interpretation

The game contributes all nine registry families at the GAME level: RESULTS, SEQUENCE, EXPOSURE, OUT_CREATION, TRAFFIC, DAMAGE, PITCHER_PROCESS, TOP_ORDER and CONTEXT. The observed current-game families carry high contextual support from GUMBO; historical sequence windows are low-coverage bounded objects. Press/HUMAN_INFORMATION is kept outside the pregame lane unless a publication/availability timestamp can be certified. Mechanism cohorting is retrospective and descriptive only.

### Reconstruction check

PA count top/bottom=3/4; pitch count top/bottom=10/20; first-inning score reconciliation=0+0=0. Exact event arrays and raw source hash are persisted. No missing historical window is converted to zero.

## GAME BLOCK 824891 — Washington Nationals @ Atlanta Braves

**Identity.** GAME_PK 824891; venue Truist Park; scheduled 2026-08-02T17:35:00Z; first pitch observed 2026-08-02T17:36:36.352Z; starters Cade Cavalli (away) / JR Ritchie (home). Source: official MLB GUMBO `https://statsapi.mlb.com/api/v1.1/game/824891/feed/live`; capture SHA-256 `87ec937bfb0d5a9d2a613d751b171feef79f2f2fa06053a2342ad8c05fe71243`.

**First-inning outcome.** Top 0, bottom 0, total 0; descriptive outcome **NRFI**. Top path `NO_RUN_PATH`; bottom path `NO_RUN_PATH`. This is a historical observation, not a forecast or betting probability.

### Top 1st — Half-Inning Card

BF=4; pitches=10; runs=0; hits=1; singles=1; XBH=0; BB=0; HBP=0; K=2; HR=0; B4/B5/B6 exposed=True/False/False; leadoff reach=False; two-out extension=False; 3-up-3-down=False. Exact PA-level sequence follows.

- PA 1 — James Wood vs JR Ritchie: strikeout; outs 0→1; runs=0; pitches=4. Sequence: 1:SI Foul 94.6 mph; 2:SI Called Strike 94.4 mph; 3:CH Ball 88.0 mph; 4:CU Called Strike 81.8 mph. Description: James Wood called out on strikes.
- PA 2 — Daylen Lile vs JR Ritchie: single; outs 1→1; runs=0; pitches=1. Sequence: 1:FF In play, no out 95.3 mph. Description: Daylen Lile singles on a line drive to right fielder Mike Yastrzemski.
- PA 3 — Dylan Crews vs JR Ritchie: force_out; outs 1→2; runs=0; pitches=2. Sequence: 1:SI Ball 95.0 mph; 2:SI In play, out(s) 95.4 mph. Description: Dylan Crews grounds into a force out, third baseman Austin Riley to second baseman Ozzie Albies. Daylen Lile out at 2nd. Dylan Crews to 1st.
- PA 4 — CJ Abrams vs JR Ritchie: strikeout; outs 2→3; runs=0; pitches=3. Sequence: 1:FF Foul Tip 96.3 mph; 2:FF Called Strike 96.6 mph; 3:CU Swinging Strike 83.2 mph. Description: CJ Abrams strikes out swinging.

### Bottom 1st — Half-Inning Card

BF=3; pitches=11; runs=0; hits=0; singles=0; XBH=0; BB=0; HBP=0; K=1; HR=0; B4/B5/B6 exposed=False/False/False; leadoff reach=False; two-out extension=False; 3-up-3-down=True. Exact PA-level sequence follows.

- PA 1 — Drake Baldwin vs Cade Cavalli: field_out; outs 0→1; runs=0; pitches=5. Sequence: 1:FF Foul 96.8 mph; 2:FC Called Strike 93.0 mph; 3:KC Ball 88.6 mph; 4:KC Ball 86.8 mph; 5:KC In play, out(s) 87.3 mph. Description: Drake Baldwin grounds out, pitcher Cade Cavalli to first baseman Andrés Chaparro.
- PA 2 — Ronald Acuña Jr. vs Cade Cavalli: strikeout; outs 1→2; runs=0; pitches=5. Sequence: 1:ST Called Strike 86.4 mph; 2:FC Swinging Strike 95.1 mph; 3:FF Foul 97.8 mph; 4:FC Ball 94.4 mph; 5:FF Swinging Strike 97.3 mph. Description: Ronald Acuña Jr. strikes out swinging.
- PA 3 — Matt Olson vs Cade Cavalli: field_out; outs 2→3; runs=0; pitches=1. Sequence: 1:ST In play, out(s) 86.3 mph. Description: Matt Olson grounds out to first baseman Andrés Chaparro.

### Pitch-level process and starter context

First-inning process objects: `{"702275":{"pitch_count_first_inning":10,"pitch_mix_first_inning":{"SI":4,"CH":1,"CU":2,"FF":3},"avg_release_speed_first_inning":92.06,"whiffs":1,"swings":5,"contacts":4},"676917":{"pitch_count_first_inning":11,"pitch_mix_first_inning":{"FF":3,"FC":3,"KC":3,"ST":2},"avg_release_speed_first_inning":91.8,"whiffs":2,"swings":6,"contacts":4}}`. These are calculated from the pitch events retained in the official first-inning GUMBO. Full-start boxscore context is retained separately in `STARTER_CONTEXT`; prior-start L3/L5/L10/L15/L20, season and career first-inning sequences are explicitly `BOUNDED_GAP` in this repair rather than fabricated. The gap does not alter the observed first-inning reconstruction.

### Feature and reliability interpretation

The game contributes all nine registry families at the GAME level: RESULTS, SEQUENCE, EXPOSURE, OUT_CREATION, TRAFFIC, DAMAGE, PITCHER_PROCESS, TOP_ORDER and CONTEXT. The observed current-game families carry high contextual support from GUMBO; historical sequence windows are low-coverage bounded objects. Press/HUMAN_INFORMATION is kept outside the pregame lane unless a publication/availability timestamp can be certified. Mechanism cohorting is retrospective and descriptive only.

### Reconstruction check

PA count top/bottom=4/3; pitch count top/bottom=10/11; first-inning score reconciliation=0+0=0. Exact event arrays and raw source hash are persisted. No missing historical window is converted to zero.

## GAME BLOCK 822783 — St. Louis Cardinals @ Toronto Blue Jays

**Identity.** GAME_PK 822783; venue Rogers Centre; scheduled 2026-08-02T17:37:00Z; first pitch observed 2026-08-02T17:37:21.883Z; starters Matthew Liberatore (away) / Max Scherzer (home). Source: official MLB GUMBO `https://statsapi.mlb.com/api/v1.1/game/822783/feed/live`; capture SHA-256 `3adc420b758a34bce808a28e7bea7e7894c85762697625413cabc5ca557a358e`.

**First-inning outcome.** Top 0, bottom 0, total 0; descriptive outcome **NRFI**. Top path `NO_RUN_PATH`; bottom path `NO_RUN_PATH`. This is a historical observation, not a forecast or betting probability.

### Top 1st — Half-Inning Card

BF=3; pitches=17; runs=0; hits=0; singles=0; XBH=0; BB=0; HBP=0; K=2; HR=0; B4/B5/B6 exposed=False/False/False; leadoff reach=False; two-out extension=False; 3-up-3-down=True. Exact PA-level sequence follows.

- PA 1 — Lars Nootbaar vs Max Scherzer: strikeout; outs 0→1; runs=0; pitches=6. Sequence: 1:FF Ball 93.2 mph; 2:FF Called Strike 93.3 mph; 3:CU Foul 74.1 mph; 4:FC Ball 88.6 mph; 5:CH Foul 85.4 mph; 6:FF Foul Tip 94.2 mph. Description: Lars Nootbaar strikes out on a foul tip.
- PA 2 — Jordan Walker vs Max Scherzer: field_out; outs 1→2; runs=0; pitches=5. Sequence: 1:FF Swinging Strike 94.2 mph; 2:SL Swinging Strike 86.1 mph; 3:FF Foul 94.9 mph; 4:SL Ball 85.8 mph; 5:SL In play, out(s) 85.3 mph. Description: Jordan Walker grounds out, third baseman Ernie Clement to first baseman Kazuma Okamoto.
- PA 3 — Alec Burleson vs Max Scherzer: strikeout; outs 2→3; runs=0; pitches=6. Sequence: 1:FF Called Strike 93.4 mph; 2:CU Ball 73.7 mph; 3:FF Foul 94.5 mph; 4:SL Foul 86.2 mph; 5:FF Ball 93.7 mph; 6:FC Called Strike 88.4 mph. Description: Alec Burleson called out on strikes.

### Bottom 1st — Half-Inning Card

BF=3; pitches=16; runs=0; hits=0; singles=0; XBH=0; BB=0; HBP=0; K=3; HR=0; B4/B5/B6 exposed=False/False/False; leadoff reach=False; two-out extension=False; 3-up-3-down=True. Exact PA-level sequence follows.

- PA 1 — Luis Urías vs Matthew Liberatore: strikeout; outs 0→1; runs=0; pitches=5. Sequence: 1:FF Ball 94.2 mph; 2:SL Called Strike 85.7 mph; 3:CH Foul 88.7 mph; 4:SL Ball 87.3 mph; 5:CU Swinging Strike 80.6 mph. Description: Luis Urías strikes out swinging.
- PA 2 — Vladimir Guerrero Jr. vs Matthew Liberatore: strikeout; outs 1→2; runs=0; pitches=5. Sequence: 1:SL Ball 87.2 mph; 2:SI Foul Tip 94.7 mph; 3:CH Swinging Strike 89.6 mph; 4:SL Ball 88.2 mph; 5:FF Swinging Strike 95.5 mph. Description: Vladimir Guerrero Jr. strikes out swinging.
- PA 3 — Kazuma Okamoto vs Matthew Liberatore: strikeout; outs 2→3; runs=0; pitches=6. Sequence: 1:SL Called Strike 87.1 mph; 2:CU Swinging Strike 82.2 mph; 3:FF Ball 95.1 mph; 4:CU Ball 81.8 mph; 5:SL Foul 88.2 mph; 6:FF Called Strike 95.5 mph. Description: Kazuma Okamoto called out on strikes.

### Pitch-level process and starter context

First-inning process objects: `{"453286":{"pitch_count_first_inning":17,"pitch_mix_first_inning":{"FF":8,"CU":2,"FC":2,"CH":1,"SL":4},"avg_release_speed_first_inning":88.53,"whiffs":2,"swings":9,"contacts":7},"669461":{"pitch_count_first_inning":16,"pitch_mix_first_inning":{"FF":4,"SL":6,"CH":2,"CU":3,"SI":1},"avg_release_speed_first_inning":88.85,"whiffs":4,"swings":7,"contacts":3}}`. These are calculated from the pitch events retained in the official first-inning GUMBO. Full-start boxscore context is retained separately in `STARTER_CONTEXT`; prior-start L3/L5/L10/L15/L20, season and career first-inning sequences are explicitly `BOUNDED_GAP` in this repair rather than fabricated. The gap does not alter the observed first-inning reconstruction.

### Feature and reliability interpretation

The game contributes all nine registry families at the GAME level: RESULTS, SEQUENCE, EXPOSURE, OUT_CREATION, TRAFFIC, DAMAGE, PITCHER_PROCESS, TOP_ORDER and CONTEXT. The observed current-game families carry high contextual support from GUMBO; historical sequence windows are low-coverage bounded objects. Press/HUMAN_INFORMATION is kept outside the pregame lane unless a publication/availability timestamp can be certified. Mechanism cohorting is retrospective and descriptive only.

### Reconstruction check

PA count top/bottom=3/3; pitch count top/bottom=17/16; first-inning score reconciliation=0+0=0. Exact event arrays and raw source hash are persisted. No missing historical window is converted to zero.

## GAME BLOCK 824404 — Arizona Diamondbacks @ Cleveland Guardians

**Identity.** GAME_PK 824404; venue Progressive Field; scheduled 2026-08-02T17:40:00Z; first pitch observed 2026-08-02T17:42:17.092Z; starters Merrill Kelly (away) / Gavin Williams (home). Source: official MLB GUMBO `https://statsapi.mlb.com/api/v1.1/game/824404/feed/live`; capture SHA-256 `15e0cf5e354c77c0b4f984944c251cf24463076b0922c46cf0165ff179fc5cb5`.

**First-inning outcome.** Top 0, bottom 0, total 0; descriptive outcome **NRFI**. Top path `NO_RUN_PATH`; bottom path `NO_RUN_PATH`. This is a historical observation, not a forecast or betting probability.

### Top 1st — Half-Inning Card

BF=3; pitches=14; runs=0; hits=0; singles=0; XBH=0; BB=0; HBP=0; K=1; HR=0; B4/B5/B6 exposed=False/False/False; leadoff reach=False; two-out extension=False; 3-up-3-down=True. Exact PA-level sequence follows.

- PA 1 — Corbin Carroll vs Gavin Williams: strikeout; outs 0→1; runs=0; pitches=6. Sequence: 1:FF Ball 97.4 mph; 2:FF Called Strike 98.2 mph; 3:ST Ball 88.3 mph; 4:ST Ball 88.1 mph; 5:FF Swinging Strike 98.5 mph; 6:FF Swinging Strike 99.6 mph. Description: Corbin Carroll strikes out swinging.
- PA 2 — Geraldo Perdomo vs Gavin Williams: field_out; outs 1→2; runs=0; pitches=1. Sequence: 1:FF In play, out(s) 99.0 mph. Description: Geraldo Perdomo flies out to left fielder Steven Kwan.
- PA 3 — Gabriel Moreno vs Gavin Williams: field_out; outs 2→3; runs=0; pitches=7. Sequence: 1:FF Ball 98.7 mph; 2:FF Called Strike 97.7 mph; 3:CU Ball 83.3 mph; 4:SI Foul 98.3 mph; 5:ST Foul 87.4 mph; 6:FF Ball 99.7 mph; 7:FF In play, out(s) 98.5 mph. Description: Gabriel Moreno flies out to right fielder Chase DeLauter.

### Bottom 1st — Half-Inning Card

BF=3; pitches=12; runs=0; hits=1; singles=1; XBH=0; BB=0; HBP=0; K=0; HR=0; B4/B5/B6 exposed=False/False/False; leadoff reach=True; two-out extension=False; 3-up-3-down=False. Exact PA-level sequence follows.

- PA 1 — Steven Kwan vs Merrill Kelly: single; outs 0→0; runs=0; pitches=5. Sequence: 1:FF Called Strike 89.7 mph; 2:FF Foul 91.2 mph; 3:FF Ball 91.2 mph; 4:FC Ball 91.1 mph; 5:CH In play, no out 88.5 mph. Description: Steven Kwan singles on a ground ball to shortstop Geraldo Perdomo, deflected by pitcher Merrill Kelly.
- PA 2 — José Ramírez vs Merrill Kelly: grounded_into_double_play; outs 0→2; runs=0; pitches=1. Sequence: 1:CH In play, out(s) 88.3 mph. Description: José Ramírez grounds into a double play, second baseman Ildemaro Vargas to shortstop Geraldo Perdomo to first baseman Tyler Locklear. Steven Kwan out at 2nd. José Ramírez out at 1st.
- PA 3 — Chase DeLauter vs Merrill Kelly: field_out; outs 2→3; runs=0; pitches=6. Sequence: 1:FF Called Strike 90.9 mph; 2:CH Ball 88.1 mph; 3:CH Ball 88.4 mph; 4:CU Called Strike 81.2 mph; 5:FC Ball 92.0 mph; 6:FC In play, out(s) 91.4 mph. Description: Chase DeLauter lines out to left fielder Max Kepler.

### Pitch-level process and starter context

First-inning process objects: `{"668909":{"pitch_count_first_inning":14,"pitch_mix_first_inning":{"FF":9,"ST":3,"CU":1,"SI":1},"avg_release_speed_first_inning":95.19,"whiffs":2,"swings":6,"contacts":4},"518876":{"pitch_count_first_inning":12,"pitch_mix_first_inning":{"FF":4,"FC":3,"CH":4,"CU":1},"avg_release_speed_first_inning":89.33,"whiffs":0,"swings":4,"contacts":4}}`. These are calculated from the pitch events retained in the official first-inning GUMBO. Full-start boxscore context is retained separately in `STARTER_CONTEXT`; prior-start L3/L5/L10/L15/L20, season and career first-inning sequences are explicitly `BOUNDED_GAP` in this repair rather than fabricated. The gap does not alter the observed first-inning reconstruction.

### Feature and reliability interpretation

The game contributes all nine registry families at the GAME level: RESULTS, SEQUENCE, EXPOSURE, OUT_CREATION, TRAFFIC, DAMAGE, PITCHER_PROCESS, TOP_ORDER and CONTEXT. The observed current-game families carry high contextual support from GUMBO; historical sequence windows are low-coverage bounded objects. Press/HUMAN_INFORMATION is kept outside the pregame lane unless a publication/availability timestamp can be certified. Mechanism cohorting is retrospective and descriptive only.

### Reconstruction check

PA count top/bottom=3/3; pitch count top/bottom=14/12; first-inning score reconciliation=0+0=0. Exact event arrays and raw source hash are persisted. No missing historical window is converted to zero.

## GAME BLOCK 824483 — Pittsburgh Pirates @ Cincinnati Reds

**Identity.** GAME_PK 824483; venue Great American Ball Park; scheduled 2026-08-02T17:40:00Z; first pitch observed 2026-08-02T17:41:49.327Z; starters Mitch Keller (away) / Chase Burns (home). Source: official MLB GUMBO `https://statsapi.mlb.com/api/v1.1/game/824483/feed/live`; capture SHA-256 `0561e92e2a349d17462232851c82a75fc1ee855b246c68acb4870f265288652c`.

**First-inning outcome.** Top 0, bottom 3, total 3; descriptive outcome **YRFI**. Top path `NO_RUN_PATH`; bottom path `HR_INVOLVED_MULTI_MECHANISM`. This is a historical observation, not a forecast or betting probability.

### Top 1st — Half-Inning Card

BF=3; pitches=13; runs=0; hits=0; singles=0; XBH=0; BB=1; HBP=0; K=0; HR=0; B4/B5/B6 exposed=False/False/False; leadoff reach=True; two-out extension=False; 3-up-3-down=False. Exact PA-level sequence follows.

- PA 1 — Jake Mangum vs Chase Burns: walk; outs 0→0; runs=0; pitches=6. Sequence: 1:FF Ball 95.5 mph; 2:FF Ball 95.9 mph; 3:FF Called Strike 95.7 mph; 4:FF Foul 96.3 mph; 5:FF Ball 96.9 mph; 6:FF Ball 97.6 mph. Description: Jake Mangum walks.
- PA 2 — Brandon Lowe vs Chase Burns: field_out; outs 0→1; runs=0; pitches=5. Sequence: 1:SL Swinging Strike (Blocked) 88.4 mph; 2:FF Ball 95.5 mph; 3:SL Ball 89.6 mph; 4:SL Ball 88.3 mph; 5:FF In play, out(s) 96.5 mph. Description: Brandon Lowe lines out to center fielder Dane Myers.
- PA 3 — Bryan Reynolds vs Chase Burns: field_out; outs 1→3; runs=0; pitches=2. Sequence: 1:FF Ball 95.4 mph; 2:SL In play, out(s) 87.9 mph. Description: Bryan Reynolds flies out to left fielder JJ Bleday.

### Bottom 1st — Half-Inning Card

BF=7; pitches=27; runs=3; hits=4; singles=2; XBH=2; BB=0; HBP=0; K=0; HR=1; B4/B5/B6 exposed=True/True/True; leadoff reach=False; two-out extension=False; 3-up-3-down=False. Exact PA-level sequence follows.

- PA 1 — Elly De La Cruz vs Mitch Keller: field_out; outs 0→1; runs=0; pitches=4. Sequence: 1:FF Ball 91.1 mph; 2:FF Called Strike 91.7 mph; 3:CH Foul 87.3 mph; 4:ST In play, out(s) 81.5 mph. Description: Elly De La Cruz grounds out, first baseman Spencer Horwitz to pitcher Mitch Keller.
- PA 2 — Sal Stewart vs Mitch Keller: home_run; outs 1→1; runs=1; pitches=4. Sequence: 1:SI Foul 92.2 mph; 2:SL Foul Tip 87.5 mph; 3:ST Ball 80.8 mph; 4:ST In play, run(s) 80.9 mph. Description: Sal Stewart homers (24) on a fly ball to left field.
- PA 3 — JJ Bleday vs Mitch Keller: single; outs 1→1; runs=0; pitches=3. Sequence: 1:ST Foul 80.0 mph; 2:FF Ball 92.8 mph; 3:CH In play, no out 88.8 mph. Description: JJ Bleday singles on a line drive to center fielder Jhostynxon Garcia.
- PA 4 — Tyler Stephenson vs Mitch Keller: double; outs 1→1; runs=1; pitches=2. Sequence: 1:ST Called Strike 79.2 mph; 2:SI In play, run(s) 92.5 mph. Description: Tyler Stephenson doubles (16) on a fly ball to center fielder Jhostynxon Garcia. JJ Bleday scores.
- PA 5 — Nathaniel Lowe vs Mitch Keller: single; outs 1→1; runs=1; pitches=2. Sequence: 1:FF Ball 93.0 mph; 2:FF In play, run(s) 93.0 mph. Description: Nathaniel Lowe singles on a sharp line drive to right fielder Esmerlyn Valdez. Tyler Stephenson scores.
- PA 6 — Dane Myers vs Mitch Keller: field_out; outs 1→2; runs=0; pitches=5. Sequence: 1:FF Ball 92.4 mph; 2:FF Ball 91.9 mph; 3:SL Ball 85.8 mph; 4:FF Called Strike 92.3 mph; 5:SL In play, out(s) 86.5 mph. Description: Dane Myers grounds out, third baseman Nick Gonzales to first baseman Spencer Horwitz. Nathaniel Lowe to 2nd.
- PA 7 — Noelvi Marte vs Mitch Keller: field_out; outs 2→3; runs=0; pitches=7. Sequence: 1:SI Called Strike 92.6 mph; 2:ST Swinging Strike 80.4 mph; 3:ST Ball 81.8 mph; 4:SL Ball In Dirt 87.5 mph; 5:SI Foul 92.4 mph; 6:SL Ball 87.4 mph; 7:ST In play, out(s) 82.1 mph. Description: Noelvi Marte pops out to shortstop Jacob Gonzalez.

### Pitch-level process and starter context

First-inning process objects: `{"695505":{"pitch_count_first_inning":13,"pitch_mix_first_inning":{"FF":9,"SL":4},"avg_release_speed_first_inning":93.81,"whiffs":1,"swings":4,"contacts":3},"656605":{"pitch_count_first_inning":27,"pitch_mix_first_inning":{"FF":8,"CH":2,"ST":8,"SI":4,"SL":5},"avg_release_speed_first_inning":87.61,"whiffs":1,"swings":13,"contacts":12}}`. These are calculated from the pitch events retained in the official first-inning GUMBO. Full-start boxscore context is retained separately in `STARTER_CONTEXT`; prior-start L3/L5/L10/L15/L20, season and career first-inning sequences are explicitly `BOUNDED_GAP` in this repair rather than fabricated. The gap does not alter the observed first-inning reconstruction.

### Feature and reliability interpretation

The game contributes all nine registry families at the GAME level: RESULTS, SEQUENCE, EXPOSURE, OUT_CREATION, TRAFFIC, DAMAGE, PITCHER_PROCESS, TOP_ORDER and CONTEXT. The observed current-game families carry high contextual support from GUMBO; historical sequence windows are low-coverage bounded objects. Press/HUMAN_INFORMATION is kept outside the pregame lane unless a publication/availability timestamp can be certified. Mechanism cohorting is retrospective and descriptive only.

### Reconstruction check

PA count top/bottom=3/7; pitch count top/bottom=13/27; first-inning score reconciliation=0+3=3. Exact event arrays and raw source hash are persisted. No missing historical window is converted to zero.

## GAME BLOCK 822943 — Chicago White Sox @ Tampa Bay Rays

**Identity.** GAME_PK 822943; venue Tropicana Field; scheduled 2026-08-02T17:40:00Z; first pitch observed 2026-08-02T17:40:15.754Z; starters Anthony Kay (away) / Griffin Jax (home). Source: official MLB GUMBO `https://statsapi.mlb.com/api/v1.1/game/822943/feed/live`; capture SHA-256 `51203d458e6264c3e75b10806b5688baf273da0042b008af5d1b413ca82df5fa`.

**First-inning outcome.** Top 2, bottom 0, total 2; descriptive outcome **YRFI**. Top path `XBH_DAMAGE`; bottom path `NO_RUN_PATH`. This is a historical observation, not a forecast or betting probability.

### Top 1st — Half-Inning Card

BF=6; pitches=28; runs=2; hits=1; singles=0; XBH=1; BB=0; HBP=0; K=2; HR=0; B4/B5/B6 exposed=True/True/True; leadoff reach=True; two-out extension=True; 3-up-3-down=False. Exact PA-level sequence follows.

- PA 1 — Sam Antonacci vs Griffin Jax: field_error; outs 0→0; runs=0; pitches=7. Sequence: 1:FF Ball 95.0 mph; 2:FF Swinging Strike 95.1 mph; 3:ST Called Strike 86.5 mph; 4:FF Foul 95.3 mph; 5:CU Ball 85.1 mph; 6:SI Foul 95.8 mph; 7:CH In play, no out 90.7 mph. Description: Sam Antonacci reaches on a fielding error by second baseman Ryan Vilade.
- PA 2 — Munetaka Murakami vs Griffin Jax: strikeout; outs 0→1; runs=0; pitches=5. Sequence: 1:SI Ball 94.8 mph; 2:FF Ball 96.0 mph; 3:ST Called Strike 86.4 mph; 4:FF Foul Tip 95.5 mph; 5:SI Called Strike 95.3 mph. Description: Munetaka Murakami called out on strikes.
- PA 3 — Miguel Vargas vs Griffin Jax: field_out; outs 1→2; runs=0; pitches=2. Sequence: 1:ST Ball 87.6 mph; 2:SI In play, out(s) 94.7 mph. Description: Miguel Vargas pops out to first baseman Jonathan Aranda in foul territory.
- PA 4 — Colson Montgomery vs Griffin Jax: double; outs 2→2; runs=0; pitches=3. Sequence: 1:FF Foul 95.5 mph; 2:CH Swinging Strike 90.6 mph; 3:SI In play, no out 95.0 mph. Description: Colson Montgomery doubles (18) on a ground ball to right fielder Jonny DeLuca. Sam Antonacci to 3rd.
- PA 5 — Andrew Benintendi vs Griffin Jax: field_error; outs 2→2; runs=1; pitches=4. Sequence: 1:FF Foul 94.8 mph; 2:ST Ball 86.9 mph; 3:CH Swinging Strike 90.9 mph; 4:CU In play, run(s) 85.1 mph. Description: Andrew Benintendi reaches on a fielding error by pitcher Griffin Jax. Sam Antonacci scores. Colson Montgomery to 3rd.
- PA 6 — Tristan Peters vs Griffin Jax: strikeout; outs 2→3; runs=1; pitches=7. Sequence: 1:CH Ball 90.3 mph; 2:FF Ball 95.0 mph; 3:ST Called Strike 87.3 mph; 4:CH Foul 91.0 mph; 5:FF Foul 96.5 mph; 6:ST Ball In Dirt 87.2 mph; 7:FF Swinging Strike 96.1 mph. Description: Tristan Peters strikes out swinging.

### Bottom 1st — Half-Inning Card

BF=3; pitches=5; runs=0; hits=0; singles=0; XBH=0; BB=0; HBP=0; K=0; HR=0; B4/B5/B6 exposed=False/False/False; leadoff reach=False; two-out extension=False; 3-up-3-down=False. Exact PA-level sequence follows.

- PA 1 — Yandy Díaz vs Anthony Kay: field_out; outs 0→1; runs=0; pitches=2. Sequence: 1:FF Ball 94.0 mph; 2:CH In play, out(s) 85.4 mph. Description: Yandy Díaz flies out to right fielder Everson Pereira.
- PA 2 — Jonathan Aranda vs Anthony Kay: field_error; outs 1→1; runs=0; pitches=1. Sequence: 1:SI In play, no out 95.0 mph. Description: Jonathan Aranda reaches on a fielding error by first baseman Munetaka Murakami.
- PA 3 — Junior Caminero vs Anthony Kay: grounded_into_double_play; outs 1→3; runs=0; pitches=2. Sequence: 1:ST Ball 81.2 mph; 2:FC In play, out(s) 92.0 mph. Description: Junior Caminero grounds into a double play, third baseman Miguel Vargas to second baseman Chase Meidroth to first baseman Munetaka Murakami. Jonathan Aranda out at 2nd. Junior Caminero out at 1st.

### Pitch-level process and starter context

First-inning process objects: `{"643377":{"pitch_count_first_inning":28,"pitch_mix_first_inning":{"FF":10,"ST":6,"CU":2,"SI":5,"CH":5},"avg_release_speed_first_inning":92.0,"whiffs":4,"swings":15,"contacts":11},"641743":{"pitch_count_first_inning":5,"pitch_mix_first_inning":{"FF":1,"CH":1,"SI":1,"ST":1,"FC":1},"avg_release_speed_first_inning":89.52,"whiffs":0,"swings":3,"contacts":3}}`. These are calculated from the pitch events retained in the official first-inning GUMBO. Full-start boxscore context is retained separately in `STARTER_CONTEXT`; prior-start L3/L5/L10/L15/L20, season and career first-inning sequences are explicitly `BOUNDED_GAP` in this repair rather than fabricated. The gap does not alter the observed first-inning reconstruction.

### Feature and reliability interpretation

The game contributes all nine registry families at the GAME level: RESULTS, SEQUENCE, EXPOSURE, OUT_CREATION, TRAFFIC, DAMAGE, PITCHER_PROCESS, TOP_ORDER and CONTEXT. The observed current-game families carry high contextual support from GUMBO; historical sequence windows are low-coverage bounded objects. Press/HUMAN_INFORMATION is kept outside the pregame lane unless a publication/availability timestamp can be certified. Mechanism cohorting is retrospective and descriptive only.

### Reconstruction check

PA count top/bottom=6/3; pitch count top/bottom=28/5; first-inning score reconciliation=2+0=2. Exact event arrays and raw source hash are persisted. No missing historical window is converted to zero.

## GAME BLOCK 823592 — Miami Marlins @ New York Mets

**Identity.** GAME_PK 823592; venue Citi Field; scheduled 2026-08-02T17:40:00Z; first pitch observed 2026-08-02T17:40:30.794Z; starters Sandy Alcantara (away) / Robert Stock (home). Source: official MLB GUMBO `https://statsapi.mlb.com/api/v1.1/game/823592/feed/live`; capture SHA-256 `cbf0743e253a14012ad9feef852de4c9f8f70abfdc77f96accb15823f7e7d3a2`.

**First-inning outcome.** Top 0, bottom 0, total 0; descriptive outcome **NRFI**. Top path `NO_RUN_PATH`; bottom path `NO_RUN_PATH`. This is a historical observation, not a forecast or betting probability.

### Top 1st — Half-Inning Card

BF=3; pitches=13; runs=0; hits=0; singles=0; XBH=0; BB=0; HBP=0; K=1; HR=0; B4/B5/B6 exposed=False/False/False; leadoff reach=False; two-out extension=False; 3-up-3-down=True. Exact PA-level sequence follows.

- PA 1 — Liam Hicks vs Robert Stock: field_out; outs 0→1; runs=0; pitches=6. Sequence: 1:FC Ball 92.7 mph; 2:FC Foul 91.9 mph; 3:FF Ball 96.2 mph; 4:FC Ball 91.4 mph; 5:FF Called Strike 95.3 mph; 6:FF In play, out(s) 96.8 mph. Description: Liam Hicks flies out to left fielder A.J. Ewing.
- PA 2 — Kyle Stowers vs Robert Stock: strikeout; outs 1→2; runs=0; pitches=4. Sequence: 1:CH Ball 81.3 mph; 2:FC Foul 93.7 mph; 3:FF Swinging Strike 97.1 mph; 4:FF Foul Tip 97.2 mph. Description: Kyle Stowers strikes out on a foul tip.
- PA 3 — Otto Lopez vs Robert Stock: field_out; outs 2→3; runs=0; pitches=3. Sequence: 1:FC Ball 94.7 mph; 2:FC Called Strike 93.0 mph; 3:SI In play, out(s) 95.8 mph. Description: Otto Lopez grounds out, shortstop Francisco Lindor to first baseman Jared Young.

### Bottom 1st — Half-Inning Card

BF=3; pitches=11; runs=0; hits=0; singles=0; XBH=0; BB=0; HBP=0; K=1; HR=0; B4/B5/B6 exposed=False/False/False; leadoff reach=False; two-out extension=False; 3-up-3-down=True. Exact PA-level sequence follows.

- PA 1 — A.J. Ewing vs Sandy Alcantara: field_out; outs 0→1; runs=0; pitches=4. Sequence: 1:CH Ball 93.5 mph; 2:SI Ball 95.5 mph; 3:SI Foul 96.4 mph; 4:CH In play, out(s) 89.6 mph. Description: A.J. Ewing grounds out, first baseman Kyle Stowers to pitcher Sandy Alcantara.
- PA 2 — Francisco Lindor vs Sandy Alcantara: field_out; outs 1→2; runs=0; pitches=3. Sequence: 1:FF Ball 95.5 mph; 2:FC Called Strike 89.1 mph; 3:CH In play, out(s) 89.4 mph. Description: Francisco Lindor flies out to center fielder Esteury Ruiz.
- PA 3 — Bo Bichette vs Sandy Alcantara: strikeout; outs 2→3; runs=0; pitches=4. Sequence: 1:FF Ball 95.5 mph; 2:SI Foul 96.7 mph; 3:ST Foul 83.5 mph; 4:CH Swinging Strike 90.2 mph. Description: Bo Bichette strikes out swinging.

### Pitch-level process and starter context

First-inning process objects: `{"476594":{"pitch_count_first_inning":13,"pitch_mix_first_inning":{"FC":6,"FF":5,"CH":1,"SI":1},"avg_release_speed_first_inning":93.62,"whiffs":1,"swings":6,"contacts":5},"645261":{"pitch_count_first_inning":11,"pitch_mix_first_inning":{"CH":4,"SI":3,"FF":2,"FC":1,"ST":1},"avg_release_speed_first_inning":92.26,"whiffs":1,"swings":6,"contacts":5}}`. These are calculated from the pitch events retained in the official first-inning GUMBO. Full-start boxscore context is retained separately in `STARTER_CONTEXT`; prior-start L3/L5/L10/L15/L20, season and career first-inning sequences are explicitly `BOUNDED_GAP` in this repair rather than fabricated. The gap does not alter the observed first-inning reconstruction.

### Feature and reliability interpretation

The game contributes all nine registry families at the GAME level: RESULTS, SEQUENCE, EXPOSURE, OUT_CREATION, TRAFFIC, DAMAGE, PITCHER_PROCESS, TOP_ORDER and CONTEXT. The observed current-game families carry high contextual support from GUMBO; historical sequence windows are low-coverage bounded objects. Press/HUMAN_INFORMATION is kept outside the pregame lane unless a publication/availability timestamp can be certified. Mechanism cohorting is retrospective and descriptive only.

### Reconstruction check

PA count top/bottom=3/3; pitch count top/bottom=13/11; first-inning score reconciliation=0+0=0. Exact event arrays and raw source hash are persisted. No missing historical window is converted to zero.

## GAME BLOCK 824163 — Texas Rangers @ Houston Astros

**Identity.** GAME_PK 824163; venue Daikin Park; scheduled 2026-08-02T18:10:00Z; first pitch observed 2026-08-02T18:10:39.175Z; starters Kumar Rocker (away) / Peter Lambert (home). Source: official MLB GUMBO `https://statsapi.mlb.com/api/v1.1/game/824163/feed/live`; capture SHA-256 `e56e766489f02bfe3a13e48a2bf14b666c90b503ff3b720ed60f75c6f154859c`.

**First-inning outcome.** Top 0, bottom 0, total 0; descriptive outcome **NRFI**. Top path `NO_RUN_PATH`; bottom path `NO_RUN_PATH`. This is a historical observation, not a forecast or betting probability.

### Top 1st — Half-Inning Card

BF=3; pitches=12; runs=0; hits=0; singles=0; XBH=0; BB=0; HBP=0; K=1; HR=0; B4/B5/B6 exposed=False/False/False; leadoff reach=False; two-out extension=False; 3-up-3-down=True. Exact PA-level sequence follows.

- PA 1 — Joc Pederson vs Peter Lambert: field_out; outs 0→1; runs=0; pitches=1. Sequence: 1:CH In play, out(s) 85.3 mph. Description: Joc Pederson grounds out, second baseman Jose Altuve to first baseman Christian Walker.
- PA 2 — Wyatt Langford vs Peter Lambert: strikeout; outs 1→2; runs=0; pitches=5. Sequence: 1:FF Ball 92.3 mph; 2:FF Called Strike 93.1 mph; 3:ST Foul 83.5 mph; 4:FF Ball 94.6 mph; 5:FF Swinging Strike 94.1 mph. Description: Wyatt Langford strikes out swinging.
- PA 3 — Corey Seager vs Peter Lambert: field_out; outs 2→3; runs=0; pitches=6. Sequence: 1:FF Ball 93.5 mph; 2:FF Swinging Strike 93.1 mph; 3:FF Foul 94.1 mph; 4:FF Ball 95.4 mph; 5:SV Ball 81.4 mph; 6:CH In play, out(s) 87.4 mph. Description: Corey Seager flies out sharply to center fielder Taylor Trammell.

### Bottom 1st — Half-Inning Card

BF=6; pitches=23; runs=0; hits=2; singles=1; XBH=1; BB=1; HBP=0; K=1; HR=0; B4/B5/B6 exposed=True/True/True; leadoff reach=True; two-out extension=True; 3-up-3-down=False. Exact PA-level sequence follows.

- PA 1 — Jeremy Peña vs Kumar Rocker: single; outs 0→0; runs=0; pitches=4. Sequence: 1:SL Called Strike 81.3 mph; 2:SI Ball 93.7 mph; 3:SI Ball 93.8 mph; 4:SL In play, no out 81.8 mph. Description: Jeremy Peña singles on a line drive to left fielder Wyatt Langford.
- PA 2 — Yordan Alvarez vs Kumar Rocker: double; outs 0→0; runs=0; pitches=2. Sequence: 1:SL Called Strike 82.1 mph; 2:FC In play, no out 89.3 mph. Description: Yordan Alvarez doubles (22) on a line drive to right fielder Brandon Nimmo. Jeremy Peña to 3rd.
- PA 3 — Isaac Paredes vs Kumar Rocker: field_out; outs 0→1; runs=0; pitches=6. Sequence: 1:SL Ball In Dirt 82.2 mph; 2:FC Ball 89.0 mph; 3:SL Called Strike 82.8 mph; 4:FC Foul 90.2 mph; 5:SI Ball 95.2 mph; 6:SI In play, out(s) 96.1 mph. Description: Isaac Paredes grounds out to first baseman Jake Burger.
- PA 4 — Christian Walker vs Kumar Rocker: strikeout; outs 1→2; runs=0; pitches=4. Sequence: 1:SL Swinging Strike 82.6 mph; 2:SL Swinging Strike 83.0 mph; 3:SL Ball In Dirt 83.1 mph; 4:FF Swinging Strike 95.3 mph. Description: Christian Walker strikes out swinging.
- PA 5 — Taylor Trammell vs Kumar Rocker: walk; outs 2→2; runs=0; pitches=6. Sequence: 1:SL Called Strike 83.6 mph; 2:FF Ball 95.4 mph; 3:FF Swinging Strike 95.2 mph; 4:SL Ball In Dirt 83.2 mph; 5:FF Ball 96.5 mph; 6:SL Ball 82.6 mph. Description: Elias Díaz challenged (pitch result), call on the field was confirmed: Taylor Trammell walks.
- PA 6 — Jose Altuve vs Kumar Rocker: force_out; outs 2→3; runs=0; pitches=1. Sequence: 1:SL In play, out(s) 83.8 mph. Description: Jose Altuve grounds into a force out, fielded by third baseman Ezequiel Duran. Yordan Alvarez out at 3rd.

### Pitch-level process and starter context

First-inning process objects: `{"663567":{"pitch_count_first_inning":12,"pitch_mix_first_inning":{"CH":2,"FF":8,"ST":1,"SV":1},"avg_release_speed_first_inning":90.65,"whiffs":2,"swings":6,"contacts":4},"677958":{"pitch_count_first_inning":23,"pitch_mix_first_inning":{"SL":12,"SI":4,"FC":3,"FF":4},"avg_release_speed_first_inning":87.9,"whiffs":4,"swings":9,"contacts":5}}`. These are calculated from the pitch events retained in the official first-inning GUMBO. Full-start boxscore context is retained separately in `STARTER_CONTEXT`; prior-start L3/L5/L10/L15/L20, season and career first-inning sequences are explicitly `BOUNDED_GAP` in this repair rather than fabricated. The gap does not alter the observed first-inning reconstruction.

### Feature and reliability interpretation

The game contributes all nine registry families at the GAME level: RESULTS, SEQUENCE, EXPOSURE, OUT_CREATION, TRAFFIC, DAMAGE, PITCHER_PROCESS, TOP_ORDER and CONTEXT. The observed current-game families carry high contextual support from GUMBO; historical sequence windows are low-coverage bounded objects. Press/HUMAN_INFORMATION is kept outside the pregame lane unless a publication/availability timestamp can be certified. Mechanism cohorting is retrospective and descriptive only.

### Reconstruction check

PA count top/bottom=3/6; pitch count top/bottom=12/23; first-inning score reconciliation=0+0=0. Exact event arrays and raw source hash are persisted. No missing historical window is converted to zero.

## GAME BLOCK 824648 — New York Yankees @ Chicago Cubs

**Identity.** GAME_PK 824648; venue Wrigley Field; scheduled 2026-08-02T18:20:00Z; first pitch observed 2026-08-02T18:20:22.804Z; starters Gerrit Cole (away) / Colin Rea (home). Source: official MLB GUMBO `https://statsapi.mlb.com/api/v1.1/game/824648/feed/live`; capture SHA-256 `dd247473bf14c3c21bb765c1101a96136dded98e22bb01ea21faeded259a2bb4`.

**First-inning outcome.** Top 0, bottom 0, total 0; descriptive outcome **NRFI**. Top path `NO_RUN_PATH`; bottom path `NO_RUN_PATH`. This is a historical observation, not a forecast or betting probability.

### Top 1st — Half-Inning Card

BF=3; pitches=13; runs=0; hits=0; singles=0; XBH=0; BB=0; HBP=0; K=3; HR=0; B4/B5/B6 exposed=False/False/False; leadoff reach=False; two-out extension=False; 3-up-3-down=True. Exact PA-level sequence follows.

- PA 1 — Trent Grisham vs Colin Rea: strikeout; outs 0→1; runs=0; pitches=3. Sequence: 1:FF Called Strike 93.6 mph; 2:FF Called Strike 94.0 mph; 3:CH Called Strike 88.2 mph. Description: Trent Grisham called out on strikes.
- PA 2 — Ben Rice vs Colin Rea: strikeout; outs 1→2; runs=0; pitches=6. Sequence: 1:CH Foul 87.3 mph; 2:FF Called Strike 94.3 mph; 3:CU Ball 80.0 mph; 4:CH Foul 88.1 mph; 5:FF Ball 94.6 mph; 6:FF Called Strike 93.5 mph. Description: Ben Rice called out on strikes.
- PA 3 — Amed Rosario vs Colin Rea: strikeout; outs 2→3; runs=0; pitches=4. Sequence: 1:FF Called Strike 94.8 mph; 2:FF Swinging Strike 94.9 mph; 3:FF Foul 94.7 mph; 4:ST Swinging Strike 81.7 mph. Description: Amed Rosario strikes out swinging.

### Bottom 1st — Half-Inning Card

BF=4; pitches=21; runs=0; hits=0; singles=0; XBH=0; BB=1; HBP=0; K=2; HR=0; B4/B5/B6 exposed=True/False/False; leadoff reach=True; two-out extension=False; 3-up-3-down=False. Exact PA-level sequence follows.

- PA 1 — Pete Crow-Armstrong vs Gerrit Cole: walk; outs 0→0; runs=0; pitches=10. Sequence: 1:FF Called Strike 96.6 mph; 2:FF Ball 96.9 mph; 3:CH Foul 86.9 mph; 4:FF Ball 95.8 mph; 5:CH Foul 85.6 mph; 6:KC Foul 83.4 mph; 7:FF Ball 98.6 mph; 8:FF Foul 96.2 mph; 9:FF Foul 97.4 mph; 10:SL Ball 91.3 mph. Description: Pete Crow-Armstrong challenged (pitch result), call on the field was overturned: Pete Crow-Armstrong walks.
- PA 2 — Seiya Suzuki vs Gerrit Cole: strikeout; outs 0→1; runs=0; pitches=3. Sequence: 1:FF Foul 96.7 mph; 2:FF Called Strike 96.9 mph; 3:FF Swinging Strike 96.6 mph. Description: Seiya Suzuki strikes out swinging.
- PA 3 — Michael Busch vs Gerrit Cole: strikeout; outs 1→2; runs=0; pitches=3. Sequence: 1:SL Called Strike 90.5 mph; 2:FF Swinging Strike 97.5 mph; 3:CH Swinging Strike 85.2 mph. Description: Michael Busch strikes out swinging.
- PA 4 — Alex Bregman vs Gerrit Cole: field_out; outs 2→3; runs=0; pitches=5. Sequence: 1:KC Ball 85.0 mph; 2:SL Ball 90.5 mph; 3:FF Foul 98.1 mph; 4:KC Ball 83.9 mph; 5:FF In play, out(s) 97.2 mph. Description: Alex Bregman grounds out, third baseman Ryan McMahon to first baseman Ben Rice.

### Pitch-level process and starter context

First-inning process objects: `{"607067":{"pitch_count_first_inning":13,"pitch_mix_first_inning":{"FF":8,"CH":3,"CU":1,"ST":1},"avg_release_speed_first_inning":90.75,"whiffs":2,"swings":5,"contacts":3},"543037":{"pitch_count_first_inning":21,"pitch_mix_first_inning":{"FF":12,"CH":3,"KC":3,"SL":3},"avg_release_speed_first_inning":92.7,"whiffs":3,"swings":11,"contacts":8}}`. These are calculated from the pitch events retained in the official first-inning GUMBO. Full-start boxscore context is retained separately in `STARTER_CONTEXT`; prior-start L3/L5/L10/L15/L20, season and career first-inning sequences are explicitly `BOUNDED_GAP` in this repair rather than fabricated. The gap does not alter the observed first-inning reconstruction.

### Feature and reliability interpretation

The game contributes all nine registry families at the GAME level: RESULTS, SEQUENCE, EXPOSURE, OUT_CREATION, TRAFFIC, DAMAGE, PITCHER_PROCESS, TOP_ORDER and CONTEXT. The observed current-game families carry high contextual support from GUMBO; historical sequence windows are low-coverage bounded objects. Press/HUMAN_INFORMATION is kept outside the pregame lane unless a publication/availability timestamp can be certified. Mechanism cohorting is retrospective and descriptive only.

### Reconstruction check

PA count top/bottom=3/4; pitch count top/bottom=13/21; first-inning score reconciliation=0+0=0. Exact event arrays and raw source hash are persisted. No missing historical window is converted to zero.

## GAME BLOCK 824323 — Kansas City Royals @ Colorado Rockies

**Identity.** GAME_PK 824323; venue Coors Field; scheduled 2026-08-02T19:10:00Z; first pitch observed 2026-08-02T19:09:50.815Z; starters Seth Lugo (away) / Kyle Freeland (home). Source: official MLB GUMBO `https://statsapi.mlb.com/api/v1.1/game/824323/feed/live`; capture SHA-256 `aabaec6906e928f0321257c05b88c376b3e7e8f5810877423ee940a1283e59d0`.

**First-inning outcome.** Top 0, bottom 1, total 1; descriptive outcome **YRFI**. Top path `NO_RUN_PATH`; bottom path `XBH_DAMAGE`. This is a historical observation, not a forecast or betting probability.

### Top 1st — Half-Inning Card

BF=4; pitches=12; runs=0; hits=0; singles=0; XBH=0; BB=1; HBP=0; K=1; HR=0; B4/B5/B6 exposed=True/False/False; leadoff reach=False; two-out extension=False; 3-up-3-down=False. Exact PA-level sequence follows.

- PA 1 — Carter Jensen vs Kyle Freeland: strikeout; outs 0→1; runs=0; pitches=4. Sequence: 1:FF Swinging Strike 91.1 mph; 2:ST Ball 84.0 mph; 3:SI Foul 89.6 mph; 4:KC Swinging Strike 82.2 mph. Description: Carter Jensen strikes out swinging.
- PA 2 — Nick Loftin vs Kyle Freeland: walk; outs 1→1; runs=0; pitches=6. Sequence: 1:FC Called Strike 89.6 mph; 2:CH Swinging Strike 83.9 mph; 3:CH Ball 84.3 mph; 4:FC Ball 88.1 mph; 5:FF Ball 92.1 mph; 6:FC Ball 89.6 mph. Description: Nick Loftin challenged (pitch result), call on the field was overturned: Nick Loftin walks.
- PA 3 — Jac Caglianone vs Kyle Freeland: field_out; outs 1→2; runs=0; pitches=1. Sequence: 1:SI In play, out(s) 91.6 mph. Description: Jac Caglianone grounds out softly, pitcher Kyle Freeland to first baseman TJ Rumfield. Nick Loftin to 2nd.
- PA 4 — Salvador Perez vs Kyle Freeland: field_out; outs 2→3; runs=0; pitches=1. Sequence: 1:CH In play, out(s) 83.7 mph. Description: Salvador Perez flies out to right fielder Troy Johnston.

### Bottom 1st — Half-Inning Card

BF=6; pitches=32; runs=1; hits=1; singles=0; XBH=1; BB=2; HBP=0; K=0; HR=0; B4/B5/B6 exposed=True/True/True; leadoff reach=False; two-out extension=True; 3-up-3-down=False. Exact PA-level sequence follows.

- PA 1 — Jake McCarthy vs Seth Lugo: field_out; outs 0→1; runs=0; pitches=3. Sequence: 1:FF Foul 89.2 mph; 2:FF Ball 92.7 mph; 3:CH In play, out(s) 83.4 mph. Description: Jake McCarthy grounds out, second baseman Nick Loftin to first baseman Salvador Perez.
- PA 2 — Mickey Moniak vs Seth Lugo: walk; outs 1→1; runs=0; pitches=6. Sequence: 1:FC Ball 89.2 mph; 2:CU Swinging Strike 74.9 mph; 3:CH Ball 84.1 mph; 4:FC Ball 91.1 mph; 5:SI Swinging Strike 92.2 mph; 6:CU Ball 78.8 mph. Description: Mickey Moniak walks.
- PA 3 — Cole Carrigg vs Seth Lugo: double; outs 1→1; runs=1; pitches=6. Sequence: 1:FF Called Strike 92.8 mph; 2:CU Ball 74.5 mph; 3:FC Ball 89.6 mph; 4:FF Called Strike 93.7 mph; 5:FC Foul 91.6 mph; 6:CH In play, run(s) 85.6 mph. Description: Cole Carrigg doubles (10) on a line drive to left fielder Starling Marte. Mickey Moniak scores.
- PA 4 — TJ Rumfield vs Seth Lugo: field_out; outs 1→2; runs=0; pitches=4. Sequence: 1:FF Ball 92.8 mph; 2:CH Called Strike 83.6 mph; 3:CU Ball 74.5 mph; 4:FC In play, out(s) 90.9 mph. Description: TJ Rumfield pops out softly to first baseman Salvador Perez.
- PA 5 — Willi Castro vs Seth Lugo: walk; outs 2→2; runs=0; pitches=7. Sequence: 1:FC Called Strike 89.5 mph; 2:ST Called Strike 79.1 mph; 3:SL Ball In Dirt 83.2 mph; 4:CH Foul 85.0 mph; 5:FC Ball 91.4 mph; 6:CU Ball In Dirt 77.6 mph; 7:FF Ball 92.7 mph. Description: Willi Castro walks.
- PA 6 — Troy Johnston vs Seth Lugo: field_out; outs 2→3; runs=0; pitches=6. Sequence: 1:FF Ball 91.2 mph; 2:SI Swinging Strike 92.1 mph; 3:CU Ball 73.8 mph; 4:FF Ball 92.4 mph; 5:SI Foul 92.0 mph; 6:FC In play, out(s) 90.8 mph. Description: Troy Johnston flies out to center fielder John Rave.

### Pitch-level process and starter context

First-inning process objects: `{"607536":{"pitch_count_first_inning":12,"pitch_mix_first_inning":{"FF":2,"ST":1,"SI":2,"KC":1,"FC":3,"CH":3},"avg_release_speed_first_inning":87.48,"whiffs":3,"swings":6,"contacts":3},"607625":{"pitch_count_first_inning":32,"pitch_mix_first_inning":{"FF":8,"CH":5,"FC":8,"CU":6,"SI":3,"ST":1,"SL":1},"avg_release_speed_first_inning":86.75,"whiffs":3,"swings":11,"contacts":8}}`. These are calculated from the pitch events retained in the official first-inning GUMBO. Full-start boxscore context is retained separately in `STARTER_CONTEXT`; prior-start L3/L5/L10/L15/L20, season and career first-inning sequences are explicitly `BOUNDED_GAP` in this repair rather than fabricated. The gap does not alter the observed first-inning reconstruction.

### Feature and reliability interpretation

The game contributes all nine registry families at the GAME level: RESULTS, SEQUENCE, EXPOSURE, OUT_CREATION, TRAFFIC, DAMAGE, PITCHER_PROCESS, TOP_ORDER and CONTEXT. The observed current-game families carry high contextual support from GUMBO; historical sequence windows are low-coverage bounded objects. Press/HUMAN_INFORMATION is kept outside the pregame lane unless a publication/availability timestamp can be certified. Mechanism cohorting is retrospective and descriptive only.

### Reconstruction check

PA count top/bottom=4/6; pitch count top/bottom=12/32; first-inning score reconciliation=0+1=1. Exact event arrays and raw source hash are persisted. No missing historical window is converted to zero.

## GAME BLOCK 823996 — Milwaukee Brewers @ Los Angeles Angels

**Identity.** GAME_PK 823996; venue Angel Stadium; scheduled 2026-08-02T19:15:00Z; first pitch observed 2026-08-02T19:15:58.863Z; starters Jacob Misiorowski (away) / Walbert Ureña (home). Source: official MLB GUMBO `https://statsapi.mlb.com/api/v1.1/game/823996/feed/live`; capture SHA-256 `187c454c092f7dadc2c7ff122628b3186658ee83eb054f006d3a477a23e5f2b8`.

**First-inning outcome.** Top 0, bottom 0, total 0; descriptive outcome **NRFI**. Top path `NO_RUN_PATH`; bottom path `NO_RUN_PATH`. This is a historical observation, not a forecast or betting probability.

### Top 1st — Half-Inning Card

BF=3; pitches=10; runs=0; hits=0; singles=0; XBH=0; BB=0; HBP=0; K=3; HR=0; B4/B5/B6 exposed=False/False/False; leadoff reach=False; two-out extension=False; 3-up-3-down=True. Exact PA-level sequence follows.

- PA 1 — Brice Turang vs Walbert Ureña: strikeout; outs 0→1; runs=0; pitches=3. Sequence: 1:SI Called Strike 99.2 mph; 2:FF Called Strike 100.2 mph; 3:FF Swinging Strike 100.1 mph. Description: Brice Turang strikes out swinging.
- PA 2 — Jackson Chourio vs Walbert Ureña: strikeout; outs 1→2; runs=0; pitches=4. Sequence: 1:SI Called Strike 100.3 mph; 2:ST Ball 90.2 mph; 3:ST Foul 90.4 mph; 4:CH Swinging Strike 94.4 mph. Description: Jackson Chourio strikes out swinging, catcher Tyler Heineman to first baseman Nolan Schanuel.
- PA 3 — Garrett Mitchell vs Walbert Ureña: strikeout; outs 2→3; runs=0; pitches=3. Sequence: 1:SI Swinging Strike 98.7 mph; 2:CH Swinging Strike 94.1 mph; 3:CH Swinging Strike 93.2 mph. Description: Garrett Mitchell strikes out swinging.

### Bottom 1st — Half-Inning Card

BF=3; pitches=10; runs=0; hits=0; singles=0; XBH=0; BB=0; HBP=0; K=3; HR=0; B4/B5/B6 exposed=False/False/False; leadoff reach=False; two-out extension=False; 3-up-3-down=True. Exact PA-level sequence follows.

- PA 1 — Zach Neto vs Jacob Misiorowski: strikeout; outs 0→1; runs=0; pitches=3. Sequence: 1:FF Foul Tip 99.9 mph; 2:FF Swinging Strike 101.0 mph; 3:FF Swinging Strike 101.0 mph. Description: Zach Neto strikes out swinging.
- PA 2 — Mike Trout vs Jacob Misiorowski: strikeout; outs 1→2; runs=0; pitches=4. Sequence: 1:FF Called Strike 102.3 mph; 2:SL Called Strike 90.9 mph; 3:FF Ball 101.2 mph; 4:FF Swinging Strike 101.0 mph. Description: Mike Trout strikes out swinging.
- PA 3 — Nolan Schanuel vs Jacob Misiorowski: strikeout; outs 2→3; runs=0; pitches=3. Sequence: 1:FF Called Strike 100.4 mph; 2:FF Called Strike 100.9 mph; 3:CU Swinging Strike (Blocked) 89.1 mph. Description: Nolan Schanuel strikes out swinging, catcher William Contreras to first baseman Andrew Vaughn.

### Pitch-level process and starter context

First-inning process objects: `{"700712":{"pitch_count_first_inning":10,"pitch_mix_first_inning":{"SI":3,"FF":2,"ST":2,"CH":3},"avg_release_speed_first_inning":96.08,"whiffs":5,"swings":6,"contacts":1},"694819":{"pitch_count_first_inning":10,"pitch_mix_first_inning":{"FF":8,"SL":1,"CU":1},"avg_release_speed_first_inning":98.77,"whiffs":4,"swings":5,"contacts":1}}`. These are calculated from the pitch events retained in the official first-inning GUMBO. Full-start boxscore context is retained separately in `STARTER_CONTEXT`; prior-start L3/L5/L10/L15/L20, season and career first-inning sequences are explicitly `BOUNDED_GAP` in this repair rather than fabricated. The gap does not alter the observed first-inning reconstruction.

### Feature and reliability interpretation

The game contributes all nine registry families at the GAME level: RESULTS, SEQUENCE, EXPOSURE, OUT_CREATION, TRAFFIC, DAMAGE, PITCHER_PROCESS, TOP_ORDER and CONTEXT. The observed current-game families carry high contextual support from GUMBO; historical sequence windows are low-coverage bounded objects. Press/HUMAN_INFORMATION is kept outside the pregame lane unless a publication/availability timestamp can be certified. Mechanism cohorting is retrospective and descriptive only.

### Reconstruction check

PA count top/bottom=3/3; pitch count top/bottom=10/10; first-inning score reconciliation=0+0=0. Exact event arrays and raw source hash are persisted. No missing historical window is converted to zero.

## GAME BLOCK 824971 — Detroit Tigers @ Athletics

**Identity.** GAME_PK 824971; venue Sutter Health Park; scheduled 2026-08-02T20:05:00Z; first pitch observed 2026-08-02T20:05:45.929Z; starters Keider Montero (away) / Gage Jump (home). Source: official MLB GUMBO `https://statsapi.mlb.com/api/v1.1/game/824971/feed/live`; capture SHA-256 `f90fe0cc54ef26cf6349a2ef9b80ccdca96bdbd1c3a6efe1476fe36df459d996`.

**First-inning outcome.** Top 2, bottom 0, total 2; descriptive outcome **YRFI**. Top path `XBH_DAMAGE`; bottom path `NO_RUN_PATH`. This is a historical observation, not a forecast or betting probability.

### Top 1st — Half-Inning Card

BF=6; pitches=19; runs=2; hits=2; singles=1; XBH=1; BB=1; HBP=0; K=2; HR=0; B4/B5/B6 exposed=True/True/True; leadoff reach=True; two-out extension=True; 3-up-3-down=False. Exact PA-level sequence follows.

- PA 1 — Gleyber Torres vs Gage Jump: walk; outs 0→0; runs=0; pitches=6. Sequence: 1:FF Ball 93.9 mph; 2:FF Called Strike 93.1 mph; 3:SL Ball 85.3 mph; 4:SL Swinging Strike 85.4 mph; 5:SL Ball 85.5 mph; 6:FF Ball 93.7 mph. Description: Gleyber Torres walks.
- PA 2 — Dillon Dingler vs Gage Jump: single; outs 0→0; runs=0; pitches=2. Sequence: 1:CU Ball 79.2 mph; 2:SI In play, no out 92.4 mph. Description: Dillon Dingler singles on a sharp line drive to left fielder Tyler Soderstrom. Gleyber Torres to 2nd.
- PA 3 — Kevin McGonigle vs Gage Jump: strikeout; outs 0→1; runs=0; pitches=4. Sequence: 1:SI Called Strike 92.3 mph; 2:ST Foul 82.4 mph; 3:CH Ball 85.2 mph; 4:SI Called Strike 93.0 mph. Description: Kevin McGonigle called out on strikes.
- PA 4 — Eduardo Valencia vs Gage Jump: strikeout; outs 1→2; runs=0; pitches=3. Sequence: 1:CH Called Strike 86.0 mph; 2:CU Foul 79.5 mph; 3:FF Called Strike 95.1 mph. Description: Eduardo Valencia called out on strikes.
- PA 5 — Spencer Torkelson vs Gage Jump: double; outs 2→2; runs=2; pitches=2. Sequence: 1:CU Ball 79.5 mph; 2:FF In play, run(s) 94.8 mph. Description: Spencer Torkelson doubles (19) on a sharp line drive to center fielder Henry Bolte. Gleyber Torres scores. Dillon Dingler scores.
- PA 6 — Hao-Yu Lee vs Gage Jump: field_out; outs 2→3; runs=0; pitches=2. Sequence: 1:SL Ball 84.5 mph; 2:SL In play, out(s) 84.3 mph. Description: Hao-Yu Lee grounds out, third baseman Tommy White to first baseman Jeff McNeil.

### Bottom 1st — Half-Inning Card

BF=4; pitches=14; runs=0; hits=0; singles=0; XBH=0; BB=1; HBP=0; K=0; HR=0; B4/B5/B6 exposed=True/False/False; leadoff reach=False; two-out extension=True; 3-up-3-down=False. Exact PA-level sequence follows.

- PA 1 — Donovan Walton vs Keider Montero: field_out; outs 0→1; runs=0; pitches=2. Sequence: 1:FF Foul 91.8 mph; 2:CH In play, out(s) 86.0 mph. Description: Donovan Walton flies out to left fielder Ben Malgeri.
- PA 2 — Tyler Soderstrom vs Keider Montero: field_out; outs 1→2; runs=0; pitches=4. Sequence: 1:SI Called Strike 93.3 mph; 2:SL Foul Tip 84.8 mph; 3:CH Ball 87.7 mph; 4:SI In play, out(s) 94.5 mph. Description: Tyler Soderstrom lines out, pitcher Keider Montero to first baseman Spencer Torkelson.
- PA 3 — Jonah Heim vs Keider Montero: walk; outs 2→2; runs=0; pitches=6. Sequence: 1:SL Called Strike 85.3 mph; 2:KC Ball 78.7 mph; 3:FF Ball 94.3 mph; 4:FF Foul 94.0 mph; 5:CH Ball 87.2 mph; 6:CH Ball 87.9 mph. Description: Jonah Heim walks.
- PA 4 — Tommy White vs Keider Montero: field_out; outs 2→3; runs=0; pitches=2. Sequence: 1:SL Ball 84.5 mph; 2:SI In play, out(s) 93.9 mph. Description: Tommy White lines out sharply to center fielder Max Clark.

### Pitch-level process and starter context

First-inning process objects: `{"695611":{"pitch_count_first_inning":19,"pitch_mix_first_inning":{"FF":5,"SL":5,"CU":3,"SI":3,"ST":1,"CH":2},"avg_release_speed_first_inning":87.64,"whiffs":1,"swings":6,"contacts":5},"672456":{"pitch_count_first_inning":14,"pitch_mix_first_inning":{"FF":3,"CH":4,"SI":3,"SL":3,"KC":1},"avg_release_speed_first_inning":88.85,"whiffs":0,"swings":6,"contacts":6}}`. These are calculated from the pitch events retained in the official first-inning GUMBO. Full-start boxscore context is retained separately in `STARTER_CONTEXT`; prior-start L3/L5/L10/L15/L20, season and career first-inning sequences are explicitly `BOUNDED_GAP` in this repair rather than fabricated. The gap does not alter the observed first-inning reconstruction.

### Feature and reliability interpretation

The game contributes all nine registry families at the GAME level: RESULTS, SEQUENCE, EXPOSURE, OUT_CREATION, TRAFFIC, DAMAGE, PITCHER_PROCESS, TOP_ORDER and CONTEXT. The observed current-game families carry high contextual support from GUMBO; historical sequence windows are low-coverage bounded objects. Press/HUMAN_INFORMATION is kept outside the pregame lane unless a publication/availability timestamp can be certified. Mechanism cohorting is retrospective and descriptive only.

### Reconstruction check

PA count top/bottom=6/4; pitch count top/bottom=19/14; first-inning score reconciliation=2+0=2. Exact event arrays and raw source hash are persisted. No missing historical window is converted to zero.

## GAME BLOCK 823270 — San Francisco Giants @ San Diego Padres

**Identity.** GAME_PK 823270; venue Petco Park; scheduled 2026-08-02T20:10:00Z; first pitch observed 2026-08-02T20:12:22.079Z; starters Landen Roupp (away) / Kyle Hart (home). Source: official MLB GUMBO `https://statsapi.mlb.com/api/v1.1/game/823270/feed/live`; capture SHA-256 `85a8af282816d08f0846f7914c22b0cbd42e8805645fdf0dd368fdcf6366404c`.

**First-inning outcome.** Top 0, bottom 0, total 0; descriptive outcome **NRFI**. Top path `NO_RUN_PATH`; bottom path `NO_RUN_PATH`. This is a historical observation, not a forecast or betting probability.

### Top 1st — Half-Inning Card

BF=3; pitches=11; runs=0; hits=0; singles=0; XBH=0; BB=0; HBP=0; K=0; HR=0; B4/B5/B6 exposed=False/False/False; leadoff reach=False; two-out extension=False; 3-up-3-down=True. Exact PA-level sequence follows.

- PA 1 — Luis Arraez vs Kyle Hart: field_out; outs 0→1; runs=0; pitches=6. Sequence: 1:FF Ball 93.2 mph; 2:SI Foul 93.9 mph; 3:FF Foul 94.1 mph; 4:ST Ball 84.4 mph; 5:SI Ball 95.6 mph; 6:SI In play, out(s) 93.8 mph. Description: Luis Arraez grounds out, first baseman Ty France to pitcher Kyle Hart.
- PA 2 — Bryce Eldridge vs Kyle Hart: field_out; outs 1→2; runs=0; pitches=3. Sequence: 1:SL Called Strike 88.9 mph; 2:SI Ball 93.2 mph; 3:SI In play, out(s) 93.6 mph. Description: Bryce Eldridge grounds out, third baseman Sung-Mun Song to first baseman Ty France.
- PA 3 — Heliot Ramos vs Kyle Hart: field_out; outs 2→3; runs=0; pitches=2. Sequence: 1:ST Ball 83.5 mph; 2:SI In play, out(s) 94.6 mph. Description: Heliot Ramos flies out to right fielder Gavin Sheets.

### Bottom 1st — Half-Inning Card

BF=4; pitches=13; runs=0; hits=1; singles=1; XBH=0; BB=0; HBP=0; K=1; HR=0; B4/B5/B6 exposed=True/False/False; leadoff reach=True; two-out extension=True; 3-up-3-down=False. Exact PA-level sequence follows.

- PA 1 — Luis Rengifo vs Landen Roupp: single; outs 0→0; runs=0; pitches=3. Sequence: 1:SI Called Strike 94.6 mph; 2:CU Ball 76.9 mph; 3:SI In play, no out 94.1 mph. Description: Luis Rengifo singles on a ground ball to right fielder Jung Hoo Lee.
- PA 2 — Jake Cronenworth vs Landen Roupp: strikeout; outs 0→1; runs=0; pitches=5. Sequence: 1:SI Called Strike 93.7 mph; 2:CH Ball 86.1 mph; 3:CH Ball 85.7 mph; 4:SI Called Strike 92.8 mph; 5:FF Swinging Strike 93.2 mph. Description: Jake Cronenworth strikes out swinging.
- PA 3 — Manny Machado vs Landen Roupp: field_out; outs 1→2; runs=0; pitches=2. Sequence: 1:CU Ball 76.8 mph; 2:SI In play, out(s) 93.5 mph. Description: Manny Machado lines out to right fielder Jung Hoo Lee.
- PA 4 — Ty France vs Landen Roupp: caught_stealing_2b; outs 2→3; runs=0; pitches=3. Sequence: 1:SI Called Strike 94.1 mph; 2:FF Swinging Strike 93.4 mph; 3:SI Ball 93.7 mph. Description: Luis Rengifo caught stealing 2nd base, catcher Drew Cavanaugh to second baseman Luis Arraez.

### Pitch-level process and starter context

First-inning process objects: `{"606996":{"pitch_count_first_inning":11,"pitch_mix_first_inning":{"FF":2,"SI":6,"ST":2,"SL":1},"avg_release_speed_first_inning":91.71,"whiffs":0,"swings":5,"contacts":5},"694738":{"pitch_count_first_inning":13,"pitch_mix_first_inning":{"SI":7,"CU":2,"CH":2,"FF":2},"avg_release_speed_first_inning":89.89,"whiffs":2,"swings":4,"contacts":2}}`. These are calculated from the pitch events retained in the official first-inning GUMBO. Full-start boxscore context is retained separately in `STARTER_CONTEXT`; prior-start L3/L5/L10/L15/L20, season and career first-inning sequences are explicitly `BOUNDED_GAP` in this repair rather than fabricated. The gap does not alter the observed first-inning reconstruction.

### Feature and reliability interpretation

The game contributes all nine registry families at the GAME level: RESULTS, SEQUENCE, EXPOSURE, OUT_CREATION, TRAFFIC, DAMAGE, PITCHER_PROCESS, TOP_ORDER and CONTEXT. The observed current-game families carry high contextual support from GUMBO; historical sequence windows are low-coverage bounded objects. Press/HUMAN_INFORMATION is kept outside the pregame lane unless a publication/availability timestamp can be certified. Mechanism cohorting is retrospective and descriptive only.

### Reconstruction check

PA count top/bottom=3/4; pitch count top/bottom=11/13; first-inning score reconciliation=0+0=0. Exact event arrays and raw source hash are persisted. No missing historical window is converted to zero.

## GAME BLOCK 823107 — Minnesota Twins @ Seattle Mariners

**Identity.** GAME_PK 823107; venue T-Mobile Park; scheduled 2026-08-02T20:10:00Z; first pitch observed 2026-08-02T20:12:35.552Z; starters Taj Bradley (away) / George Kirby (home). Source: official MLB GUMBO `https://statsapi.mlb.com/api/v1.1/game/823107/feed/live`; capture SHA-256 `b151904d3750a850bcdd949999e02977cdf8213bf43e83a902a3476d73795f13`.

**First-inning outcome.** Top 0, bottom 2, total 2; descriptive outcome **YRFI**. Top path `NO_RUN_PATH`; bottom path `XBH_DAMAGE`. This is a historical observation, not a forecast or betting probability.

### Top 1st — Half-Inning Card

BF=4; pitches=15; runs=0; hits=1; singles=1; XBH=0; BB=0; HBP=0; K=1; HR=0; B4/B5/B6 exposed=True/False/False; leadoff reach=False; two-out extension=False; 3-up-3-down=False. Exact PA-level sequence follows.

- PA 1 — Trevor Larnach vs George Kirby: strikeout; outs 0→1; runs=0; pitches=4. Sequence: 1:FF Swinging Strike 97.0 mph; 2:ST Called Strike 88.9 mph; 3:FS Ball 88.8 mph; 4:FS Called Strike 88.8 mph. Description: Trevor Larnach called out on strikes.
- PA 2 — Ryan Jeffers vs George Kirby: single; outs 1→1; runs=0; pitches=5. Sequence: 1:FF Foul 97.3 mph; 2:SI Foul 97.8 mph; 3:ST Ball 90.8 mph; 4:SI Ball 99.3 mph; 5:SI In play, no out 98.3 mph. Description: Ryan Jeffers singles on a sharp line drive to right fielder Victor Robles.
- PA 3 — Josh Bell vs George Kirby: field_out; outs 1→2; runs=0; pitches=1. Sequence: 1:KC In play, out(s) 84.6 mph. Description: Josh Bell flies out to left fielder Randy Arozarena.
- PA 4 — Kody Clemens vs George Kirby: field_out; outs 2→3; runs=0; pitches=5. Sequence: 1:FF Called Strike 97.9 mph; 2:FF Ball 97.9 mph; 3:FF Ball 97.6 mph; 4:FF Ball 96.5 mph; 5:SI In play, out(s) 97.2 mph. Description: Kody Clemens flies out to left fielder Randy Arozarena.

### Bottom 1st — Half-Inning Card

BF=6; pitches=23; runs=2; hits=2; singles=1; XBH=1; BB=1; HBP=0; K=1; HR=0; B4/B5/B6 exposed=True/True/True; leadoff reach=True; two-out extension=True; 3-up-3-down=False. Exact PA-level sequence follows.

- PA 1 — Cole Young vs Taj Bradley: single; outs 0→0; runs=0; pitches=1. Sequence: 1:FF In play, no out 95.8 mph. Description: Cole Young singles on a line drive to center fielder Luke Keaschall.
- PA 2 — Randy Arozarena vs Taj Bradley: walk; outs 0→0; runs=0; pitches=4. Sequence: 1:FF Ball 96.8 mph; 2:FS Ball 91.5 mph; 3:FF Ball 96.8 mph; 4:FF Ball 96.5 mph. Description: Randy Arozarena walks. Cole Young to 2nd.
- PA 3 — Dominic Canzone vs Taj Bradley: field_out; outs 0→1; runs=0; pitches=8. Sequence: 1:FS Swinging Strike 91.8 mph; 2:FC Ball 93.3 mph; 3:FC Foul 92.9 mph; 4:FS Ball In Dirt 93.3 mph; 5:FF Foul 98.4 mph; 6:FS Foul 93.5 mph; 7:CU Foul 84.3 mph; 8:FC In play, out(s) 90.2 mph. Description: Dominic Canzone flies out to left fielder Trevor Larnach.
- PA 4 — Julio Rodríguez vs Taj Bradley: strikeout; outs 1→2; runs=0; pitches=3. Sequence: 1:FC Foul 90.1 mph; 2:FF Foul 99.8 mph; 3:FF Swinging Strike 100.4 mph. Description: Julio Rodríguez strikes out swinging.
- PA 5 — Josh Naylor vs Taj Bradley: double; outs 2→2; runs=2; pitches=3. Sequence: 1:FS Ball In Dirt 94.0 mph; 2:FF Ball 99.5 mph; 3:FF In play, run(s) 98.9 mph. Description: Josh Naylor doubles (16) on a line drive to left fielder Trevor Larnach. Cole Young scores. Randy Arozarena scores.
- PA 6 — Cal Raleigh vs Taj Bradley: field_out; outs 2→3; runs=0; pitches=4. Sequence: 1:FF Swinging Strike 98.3 mph; 2:FF Called Strike 98.8 mph; 3:FF Ball 98.4 mph; 4:FC In play, out(s) 91.8 mph. Description: Cal Raleigh flies out to center fielder Luke Keaschall.

### Pitch-level process and starter context

First-inning process objects: `{"669923":{"pitch_count_first_inning":15,"pitch_mix_first_inning":{"FF":6,"ST":2,"FS":2,"SI":4,"KC":1},"avg_release_speed_first_inning":94.58,"whiffs":1,"swings":6,"contacts":5},"671737":{"pitch_count_first_inning":23,"pitch_mix_first_inning":{"FF":12,"FS":5,"FC":5,"CU":1},"avg_release_speed_first_inning":95.0,"whiffs":3,"swings":13,"contacts":10}}`. These are calculated from the pitch events retained in the official first-inning GUMBO. Full-start boxscore context is retained separately in `STARTER_CONTEXT`; prior-start L3/L5/L10/L15/L20, season and career first-inning sequences are explicitly `BOUNDED_GAP` in this repair rather than fabricated. The gap does not alter the observed first-inning reconstruction.

### Feature and reliability interpretation

The game contributes all nine registry families at the GAME level: RESULTS, SEQUENCE, EXPOSURE, OUT_CREATION, TRAFFIC, DAMAGE, PITCHER_PROCESS, TOP_ORDER and CONTEXT. The observed current-game families carry high contextual support from GUMBO; historical sequence windows are low-coverage bounded objects. Press/HUMAN_INFORMATION is kept outside the pregame lane unless a publication/availability timestamp can be certified. Mechanism cohorting is retrospective and descriptive only.

### Reconstruction check

PA count top/bottom=4/6; pitch count top/bottom=15/23; first-inning score reconciliation=0+2=2. Exact event arrays and raw source hash are persisted. No missing historical window is converted to zero.

## GAME BLOCK 823919 — Boston Red Sox @ Los Angeles Dodgers

**Identity.** GAME_PK 823919; venue UNIQLO Field at Dodger Stadium; scheduled 2026-08-02T23:20:00Z; first pitch observed 2026-08-02T23:20:53.970Z; starters Jake Bennett (away) / Emmet Sheehan (home). Source: official MLB GUMBO `https://statsapi.mlb.com/api/v1.1/game/823919/feed/live`; capture SHA-256 `649053afd44c0230d1cd095dabe4206f55f03e55c158b818210c5f90c343991c`.

**First-inning outcome.** Top 2, bottom 0, total 2; descriptive outcome **YRFI**. Top path `FREE_TRAFFIC_CHAIN`; bottom path `NO_RUN_PATH`. This is a historical observation, not a forecast or betting probability.

### Top 1st — Half-Inning Card

BF=7; pitches=30; runs=2; hits=3; singles=3; XBH=0; BB=1; HBP=0; K=1; HR=0; B4/B5/B6 exposed=True/True/True; leadoff reach=True; two-out extension=True; 3-up-3-down=False. Exact PA-level sequence follows.

- PA 1 — Nick Sogard vs Emmet Sheehan: walk; outs 0→0; runs=0; pitches=7. Sequence: 1:FF Foul 94.4 mph; 2:FF Ball 94.4 mph; 3:CU Ball 79.8 mph; 4:FF Ball 93.1 mph; 5:SL Swinging Strike 85.9 mph; 6:FF Foul 95.4 mph; 7:CU Ball 78.9 mph. Description: Nick Sogard walks.
- PA 2 — Ceddanne Rafaela vs Emmet Sheehan: force_out; outs 0→1; runs=0; pitches=5. Sequence: 1:SL Called Strike 85.4 mph; 2:SL Ball 84.7 mph; 3:FF Foul Tip 94.6 mph; 4:FF Foul 91.7 mph; 5:CU In play, out(s) 79.7 mph. Description: Ceddanne Rafaela grounds into a force out, shortstop Mookie Betts to second baseman Tommy Edman. Nick Sogard out at 2nd. Ceddanne Rafaela to 1st.
- PA 3 — Wilyer Abreu vs Emmet Sheehan: single; outs 1→1; runs=0; pitches=4. Sequence: 1:FF Ball 92.4 mph; 2:CU Called Strike 77.4 mph; 3:FF Swinging Strike 93.3 mph; 4:CH In play, no out 85.3 mph. Description: Wilyer Abreu singles on a sharp ground ball to center fielder Andy Pages. Ceddanne Rafaela to 2nd.
- PA 4 — Willson Contreras vs Emmet Sheehan: field_out; outs 1→2; runs=0; pitches=1. Sequence: 1:SL In play, out(s) 84.4 mph. Description: Willson Contreras lines out to left fielder Teoscar Hernández.
- PA 5 — Masataka Yoshida vs Emmet Sheehan: single; outs 2→2; runs=1; pitches=5. Sequence: 1:CU Ball 78.2 mph; 2:CH Swinging Strike 84.3 mph; 3:FF Ball 93.8 mph; 4:FF Called Strike 93.9 mph; 5:SL In play, run(s) 85.8 mph. Description: Masataka Yoshida singles on a ground ball to left fielder Teoscar Hernández. Ceddanne Rafaela scores. Wilyer Abreu to 2nd.
- PA 6 — Caleb Durbin vs Emmet Sheehan: single; outs 2→2; runs=1; pitches=2. Sequence: 1:SL Called Strike 85.6 mph; 2:FF In play, run(s) 93.0 mph. Description: Caleb Durbin singles on a line drive to center fielder Andy Pages. Wilyer Abreu scores. Masataka Yoshida to 3rd.
- PA 7 — Andruw Monasterio vs Emmet Sheehan: strikeout; outs 2→3; runs=0; pitches=6. Sequence: 1:CU Ball 78.1 mph; 2:SL Ball 85.2 mph; 3:SL Called Strike 84.9 mph; 4:FF Swinging Strike 94.0 mph; 5:SL Ball 86.9 mph; 6:SL Swinging Strike 86.7 mph. Description: Andruw Monasterio strikes out swinging.

### Bottom 1st — Half-Inning Card

BF=4; pitches=16; runs=0; hits=1; singles=1; XBH=0; BB=0; HBP=0; K=2; HR=0; B4/B5/B6 exposed=True/False/False; leadoff reach=True; two-out extension=False; 3-up-3-down=False. Exact PA-level sequence follows.

- PA 1 — Shohei Ohtani vs Jake Bennett: single; outs 0→0; runs=0; pitches=1. Sequence: 1:FF In play, no out 93.1 mph. Description: Shohei Ohtani singles on a sharp line drive to right fielder Wilyer Abreu.
- PA 2 — Andy Pages vs Jake Bennett: strikeout; outs 0→1; runs=0; pitches=5. Sequence: 1:SI Ball 91.6 mph; 2:CH Called Strike 82.1 mph; 3:FF Ball 91.7 mph; 4:CH Foul 82.1 mph; 5:CH Swinging Strike 82.4 mph. Description: Andy Pages strikes out swinging.
- PA 3 — Tommy Edman vs Jake Bennett: strikeout; outs 1→2; runs=0; pitches=5. Sequence: 1:CH Called Strike 80.4 mph; 2:FF Foul 92.4 mph; 3:CH Ball 81.6 mph; 4:CH Foul 83.8 mph; 5:CU Swinging Strike (Blocked) 77.9 mph. Description: Tommy Edman strikes out swinging.
- PA 4 — Freddie Freeman vs Jake Bennett: field_out; outs 2→3; runs=0; pitches=5. Sequence: 1:FC Ball In Dirt 84.2 mph; 2:SI Foul 93.0 mph; 3:FF Foul 93.1 mph; 4:ST Ball 81.4 mph; 5:FC In play, out(s) 84.4 mph. Description: Freddie Freeman grounds out to first baseman Willson Contreras.

### Pitch-level process and starter context

First-inning process objects: `{"686218":{"pitch_count_first_inning":30,"pitch_mix_first_inning":{"FF":12,"CU":6,"SL":10,"CH":2},"avg_release_speed_first_inning":87.37,"whiffs":5,"swings":14,"contacts":9},"687562":{"pitch_count_first_inning":16,"pitch_mix_first_inning":{"FF":4,"SI":2,"CH":6,"CU":1,"FC":2,"ST":1},"avg_release_speed_first_inning":85.95,"whiffs":2,"swings":9,"contacts":7}}`. These are calculated from the pitch events retained in the official first-inning GUMBO. Full-start boxscore context is retained separately in `STARTER_CONTEXT`; prior-start L3/L5/L10/L15/L20, season and career first-inning sequences are explicitly `BOUNDED_GAP` in this repair rather than fabricated. The gap does not alter the observed first-inning reconstruction.

### Feature and reliability interpretation

The game contributes all nine registry families at the GAME level: RESULTS, SEQUENCE, EXPOSURE, OUT_CREATION, TRAFFIC, DAMAGE, PITCHER_PROCESS, TOP_ORDER and CONTEXT. The observed current-game families carry high contextual support from GUMBO; historical sequence windows are low-coverage bounded objects. Press/HUMAN_INFORMATION is kept outside the pregame lane unless a publication/availability timestamp can be certified. Mechanism cohorting is retrospective and descriptive only.

### Reconstruction check

PA count top/bottom=7/4; pitch count top/bottom=30/16; first-inning score reconciliation=2+0=2. Exact event arrays and raw source hash are persisted. No missing historical window is converted to zero.


## F3 — FEATURE FACTORY


For each GAME_PK the structured store receives all nine mandatory feature families. RESULTS/EXPOSURE/OUT_CREATION/TRAFFIC/DAMAGE/PITCHER_PROCESS/TOP_ORDER/CONTEXT are derived from the captured game and carry source lineage. SEQUENCE contains the required L3/L5/L10/L15/L20/SEASON/CAREER keys, but where the repair artifact does not contain prior-start first-inning history the value is explicitly `BOUNDED_GAP` with LOW_COVERAGE, N=0 and a written reason. Presence of the key therefore does not masquerade as availability of the statistic.


## F4 — HISTORICAL PRESS / RELIABILITY / MECHANISMS / COHORTS


Exact first-inning event sequences are preserved as raw arrays before mechanism classification. Primary paths are derived descriptors and never replace the raw sequence. Same-day mechanism cohorts are created only as retrospective descriptive comparisons and are explicitly non-causal. GUMBO does not contain timestamp-certified pregame press; therefore no postgame narrative is promoted to PREGAME_EVIDENCE. PRESS_HUMAN_INFORMATION remains an explicit bounded gap unless external publication timing is independently recovered.


## F5 — QUERYABLE INTELLIGENCE


The amendment creates one daily Evidence Packet after all 15 structured games are loaded. Its queryable dimensions include identity, pitcher/first-inning history, top-order composition, pitch process, mechanism, context, coverage/reliability and cohorts. FUTURE_GAME_COUNT=0 and POSTGAME_LEAK_COUNT=0 are enforced. No pick, stake, EV, odds or invented NRFI probability is emitted.


## DAILY_CLOSURE


Closure is not inferred from this prose. Supabase must independently report all 15 games F1/F2/F3/F4 semantic-ready, all games PROCESSED, F1–F5 receipts COMPLETE, Evidence Packet present, report contract verified, Drive append/readback verified and final audit PASS. Until those physical gates pass, this amendment remains IN_PROGRESS.


## GAME_BLOCKS


GAME_BLOCK_COUNT=15. The detailed blocks above are the human-readable projection of the structured semantic store; Supabase remains the process/audit source of truth and the official GUMBO hashes remain the source-lineage anchors.

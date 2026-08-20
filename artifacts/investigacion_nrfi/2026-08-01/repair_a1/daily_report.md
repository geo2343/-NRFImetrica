# AMENDMENT SEMÁNTICO — @investigacionNRFI — 2026-08-01

RUN_ID: `INVNRFI-20260801-AMEND-A1`  

PARENT_RUN_ID: `INVNRFI-20260801-f709b44c`  

RUN_TYPE: `AMENDMENT`  

SYSTEM_VERSION: `INVESTIGACION-NRFI-HISTORICAL-V1.0`  

KERNEL_VERSION: `INVESTIGACION-NRFI-KERNEL-0.2-SEMANTIC-COMPLETENESS`


## EXECUTION_SUMMARY


Official finalized universe: 15 games. Official GUMBO captured for 15/15 games in GitHub commit `a63b60ac9caec558a76fab5dd826172c0b15120b`. The original shallow certification is withdrawn. This amendment reconstructs the first inning from play/pitch objects and persists semantic objects required by F1–F5. Historical descriptive outcomes in the captured universe: NRFI=6; YRFI=9; total first-inning runs=14; 0-run games=6; 1-run=4; 2-run=5; 3+-run=0. These are retrospective counts only.


## F1 — CAPTURA FORENSE


Every GAME_PK is tied to the official MLB GUMBO endpoint and raw SHA-256. The amendment stores scheduled/actual first pitch, venue, starters, lineup/catcher when recovered from the official boxscore, source lineage and a postgame evidence lane. Any lineup/catcher parsing limitation is preserved as an explicit bounded gap rather than silently omitted.


## F2 — RECONSTRUCCIÓN PROFUNDA


The following 15 GAME BLOCKS contain both half innings, every first-inning plate appearance retained in GUMBO, pitch sequences, run mechanism, exposure and starter first-inning process. This is the material reconstruction that the withdrawn original lacked.

## GAME BLOCK 822781 — St. Louis Cardinals @ Toronto Blue Jays

**Identity.** GAME_PK 822781; venue Rogers Centre; scheduled 2026-08-01T19:07:00Z; first pitch observed 2026-08-01T19:07:56.592Z; starters Quinn Mathews (away) / Kevin Gausman (home). Source: official MLB GUMBO `https://statsapi.mlb.com/api/v1.1/game/822781/feed/live`; capture SHA-256 `455dbaedf3b9cc71918ef756aebbe0ad7fe096409f8e35ecb0ea770077810d2a`.

**First-inning outcome.** Top 0, bottom 0, total 0; descriptive outcome **NRFI**. Top path `NO_RUN_PATH`; bottom path `NO_RUN_PATH`. This is a historical observation, not a forecast or betting probability.

### Top 1st — Half-Inning Card

BF=4; pitches=15; runs=0; hits=1; singles=1; XBH=0; BB=0; HBP=0; K=1; HR=0; B4/B5/B6 exposed=True/False/False; leadoff reach=False; two-out extension=True; 3-up-3-down=False. Exact PA-level sequence follows.

- PA 1 — JJ Wetherholt vs Kevin Gausman: field_out; outs 0→1; runs=0; pitches=6. Sequence: 1:FF Called Strike 93.0 mph; 2:FF Ball 93.9 mph; 3:FF Ball 94.6 mph; 4:FS Called Strike 84.9 mph; 5:FS Foul 84.8 mph; 6:FF In play, out(s) 94.7 mph. Description: JJ Wetherholt grounds out, shortstop Ernie Clement to first baseman Vladimir Guerrero Jr.
- PA 2 — Jordan Walker vs Kevin Gausman: strikeout; outs 1→2; runs=0; pitches=4. Sequence: 1:FF Foul 94.7 mph; 2:FS Swinging Strike 85.0 mph; 3:FS Ball 86.4 mph; 4:FF Swinging Strike 95.8 mph. Description: Jordan Walker strikes out swinging.
- PA 3 — Alec Burleson vs Kevin Gausman: single; outs 2→2; runs=0; pitches=3. Sequence: 1:FS Swinging Strike 84.3 mph; 2:FF Ball 94.7 mph; 3:FS In play, no out 85.6 mph. Description: Alec Burleson singles on a fly ball to left fielder Davis Schneider.
- PA 4 — Iván Herrera vs Kevin Gausman: force_out; outs 2→3; runs=0; pitches=2. Sequence: 1:FF Called Strike 93.9 mph; 2:FF In play, out(s) 93.9 mph. Description: Iván Herrera grounds into a force out, third baseman Kazuma Okamoto to second baseman Luis Urías. Alec Burleson out at 2nd.

### Bottom 1st — Half-Inning Card

BF=4; pitches=20; runs=0; hits=1; singles=1; XBH=0; BB=0; HBP=0; K=1; HR=0; B4/B5/B6 exposed=True/False/False; leadoff reach=True; two-out extension=False; 3-up-3-down=False. Exact PA-level sequence follows.

- PA 1 — Luis Urías vs Quinn Mathews: single; outs 0→0; runs=0; pitches=5. Sequence: 1:FF Called Strike 94.6 mph; 2:SL Called Strike 86.6 mph; 3:SL Ball 87.2 mph; 4:FF Ball 94.8 mph; 5:CH In play, no out 83.3 mph. Description: Luis Urías singles on a fly ball to left fielder Lars Nootbaar.
- PA 2 — Vladimir Guerrero Jr. vs Quinn Mathews: force_out; outs 0→1; runs=0; pitches=4. Sequence: 1:CU Foul 76.2 mph; 2:FF Foul 95.1 mph; 3:SL Ball 87.4 mph; 4:CH In play, out(s) 83.0 mph. Description: Vladimir Guerrero Jr. grounds into a force out, third baseman Blaze Jordan to second baseman JJ Wetherholt. Luis Urías out at 2nd. Vladimir Guerrero Jr. to 1st.
- PA 3 — Kazuma Okamoto vs Quinn Mathews: strikeout; outs 1→2; runs=0; pitches=4. Sequence: 1:SL Called Strike 87.7 mph; 2:CH Swinging Strike 83.7 mph; 3:FF Ball 94.5 mph; 4:FF Swinging Strike 96.0 mph. Description: Kazuma Okamoto strikes out swinging.
- PA 4 — George Springer vs Quinn Mathews: field_out; outs 2→3; runs=0; pitches=7. Sequence: 1:CH Ball 85.0 mph; 2:FF Called Strike 94.0 mph; 3:CH Swinging Strike 85.1 mph; 4:CU Foul 79.2 mph; 5:FF Ball 95.6 mph; 6:SL Ball In Dirt 87.3 mph; 7:FF In play, out(s) 94.4 mph. Description: George Springer grounds out, third baseman Blaze Jordan to first baseman Alec Burleson.

### Pitch-level process and starter context

First-inning process objects: `{"592332":{"pitch_count_first_inning":15,"pitch_mix_first_inning":{"FF":9,"FS":6},"avg_release_speed_first_inning":90.68,"whiffs":3,"swings":8,"contacts":5},"687273":{"pitch_count_first_inning":20,"pitch_mix_first_inning":{"FF":8,"SL":5,"CH":5,"CU":2},"avg_release_speed_first_inning":88.53,"whiffs":3,"swings":9,"contacts":6}}`. These are calculated from the pitch events retained in the official first-inning GUMBO. Full-start boxscore context is retained separately in `STARTER_CONTEXT`; prior-start L3/L5/L10/L15/L20, season and career first-inning sequences are explicitly `BOUNDED_GAP` in this repair rather than fabricated. The gap does not alter the observed first-inning reconstruction.

### Feature and reliability interpretation

The game contributes all nine registry families at the GAME level: RESULTS, SEQUENCE, EXPOSURE, OUT_CREATION, TRAFFIC, DAMAGE, PITCHER_PROCESS, TOP_ORDER and CONTEXT. The observed current-game families carry high contextual support from GUMBO; historical sequence windows are low-coverage bounded objects. Press/HUMAN_INFORMATION is kept outside the pregame lane unless a publication/availability timestamp can be certified. Mechanism cohorting is retrospective and descriptive only.

### Reconstruction check

PA count top/bottom=4/4; pitch count top/bottom=15/20; first-inning score reconciliation=0+0=0. Exact event arrays and raw source hash are persisted. No missing historical window is converted to zero.

## GAME BLOCK 823109 — Minnesota Twins @ Seattle Mariners

**Identity.** GAME_PK 823109; venue T-Mobile Park; scheduled 2026-08-01T20:10:00Z; first pitch observed 2026-08-01T20:12:12.618Z; starters Connor Prielipp (away) / Logan Gilbert (home). Source: official MLB GUMBO `https://statsapi.mlb.com/api/v1.1/game/823109/feed/live`; capture SHA-256 `beca09305bcf77c4dc9d0202eec324901170afe8db2bcf0235ce4fc04e760139`.

**First-inning outcome.** Top 0, bottom 2, total 2; descriptive outcome **YRFI**. Top path `NO_RUN_PATH`; bottom path `XBH_DAMAGE`. This is a historical observation, not a forecast or betting probability.

### Top 1st — Half-Inning Card

BF=3; pitches=16; runs=0; hits=0; singles=0; XBH=0; BB=0; HBP=0; K=1; HR=0; B4/B5/B6 exposed=False/False/False; leadoff reach=False; two-out extension=False; 3-up-3-down=True. Exact PA-level sequence follows.

- PA 1 — Trevor Larnach vs Logan Gilbert: strikeout; outs 0→1; runs=0; pitches=4. Sequence: 1:SL Ball 87.8 mph; 2:FF Swinging Strike 97.9 mph; 3:SL Swinging Strike 89.1 mph; 4:FS Swinging Strike 85.6 mph. Description: Trevor Larnach strikes out swinging.
- PA 2 — Ryan Jeffers vs Logan Gilbert: field_out; outs 1→2; runs=0; pitches=4. Sequence: 1:FF Called Strike 98.6 mph; 2:FF Foul 99.2 mph; 3:SL Ball 89.1 mph; 4:FS In play, out(s) 85.1 mph. Description: Ryan Jeffers flies out to left fielder Randy Arozarena.
- PA 3 — Kody Clemens vs Logan Gilbert: field_out; outs 2→3; runs=0; pitches=8. Sequence: 1:SL Swinging Strike 87.8 mph; 2:SL Swinging Strike 88.4 mph; 3:SL Ball 89.7 mph; 4:FS Ball 85.7 mph; 5:FS Foul 85.8 mph; 6:FF Foul 98.9 mph; 7:SL Ball 88.4 mph; 8:SL In play, out(s) 88.8 mph. Description: Kody Clemens grounds out, first baseman Josh Naylor to pitcher Logan Gilbert.

### Bottom 1st — Half-Inning Card

BF=8; pitches=35; runs=2; hits=2; singles=1; XBH=1; BB=3; HBP=0; K=3; HR=0; B4/B5/B6 exposed=True/True/True; leadoff reach=True; two-out extension=True; 3-up-3-down=False. Exact PA-level sequence follows.

- PA 1 — Cole Young vs Connor Prielipp: double; outs 0→0; runs=0; pitches=1. Sequence: 1:FF In play, no out 95.4 mph. Description: Cole Young doubles (15) on a sharp line drive to right fielder Austin Martin.
- PA 2 — Randy Arozarena vs Connor Prielipp: walk; outs 0→0; runs=0; pitches=4. Sequence: 1:FF Ball 95.2 mph; 2:FF Ball 94.5 mph; 3:SL Ball 88.7 mph; 4:FF Ball 94.8 mph. Description: Randy Arozarena walks.
- PA 3 — Dominic Canzone vs Connor Prielipp: walk; outs 0→0; runs=0; pitches=6. Sequence: 1:SL Called Strike 88.8 mph; 2:SL Ball 88.8 mph; 3:CU Ball 83.2 mph; 4:FF Ball 96.0 mph; 5:SL Called Strike 88.2 mph; 6:SL Ball 88.8 mph. Description: Dominic Canzone walks. Cole Young to 3rd. Randy Arozarena to 2nd.
- PA 4 — Julio Rodríguez vs Connor Prielipp: single; outs 0→0; runs=1; pitches=1. Sequence: 1:SL In play, run(s) 90.7 mph. Description: Julio Rodríguez singles on a ground ball to shortstop Ryan Kreidler. Cole Young scores. Randy Arozarena to 3rd. Dominic Canzone to 2nd.
- PA 5 — Cal Raleigh vs Connor Prielipp: strikeout; outs 0→1; runs=0; pitches=4. Sequence: 1:SI Called Strike 96.8 mph; 2:FF Foul 97.7 mph; 3:FF Foul 96.8 mph; 4:SL Swinging Strike 89.2 mph. Description: Cal Raleigh strikes out swinging.
- PA 6 — Josh Naylor vs Connor Prielipp: strikeout; outs 1→2; runs=0; pitches=4. Sequence: 1:SI Called Strike 96.8 mph; 2:SI Ball 96.8 mph; 3:SL Foul 88.8 mph; 4:CU Swinging Strike 84.1 mph. Description: Josh Naylor strikes out swinging.
- PA 7 — Mitch Garver vs Connor Prielipp: walk; outs 2→2; runs=1; pitches=11. Sequence: 1:SI Foul 95.3 mph; 2:SI Swinging Strike 97.4 mph; 3:FF Ball 97.7 mph; 4:SL Foul 89.9 mph; 5:FF Foul 97.3 mph; 6:CU Foul 86.5 mph; 7:CU Ball 84.7 mph; 8:FF Foul 97.0 mph; 9:FF Foul 98.4 mph; 10:SL Ball 91.1 mph; 11:SL Ball 91.6 mph. Description: Mitch Garver walks. Randy Arozarena scores. Dominic Canzone to 3rd. Julio Rodríguez to 2nd.
- PA 8 — Weston Wilson vs Connor Prielipp: strikeout; outs 2→3; runs=0; pitches=4. Sequence: 1:SL Swinging Strike 91.5 mph; 2:CH Swinging Strike 88.4 mph; 3:SL Foul 90.8 mph; 4:CH Swinging Strike 88.3 mph. Description: Weston Wilson strikes out swinging.

### Pitch-level process and starter context

First-inning process objects: `{"669302":{"pitch_count_first_inning":16,"pitch_mix_first_inning":{"SL":8,"FF":4,"FS":4},"avg_release_speed_first_inning":90.37,"whiffs":5,"swings":10,"contacts":5},"687570":{"pitch_count_first_inning":35,"pitch_mix_first_inning":{"FF":11,"SL":13,"CU":4,"SI":5,"CH":2},"avg_release_speed_first_inning":92.17,"whiffs":6,"swings":18,"contacts":12}}`. These are calculated from the pitch events retained in the official first-inning GUMBO. Full-start boxscore context is retained separately in `STARTER_CONTEXT`; prior-start L3/L5/L10/L15/L20, season and career first-inning sequences are explicitly `BOUNDED_GAP` in this repair rather than fabricated. The gap does not alter the observed first-inning reconstruction.

### Feature and reliability interpretation

The game contributes all nine registry families at the GAME level: RESULTS, SEQUENCE, EXPOSURE, OUT_CREATION, TRAFFIC, DAMAGE, PITCHER_PROCESS, TOP_ORDER and CONTEXT. The observed current-game families carry high contextual support from GUMBO; historical sequence windows are low-coverage bounded objects. Press/HUMAN_INFORMATION is kept outside the pregame lane unless a publication/availability timestamp can be certified. Mechanism cohorting is retrospective and descriptive only.

### Reconstruction check

PA count top/bottom=3/8; pitch count top/bottom=16/35; first-inning score reconciliation=0+2=2. Exact event arrays and raw source hash are persisted. No missing historical window is converted to zero.

## GAME BLOCK 822944 — Chicago White Sox @ Tampa Bay Rays

**Identity.** GAME_PK 822944; venue Tropicana Field; scheduled 2026-08-01T20:10:00Z; first pitch observed 2026-08-01T20:10:28.072Z; starters Jordan Hicks (away) / Drew Rasmussen (home). Source: official MLB GUMBO `https://statsapi.mlb.com/api/v1.1/game/822944/feed/live`; capture SHA-256 `58ae7d9fc03d29ac97247cc854db64c24e52141aa7f4abc4f5756bca0b19c190`.

**First-inning outcome.** Top 0, bottom 0, total 0; descriptive outcome **NRFI**. Top path `NO_RUN_PATH`; bottom path `NO_RUN_PATH`. This is a historical observation, not a forecast or betting probability.

### Top 1st — Half-Inning Card

BF=3; pitches=14; runs=0; hits=0; singles=0; XBH=0; BB=1; HBP=0; K=2; HR=0; B4/B5/B6 exposed=False/False/False; leadoff reach=True; two-out extension=False; 3-up-3-down=False. Exact PA-level sequence follows.

- PA 1 — Sam Antonacci vs Drew Rasmussen: walk; outs 0→0; runs=0; pitches=5. Sequence: 1:FF Ball 94.8 mph; 2:FF Called Strike 94.1 mph; 3:FC Ball 88.9 mph; 4:SI Ball 94.6 mph; 5:FF Ball 94.6 mph. Description: Sam Antonacci walks.
- PA 2 — Munetaka Murakami vs Drew Rasmussen: strikeout; outs 0→2; runs=0; pitches=5. Sequence: 1:FF Ball 95.8 mph; 2:FF Called Strike 95.4 mph; 3:SI Called Strike 96.1 mph; 4:FC Ball 89.8 mph; 5:FF Swinging Strike 96.0 mph. Description: Munetaka Murakami strikes out swinging.
- PA 3 — Miguel Vargas vs Drew Rasmussen: strikeout; outs 2→3; runs=0; pitches=4. Sequence: 1:FC Called Strike 90.0 mph; 2:FF Swinging Strike 96.5 mph; 3:FC Ball 90.6 mph; 4:FF Swinging Strike 96.3 mph. Description: Miguel Vargas strikes out swinging.

### Bottom 1st — Half-Inning Card

BF=3; pitches=8; runs=0; hits=0; singles=0; XBH=0; BB=0; HBP=0; K=1; HR=0; B4/B5/B6 exposed=False/False/False; leadoff reach=False; two-out extension=False; 3-up-3-down=True. Exact PA-level sequence follows.

- PA 1 — Yandy Díaz vs Jordan Hicks: field_out; outs 0→1; runs=0; pitches=1. Sequence: 1:SI In play, out(s) 98.3 mph. Description: Yandy Díaz lines out sharply to right fielder Braden Montgomery.
- PA 2 — Chandler Simpson vs Jordan Hicks: field_out; outs 1→2; runs=0; pitches=3. Sequence: 1:SI Called Strike 99.0 mph; 2:FF Foul 96.9 mph; 3:FF In play, out(s) 98.1 mph. Description: Chandler Simpson lines out to left fielder Sam Antonacci.
- PA 3 — Junior Caminero vs Jordan Hicks: strikeout; outs 2→3; runs=0; pitches=4. Sequence: 1:SI Called Strike 99.3 mph; 2:ST Called Strike 84.1 mph; 3:ST Ball 85.4 mph; 4:ST Swinging Strike 85.3 mph. Description: Junior Caminero strikes out swinging.

### Pitch-level process and starter context

First-inning process objects: `{"656876":{"pitch_count_first_inning":14,"pitch_mix_first_inning":{"FF":8,"FC":4,"SI":2},"avg_release_speed_first_inning":93.82,"whiffs":3,"swings":3,"contacts":0},"663855":{"pitch_count_first_inning":8,"pitch_mix_first_inning":{"SI":3,"FF":2,"ST":3},"avg_release_speed_first_inning":93.3,"whiffs":1,"swings":4,"contacts":3}}`. These are calculated from the pitch events retained in the official first-inning GUMBO. Full-start boxscore context is retained separately in `STARTER_CONTEXT`; prior-start L3/L5/L10/L15/L20, season and career first-inning sequences are explicitly `BOUNDED_GAP` in this repair rather than fabricated. The gap does not alter the observed first-inning reconstruction.

### Feature and reliability interpretation

The game contributes all nine registry families at the GAME level: RESULTS, SEQUENCE, EXPOSURE, OUT_CREATION, TRAFFIC, DAMAGE, PITCHER_PROCESS, TOP_ORDER and CONTEXT. The observed current-game families carry high contextual support from GUMBO; historical sequence windows are low-coverage bounded objects. Press/HUMAN_INFORMATION is kept outside the pregame lane unless a publication/availability timestamp can be certified. Mechanism cohorting is retrospective and descriptive only.

### Reconstruction check

PA count top/bottom=3/3; pitch count top/bottom=14/8; first-inning score reconciliation=0+0=0. Exact event arrays and raw source hash are persisted. No missing historical window is converted to zero.

## GAME BLOCK 823594 — Miami Marlins @ New York Mets

**Identity.** GAME_PK 823594; venue Citi Field; scheduled 2026-08-01T20:10:00Z; first pitch observed 2026-08-01T20:30:30.270Z; starters Tyler Phillips (away) / Zac Thornton (home). Source: official MLB GUMBO `https://statsapi.mlb.com/api/v1.1/game/823594/feed/live`; capture SHA-256 `3a406fa73d61ee67897a44464bb22efa1744a1ae6d097c0f709a9011238255bd`.

**First-inning outcome.** Top 1, bottom 0, total 1; descriptive outcome **YRFI**. Top path `HIT_CONTACT_CHAIN`; bottom path `NO_RUN_PATH`. This is a historical observation, not a forecast or betting probability.

### Top 1st — Half-Inning Card

BF=5; pitches=24; runs=1; hits=1; singles=1; XBH=0; BB=0; HBP=0; K=0; HR=0; B4/B5/B6 exposed=True/True/False; leadoff reach=True; two-out extension=False; 3-up-3-down=False. Exact PA-level sequence follows.

- PA 1 — Otto Lopez vs Zac Thornton: field_error; outs 0→0; runs=0; pitches=6. Sequence: 1:FF Called Strike 90.2 mph; 2:SI Foul 91.3 mph; 3:CU Ball 76.4 mph; 4:SL Ball 86.1 mph; 5:SI Ball 92.0 mph; 6:FC In play, no out 88.1 mph. Description: Otto Lopez reaches on a fielding error by shortstop Francisco Lindor.
- PA 2 — Heriberto Hernández vs Zac Thornton: field_out; outs 0→1; runs=0; pitches=7. Sequence: 1:FC Swinging Strike 88.9 mph; 2:FC Ball 88.2 mph; 3:FC Swinging Strike 88.4 mph; 4:FC Foul 90.3 mph; 5:ST Foul 79.7 mph; 6:CH Ball 82.3 mph; 7:SI In play, out(s) 93.9 mph. Description: Heriberto Hernández grounds out, shortstop Francisco Lindor to second baseman Marcus Semien to first baseman Jared Young. Otto Lopez to 2nd.
- PA 3 — Liam Hicks vs Zac Thornton: single; outs 1→1; runs=1; pitches=6. Sequence: 1:FC Ball 89.6 mph; 2:FC Foul 88.9 mph; 3:CU Called Strike 72.0 mph; 4:FF Foul 93.4 mph; 5:CU Ball In Dirt 76.9 mph; 6:FC In play, run(s) 87.9 mph. Description: Liam Hicks singles on a ground ball to left fielder Tyrone Taylor. Otto Lopez scores. Liam Hicks to 2nd.
- PA 4 — Xavier Edwards vs Zac Thornton: field_out; outs 1→2; runs=0; pitches=3. Sequence: 1:FF Ball 91.6 mph; 2:SI Ball 91.6 mph; 3:FC In play, out(s) 88.6 mph. Description: Xavier Edwards pops out to shortstop Francisco Lindor.
- PA 5 — Leo Jiménez vs Zac Thornton: field_out; outs 2→3; runs=0; pitches=2. Sequence: 1:FC Called Strike 88.2 mph; 2:FC In play, out(s) 89.2 mph. Description: Leo Jiménez grounds out, first baseman Jared Young to pitcher Zac Thornton.

### Bottom 1st — Half-Inning Card

BF=5; pitches=13; runs=0; hits=2; singles=2; XBH=0; BB=0; HBP=0; K=0; HR=0; B4/B5/B6 exposed=True/True/False; leadoff reach=False; two-out extension=True; 3-up-3-down=False. Exact PA-level sequence follows.

- PA 1 — A.J. Ewing vs Tyler Phillips: field_out; outs 0→1; runs=0; pitches=2. Sequence: 1:CU Ball 82.0 mph; 2:SI In play, out(s) 94.4 mph. Description: A.J. Ewing flies out to right fielder Javier Sanoja.
- PA 2 — Francisco Lindor vs Tyler Phillips: single; outs 1→1; runs=0; pitches=3. Sequence: 1:FF Ball 95.8 mph; 2:SL Called Strike 87.7 mph; 3:CU In play, no out 84.3 mph. Description: Francisco Lindor singles on a sharp line drive to right fielder Javier Sanoja.
- PA 3 — Bo Bichette vs Tyler Phillips: force_out; outs 1→2; runs=0; pitches=3. Sequence: 1:ST Called Strike 82.6 mph; 2:FS Swinging Strike 87.1 mph; 3:SI In play, out(s) 95.1 mph. Description: Bo Bichette grounds into a force out, shortstop Otto Lopez to second baseman Xavier Edwards. Francisco Lindor out at 2nd. Bo Bichette to 1st.
- PA 4 — Carson Benge vs Tyler Phillips: single; outs 2→2; runs=0; pitches=2. Sequence: 1:FF Ball 95.6 mph; 2:CU In play, no out 82.7 mph. Description: Carson Benge singles on a sharp line drive to center fielder Esteury Ruiz. Bo Bichette to 3rd.
- PA 5 — Jared Young vs Tyler Phillips: force_out; outs 2→3; runs=0; pitches=3. Sequence: 1:ST Foul 84.8 mph; 2:FS Ball 86.0 mph; 3:SI In play, out(s) 94.8 mph. Description: Jared Young grounds into a force out, fielded by shortstop Otto Lopez. Carson Benge out at 2nd.

### Pitch-level process and starter context

First-inning process objects: `{"804267":{"pitch_count_first_inning":24,"pitch_mix_first_inning":{"FF":3,"SI":4,"CU":3,"SL":1,"FC":11,"ST":1,"CH":1},"avg_release_speed_first_inning":87.24,"whiffs":2,"swings":12,"contacts":10},"663969":{"pitch_count_first_inning":13,"pitch_mix_first_inning":{"CU":3,"SI":3,"FF":2,"SL":1,"ST":2,"FS":2},"avg_release_speed_first_inning":88.68,"whiffs":1,"swings":7,"contacts":6}}`. These are calculated from the pitch events retained in the official first-inning GUMBO. Full-start boxscore context is retained separately in `STARTER_CONTEXT`; prior-start L3/L5/L10/L15/L20, season and career first-inning sequences are explicitly `BOUNDED_GAP` in this repair rather than fabricated. The gap does not alter the observed first-inning reconstruction.

### Feature and reliability interpretation

The game contributes all nine registry families at the GAME level: RESULTS, SEQUENCE, EXPOSURE, OUT_CREATION, TRAFFIC, DAMAGE, PITCHER_PROCESS, TOP_ORDER and CONTEXT. The observed current-game families carry high contextual support from GUMBO; historical sequence windows are low-coverage bounded objects. Press/HUMAN_INFORMATION is kept outside the pregame lane unless a publication/availability timestamp can be certified. Mechanism cohorting is retrospective and descriptive only.

### Reconstruction check

PA count top/bottom=5/5; pitch count top/bottom=24/13; first-inning score reconciliation=1+0=1. Exact event arrays and raw source hash are persisted. No missing historical window is converted to zero.

## GAME BLOCK 824485 — Pittsburgh Pirates @ Cincinnati Reds

**Identity.** GAME_PK 824485; venue Great American Ball Park; scheduled 2026-08-01T22:40:00Z; first pitch observed 2026-08-01T22:41:12.649Z; starters Braxton Ashcraft (away) / Andrew Abbott (home). Source: official MLB GUMBO `https://statsapi.mlb.com/api/v1.1/game/824485/feed/live`; capture SHA-256 `1f92dea0807a4e29038c6d1155073033f2e93419893b805e9536b7e826abf6e2`.

**First-inning outcome.** Top 0, bottom 0, total 0; descriptive outcome **NRFI**. Top path `NO_RUN_PATH`; bottom path `NO_RUN_PATH`. This is a historical observation, not a forecast or betting probability.

### Top 1st — Half-Inning Card

BF=4; pitches=15; runs=0; hits=1; singles=1; XBH=0; BB=0; HBP=0; K=0; HR=0; B4/B5/B6 exposed=True/False/False; leadoff reach=True; two-out extension=False; 3-up-3-down=False. Exact PA-level sequence follows.

- PA 1 — Jake Mangum vs Andrew Abbott: single; outs 0→0; runs=0; pitches=7. Sequence: 1:FF Ball 90.4 mph; 2:FF Ball 91.7 mph; 3:FF Called Strike 91.5 mph; 4:FF Swinging Strike 92.3 mph; 5:FF Foul 93.1 mph; 6:FF Ball 92.4 mph; 7:FF In play, no out 93.2 mph. Description: Jake Mangum singles on a ground ball to right fielder Noelvi Marte.
- PA 2 — Brandon Lowe vs Andrew Abbott: force_out; outs 0→1; runs=0; pitches=4. Sequence: 1:FF Foul 92.3 mph; 2:CU Ball In Dirt 82.4 mph; 3:FF Ball 92.8 mph; 4:ST In play, out(s) 83.1 mph. Description: Brandon Lowe grounds into a force out, third baseman Eugenio Suárez to shortstop Elly De La Cruz. Jake Mangum out at 2nd. Brandon Lowe to 1st.
- PA 3 — Bryan Reynolds vs Andrew Abbott: field_out; outs 1→2; runs=0; pitches=2. Sequence: 1:FF Foul 92.1 mph; 2:FF In play, out(s) 92.4 mph. Description: Bryan Reynolds flies out sharply to center fielder TJ Friedl.
- PA 4 — Esmerlyn Valdez vs Andrew Abbott: field_out; outs 2→3; runs=0; pitches=2. Sequence: 1:CH Ball 85.7 mph; 2:CH In play, out(s) 85.3 mph. Description: Esmerlyn Valdez flies out to left fielder JJ Bleday.

### Bottom 1st — Half-Inning Card

BF=3; pitches=12; runs=0; hits=0; singles=0; XBH=0; BB=0; HBP=0; K=1; HR=0; B4/B5/B6 exposed=False/False/False; leadoff reach=False; two-out extension=False; 3-up-3-down=True. Exact PA-level sequence follows.

- PA 1 — Elly De La Cruz vs Braxton Ashcraft: field_out; outs 0→1; runs=0; pitches=1. Sequence: 1:FF In play, out(s) 98.0 mph. Description: Elly De La Cruz grounds out, second baseman Brandon Lowe to first baseman Rafael Flores Jr.
- PA 2 — Sal Stewart vs Braxton Ashcraft: strikeout; outs 1→2; runs=0; pitches=8. Sequence: 1:SI Called Strike 98.2 mph; 2:SL Ball 92.3 mph; 3:SL Foul 91.9 mph; 4:CU Foul 86.7 mph; 5:SL Foul 93.7 mph; 6:SI Foul 98.9 mph; 7:CU Ball 86.7 mph; 8:FF Swinging Strike 99.2 mph. Description: Sal Stewart strikes out swinging.
- PA 3 — JJ Bleday vs Braxton Ashcraft: field_out; outs 2→3; runs=0; pitches=3. Sequence: 1:CU Ball 87.1 mph; 2:SL Foul 92.7 mph; 3:SL In play, out(s) 92.9 mph. Description: JJ Bleday grounds out, second baseman Brandon Lowe to first baseman Rafael Flores Jr.

### Pitch-level process and starter context

First-inning process objects: `{"671096":{"pitch_count_first_inning":15,"pitch_mix_first_inning":{"FF":11,"CU":1,"ST":1,"CH":2},"avg_release_speed_first_inning":90.05,"whiffs":1,"swings":8,"contacts":7},"677952":{"pitch_count_first_inning":12,"pitch_mix_first_inning":{"FF":2,"SI":2,"SL":5,"CU":3},"avg_release_speed_first_inning":93.19,"whiffs":1,"swings":8,"contacts":7}}`. These are calculated from the pitch events retained in the official first-inning GUMBO. Full-start boxscore context is retained separately in `STARTER_CONTEXT`; prior-start L3/L5/L10/L15/L20, season and career first-inning sequences are explicitly `BOUNDED_GAP` in this repair rather than fabricated. The gap does not alter the observed first-inning reconstruction.

### Feature and reliability interpretation

The game contributes all nine registry families at the GAME level: RESULTS, SEQUENCE, EXPOSURE, OUT_CREATION, TRAFFIC, DAMAGE, PITCHER_PROCESS, TOP_ORDER and CONTEXT. The observed current-game families carry high contextual support from GUMBO; historical sequence windows are low-coverage bounded objects. Press/HUMAN_INFORMATION is kept outside the pregame lane unless a publication/availability timestamp can be certified. Mechanism cohorting is retrospective and descriptive only.

### Reconstruction check

PA count top/bottom=4/3; pitch count top/bottom=15/12; first-inning score reconciliation=0+0=0. Exact event arrays and raw source hash are persisted. No missing historical window is converted to zero.

## GAME BLOCK 824808 — Philadelphia Phillies @ Baltimore Orioles

**Identity.** GAME_PK 824808; venue Oriole Park at Camden Yards; scheduled 2026-08-01T23:05:00Z; first pitch observed 2026-08-01T23:08:41.840Z; starters Cristopher Sánchez (away) / Shane Baz (home). Source: official MLB GUMBO `https://statsapi.mlb.com/api/v1.1/game/824808/feed/live`; capture SHA-256 `8b60662b3c0c305e4e68fc44e8699fc3cd35ad59f15aaabe2fdda6b3db56f5eb`.

**First-inning outcome.** Top 0, bottom 0, total 0; descriptive outcome **NRFI**. Top path `NO_RUN_PATH`; bottom path `NO_RUN_PATH`. This is a historical observation, not a forecast or betting probability.

### Top 1st — Half-Inning Card

BF=3; pitches=10; runs=0; hits=0; singles=0; XBH=0; BB=0; HBP=0; K=0; HR=0; B4/B5/B6 exposed=False/False/False; leadoff reach=False; two-out extension=False; 3-up-3-down=True. Exact PA-level sequence follows.

- PA 1 — Trea Turner vs Shane Baz: field_out; outs 0→1; runs=0; pitches=6. Sequence: 1:SI Called Strike 94.4 mph; 2:SI Called Strike 96.1 mph; 3:KC Ball 87.7 mph; 4:FC Ball 91.3 mph; 5:KC Foul 87.1 mph; 6:SI In play, out(s) 97.5 mph. Description: Trea Turner lines out to right fielder Tyler O'Neill.
- PA 2 — Kyle Schwarber vs Shane Baz: field_out; outs 1→2; runs=0; pitches=2. Sequence: 1:KC Ball 83.8 mph; 2:SI In play, out(s) 95.4 mph. Description: Kyle Schwarber lines out sharply to center fielder Leody Taveras.
- PA 3 — Bryce Harper vs Shane Baz: field_out; outs 2→3; runs=0; pitches=2. Sequence: 1:FF Ball 96.0 mph; 2:FF In play, out(s) 95.5 mph. Description: Bryce Harper grounds out, second baseman Jackson Holliday to first baseman Pete Alonso.

### Bottom 1st — Half-Inning Card

BF=4; pitches=14; runs=0; hits=1; singles=1; XBH=0; BB=0; HBP=0; K=2; HR=0; B4/B5/B6 exposed=True/False/False; leadoff reach=False; two-out extension=True; 3-up-3-down=False. Exact PA-level sequence follows.

- PA 1 — Coby Mayo vs Cristopher Sánchez: strikeout; outs 0→1; runs=0; pitches=3. Sequence: 1:SI Swinging Strike 94.8 mph; 2:CH Swinging Strike 87.3 mph; 3:CH Swinging Strike 88.3 mph. Description: Coby Mayo strikes out swinging.
- PA 2 — Taylor Ward vs Cristopher Sánchez: field_out; outs 1→2; runs=0; pitches=3. Sequence: 1:SI Ball 94.8 mph; 2:SI Ball 95.1 mph; 3:SI In play, out(s) 94.8 mph. Description: Taylor Ward grounds out, second baseman Bryson Stott to first baseman Bryce Harper.
- PA 3 — Gunnar Henderson vs Cristopher Sánchez: single; outs 2→2; runs=0; pitches=2. Sequence: 1:SI Ball 94.3 mph; 2:SI In play, no out 94.7 mph. Description: Gunnar Henderson singles on a line drive to right fielder Bryan De La Cruz.
- PA 4 — Pete Alonso vs Cristopher Sánchez: strikeout; outs 2→3; runs=0; pitches=6. Sequence: 1:CH Ball 86.1 mph; 2:SI Called Strike 95.3 mph; 3:SI Ball 94.4 mph; 4:SL Ball 87.8 mph; 5:SI Foul 95.6 mph; 6:SI Called Strike 94.5 mph. Description: Pete Alonso called out on strikes.

### Pitch-level process and starter context

First-inning process objects: `{"669358":{"pitch_count_first_inning":10,"pitch_mix_first_inning":{"SI":4,"KC":3,"FC":1,"FF":2},"avg_release_speed_first_inning":92.48,"whiffs":0,"swings":4,"contacts":4},"650911":{"pitch_count_first_inning":14,"pitch_mix_first_inning":{"SI":10,"CH":3,"SL":1},"avg_release_speed_first_inning":92.7,"whiffs":3,"swings":6,"contacts":3}}`. These are calculated from the pitch events retained in the official first-inning GUMBO. Full-start boxscore context is retained separately in `STARTER_CONTEXT`; prior-start L3/L5/L10/L15/L20, season and career first-inning sequences are explicitly `BOUNDED_GAP` in this repair rather than fabricated. The gap does not alter the observed first-inning reconstruction.

### Feature and reliability interpretation

The game contributes all nine registry families at the GAME level: RESULTS, SEQUENCE, EXPOSURE, OUT_CREATION, TRAFFIC, DAMAGE, PITCHER_PROCESS, TOP_ORDER and CONTEXT. The observed current-game families carry high contextual support from GUMBO; historical sequence windows are low-coverage bounded objects. Press/HUMAN_INFORMATION is kept outside the pregame lane unless a publication/availability timestamp can be certified. Mechanism cohorting is retrospective and descriptive only.

### Reconstruction check

PA count top/bottom=3/4; pitch count top/bottom=10/14; first-inning score reconciliation=0+0=0. Exact event arrays and raw source hash are persisted. No missing historical window is converted to zero.

## GAME BLOCK 824162 — Texas Rangers @ Houston Astros

**Identity.** GAME_PK 824162; venue Daikin Park; scheduled 2026-08-01T23:10:00Z; first pitch observed 2026-08-01T23:11:05.365Z; starters Jacob deGrom (away) / Ronel Blanco (home). Source: official MLB GUMBO `https://statsapi.mlb.com/api/v1.1/game/824162/feed/live`; capture SHA-256 `2d3e8b0420e74a1cba27244e55d450ab7402fd5b1b8ac8f071d82f915935c3bf`.

**First-inning outcome.** Top 0, bottom 0, total 0; descriptive outcome **NRFI**. Top path `NO_RUN_PATH`; bottom path `NO_RUN_PATH`. This is a historical observation, not a forecast or betting probability.

### Top 1st — Half-Inning Card

BF=5; pitches=18; runs=0; hits=2; singles=2; XBH=0; BB=0; HBP=0; K=1; HR=0; B4/B5/B6 exposed=True/True/False; leadoff reach=True; two-out extension=False; 3-up-3-down=False. Exact PA-level sequence follows.

- PA 1 — Joc Pederson vs Ronel Blanco: single; outs 0→0; runs=0; pitches=3. Sequence: 1:FF Ball 93.6 mph; 2:FF Ball 93.8 mph; 3:FF In play, no out 94.9 mph. Description: Joc Pederson singles on a ground ball to third baseman Isaac Paredes.
- PA 2 — Wyatt Langford vs Ronel Blanco: strikeout; outs 0→1; runs=0; pitches=7. Sequence: 1:SL Foul 87.3 mph; 2:FF Ball 93.3 mph; 3:FF Ball 93.1 mph; 4:SL Foul 87.1 mph; 5:CH Ball 84.9 mph; 6:CH Foul 84.0 mph; 7:FF Called Strike 93.5 mph. Description: Wyatt Langford called out on strikes.
- PA 3 — Corey Seager vs Ronel Blanco: single; outs 1→1; runs=0; pitches=4. Sequence: 1:FF Foul Tip 93.7 mph; 2:FF Ball 94.4 mph; 3:CH Ball 86.5 mph; 4:FF In play, no out 93.9 mph. Description: Corey Seager singles on a ground ball to right fielder Cam Smith. Joc Pederson to 2nd.
- PA 4 — Brandon Nimmo vs Ronel Blanco: field_out; outs 1→2; runs=0; pitches=1. Sequence: 1:FF In play, out(s) 93.3 mph. Description: Brandon Nimmo flies out to left fielder LaMonte Wade Jr.
- PA 5 — Evan Carter vs Ronel Blanco: field_out; outs 2→3; runs=0; pitches=3. Sequence: 1:CU Called Strike 80.8 mph; 2:CH Called Strike 85.6 mph; 3:CH In play, out(s) 85.4 mph. Description: Evan Carter flies out to shortstop Jeremy Peña.

### Bottom 1st — Half-Inning Card

BF=4; pitches=22; runs=0; hits=1; singles=1; XBH=0; BB=0; HBP=0; K=1; HR=0; B4/B5/B6 exposed=True/False/False; leadoff reach=False; two-out extension=True; 3-up-3-down=False. Exact PA-level sequence follows.

- PA 1 — Jeremy Peña vs Jacob deGrom: strikeout; outs 0→1; runs=0; pitches=7. Sequence: 1:SL Ball 92.3 mph; 2:SL Swinging Strike 91.9 mph; 3:CU Ball 84.0 mph; 4:SL Swinging Strike 92.6 mph; 5:SL Ball 93.2 mph; 6:FF Foul 98.6 mph; 7:SL Swinging Strike 93.0 mph. Description: Jeremy Peña strikes out swinging.
- PA 2 — Yordan Alvarez vs Jacob deGrom: field_out; outs 1→2; runs=0; pitches=4. Sequence: 1:FF Called Strike 99.2 mph; 2:FF Ball 98.4 mph; 3:CH Ball 91.1 mph; 4:FF In play, out(s) 99.1 mph. Description: Yordan Alvarez grounds out, pitcher Jacob deGrom to first baseman Joc Pederson.
- PA 3 — Isaac Paredes vs Jacob deGrom: single; outs 2→2; runs=0; pitches=7. Sequence: 1:FF Called Strike 99.1 mph; 2:FF Foul 98.4 mph; 3:SL Ball 92.8 mph; 4:FF Foul 99.0 mph; 5:SL Ball 92.7 mph; 6:FF Foul 99.0 mph; 7:FF In play, no out 98.8 mph. Description: Isaac Paredes singles on a line drive to center fielder Evan Carter.
- PA 4 — Christian Walker vs Jacob deGrom: field_out; outs 2→3; runs=0; pitches=4. Sequence: 1:SL Swinging Strike 92.3 mph; 2:SL Ball 93.1 mph; 3:SI Foul Tip 98.7 mph; 4:SL In play, out(s) 92.0 mph. Description: Christian Walker grounds out, second baseman Nicky Lopez to first baseman Joc Pederson.

### Pitch-level process and starter context

First-inning process objects: `{"669854":{"pitch_count_first_inning":18,"pitch_mix_first_inning":{"FF":10,"SL":2,"CH":5,"CU":1},"avg_release_speed_first_inning":89.95,"whiffs":0,"swings":8,"contacts":8},"594798":{"pitch_count_first_inning":22,"pitch_mix_first_inning":{"SL":10,"CU":1,"FF":9,"CH":1,"SI":1},"avg_release_speed_first_inning":94.97,"whiffs":4,"swings":12,"contacts":8}}`. These are calculated from the pitch events retained in the official first-inning GUMBO. Full-start boxscore context is retained separately in `STARTER_CONTEXT`; prior-start L3/L5/L10/L15/L20, season and career first-inning sequences are explicitly `BOUNDED_GAP` in this repair rather than fabricated. The gap does not alter the observed first-inning reconstruction.

### Feature and reliability interpretation

The game contributes all nine registry families at the GAME level: RESULTS, SEQUENCE, EXPOSURE, OUT_CREATION, TRAFFIC, DAMAGE, PITCHER_PROCESS, TOP_ORDER and CONTEXT. The observed current-game families carry high contextual support from GUMBO; historical sequence windows are low-coverage bounded objects. Press/HUMAN_INFORMATION is kept outside the pregame lane unless a publication/availability timestamp can be certified. Mechanism cohorting is retrospective and descriptive only.

### Reconstruction check

PA count top/bottom=5/4; pitch count top/bottom=18/22; first-inning score reconciliation=0+0=0. Exact event arrays and raw source hash are persisted. No missing historical window is converted to zero.

## GAME BLOCK 824405 — Arizona Diamondbacks @ Cleveland Guardians

**Identity.** GAME_PK 824405; venue Progressive Field; scheduled 2026-08-01T23:15:00Z; first pitch observed 2026-08-01T23:15:50.709Z; starters Kohl Drake (away) / Parker Messick (home). Source: official MLB GUMBO `https://statsapi.mlb.com/api/v1.1/game/824405/feed/live`; capture SHA-256 `fa28568465e5c14e3cff3bdc2b16b1061ce624334b872d5ad0d9f76529e594a3`.

**First-inning outcome.** Top 0, bottom 2, total 2; descriptive outcome **YRFI**. Top path `NO_RUN_PATH`; bottom path `HR_INVOLVED_MULTI_MECHANISM`. This is a historical observation, not a forecast or betting probability.

### Top 1st — Half-Inning Card

BF=5; pitches=22; runs=0; hits=1; singles=1; XBH=0; BB=1; HBP=0; K=2; HR=0; B4/B5/B6 exposed=True/True/False; leadoff reach=True; two-out extension=False; 3-up-3-down=False. Exact PA-level sequence follows.

- PA 1 — Corbin Carroll vs Parker Messick: walk; outs 0→0; runs=0; pitches=4. Sequence: 1:FF Ball 93.3 mph; 2:FF Ball 93.4 mph; 3:FF Ball 93.2 mph; 4:FF Ball 93.5 mph. Description: Corbin Carroll walks.
- PA 2 — Geraldo Perdomo vs Parker Messick: single; outs 0→0; runs=0; pitches=6. Sequence: 1:SI Called Strike 92.9 mph; 2:SL Ball 87.0 mph; 3:SI Ball 92.4 mph; 4:FF Ball 94.2 mph; 5:FF Called Strike 94.4 mph; 6:FF In play, no out 94.8 mph. Description: Geraldo Perdomo singles on a ground ball to right fielder Angel Martínez. Corbin Carroll to 2nd.
- PA 3 — Gabriel Moreno vs Parker Messick: strikeout; outs 0→1; runs=0; pitches=5. Sequence: 1:CU Ball In Dirt 80.7 mph; 2:FF Ball 94.3 mph; 3:SI Called Strike 93.6 mph; 4:FF Foul 94.1 mph; 5:FF Swinging Strike 95.3 mph. Description: Gabriel Moreno strikes out swinging.
- PA 4 — Ketel Marte vs Parker Messick: strikeout; outs 1→2; runs=0; pitches=5. Sequence: 1:CH Swinging Strike 87.4 mph; 2:FF Swinging Strike 95.9 mph; 3:FF Ball 95.5 mph; 4:FF Foul 95.9 mph; 5:CH Swinging Strike 87.0 mph. Description: Ketel Marte strikes out swinging.
- PA 5 — Nolan Arenado vs Parker Messick: force_out; outs 2→3; runs=0; pitches=2. Sequence: 1:SI Called Strike 94.7 mph; 2:CH In play, out(s) 87.5 mph. Description: Nolan Arenado grounds into a force out, shortstop Brayan Rocchio to second baseman Travis Bazzana. Geraldo Perdomo out at 2nd.

### Bottom 1st — Half-Inning Card

BF=5; pitches=24; runs=2; hits=2; singles=1; XBH=1; BB=0; HBP=0; K=1; HR=1; B4/B5/B6 exposed=True/True/False; leadoff reach=True; two-out extension=True; 3-up-3-down=False. Exact PA-level sequence follows.

- PA 1 — Steven Kwan vs Kohl Drake: single; outs 0→0; runs=0; pitches=5. Sequence: 1:FF Called Strike 90.4 mph; 2:FF Ball 91.3 mph; 3:FF Ball 91.8 mph; 4:FF Foul 91.8 mph; 5:FF In play, no out 92.5 mph. Description: Steven Kwan singles on a ground ball to center fielder Tim Tawa.
- PA 2 — José Ramírez vs Kohl Drake: field_out; outs 0→1; runs=0; pitches=7. Sequence: 1:FC Called Strike 86.2 mph; 2:CH Ball 82.3 mph; 3:CH Foul 81.6 mph; 4:FF Ball 92.1 mph; 5:FF Foul 92.0 mph; 6:FC Ball 86.8 mph; 7:FF In play, out(s) 92.3 mph. Description: José Ramírez flies out to left fielder Ryan Waldschmidt.
- PA 3 — Chase DeLauter vs Kohl Drake: force_out; outs 1→2; runs=0; pitches=3. Sequence: 1:FC Called Strike 88.0 mph; 2:CH Foul 82.1 mph; 3:SL In play, out(s) 82.5 mph. Description: Chase DeLauter grounds into a force out, fielded by second baseman Ketel Marte. Steven Kwan out at 2nd. Chase DeLauter to 1st.
- PA 4 — Rhys Hoskins vs Kohl Drake: home_run; outs 2→2; runs=2; pitches=3. Sequence: 1:CU Ball In Dirt 79.8 mph; 2:FF Called Strike 92.5 mph; 3:FF In play, run(s) 92.8 mph. Description: Rhys Hoskins homers (12) on a fly ball to center field. Chase DeLauter scores.
- PA 5 — Angel Martínez vs Kohl Drake: strikeout; outs 2→3; runs=0; pitches=6. Sequence: 1:FF Ball 91.9 mph; 2:FC Foul 85.7 mph; 3:FF Swinging Strike 92.5 mph; 4:FF Ball 92.0 mph; 5:CU Ball 77.6 mph; 6:FF Foul Tip 92.4 mph. Description: Angel Martínez strikes out on a foul tip.

### Pitch-level process and starter context

First-inning process objects: `{"800048":{"pitch_count_first_inning":22,"pitch_mix_first_inning":{"FF":13,"SI":4,"SL":1,"CU":1,"CH":3},"avg_release_speed_first_inning":92.32,"whiffs":4,"swings":8,"contacts":4},"684442":{"pitch_count_first_inning":24,"pitch_mix_first_inning":{"FF":14,"FC":4,"CH":3,"SL":1,"CU":2},"avg_release_speed_first_inning":88.37,"whiffs":1,"swings":11,"contacts":10}}`. These are calculated from the pitch events retained in the official first-inning GUMBO. Full-start boxscore context is retained separately in `STARTER_CONTEXT`; prior-start L3/L5/L10/L15/L20, season and career first-inning sequences are explicitly `BOUNDED_GAP` in this repair rather than fabricated. The gap does not alter the observed first-inning reconstruction.

### Feature and reliability interpretation

The game contributes all nine registry families at the GAME level: RESULTS, SEQUENCE, EXPOSURE, OUT_CREATION, TRAFFIC, DAMAGE, PITCHER_PROCESS, TOP_ORDER and CONTEXT. The observed current-game families carry high contextual support from GUMBO; historical sequence windows are low-coverage bounded objects. Press/HUMAN_INFORMATION is kept outside the pregame lane unless a publication/availability timestamp can be certified. Mechanism cohorting is retrospective and descriptive only.

### Reconstruction check

PA count top/bottom=5/5; pitch count top/bottom=22/24; first-inning score reconciliation=0+2=2. Exact event arrays and raw source hash are persisted. No missing historical window is converted to zero.

## GAME BLOCK 824890 — Washington Nationals @ Atlanta Braves

**Identity.** GAME_PK 824890; venue Truist Park; scheduled 2026-08-01T23:15:00Z; first pitch observed 2026-08-01T23:17:45.962Z; starters Miles Mikolas (away) / Martín Pérez (home). Source: official MLB GUMBO `https://statsapi.mlb.com/api/v1.1/game/824890/feed/live`; capture SHA-256 `12eb15d3366008d45b1147bda2fedd1ebe7c372c2b4a56512482a2ed2889e788`.

**First-inning outcome.** Top 0, bottom 2, total 2; descriptive outcome **YRFI**. Top path `NO_RUN_PATH`; bottom path `MULTI_HR`. This is a historical observation, not a forecast or betting probability.

### Top 1st — Half-Inning Card

BF=3; pitches=7; runs=0; hits=0; singles=0; XBH=0; BB=0; HBP=0; K=0; HR=0; B4/B5/B6 exposed=False/False/False; leadoff reach=False; two-out extension=False; 3-up-3-down=True. Exact PA-level sequence follows.

- PA 1 — James Wood vs Martín Pérez: field_out; outs 0→1; runs=0; pitches=4. Sequence: 1:SI Ball 89.1 mph; 2:SI Ball 89.2 mph; 3:SI Called Strike 88.7 mph; 4:CH In play, out(s) 81.1 mph. Description: James Wood pops out to third baseman Austin Riley in foul territory.
- PA 2 — Andrés Chaparro vs Martín Pérez: field_out; outs 1→2; runs=0; pitches=2. Sequence: 1:SI Swinging Strike 89.3 mph; 2:SI In play, out(s) 90.1 mph. Description: Andrés Chaparro grounds out softly, second baseman Ozzie Albies to first baseman Matt Olson.
- PA 3 — Dylan Crews vs Martín Pérez: field_out; outs 2→3; runs=0; pitches=1. Sequence: 1:SI In play, out(s) 90.4 mph. Description: Dylan Crews lines out to left fielder Mike Yastrzemski.

### Bottom 1st — Half-Inning Card

BF=6; pitches=13; runs=2; hits=3; singles=1; XBH=2; BB=0; HBP=0; K=1; HR=2; B4/B5/B6 exposed=True/True/True; leadoff reach=False; two-out extension=True; 3-up-3-down=False. Exact PA-level sequence follows.

- PA 1 — Drake Baldwin vs Miles Mikolas: field_out; outs 0→1; runs=0; pitches=1. Sequence: 1:FF In play, out(s) 92.1 mph. Description: Drake Baldwin flies out to left fielder Dylan Crews.
- PA 2 — Ronald Acuña Jr. vs Miles Mikolas: home_run; outs 1→1; runs=1; pitches=2. Sequence: 1:SL Ball 87.0 mph; 2:SI In play, run(s) 91.6 mph. Description: Ronald Acuña Jr. homers (9) on a fly ball to center field.
- PA 3 — Matt Olson vs Miles Mikolas: home_run; outs 1→1; runs=1; pitches=2. Sequence: 1:FF Swinging Strike 92.3 mph; 2:SL In play, run(s) 88.4 mph. Description: Matt Olson homers (30) on a fly ball to right field.
- PA 4 — Michael Harris II vs Miles Mikolas: strikeout; outs 1→2; runs=0; pitches=3. Sequence: 1:SI Called Strike 92.7 mph; 2:SI Foul 92.7 mph; 3:CU Swinging Strike (Blocked) 78.1 mph. Description: Michael Harris II strikes out swinging.
- PA 5 — Ozzie Albies vs Miles Mikolas: single; outs 2→2; runs=0; pitches=2. Sequence: 1:CU Ball 76.8 mph; 2:SI In play, no out 92.5 mph. Description: Ozzie Albies singles on a sharp line drive to right fielder James Wood.
- PA 6 — Dominic Smith vs Miles Mikolas: field_out; outs 2→3; runs=0; pitches=3. Sequence: 1:SI Called Strike 91.7 mph; 2:SI Ball 92.2 mph; 3:CU In play, out(s) 76.4 mph. Description: Dominic Smith grounds out, second baseman Nasim Nuñez to first baseman Luis García Jr.

### Pitch-level process and starter context

First-inning process objects: `{"527048":{"pitch_count_first_inning":7,"pitch_mix_first_inning":{"SI":6,"CH":1},"avg_release_speed_first_inning":88.27,"whiffs":1,"swings":4,"contacts":3},"571945":{"pitch_count_first_inning":13,"pitch_mix_first_inning":{"FF":2,"SL":2,"SI":6,"CU":3},"avg_release_speed_first_inning":88.04,"whiffs":2,"swings":8,"contacts":6}}`. These are calculated from the pitch events retained in the official first-inning GUMBO. Full-start boxscore context is retained separately in `STARTER_CONTEXT`; prior-start L3/L5/L10/L15/L20, season and career first-inning sequences are explicitly `BOUNDED_GAP` in this repair rather than fabricated. The gap does not alter the observed first-inning reconstruction.

### Feature and reliability interpretation

The game contributes all nine registry families at the GAME level: RESULTS, SEQUENCE, EXPOSURE, OUT_CREATION, TRAFFIC, DAMAGE, PITCHER_PROCESS, TOP_ORDER and CONTEXT. The observed current-game families carry high contextual support from GUMBO; historical sequence windows are low-coverage bounded objects. Press/HUMAN_INFORMATION is kept outside the pregame lane unless a publication/availability timestamp can be certified. Mechanism cohorting is retrospective and descriptive only.

### Reconstruction check

PA count top/bottom=3/6; pitch count top/bottom=7/13; first-inning score reconciliation=0+2=2. Exact event arrays and raw source hash are persisted. No missing historical window is converted to zero.

## GAME BLOCK 824649 — New York Yankees @ Chicago Cubs

**Identity.** GAME_PK 824649; venue Wrigley Field; scheduled 2026-08-01T23:15:00Z; first pitch observed 2026-08-01T23:15:09.166Z; starters Max Fried (away) / David Peterson (home). Source: official MLB GUMBO `https://statsapi.mlb.com/api/v1.1/game/824649/feed/live`; capture SHA-256 `344bda5abf4e151f00ea95a5c7cb1042ea23d7268c3fa26ccf1581434b2a2d5b`.

**First-inning outcome.** Top 0, bottom 1, total 1; descriptive outcome **YRFI**. Top path `NO_RUN_PATH`; bottom path `FREE_TRAFFIC_CHAIN`. This is a historical observation, not a forecast or betting probability.

### Top 1st — Half-Inning Card

BF=3; pitches=21; runs=0; hits=0; singles=0; XBH=0; BB=0; HBP=0; K=2; HR=0; B4/B5/B6 exposed=False/False/False; leadoff reach=False; two-out extension=False; 3-up-3-down=True. Exact PA-level sequence follows.

- PA 1 — Max Schuemann vs David Peterson: strikeout; outs 0→1; runs=0; pitches=6. Sequence: 1:SI Swinging Strike 92.9 mph; 2:SI Ball 91.9 mph; 3:CH Foul 85.8 mph; 4:CH Ball 85.1 mph; 5:SI Ball 94.1 mph; 6:SI Called Strike 95.2 mph. Description: Max Schuemann challenged (pitch result), call on the field was confirmed: Max Schuemann called out on strikes.
- PA 2 — Paul Goldschmidt vs David Peterson: field_out; outs 1→2; runs=0; pitches=7. Sequence: 1:SI Ball 93.6 mph; 2:CH Called Strike 87.8 mph; 3:SI Ball 93.7 mph; 4:CH Called Strike 86.5 mph; 5:CH Foul 87.9 mph; 6:FF Ball 93.3 mph; 7:FF In play, out(s) 93.2 mph. Description: Paul Goldschmidt lines out softly to second baseman Nico Hoerner.
- PA 3 — Amed Rosario vs David Peterson: strikeout; outs 2→3; runs=0; pitches=8. Sequence: 1:FF Ball 93.0 mph; 2:SI Called Strike 92.3 mph; 3:SI Called Strike 93.6 mph; 4:FF Foul 93.7 mph; 5:FF Ball 92.9 mph; 6:SI Foul 93.7 mph; 7:SI Foul 92.4 mph; 8:CH Foul Tip 85.3 mph. Description: Amed Rosario strikes out on a foul tip.

### Bottom 1st — Half-Inning Card

BF=4; pitches=23; runs=1; hits=0; singles=0; XBH=0; BB=1; HBP=0; K=1; HR=0; B4/B5/B6 exposed=True/False/False; leadoff reach=True; two-out extension=False; 3-up-3-down=False. Exact PA-level sequence follows.

- PA 1 — Pete Crow-Armstrong vs Max Fried: walk; outs 0→0; runs=0; pitches=8. Sequence: 1:FF Called Strike 94.9 mph; 2:ST Ball 81.7 mph; 3:FF Foul Tip 95.8 mph; 4:FF Ball 96.9 mph; 5:SI Ball 94.8 mph; 6:FF Foul 97.6 mph; 7:FF Foul 96.9 mph; 8:SI Ball 94.3 mph. Description: Pete Crow-Armstrong walks.
- PA 2 — Seiya Suzuki vs Max Fried: field_out; outs 0→1; runs=0; pitches=6. Sequence: 1:CU Ball 73.6 mph; 2:SI Called Strike 94.3 mph; 3:FF Foul Tip 95.2 mph; 4:CU Ball 77.4 mph; 5:FC Ball 92.9 mph; 6:FC In play, out(s) 93.8 mph. Description: Seiya Suzuki grounds out, second baseman Jazz Chisholm Jr. to first baseman Paul Goldschmidt. Pete Crow-Armstrong to 3rd.
- PA 3 — Alex Bregman vs Max Fried: field_out; outs 1→2; runs=1; pitches=3. Sequence: 1:ST Ball 81.4 mph; 2:FF Ball 95.6 mph; 3:FF In play, out(s) 94.9 mph. Description: Alex Bregman flies out to center fielder Spencer Jones.
- PA 4 — Carson Kelly vs Max Fried: strikeout; outs 2→3; runs=0; pitches=6. Sequence: 1:ST Called Strike 81.2 mph; 2:FF Ball 95.1 mph; 3:FC Foul 93.3 mph; 4:FF Foul 96.1 mph; 5:ST Ball 82.6 mph; 6:CU Swinging Strike 74.6 mph. Description: Carson Kelly strikes out swinging.

### Pitch-level process and starter context

First-inning process objects: `{"656849":{"pitch_count_first_inning":21,"pitch_mix_first_inning":{"SI":10,"CH":6,"FF":5},"avg_release_speed_first_inning":91.33,"whiffs":1,"swings":8,"contacts":7},"608331":{"pitch_count_first_inning":23,"pitch_mix_first_inning":{"FF":10,"ST":4,"SI":3,"CU":3,"FC":3},"avg_release_speed_first_inning":90.21,"whiffs":1,"swings":9,"contacts":8}}`. These are calculated from the pitch events retained in the official first-inning GUMBO. Full-start boxscore context is retained separately in `STARTER_CONTEXT`; prior-start L3/L5/L10/L15/L20, season and career first-inning sequences are explicitly `BOUNDED_GAP` in this repair rather than fabricated. The gap does not alter the observed first-inning reconstruction.

### Feature and reliability interpretation

The game contributes all nine registry families at the GAME level: RESULTS, SEQUENCE, EXPOSURE, OUT_CREATION, TRAFFIC, DAMAGE, PITCHER_PROCESS, TOP_ORDER and CONTEXT. The observed current-game families carry high contextual support from GUMBO; historical sequence windows are low-coverage bounded objects. Press/HUMAN_INFORMATION is kept outside the pregame lane unless a publication/availability timestamp can be certified. Mechanism cohorting is retrospective and descriptive only.

### Reconstruction check

PA count top/bottom=3/4; pitch count top/bottom=21/23; first-inning score reconciliation=0+1=1. Exact event arrays and raw source hash are persisted. No missing historical window is converted to zero.

## GAME BLOCK 824326 — Kansas City Royals @ Colorado Rockies

**Identity.** GAME_PK 824326; venue Coors Field; scheduled 2026-08-02T00:10:00Z; first pitch observed 2026-08-02T00:12:06.713Z; starters Luinder Avila (away) / Ryan Feltner (home). Source: official MLB GUMBO `https://statsapi.mlb.com/api/v1.1/game/824326/feed/live`; capture SHA-256 `c65cbe2f4da568debcbd7e6ab3e4b0b5a9208792227609dab9e3910f740c76a5`.

**First-inning outcome.** Top 0, bottom 0, total 0; descriptive outcome **NRFI**. Top path `NO_RUN_PATH`; bottom path `NO_RUN_PATH`. This is a historical observation, not a forecast or betting probability.

### Top 1st — Half-Inning Card

BF=4; pitches=16; runs=0; hits=1; singles=1; XBH=0; BB=1; HBP=0; K=0; HR=0; B4/B5/B6 exposed=True/False/False; leadoff reach=True; two-out extension=False; 3-up-3-down=False. Exact PA-level sequence follows.

- PA 1 — Carter Jensen vs Ryan Feltner: walk; outs 0→0; runs=0; pitches=5. Sequence: 1:FF Ball 94.4 mph; 2:FF Called Strike 94.4 mph; 3:CH Ball 85.1 mph; 4:SL Ball 91.5 mph; 5:SL Ball 91.0 mph. Description: Carter Jensen walks.
- PA 2 — Lane Thomas vs Ryan Feltner: single; outs 0→0; runs=0; pitches=6. Sequence: 1:SL Called Strike 90.1 mph; 2:SI Ball 94.3 mph; 3:SL Foul 89.3 mph; 4:FF Ball 95.8 mph; 5:ST Ball 83.0 mph; 6:FF In play, no out 94.7 mph. Description: Lane Thomas singles on a line drive to left fielder Jake McCarthy. Carter Jensen to 2nd.
- PA 3 — Jac Caglianone vs Ryan Feltner: grounded_into_double_play; outs 0→2; runs=0; pitches=1. Sequence: 1:FF In play, out(s) 96.3 mph. Description: Jac Caglianone grounds into a double play, shortstop Cole Carrigg to first baseman TJ Rumfield. Carter Jensen to 3rd. Lane Thomas out at 2nd. Jac Caglianone out at 1st.
- PA 4 — Salvador Perez vs Ryan Feltner: field_out; outs 2→3; runs=0; pitches=4. Sequence: 1:SL Called Strike 89.9 mph; 2:SL Foul 90.4 mph; 3:ST Ball In Dirt 85.2 mph; 4:CH In play, out(s) 85.9 mph. Description: Salvador Perez grounds out, third baseman Kyle Karros to first baseman TJ Rumfield.

### Bottom 1st — Half-Inning Card

BF=3; pitches=12; runs=0; hits=0; singles=0; XBH=0; BB=0; HBP=0; K=1; HR=0; B4/B5/B6 exposed=False/False/False; leadoff reach=False; two-out extension=False; 3-up-3-down=True. Exact PA-level sequence follows.

- PA 1 — Jake McCarthy vs Luinder Avila: field_out; outs 0→1; runs=0; pitches=4. Sequence: 1:FF Called Strike 93.8 mph; 2:CU Swinging Strike 82.9 mph; 3:SL Ball 86.2 mph; 4:FF In play, out(s) 96.5 mph. Description: Jake McCarthy lines out sharply to left fielder Isaac Collins.
- PA 2 — Kyle Karros vs Luinder Avila: strikeout; outs 1→2; runs=0; pitches=5. Sequence: 1:FF Foul 94.9 mph; 2:SI Foul 96.3 mph; 3:SL Ball 88.5 mph; 4:SL Foul 88.0 mph; 5:SL Swinging Strike 88.8 mph. Description: Kyle Karros strikes out swinging.
- PA 3 — TJ Rumfield vs Luinder Avila: field_out; outs 2→3; runs=0; pitches=3. Sequence: 1:SI Ball 97.8 mph; 2:CH Swinging Strike 89.8 mph; 3:FF In play, out(s) 97.3 mph. Description: TJ Rumfield grounds out to first baseman Jac Caglianone.

### Pitch-level process and starter context

First-inning process objects: `{"663372":{"pitch_count_first_inning":16,"pitch_mix_first_inning":{"FF":5,"CH":2,"SL":6,"SI":1,"ST":2},"avg_release_speed_first_inning":90.71,"whiffs":0,"swings":5,"contacts":5},"679883":{"pitch_count_first_inning":12,"pitch_mix_first_inning":{"FF":4,"CU":1,"SL":4,"SI":2,"CH":1},"avg_release_speed_first_inning":91.73,"whiffs":3,"swings":8,"contacts":5}}`. These are calculated from the pitch events retained in the official first-inning GUMBO. Full-start boxscore context is retained separately in `STARTER_CONTEXT`; prior-start L3/L5/L10/L15/L20, season and career first-inning sequences are explicitly `BOUNDED_GAP` in this repair rather than fabricated. The gap does not alter the observed first-inning reconstruction.

### Feature and reliability interpretation

The game contributes all nine registry families at the GAME level: RESULTS, SEQUENCE, EXPOSURE, OUT_CREATION, TRAFFIC, DAMAGE, PITCHER_PROCESS, TOP_ORDER and CONTEXT. The observed current-game families carry high contextual support from GUMBO; historical sequence windows are low-coverage bounded objects. Press/HUMAN_INFORMATION is kept outside the pregame lane unless a publication/availability timestamp can be certified. Mechanism cohorting is retrospective and descriptive only.

### Reconstruction check

PA count top/bottom=4/3; pitch count top/bottom=16/12; first-inning score reconciliation=0+0=0. Exact event arrays and raw source hash are persisted. No missing historical window is converted to zero.

## GAME BLOCK 823269 — San Francisco Giants @ San Diego Padres

**Identity.** GAME_PK 823269; venue Petco Park; scheduled 2026-08-02T00:40:00Z; first pitch observed 2026-08-02T00:41:03.651Z; starters Tyler Mahle (away) / Walker Buehler (home). Source: official MLB GUMBO `https://statsapi.mlb.com/api/v1.1/game/823269/feed/live`; capture SHA-256 `c0f178fc8cbc359826d509cdb0f3ca9717b6a93f1056ee78986a8acc8ad1d7bf`.

**First-inning outcome.** Top 0, bottom 2, total 2; descriptive outcome **YRFI**. Top path `NO_RUN_PATH`; bottom path `XBH_DAMAGE`. This is a historical observation, not a forecast or betting probability.

### Top 1st — Half-Inning Card

BF=3; pitches=17; runs=0; hits=1; singles=1; XBH=0; BB=0; HBP=0; K=1; HR=0; B4/B5/B6 exposed=False/False/False; leadoff reach=True; two-out extension=False; 3-up-3-down=False. Exact PA-level sequence follows.

- PA 1 — Bryce Eldridge vs Walker Buehler: single; outs 0→0; runs=0; pitches=4. Sequence: 1:FF Foul 93.7 mph; 2:SI Ball 94.8 mph; 3:FC Ball 91.2 mph; 4:SI In play, no out 95.4 mph. Description: Bryce Eldridge singles on a fly ball to left fielder Jase Bowen.
- PA 2 — Jung Hoo Lee vs Walker Buehler: force_out; outs 0→1; runs=0; pitches=9. Sequence: 1:FF Ball 95.0 mph; 2:FF Ball 94.8 mph; 3:SI Foul 95.4 mph; 4:SI Ball 94.7 mph; 5:FF Called Strike 95.0 mph; 6:FC Foul 91.6 mph; 7:CH Foul 90.6 mph; 8:FC Foul 92.2 mph; 9:FF In play, out(s) 96.1 mph. Description: Jung Hoo Lee grounds into a force out, first baseman Ty France to shortstop Xander Bogaerts. Bryce Eldridge out at 2nd. Jung Hoo Lee to 1st.
- PA 3 — Heliot Ramos vs Walker Buehler: strikeout; outs 1→3; runs=0; pitches=4. Sequence: 1:FC Ball 89.8 mph; 2:FC Swinging Strike 92.4 mph; 3:SI Called Strike 96.0 mph; 4:ST Swinging Strike 82.6 mph. Description: Heliot Ramos strikes out swinging.

### Bottom 1st — Half-Inning Card

BF=7; pitches=33; runs=2; hits=2; singles=1; XBH=1; BB=1; HBP=1; K=2; HR=0; B4/B5/B6 exposed=True/True/True; leadoff reach=False; two-out extension=True; 3-up-3-down=False. Exact PA-level sequence follows.

- PA 1 — Fernando Tatis Jr. vs Tyler Mahle: strikeout; outs 0→1; runs=0; pitches=5. Sequence: 1:FF Called Strike 93.0 mph; 2:FS Called Strike 85.6 mph; 3:FF Ball 92.2 mph; 4:FF Ball 93.0 mph; 5:FS Swinging Strike 86.4 mph. Description: Fernando Tatis Jr. strikes out swinging.
- PA 2 — Jake Cronenworth vs Tyler Mahle: strikeout; outs 1→2; runs=0; pitches=5. Sequence: 1:FF Foul 93.4 mph; 2:FF Ball 94.0 mph; 3:FS Foul 87.4 mph; 4:FF Ball 94.9 mph; 5:FS Foul Tip 85.4 mph. Description: Jake Cronenworth strikes out on a foul tip.
- PA 3 — Manny Machado vs Tyler Mahle: walk; outs 2→2; runs=0; pitches=4. Sequence: 1:FF Ball 94.0 mph; 2:FC Ball 88.6 mph; 3:FC Ball 88.5 mph; 4:FF Ball 94.6 mph. Description: Manny Machado walks.
- PA 4 — Ty France vs Tyler Mahle: single; outs 2→2; runs=0; pitches=7. Sequence: 1:FF Called Strike 93.5 mph; 2:FS Foul 86.8 mph; 3:FF Ball 93.9 mph; 4:FC Ball In Dirt 88.5 mph; 5:FS Foul 87.3 mph; 6:FF Ball 94.2 mph; 7:FS In play, no out 87.5 mph. Description: Ty France singles on a ground ball to left fielder Heliot Ramos. Manny Machado to 2nd.
- PA 5 — Jackson Merrill vs Tyler Mahle: double; outs 2→2; runs=2; pitches=4. Sequence: 1:FS Ball In Dirt 87.8 mph; 2:FS Swinging Strike 87.7 mph; 3:FF Ball 93.6 mph; 4:FC In play, run(s) 88.8 mph. Description: Jackson Merrill doubles (18) on a line drive to left fielder Heliot Ramos. Manny Machado scores. Ty France scores.
- PA 6 — Luis Rengifo vs Tyler Mahle: hit_by_pitch; outs 2→2; runs=0; pitches=4. Sequence: 1:FF Ball 94.0 mph; 2:FF Called Strike 94.6 mph; 3:FS Foul 86.9 mph; 4:FF Hit By Pitch 94.2 mph. Description: Luis Rengifo hit by pitch.
- PA 7 — Xander Bogaerts vs Tyler Mahle: field_out; outs 2→3; runs=0; pitches=4. Sequence: 1:FS Swinging Strike 86.2 mph; 2:FC Ball 86.8 mph; 3:FS Ball 86.5 mph; 4:FF In play, out(s) 93.9 mph. Description: Xander Bogaerts grounds out, second baseman Osleivis Basabe to first baseman Rafael Devers.

### Pitch-level process and starter context

First-inning process objects: `{"621111":{"pitch_count_first_inning":17,"pitch_mix_first_inning":{"FF":5,"SI":5,"FC":5,"CH":1,"ST":1},"avg_release_speed_first_inning":93.02,"whiffs":2,"swings":9,"contacts":7},"641816":{"pitch_count_first_inning":33,"pitch_mix_first_inning":{"FF":16,"FS":12,"FC":5},"avg_release_speed_first_inning":90.42,"whiffs":3,"swings":12,"contacts":9}}`. These are calculated from the pitch events retained in the official first-inning GUMBO. Full-start boxscore context is retained separately in `STARTER_CONTEXT`; prior-start L3/L5/L10/L15/L20, season and career first-inning sequences are explicitly `BOUNDED_GAP` in this repair rather than fabricated. The gap does not alter the observed first-inning reconstruction.

### Feature and reliability interpretation

The game contributes all nine registry families at the GAME level: RESULTS, SEQUENCE, EXPOSURE, OUT_CREATION, TRAFFIC, DAMAGE, PITCHER_PROCESS, TOP_ORDER and CONTEXT. The observed current-game families carry high contextual support from GUMBO; historical sequence windows are low-coverage bounded objects. Press/HUMAN_INFORMATION is kept outside the pregame lane unless a publication/availability timestamp can be certified. Mechanism cohorting is retrospective and descriptive only.

### Reconstruction check

PA count top/bottom=3/7; pitch count top/bottom=17/33; first-inning score reconciliation=0+2=2. Exact event arrays and raw source hash are persisted. No missing historical window is converted to zero.

## GAME BLOCK 823920 — Boston Red Sox @ Los Angeles Dodgers

**Identity.** GAME_PK 823920; venue UNIQLO Field at Dodger Stadium; scheduled 2026-08-02T01:10:00Z; first pitch observed 2026-08-02T01:11:35.381Z; starters Payton Tolle (away) / Yoshinobu Yamamoto (home). Source: official MLB GUMBO `https://statsapi.mlb.com/api/v1.1/game/823920/feed/live`; capture SHA-256 `d8e904cc9487094f4e79e4e05ab89d63aa3032b070947626b370d0cfc82d899c`.

**First-inning outcome.** Top 1, bottom 0, total 1; descriptive outcome **YRFI**. Top path `SOLO_HR`; bottom path `NO_RUN_PATH`. This is a historical observation, not a forecast or betting probability.

### Top 1st — Half-Inning Card

BF=4; pitches=9; runs=1; hits=1; singles=0; XBH=1; BB=0; HBP=0; K=0; HR=1; B4/B5/B6 exposed=True/False/False; leadoff reach=False; two-out extension=False; 3-up-3-down=False. Exact PA-level sequence follows.

- PA 1 — Anthony Seigler vs Yoshinobu Yamamoto: field_out; outs 0→1; runs=0; pitches=2. Sequence: 1:CU Called Strike 77.1 mph; 2:FC In play, out(s) 94.2 mph. Description: Anthony Seigler grounds out softly, second baseman Tommy Edman to first baseman Freddie Freeman.
- PA 2 — Ceddanne Rafaela vs Yoshinobu Yamamoto: home_run; outs 1→1; runs=1; pitches=1. Sequence: 1:FS In play, run(s) 90.5 mph. Description: Ceddanne Rafaela homers (13) on a fly ball to left center field.
- PA 3 — Wilyer Abreu vs Yoshinobu Yamamoto: field_out; outs 1→2; runs=0; pitches=2. Sequence: 1:FF Called Strike 97.3 mph; 2:FS In play, out(s) 91.6 mph. Description: Wilyer Abreu grounds out, second baseman Tommy Edman to first baseman Freddie Freeman.
- PA 4 — Caleb Durbin vs Yoshinobu Yamamoto: field_out; outs 2→3; runs=0; pitches=4. Sequence: 1:FF Swinging Strike 96.3 mph; 2:CU Called Strike 78.4 mph; 3:SI Ball 96.6 mph; 4:FS In play, out(s) 92.2 mph. Description: Caleb Durbin grounds out, third baseman Max Muncy to first baseman Freddie Freeman.

### Bottom 1st — Half-Inning Card

BF=3; pitches=8; runs=0; hits=1; singles=1; XBH=0; BB=0; HBP=0; K=1; HR=0; B4/B5/B6 exposed=False/False/False; leadoff reach=True; two-out extension=False; 3-up-3-down=False. Exact PA-level sequence follows.

- PA 1 — Shohei Ohtani vs Payton Tolle: single; outs 0→0; runs=0; pitches=3. Sequence: 1:FF Ball 95.8 mph; 2:FC Called Strike 89.1 mph; 3:FF In play, no out 96.4 mph. Description: Shohei Ohtani singles on a sharp ground ball to center fielder Ceddanne Rafaela.
- PA 2 — Andy Pages vs Payton Tolle: double_play; outs 0→2; runs=0; pitches=1. Sequence: 1:SI In play, out(s) 94.1 mph. Description: Andy Pages lines into a double play, right fielder Wilyer Abreu to shortstop Andruw Monasterio. Shohei Ohtani out at 2nd.
- PA 3 — Tommy Edman vs Payton Tolle: strikeout; outs 2→3; runs=0; pitches=4. Sequence: 1:FF Swinging Strike 96.1 mph; 2:FF Foul 97.7 mph; 3:CU Ball 83.1 mph; 4:CU Swinging Strike 82.1 mph. Description: Tommy Edman strikes out swinging.

### Pitch-level process and starter context

First-inning process objects: `{"808967":{"pitch_count_first_inning":9,"pitch_mix_first_inning":{"CU":2,"FC":1,"FS":3,"FF":2,"SI":1},"avg_release_speed_first_inning":90.47,"whiffs":1,"swings":5,"contacts":4},"801139":{"pitch_count_first_inning":8,"pitch_mix_first_inning":{"FF":4,"FC":1,"SI":1,"CU":2},"avg_release_speed_first_inning":91.8,"whiffs":2,"swings":5,"contacts":3}}`. These are calculated from the pitch events retained in the official first-inning GUMBO. Full-start boxscore context is retained separately in `STARTER_CONTEXT`; prior-start L3/L5/L10/L15/L20, season and career first-inning sequences are explicitly `BOUNDED_GAP` in this repair rather than fabricated. The gap does not alter the observed first-inning reconstruction.

### Feature and reliability interpretation

The game contributes all nine registry families at the GAME level: RESULTS, SEQUENCE, EXPOSURE, OUT_CREATION, TRAFFIC, DAMAGE, PITCHER_PROCESS, TOP_ORDER and CONTEXT. The observed current-game families carry high contextual support from GUMBO; historical sequence windows are low-coverage bounded objects. Press/HUMAN_INFORMATION is kept outside the pregame lane unless a publication/availability timestamp can be certified. Mechanism cohorting is retrospective and descriptive only.

### Reconstruction check

PA count top/bottom=4/3; pitch count top/bottom=9/8; first-inning score reconciliation=1+0=1. Exact event arrays and raw source hash are persisted. No missing historical window is converted to zero.

## GAME BLOCK 824000 — Milwaukee Brewers @ Los Angeles Angels

**Identity.** GAME_PK 824000; venue Angel Stadium; scheduled 2026-08-02T01:38:00Z; first pitch observed 2026-08-02T01:38:35.235Z; starters Robert Gasser (away) / Brent Suter (home). Source: official MLB GUMBO `https://statsapi.mlb.com/api/v1.1/game/824000/feed/live`; capture SHA-256 `cc413fc730696caf574373f5d901c99a21b71adbf9cadf7cb2edf38a46263170`.

**First-inning outcome.** Top 0, bottom 1, total 1; descriptive outcome **YRFI**. Top path `NO_RUN_PATH`; bottom path `XBH_DAMAGE`. This is a historical observation, not a forecast or betting probability.

### Top 1st — Half-Inning Card

BF=3; pitches=12; runs=0; hits=0; singles=0; XBH=0; BB=0; HBP=0; K=0; HR=0; B4/B5/B6 exposed=False/False/False; leadoff reach=False; two-out extension=False; 3-up-3-down=True. Exact PA-level sequence follows.

- PA 1 — Jackson Chourio vs Brent Suter: field_out; outs 0→1; runs=0; pitches=4. Sequence: 1:SI Ball 90.2 mph; 2:FF Ball 88.8 mph; 3:FF Called Strike 88.0 mph; 4:SI In play, out(s) 89.9 mph. Description: Jackson Chourio lines out sharply to right fielder Jo Adell.
- PA 2 — Brice Turang vs Brent Suter: field_out; outs 1→2; runs=0; pitches=5. Sequence: 1:FF Ball 89.1 mph; 2:SL Called Strike 77.2 mph; 3:SL Called Strike 78.3 mph; 4:FF Foul 90.1 mph; 5:SI In play, out(s) 90.5 mph. Description: Brice Turang flies out to left fielder Jose Siri.
- PA 3 — William Contreras vs Brent Suter: field_out; outs 2→3; runs=0; pitches=3. Sequence: 1:SI Ball 90.8 mph; 2:SI Swinging Strike 90.6 mph; 3:CH In play, out(s) 80.7 mph. Description: William Contreras grounds out, second baseman Vaughn Grissom to first baseman Nolan Schanuel.

### Bottom 1st — Half-Inning Card

BF=5; pitches=22; runs=1; hits=2; singles=1; XBH=1; BB=0; HBP=0; K=2; HR=0; B4/B5/B6 exposed=True/True/False; leadoff reach=False; two-out extension=True; 3-up-3-down=False. Exact PA-level sequence follows.

- PA 1 — Zach Neto vs Robert Gasser: strikeout; outs 0→1; runs=0; pitches=4. Sequence: 1:FF Foul 91.3 mph; 2:FF Swinging Strike 92.3 mph; 3:ST Ball 80.1 mph; 4:ST Swinging Strike 80.1 mph. Description: Zach Neto strikes out swinging.
- PA 2 — Mike Trout vs Robert Gasser: single; outs 1→1; runs=0; pitches=4. Sequence: 1:FF Called Strike 92.3 mph; 2:CH Foul 88.2 mph; 3:FF Foul 93.8 mph; 4:ST In play, no out 80.9 mph. Description: Mike Trout singles on a line drive to left fielder Jackson Chourio.
- PA 3 — Nolan Schanuel vs Robert Gasser: strikeout; outs 1→2; runs=0; pitches=9. Sequence: 1:SI Ball 92.8 mph; 2:SI Called Strike 93.0 mph; 3:SI Called Strike 93.3 mph; 4:FF Ball 94.5 mph; 5:ST Foul 82.5 mph; 6:FF Foul 94.1 mph; 7:SI Foul 93.5 mph; 8:ST Ball 82.0 mph; 9:SI Called Strike 92.4 mph. Description: Nolan Schanuel challenged (pitch result), call on the field was confirmed: Nolan Schanuel called out on strikes.
- PA 4 — Jorge Soler vs Robert Gasser: double; outs 2→2; runs=1; pitches=2. Sequence: 1:FC Foul 88.8 mph; 2:FF In play, run(s) 93.5 mph. Description: Jorge Soler doubles (16) on a line drive to left fielder Jackson Chourio. Mike Trout scores.
- PA 5 — Vaughn Grissom vs Robert Gasser: field_out; outs 2→3; runs=0; pitches=3. Sequence: 1:SI Ball 92.9 mph; 2:ST Swinging Strike 81.0 mph; 3:ST In play, out(s) 80.8 mph. Description: Vaughn Grissom grounds out, third baseman Joey Ortiz to first baseman Andrew Vaughn.

### Pitch-level process and starter context

First-inning process objects: `{"608718":{"pitch_count_first_inning":12,"pitch_mix_first_inning":{"SI":5,"FF":4,"SL":2,"CH":1},"avg_release_speed_first_inning":87.02,"whiffs":1,"swings":5,"contacts":4},"688107":{"pitch_count_first_inning":22,"pitch_mix_first_inning":{"FF":7,"ST":7,"CH":1,"SI":6,"FC":1},"avg_release_speed_first_inning":88.82,"whiffs":3,"swings":13,"contacts":10}}`. These are calculated from the pitch events retained in the official first-inning GUMBO. Full-start boxscore context is retained separately in `STARTER_CONTEXT`; prior-start L3/L5/L10/L15/L20, season and career first-inning sequences are explicitly `BOUNDED_GAP` in this repair rather than fabricated. The gap does not alter the observed first-inning reconstruction.

### Feature and reliability interpretation

The game contributes all nine registry families at the GAME level: RESULTS, SEQUENCE, EXPOSURE, OUT_CREATION, TRAFFIC, DAMAGE, PITCHER_PROCESS, TOP_ORDER and CONTEXT. The observed current-game families carry high contextual support from GUMBO; historical sequence windows are low-coverage bounded objects. Press/HUMAN_INFORMATION is kept outside the pregame lane unless a publication/availability timestamp can be certified. Mechanism cohorting is retrospective and descriptive only.

### Reconstruction check

PA count top/bottom=3/5; pitch count top/bottom=12/22; first-inning score reconciliation=0+1=1. Exact event arrays and raw source hash are persisted. No missing historical window is converted to zero.

## GAME BLOCK 824972 — Detroit Tigers @ Athletics

**Identity.** GAME_PK 824972; venue Sutter Health Park; scheduled 2026-08-02T01:40:00Z; first pitch observed 2026-08-02T01:40:40.706Z; starters Framber Valdez (away) / Jack Perkins (home). Source: official MLB GUMBO `https://statsapi.mlb.com/api/v1.1/game/824972/feed/live`; capture SHA-256 `9634a1784093130fcaa93cc93176ebf7eb951ca72ae8a664b67b407bc477cc2b`.

**First-inning outcome.** Top 2, bottom 0, total 2; descriptive outcome **YRFI**. Top path `HR_INVOLVED_MULTI_MECHANISM`; bottom path `NO_RUN_PATH`. This is a historical observation, not a forecast or betting probability.

### Top 1st — Half-Inning Card

BF=7; pitches=20; runs=2; hits=4; singles=3; XBH=1; BB=0; HBP=0; K=2; HR=1; B4/B5/B6 exposed=True/True/True; leadoff reach=True; two-out extension=False; 3-up-3-down=False. Exact PA-level sequence follows.

- PA 1 — Kevin McGonigle vs Jack Perkins: home_run; outs 0→0; runs=1; pitches=3. Sequence: 1:FF Ball 95.2 mph; 2:CH Called Strike 85.7 mph; 3:FF In play, run(s) 94.4 mph. Description: Kevin McGonigle homers (11) on a fly ball to left field.
- PA 2 — Gleyber Torres vs Jack Perkins: single; outs 0→0; runs=0; pitches=1. Sequence: 1:FF In play, no out 94.9 mph. Description: Gleyber Torres singles on a ground ball to left fielder Tyler Soderstrom.
- PA 3 — Dillon Dingler vs Jack Perkins: single; outs 0→0; runs=0; pitches=2. Sequence: 1:ST Swinging Strike 86.0 mph; 2:ST In play, no out 86.1 mph. Description: Dillon Dingler singles on a line drive to left fielder Tyler Soderstrom. Gleyber Torres to 2nd.
- PA 4 — Riley Greene vs Jack Perkins: field_out; outs 0→1; runs=0; pitches=1. Sequence: 1:CH In play, out(s) 88.0 mph. Description: Riley Greene flies out to left fielder Tyler Soderstrom.
- PA 5 — Colt Keith vs Jack Perkins: single; outs 1→1; runs=1; pitches=3. Sequence: 1:FC Ball 92.1 mph; 2:CH Called Strike 89.1 mph; 3:FC In play, run(s) 91.9 mph. Description: Colt Keith singles on a ground ball to right fielder Lawrence Butler. Gleyber Torres scores. Dillon Dingler to 3rd.
- PA 6 — Spencer Torkelson vs Jack Perkins: strikeout; outs 1→2; runs=0; pitches=4. Sequence: 1:FC Ball 91.8 mph; 2:SI Swinging Strike 94.5 mph; 3:FC Swinging Strike 91.6 mph; 4:ST Swinging Strike 85.8 mph. Description: Spencer Torkelson strikes out swinging.
- PA 7 — Max Clark vs Jack Perkins: strikeout; outs 2→3; runs=0; pitches=6. Sequence: 1:FC Foul 92.7 mph; 2:CH Called Strike 88.8 mph; 3:FF Ball 96.1 mph; 4:ST Foul 86.3 mph; 5:ST Foul 85.8 mph; 6:FF Swinging Strike 95.5 mph. Description: Max Clark strikes out swinging.

### Bottom 1st — Half-Inning Card

BF=5; pitches=16; runs=0; hits=2; singles=2; XBH=0; BB=0; HBP=0; K=1; HR=0; B4/B5/B6 exposed=True/True/False; leadoff reach=False; two-out extension=True; 3-up-3-down=False. Exact PA-level sequence follows.

- PA 1 — Jacob Wilson vs Framber Valdez: field_out; outs 0→1; runs=0; pitches=5. Sequence: 1:SI Ball 94.0 mph; 2:SI Ball 95.0 mph; 3:SI Called Strike 93.3 mph; 4:CU Foul 77.7 mph; 5:SI In play, out(s) 93.9 mph. Description: Jacob Wilson grounds out to first baseman Spencer Torkelson.
- PA 2 — Jonah Heim vs Framber Valdez: strikeout; outs 1→2; runs=0; pitches=5. Sequence: 1:CU Called Strike 77.4 mph; 2:FF Swinging Strike 94.7 mph; 3:FF Foul 94.6 mph; 4:CU Ball 78.5 mph; 5:CU Swinging Strike 79.2 mph. Description: Jonah Heim strikes out swinging.
- PA 3 — Tyler Soderstrom vs Framber Valdez: single; outs 2→2; runs=0; pitches=2. Sequence: 1:SL Called Strike 84.3 mph; 2:SI In play, no out 95.3 mph. Description: Tyler Soderstrom singles on a ground ball to left fielder Riley Greene.
- PA 4 — Tommy White vs Framber Valdez: single; outs 2→2; runs=0; pitches=3. Sequence: 1:SI Called Strike 93.4 mph; 2:CH Foul 87.5 mph; 3:FF In play, no out 94.6 mph. Description: Tommy White singles on a line drive to right fielder Zach McKinstry. Tyler Soderstrom to 3rd.
- PA 5 — Lawrence Butler vs Framber Valdez: field_out; outs 2→3; runs=0; pitches=1. Sequence: 1:SI In play, out(s) 94.6 mph. Description: Lawrence Butler grounds out to first baseman Spencer Torkelson.

### Pitch-level process and starter context

First-inning process objects: `{"678022":{"pitch_count_first_inning":20,"pitch_mix_first_inning":{"FF":5,"CH":4,"ST":5,"FC":5,"SI":1},"avg_release_speed_first_inning":90.61,"whiffs":5,"swings":13,"contacts":8},"664285":{"pitch_count_first_inning":16,"pitch_mix_first_inning":{"SI":7,"CU":4,"FF":3,"SL":1,"CH":1},"avg_release_speed_first_inning":89.25,"whiffs":2,"swings":9,"contacts":7}}`. These are calculated from the pitch events retained in the official first-inning GUMBO. Full-start boxscore context is retained separately in `STARTER_CONTEXT`; prior-start L3/L5/L10/L15/L20, season and career first-inning sequences are explicitly `BOUNDED_GAP` in this repair rather than fabricated. The gap does not alter the observed first-inning reconstruction.

### Feature and reliability interpretation

The game contributes all nine registry families at the GAME level: RESULTS, SEQUENCE, EXPOSURE, OUT_CREATION, TRAFFIC, DAMAGE, PITCHER_PROCESS, TOP_ORDER and CONTEXT. The observed current-game families carry high contextual support from GUMBO; historical sequence windows are low-coverage bounded objects. Press/HUMAN_INFORMATION is kept outside the pregame lane unless a publication/availability timestamp can be certified. Mechanism cohorting is retrospective and descriptive only.

### Reconstruction check

PA count top/bottom=7/5; pitch count top/bottom=20/16; first-inning score reconciliation=2+0=2. Exact event arrays and raw source hash are persisted. No missing historical window is converted to zero.


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

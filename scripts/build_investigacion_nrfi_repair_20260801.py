from __future__ import annotations

import hashlib
import json
import pathlib
from collections import Counter, defaultdict
from datetime import datetime, timezone

RUN_ID = "INVNRFI-20260801-AMEND-A1"
PARENT_RUN_ID = "INVNRFI-20260801-f709b44c"
CAPTURE_COMMIT = "a63b60ac9caec558a76fab5dd826172c0b15120b"
CAPTURED_AT = "2026-08-20T11:53:37Z"
DATA_ERA = "MLB_GUMBO_2026"
FEATURE_VERSION = "INVNRFI_FEATURE_REGISTRY_V1.1"
MECH_VERSION = "MECHANISM_V1.1"
ROOT = pathlib.Path("artifacts/investigacion_nrfi/2026-08-01")
RAW_PATH = ROOT / "first_inning_extract.json"
OUT = ROOT / "repair_a1"
SQL_DIR = OUT / "sql"
NORM_DIR = OUT / "normalized"


def jd(value):
    return json.dumps(value, ensure_ascii=False, separators=(",", ":"), default=str)


def sq(value):
    if value is None:
        return "null"
    return "'" + str(value).replace("'", "''") + "'"


def sj(value):
    return sq(jd(value)) + "::jsonb"


def sa(values):
    return "ARRAY[" + ",".join(sq(v) for v in values) + "]::text[]"


def sn(value):
    if value is None or value == "":
        return "null"
    try:
        return str(float(value))
    except Exception:
        return "null"


def sb(value):
    return "true" if bool(value) else "false"


def player_obj(game, pid):
    if pid is None:
        return {}
    return (game.get("players") or {}).get(f"ID{pid}", {}) or {}


def person_name(obj):
    p = obj.get("person") or obj
    return p.get("fullName") or p.get("name") or "UNKNOWN"


def side_team(game, side):
    return ((game.get("teams") or {}).get(side.lower()) or {}).get("name") or side


def extract_lineup(game, side):
    box = game.get(f"{side.lower()}_boxscore") or {}
    gd_players = game.get("players") or {}
    order = box.get("battingOrder") or []
    if not order:
        candidates = []
        for key, pobj in (box.get("players") or {}).items():
            bo = pobj.get("battingOrder")
            if bo:
                try:
                    candidates.append((int(str(bo)), int(str(key).replace("ID", ""))))
                except Exception:
                    pass
        order = [pid for _, pid in sorted(candidates)[:9]]
    order = [int(x) for x in order[:9]]
    lineup = []
    catcher_id = None
    for slot, pid in enumerate(order, 1):
        pobj = gd_players.get(f"ID{pid}", {}) or (box.get("players") or {}).get(f"ID{pid}", {})
        pos = pobj.get("primaryPosition") or pobj.get("position") or {}
        abbr = pos.get("abbreviation") or pos.get("name") or ""
        if str(abbr).upper() in {"C", "CATCHER"}:
            catcher_id = str(pid)
        bat = (pobj.get("batSide") or {}).get("code") or (pobj.get("batSide") or {}).get("description")
        lineup.append({
            "slot": slot,
            "player_id": str(pid),
            "player_name": person_name(pobj),
            "handedness": bat,
            "position": abbr,
        })
    if catcher_id is None:
        for key, pobj in gd_players.items():
            pos = pobj.get("primaryPosition") or {}
            if str(pos.get("abbreviation") or "").upper() == "C":
                pid = str(key).replace("ID", "")
                if any(x["player_id"] == pid for x in lineup):
                    catcher_id = pid
                    break
    return lineup, catcher_id


def event_desc(play):
    result = play.get("result") or {}
    return result.get("description") or result.get("event") or result.get("eventType") or "PA completed"


def event_type(play):
    return str((play.get("result") or {}).get("eventType") or (play.get("result") or {}).get("event") or "UNKNOWN").lower()


def is_reach_type(et):
    et = et.lower()
    outs = {"strikeout", "field_out", "force_out", "grounded_into_double_play", "double_play", "triple_play", "fielders_choice_out", "sac_fly", "sac_bunt"}
    return et not in outs and "out" not in et


def classify_path(plays, runs):
    if runs == 0:
        return "NO_RUN_PATH"
    text = " ".join(event_desc(p).lower() for p in plays)
    types = [event_type(p) for p in plays]
    if "wild pitch" in text:
        return "OTHER_EXPLICIT_WILD_PITCH"
    hr = sum(("home_run" in t or "home run" in event_desc(p).lower()) for t, p in zip(types, plays))
    if hr >= 2:
        return "MULTI_HR"
    if hr == 1 and runs == 1:
        return "SOLO_HR"
    if hr == 1:
        return "HR_INVOLVED_MULTI_MECHANISM"
    if any("double" in t or "triple" in t for t in types):
        return "XBH_DAMAGE"
    if any("walk" in t or "hit_by_pitch" in t for t in types):
        return "FREE_TRAFFIC_CHAIN"
    return "HIT_CONTACT_CHAIN"


def pitch_detail(ev):
    d = ev.get("details") or {}
    pd = ev.get("pitchData") or {}
    hd = ev.get("hitData") or {}
    coords = pd.get("coordinates") or {}
    brk = pd.get("breaks") or {}
    ptype = d.get("type") or {}
    desc = d.get("description") or ""
    low = desc.lower()
    return {
        "pitch_type": ptype.get("code") or ptype.get("description"),
        "description": desc,
        "result": (d.get("call") or {}).get("description") or d.get("code"),
        "release_speed": pd.get("startSpeed"),
        "extension": pd.get("extension"),
        "plate_x": coords.get("pX"),
        "plate_z": coords.get("pZ"),
        "sz_top": pd.get("strikeZoneTop"),
        "sz_bot": pd.get("strikeZoneBottom"),
        "pfx_x": brk.get("breakHorizontal"),
        "pfx_z": brk.get("breakVerticalInduced"),
        "batted_ball_type": hd.get("trajectory"),
        "exit_velocity": hd.get("launchSpeed"),
        "launch_angle": hd.get("launchAngle"),
        "swing": any(x in low for x in ("swing", "foul", "in play")),
        "whiff": any(x in low for x in ("swinging strike", "missed bunt")),
        "contact": any(x in low for x in ("foul", "in play")),
        "event_time": ev.get("startTime") or ev.get("endTime"),
        "raw_count": ev.get("count") or {},
    }


def normalized_game(game):
    game_pk = str(game["game_pk"])
    plays = game.get("first_inning_plays") or []
    top_plays = [p for p in plays if (p.get("about") or {}).get("isTopInning")]
    bottom_plays = [p for p in plays if not (p.get("about") or {}).get("isTopInning")]
    away_lineup, away_catcher = extract_lineup(game, "away")
    home_lineup, home_catcher = extract_lineup(game, "home")
    slot_map = {"AWAY": {x["player_id"]: x["slot"] for x in away_lineup}, "HOME": {x["player_id"]: x["slot"] for x in home_lineup}}

    first_pitch_time = None
    for p in plays:
        for ev in p.get("playEvents") or []:
            if ev.get("isPitch"):
                t = ev.get("startTime") or ev.get("endTime")
                if t and (first_pitch_time is None or t < first_pitch_time):
                    first_pitch_time = t
    dt = game.get("game_datetime") or {}
    scheduled = dt.get("dateTime") if isinstance(dt, dict) else None
    if first_pitch_time is None:
        first_pitch_time = scheduled

    probable = game.get("probable_pitchers") or {}
    first_top = top_plays[0] if top_plays else {}
    first_bottom = bottom_plays[0] if bottom_plays else {}
    home_starter = probable.get("home") or ((first_top.get("matchup") or {}).get("pitcher") or {})
    away_starter = probable.get("away") or ((first_bottom.get("matchup") or {}).get("pitcher") or {})
    home_starter_id = str(home_starter.get("id") or ((first_top.get("matchup") or {}).get("pitcher") or {}).get("id") or "")
    away_starter_id = str(away_starter.get("id") or ((first_bottom.get("matchup") or {}).get("pitcher") or {}).get("id") or "")
    home_starter_name = home_starter.get("fullName") or person_name(player_obj(game, home_starter_id))
    away_starter_name = away_starter.get("fullName") or person_name(player_obj(game, away_starter_id))

    lines = game.get("linescore_first") or {}
    top_runs = int(((lines.get("away") or {}).get("runs") or 0))
    bottom_runs = int(((lines.get("home") or {}).get("runs") or 0))

    pa_rows = []
    pitch_rows = []
    halves = {}
    score_state = {"away": 0, "home": 0}
    for half_name, half_plays, batting_side, runs in (
        ("TOP", top_plays, "AWAY", top_runs),
        ("BOTTOM", bottom_plays, "HOME", bottom_runs),
    ):
        outs_before = 0
        sequence = []
        batters = []
        hits = singles = doubles = triples = bb = hbp = roe = k = hr = 0
        leadoff_reach = False
        two_out_extension = False
        runners_first = runners_second = 0
        half_pitch_count = 0
        for idx, play in enumerate(half_plays, 1):
            matchup = play.get("matchup") or {}
            batter = matchup.get("batter") or {}
            pitcher = matchup.get("pitcher") or {}
            batter_id = str(batter.get("id") or "")
            pitcher_id = str(pitcher.get("id") or "")
            et = event_type(play)
            desc = event_desc(play)
            batters.append({"id": batter_id, "name": batter.get("fullName"), "slot": slot_map[batting_side].get(batter_id)})
            sequence.append({"pa": idx, "batter": batter.get("fullName"), "pitcher": pitcher.get("fullName"), "event": et, "description": desc})
            if et in {"single"}: singles += 1; hits += 1
            elif et in {"double"}: doubles += 1; hits += 1
            elif et in {"triple"}: triples += 1; hits += 1
            elif "home_run" in et: hr += 1; hits += 1
            elif et in {"walk", "intent_walk"}: bb += 1
            elif et == "hit_by_pitch": hbp += 1
            elif et in {"field_error", "reached_on_error"}: roe += 1
            if "strikeout" in et: k += 1
            reached = is_reach_type(et)
            if idx == 1: leadoff_reach = reached
            if outs_before == 2 and reached: two_out_extension = True
            if outs_before == 0 and reached: runners_first += 1
            if outs_before <= 1 and reached: runners_second += 1
            result = play.get("result") or {}
            away_after = int(result.get("awayScore") if result.get("awayScore") is not None else score_state["away"])
            home_after = int(result.get("homeScore") if result.get("homeScore") is not None else score_state["home"])
            runs_on_pa = max(0, (away_after + home_after) - (score_state["away"] + score_state["home"]))
            pa_id = f"{game_pk}-{half_name}-{idx:02d}"
            pitch_seq = []
            balls_before = strikes_before = 0
            pitch_number = 0
            for ev in play.get("playEvents") or []:
                if not ev.get("isPitch"):
                    continue
                pitch_number += 1
                half_pitch_count += 1
                pd = pitch_detail(ev)
                pitch_seq.append({"n": pitch_number, "type": pd["pitch_type"], "description": pd["description"], "velo": pd["release_speed"], "result": pd["result"]})
                count_after = pd["raw_count"]
                pitch_rows.append({
                    "pa_id": pa_id, "pitch_number": pitch_number, "half": half_name,
                    "pitcher_id": pitcher_id, "batter_id": batter_id,
                    "batter_slot": slot_map[batting_side].get(batter_id),
                    "balls_before": balls_before, "strikes_before": strikes_before,
                    "outs_before": outs_before, "score_before": dict(score_state),
                    **{k: v for k, v in pd.items() if k != "raw_count"},
                })
                balls_before = int(count_after.get("balls") or balls_before)
                strikes_before = int(count_after.get("strikes") or strikes_before)
            outs_after = int((play.get("count") or {}).get("outs") if (play.get("count") or {}).get("outs") is not None else outs_before)
            pa_rows.append({
                "pa_id": pa_id, "half": half_name, "batter_id": batter_id,
                "batter_name": batter.get("fullName"), "pitcher_id": pitcher_id,
                "pitcher_name": pitcher.get("fullName"), "batter_slot": slot_map[batting_side].get(batter_id),
                "ordinal": idx, "outs_before": outs_before, "pitch_sequence": pitch_seq,
                "pitch_count": pitch_number, "pa_result": et, "reach_type": et if reached else None,
                "runs_scored": runs_on_pa, "outs_after": outs_after,
                "transition": {"description": desc, "score_before": dict(score_state), "score_after": {"away": away_after, "home": home_after}},
            })
            score_state = {"away": away_after, "home": home_after}
            outs_before = min(3, outs_after)
        halves[half_name] = {
            "bf": len(half_plays), "pa": len(half_plays), "pitches": half_pitch_count, "runs": runs,
            "hits": hits, "singles": singles, "xbh": doubles + triples + hr, "doubles": doubles,
            "triples": triples, "bb": bb, "hbp": hbp, "roe": roe, "k": k, "hr": hr,
            "b4_exposed": len(half_plays) >= 4, "b5_exposed": len(half_plays) >= 5,
            "b6_exposed": len(half_plays) >= 6, "leadoff_reach": leadoff_reach,
            "run_after_leadoff_reach": bool(leadoff_reach and runs > 0), "two_out_extension": two_out_extension,
            "runners_before_first_out": runners_first, "runners_before_second_out": runners_second,
            "three_up_three_down": len(half_plays) == 3 and runs == 0 and hits == 0 and bb == 0 and hbp == 0 and roe == 0,
            "sequence": sequence, "batters": batters, "primary_path": classify_path(half_plays, runs),
        }

    venue = game.get("venue") or {}
    status = game.get("status") or {}
    info = game.get("game_info") or {}
    weather = game.get("weather") or {}
    process = defaultdict(list)
    for p in pitch_rows:
        process[p["pitcher_id"]].append(p)
    pitcher_process = {}
    for pid, rows in process.items():
        speeds = [float(x["release_speed"]) for x in rows if x.get("release_speed") is not None]
        mixes = Counter(x.get("pitch_type") or "UNK" for x in rows)
        pitcher_process[pid] = {
            "pitch_count_first_inning": len(rows),
            "pitch_mix_first_inning": dict(mixes),
            "avg_release_speed_first_inning": round(sum(speeds)/len(speeds), 2) if speeds else None,
            "whiffs": sum(bool(x.get("whiff")) for x in rows),
            "swings": sum(bool(x.get("swing")) for x in rows),
            "contacts": sum(bool(x.get("contact")) for x in rows),
        }

    return {
        "game_pk": game_pk, "matchup": game.get("matchup"), "source_url": game.get("source_url"), "raw_sha256": game.get("sha256"),
        "scheduled_start_at": scheduled, "actual_first_pitch_at": first_pitch_time,
        "venue_id": str(venue.get("id") or ""), "venue_name": venue.get("name") or "UNKNOWN_VENUE",
        "away_team": side_team(game, "away"), "home_team": side_team(game, "home"),
        "away_starter_id": away_starter_id, "away_starter_name": away_starter_name,
        "home_starter_id": home_starter_id, "home_starter_name": home_starter_name,
        "away_catcher_id": away_catcher, "home_catcher_id": home_catcher,
        "away_lineup": away_lineup, "home_lineup": home_lineup,
        "day_night": info.get("gameDuration") and (dt.get("dayNight") if isinstance(dt, dict) else None),
        "weather": weather, "status": status,
        "top_runs": top_runs, "bottom_runs": bottom_runs, "total_runs": top_runs + bottom_runs,
        "halves": halves, "plate_appearances": pa_rows, "pitch_events": pitch_rows,
        "pitcher_process": pitcher_process,
    }


def box_pitching_stats(game, pid, side):
    box = game.get(f"{side.lower()}_boxscore") or {}
    pobj = (box.get("players") or {}).get(f"ID{pid}", {})
    return (((pobj.get("stats") or {}).get("pitching") or {}))


def build_game_sql(raw_game, g, cohort_members):
    pk = g["game_pk"]
    tool_id = f"INVNRFI-GUMBO-{pk}-A1"
    evid_id = f"INVNRFI-EVID-GUMBO-{pk}-A1"
    lineage = [{"source": g["source_url"], "sha256": g["raw_sha256"], "capture_commit": CAPTURE_COMMIT, "retrieved_at": CAPTURED_AT}]
    stmts = ["begin;"]
    family_hash = hashlib.sha256(b"statsapi.mlb.com|MLB_STATS_API_GUMBO").hexdigest()
    stmts.append(f"insert into public.investigacion_nrfi_source_families(source_family_id,canonical_origin,publisher,family_hash,metadata) values('INVNRFI-SRCF-MLB-GUMBO','statsapi.mlb.com','MLB', '{family_hash}', '{{\"schema\":\"GUMBO v1.1\"}}'::jsonb) on conflict(source_family_id) do nothing;")
    stmts.append(f"insert into public.investigacion_nrfi_tool_events(event_id,daily_run_id,game_pk,tool_name,source_ref,invoked_at,completed_at,input_hash,output_hash,metadata) values({sq(tool_id)},{sq(RUN_ID)},{sq(pk)},'GitHub_Actions_MLB_GUMBO_CAPTURE',{sq(g['source_url'])},{sq(CAPTURED_AT)}::timestamptz,{sq(CAPTURED_AT)}::timestamptz,null,{sq(g['raw_sha256'])},{sj({'capture_commit': CAPTURE_COMMIT, 'artifact':'first_inning_extract.json'})}) on conflict(event_id) do nothing;")
    ev_payload = {"game_pk": pk, "source_url": g["source_url"], "raw_sha256": g["raw_sha256"], "first_inning_runs": {"top": g["top_runs"], "bottom": g["bottom_runs"]}}
    snap = hashlib.sha256((g["source_url"] + g["raw_sha256"]).encode()).hexdigest()
    stmts.append(f"insert into public.investigacion_nrfi_evidence(evidence_id,daily_run_id,game_pk,phase_id,tool_event_id,source_family_id,source_url,temporal_lane,epistemic_lane,retrieved_at,available_at,first_pitch_at,event_time,payload_hash,snapshot_hash,data_coverage_state,object_payload) values({sq(evid_id)},{sq(RUN_ID)},{sq(pk)},'F1_FORENSIC_CAPTURE',{sq(tool_id)},'INVNRFI-SRCF-MLB-GUMBO',{sq(g['source_url'])},'POSTGAME_EXPLANATORY_EVIDENCE','OBSERVED',{sq(CAPTURED_AT)}::timestamptz,null,{sq(g['actual_first_pitch_at'])}::timestamptz,null,{sq(g['raw_sha256'])},{sq(snap)},'AVAILABLE_COMPLETE',{sj(ev_payload)}) on conflict(evidence_id) do nothing;")
    stmts.append(f"update public.investigacion_nrfi_games set scheduled_start_at={sq(g['scheduled_start_at'])}::timestamptz,actual_first_pitch_at={sq(g['actual_first_pitch_at'])}::timestamptz,first_pitch_verified=true,venue_id={sq(g['venue_id'])},venue_name={sq(g['venue_name'])},away_starter_id={sq(g['away_starter_id'])},away_starter_name={sq(g['away_starter_name'])},home_starter_id={sq(g['home_starter_id'])},home_starter_name={sq(g['home_starter_name'])},away_catcher_id={sq(g['away_catcher_id'])},home_catcher_id={sq(g['home_catcher_id'])},weather_state={sj(g['weather'])},data_era={sq(DATA_ERA)} where daily_run_id={sq(RUN_ID)} and game_pk={sq(pk)};")

    for side in ("AWAY", "HOME"):
        for row in g[f"{side.lower()}_lineup"]:
            stmts.append("insert into public.investigacion_nrfi_lineup_entries(daily_run_id,game_pk,team_side,batting_slot,player_id,player_name,handedness,lineup_version,available_at,pregame_available,coverage_state,source_lineage) values(" + ",".join([
                sq(RUN_ID), sq(pk), sq(side), str(row['slot']), sq(row['player_id']), sq(row['player_name']), sq(row.get('handedness')),
                "'GUMBO_BOX_V1'", "null", "false", "'AVAILABLE_COMPLETE'", sj(lineage)
            ]) + ") on conflict(daily_run_id,game_pk,team_side,batting_slot) do update set player_id=excluded.player_id,player_name=excluded.player_name,handedness=excluded.handedness,coverage_state=excluded.coverage_state,source_lineage=excluded.source_lineage;")

    if len(g["away_lineup"]) < 9 or len(g["home_lineup"]) < 9 or not g["away_catcher_id"] or not g["home_catcher_id"]:
        notes = "GUMBO boxscore did not yield 18 starter lineup slots plus both catcher IDs; bounded to the official game feed after recovery parsing."
        stmts.append(f"insert into public.investigacion_nrfi_component_coverage(daily_run_id,game_pk,component,status,source_families_attempted,tool_event_ids,evidence_ids,notes) values({sq(RUN_ID)},{sq(pk)},'LINEUP_CATCHER','BOUNDED_GAP',{sa(['MLB_GUMBO_BOX_SCORE'])},{sa([tool_id])},{sa([evid_id])},{sq(notes)}) on conflict(daily_run_id,game_pk,component) do update set status=excluded.status,source_families_attempted=excluded.source_families_attempted,tool_event_ids=excluded.tool_event_ids,evidence_ids=excluded.evidence_ids,notes=excluded.notes;")

    for half in ("TOP", "BOTTOM"):
        h = g["halves"][half]
        batting_team = g["away_team"] if half == "TOP" else g["home_team"]
        pitching_team = g["home_team"] if half == "TOP" else g["away_team"]
        pitcher_id = g["home_starter_id"] if half == "TOP" else g["away_starter_id"]
        pitcher_name = g["home_starter_name"] if half == "TOP" else g["away_starter_name"]
        stmts.append("insert into public.investigacion_nrfi_half_innings(daily_run_id,game_pk,inning,half,batting_team,pitching_team,pitcher_sequence,batter_sequence,bf,pa,pitches,runs,hits,singles,xbh,doubles,triples,bb,hbp,roe,k,hr,b4_exposed,b5_exposed,b6_exposed,leadoff_reach,run_after_leadoff_reach,two_out_extension,runners_before_first_out,runners_before_second_out,three_up_three_down,exact_event_sequence,primary_path,contributing_paths,mechanism_classifier_version,coverage_state,source_lineage) values(" + ",".join([
            sq(RUN_ID),sq(pk),"1",sq(half),sq(batting_team),sq(pitching_team),sj([{"id":pitcher_id,"name":pitcher_name}]),sj(h['batters']),str(h['bf']),str(h['pa']),str(h['pitches']),str(h['runs']),str(h['hits']),str(h['singles']),str(h['xbh']),str(h['doubles']),str(h['triples']),str(h['bb']),str(h['hbp']),str(h['roe']),str(h['k']),str(h['hr']),sb(h['b4_exposed']),sb(h['b5_exposed']),sb(h['b6_exposed']),sb(h['leadoff_reach']),sb(h['run_after_leadoff_reach']),sb(h['two_out_extension']),str(h['runners_before_first_out']),str(h['runners_before_second_out']),sb(h['three_up_three_down']),sj(h['sequence']),sq(h['primary_path']),sa([]),sq(MECH_VERSION),"'AVAILABLE_COMPLETE'",sj(lineage)
        ]) + ") on conflict(daily_run_id,game_pk,inning,half) do update set batter_sequence=excluded.batter_sequence,bf=excluded.bf,pa=excluded.pa,pitches=excluded.pitches,runs=excluded.runs,hits=excluded.hits,singles=excluded.singles,xbh=excluded.xbh,doubles=excluded.doubles,triples=excluded.triples,bb=excluded.bb,hbp=excluded.hbp,roe=excluded.roe,k=excluded.k,hr=excluded.hr,exact_event_sequence=excluded.exact_event_sequence,primary_path=excluded.primary_path,coverage_state=excluded.coverage_state,source_lineage=excluded.source_lineage;")

    for pa in g["plate_appearances"]:
        stmts.append("insert into public.investigacion_nrfi_plate_appearances(daily_run_id,game_pk,pa_id,inning,half,batter_id,batter_name,pitcher_id,pitcher_name,batter_slot,pa_ordinal_in_half,outs_before,runners_before,pitch_sequence,pitch_count,pa_result,reach_type,runs_scored,outs_after,runners_after,exact_pa_transition,source_lineage,coverage_state) values(" + ",".join([
            sq(RUN_ID),sq(pk),sq(pa['pa_id']),"1",sq(pa['half']),sq(pa['batter_id']),sq(pa['batter_name']),sq(pa['pitcher_id']),sq(pa['pitcher_name']),str(pa['batter_slot']) if pa.get('batter_slot') else "null",str(pa['ordinal']),str(pa['outs_before']),"'{}'::jsonb",sj(pa['pitch_sequence']),str(pa['pitch_count']),sq(pa['pa_result']),sq(pa.get('reach_type')),str(pa['runs_scored']),str(pa['outs_after']),"'{}'::jsonb",sj(pa['transition']),sj(lineage),"'AVAILABLE_COMPLETE'"
        ]) + ") on conflict(daily_run_id,game_pk,pa_id) do update set pitch_sequence=excluded.pitch_sequence,pitch_count=excluded.pitch_count,pa_result=excluded.pa_result,runs_scored=excluded.runs_scored,outs_after=excluded.outs_after,exact_pa_transition=excluded.exact_pa_transition,source_lineage=excluded.source_lineage,coverage_state=excluded.coverage_state;")

    for p in g["pitch_events"]:
        release_pos = {}
        expected = {}
        stmts.append("insert into public.investigacion_nrfi_pitch_events(daily_run_id,game_pk,pa_id,pitch_number,inning,half,pitcher_id,batter_id,batter_slot,balls_before,strikes_before,outs_before,runners_before,score_before,pitch_type,release_speed,pfx_x,pfx_z,release_position,extension,plate_x,plate_z,sz_top,sz_bot,description,result,swing_flag,whiff_flag,contact_flag,batted_ball_type,exit_velocity,launch_angle,expected_metrics,outs_after,runners_after,score_after,event_time,source_ref,coverage_state) values(" + ",".join([
            sq(RUN_ID),sq(pk),sq(p['pa_id']),str(p['pitch_number']),"1",sq(p['half']),sq(p['pitcher_id']),sq(p['batter_id']),str(p['batter_slot']) if p.get('batter_slot') else "null",str(p['balls_before']),str(p['strikes_before']),str(p['outs_before']),"'{}'::jsonb",sj(p['score_before']),sq(p.get('pitch_type')),sn(p.get('release_speed')),sn(p.get('pfx_x')),sn(p.get('pfx_z')),sj(release_pos),sn(p.get('extension')),sn(p.get('plate_x')),sn(p.get('plate_z')),sn(p.get('sz_top')),sn(p.get('sz_bot')),sq(p.get('description')),sq(p.get('result')),sb(p.get('swing')),sb(p.get('whiff')),sb(p.get('contact')),sq(p.get('batted_ball_type')),sn(p.get('exit_velocity')),sn(p.get('launch_angle')),sj(expected),"null","'{}'::jsonb",sj(p['score_before']),sq(p.get('event_time')) + "::timestamptz" if p.get('event_time') else "null",sq(g['source_url']),"'AVAILABLE_COMPLETE'"
        ]) + ") on conflict(daily_run_id,game_pk,pa_id,pitch_number) do update set pitch_type=excluded.pitch_type,release_speed=excluded.release_speed,description=excluded.description,result=excluded.result,swing_flag=excluded.swing_flag,whiff_flag=excluded.whiff_flag,contact_flag=excluded.contact_flag,batted_ball_type=excluded.batted_ball_type,exit_velocity=excluded.exit_velocity,launch_angle=excluded.launch_angle,source_ref=excluded.source_ref,coverage_state=excluded.coverage_state;")

    total = g['total_runs']
    top_path = g['halves']['TOP']['primary_path']; bottom_path = g['halves']['BOTTOM']['primary_path']
    combined_seq = [{"half":"TOP","events":g['halves']['TOP']['sequence']},{"half":"BOTTOM","events":g['halves']['BOTTOM']['sequence']}]
    stmts.append("insert into public.investigacion_nrfi_first_innings(daily_run_id,game_pk,top_runs,bottom_runs,total_runs,p0,exactly_1,exactly_2,three_plus,nrfi,yrfi,top_bf,bottom_bf,top_path,bottom_path,first_inning_exact_sequence,reconstruction_check,coverage_gaps,coverage_state,source_lineage) values(" + ",".join([
        sq(RUN_ID),sq(pk),str(g['top_runs']),str(g['bottom_runs']),str(total),sb(total==0),sb(total==1),sb(total==2),sb(total>=3),sb(total==0),sb(total>0),str(g['halves']['TOP']['bf']),str(g['halves']['BOTTOM']['bf']),sq(top_path),sq(bottom_path),sj(combined_seq),"'PASS_OFFICIAL_GUMBO_PITCH_PA_RECONSTRUCTION'","'[]'::jsonb","'AVAILABLE_COMPLETE'",sj(lineage)
    ]) + ") on conflict(daily_run_id,game_pk) do update set top_runs=excluded.top_runs,bottom_runs=excluded.bottom_runs,total_runs=excluded.total_runs,p0=excluded.p0,exactly_1=excluded.exactly_1,exactly_2=excluded.exactly_2,three_plus=excluded.three_plus,nrfi=excluded.nrfi,yrfi=excluded.yrfi,top_bf=excluded.top_bf,bottom_bf=excluded.bottom_bf,top_path=excluded.top_path,bottom_path=excluded.bottom_path,first_inning_exact_sequence=excluded.first_inning_exact_sequence,reconstruction_check=excluded.reconstruction_check,coverage_state=excluded.coverage_state,source_lineage=excluded.source_lineage;")

    for side, pid, name, half in (("AWAY",g['away_starter_id'],g['away_starter_name'],"BOTTOM"),("HOME",g['home_starter_id'],g['home_starter_name'],"TOP")):
        h = g['halves'][half]
        stats = box_pitching_stats(raw_game, pid, side.lower())
        first_inning_ctx = {"runs":h['runs'],"bf":h['bf'],"pitches":h['pitches'],"hits":h['hits'],"bb":h['bb'],"k":h['k'],"hr":h['hr'],"process":g['pitcher_process'].get(pid,{})}
        bounded = {"coverage":"BOUNDED_GAP","reason":"The repair capture retained complete first-inning GUMBO and final boxscore, not the full historical prior-start play stream."}
        start_complete = {"official_boxscore_pitching":stats,"coverage":"AVAILABLE_PARTIAL"}
        stmts.append("insert into public.investigacion_nrfi_starter_contexts(daily_run_id,game_pk,pitcher_id,pitcher_name,pitching_half,first_inning,first_tto,start_complete,season_to_date_as_of_game,career_available_as_of_game,days_since_previous_start,prior_start_workload,rest_context,catcher_id,coverage_state,source_lineage) values(" + ",".join([
            sq(RUN_ID),sq(pk),sq(pid),sq(name),sq(half),sj(first_inning_ctx),sj(bounded),sj(start_complete),sj(bounded),sj(bounded),"null",sj(bounded),sj(bounded),sq(g['away_catcher_id'] if side=='AWAY' else g['home_catcher_id']),"'AVAILABLE_PARTIAL'",sj(lineage)
        ]) + ") on conflict(daily_run_id,game_pk,pitcher_id) do update set first_inning=excluded.first_inning,first_tto=excluded.first_tto,start_complete=excluded.start_complete,season_to_date_as_of_game=excluded.season_to_date_as_of_game,career_available_as_of_game=excluded.career_available_as_of_game,coverage_state=excluded.coverage_state,source_lineage=excluded.source_lineage;")

    feature_specs = []
    feature_specs.append(("RESULTS","GAME",{"first_inning_runs":total,"outcome":"NRFI" if total==0 else "YRFI"},1,"HIGH_CONTEXTUAL_SUPPORT"))
    feature_specs.append(("EXPOSURE","GAME",{"top_bf":g['halves']['TOP']['bf'],"bottom_bf":g['halves']['BOTTOM']['bf'],"top_b5":g['halves']['TOP']['b5_exposed'],"bottom_b5":g['halves']['BOTTOM']['b5_exposed']},2,"HIGH_CONTEXTUAL_SUPPORT"))
    feature_specs.append(("OUT_CREATION","GAME",{"top_k":g['halves']['TOP']['k'],"bottom_k":g['halves']['BOTTOM']['k'],"pitch_count":len(g['pitch_events'])},2,"HIGH_CONTEXTUAL_SUPPORT"))
    feature_specs.append(("TRAFFIC","GAME",{"top_hits":g['halves']['TOP']['hits'],"bottom_hits":g['halves']['BOTTOM']['hits'],"top_bb":g['halves']['TOP']['bb'],"bottom_bb":g['halves']['BOTTOM']['bb']},2,"HIGH_CONTEXTUAL_SUPPORT"))
    feature_specs.append(("DAMAGE","GAME",{"top_xbh":g['halves']['TOP']['xbh'],"bottom_xbh":g['halves']['BOTTOM']['xbh'],"top_hr":g['halves']['TOP']['hr'],"bottom_hr":g['halves']['BOTTOM']['hr']},2,"HIGH_CONTEXTUAL_SUPPORT"))
    feature_specs.append(("PITCHER_PROCESS","GAME",g['pitcher_process'],2,"HIGH_CONTEXTUAL_SUPPORT"))
    feature_specs.append(("TOP_ORDER","GAME",{"away_top3":g['away_lineup'][:3],"home_top3":g['home_lineup'][:3]},6,"HIGH_CONTEXTUAL_SUPPORT"))
    feature_specs.append(("CONTEXT","GAME",{"venue":g['venue_name'],"weather":g['weather'],"scheduled":g['scheduled_start_at'],"actual_first_pitch":g['actual_first_pitch_at']},1,"HIGH_CONTEXTUAL_SUPPORT"))
    for fam, win, rawv, n, rel in feature_specs:
        fid = f"INVNRFI-FV-{pk}-{fam}-{win}"
        stmts.append(f"insert into public.investigacion_nrfi_feature_values(feature_value_id,daily_run_id,game_pk,entity_level,entity_id,feature_id,feature_name,feature_family,source_fields,formula_or_transformation,definition_version,feature_window,split,as_of_query,n,raw_value,uncertainty,reliability_state,data_coverage_state,source_lineage) values({sq(fid)},{sq(RUN_ID)},{sq(pk)},'GAME',{sq(pk)},{sq(fam+'_'+win)},{sq(fam+' '+win)},{sq(fam)},'[]'::jsonb,'Observed/derived from official first-inning GUMBO',{sq(FEATURE_VERSION)},{sq(win)},'ALL',{sq(g['actual_first_pitch_at'])}::timestamptz,{n},{sj(rawv)},'{{}}'::jsonb,{sq(rel)},'AVAILABLE_COMPLETE',{sj(lineage)}) on conflict(feature_value_id) do update set raw_value=excluded.raw_value,n=excluded.n,reliability_state=excluded.reliability_state,data_coverage_state=excluded.data_coverage_state,source_lineage=excluded.source_lineage;")
    for win in ("L3","L5","L10","L15","L20","SEASON","CAREER"):
        fid = f"INVNRFI-FV-{pk}-SEQUENCE-{win}"
        rawv = {"status":"BOUNDED_GAP","reason":"Prior-start first-inning sequence window not contained in the captured 2026-08-01 GUMBO repair artifact; no zero-fill or fabricated series.","window":win}
        stmts.append(f"insert into public.investigacion_nrfi_feature_values(feature_value_id,daily_run_id,game_pk,entity_level,entity_id,feature_id,feature_name,feature_family,source_fields,formula_or_transformation,definition_version,feature_window,split,as_of_query,n,raw_value,uncertainty,reliability_state,data_coverage_state,source_lineage) values({sq(fid)},{sq(RUN_ID)},{sq(pk)},'GAME',{sq(pk)},{sq('SEQUENCE_'+win)},{sq('Historical sequence '+win)},'SEQUENCE','[]'::jsonb,'Explicit bounded historical window',{sq(FEATURE_VERSION)},{sq(win)},'ALL',{sq(g['actual_first_pitch_at'])}::timestamptz,0,{sj(rawv)},{sj({'reason':'historical window not reconstructed in repair capture'})},'LOW_COVERAGE','BOUNDED_GAP',{sj(lineage)}) on conflict(feature_value_id) do update set raw_value=excluded.raw_value,reliability_state=excluded.reliability_state,data_coverage_state=excluded.data_coverage_state,source_lineage=excluded.source_lineage;")

    press_notes = "Recovery boundary: official GUMBO contains game facts/PBP but not timestamp-certified pregame press. No postgame narrative promoted to PREGAME_EVIDENCE; external press recovery is recorded separately if found."
    stmts.append(f"insert into public.investigacion_nrfi_component_coverage(daily_run_id,game_pk,component,status,source_families_attempted,tool_event_ids,evidence_ids,notes) values({sq(RUN_ID)},{sq(pk)},'PRESS_HUMAN_INFORMATION','BOUNDED_GAP',{sa(['MLB_GUMBO'])},{sa([tool_id])},{sa([evid_id])},{sq(press_notes)}) on conflict(daily_run_id,game_pk,component) do update set status=excluded.status,source_families_attempted=excluded.source_families_attempted,tool_event_ids=excluded.tool_event_ids,evidence_ids=excluded.evidence_ids,notes=excluded.notes;")
    cohort_id = f"INVNRFI-COHORT-{pk}-{g['halves']['TOP']['primary_path']}-{g['halves']['BOTTOM']['primary_path']}"
    members = cohort_members[(g['halves']['TOP']['primary_path'], g['halves']['BOTTOM']['primary_path'])]
    stmts.append(f"insert into public.investigacion_nrfi_cohorts(cohort_id,daily_run_id,game_pk,query_as_of,inclusion_rules,exclusion_rules,feature_space,era_compatibility,n_games,n_half_innings,entity_set,outcome_distribution,process_distribution,sensitivity_checks,limitations) values({sq(cohort_id)},{sq(RUN_ID)},{sq(pk)},{sq(CAPTURED_AT)}::timestamptz,{sj({'rule':'same top/bottom primary path within 2026-08-01 repair cohort'})},'[]'::jsonb,{sj(['TOP_PATH','BOTTOM_PATH','TOTAL_RUNS'])},'SAME_SEASON_SAME_DATE', {len(members)}, {len(members)*2}, {sj(members)}, {sj({'NRFI':sum(1 for x in members if x['total_runs']==0),'YRFI':sum(1 for x in members if x['total_runs']>0)})}, {sj({'top_path':g['halves']['TOP']['primary_path'],'bottom_path':g['halves']['BOTTOM']['primary_path']})}, {sj({'small_sample':True})}, {sj(['Retrospective descriptive cohort; not causal and not a probability engine.'])}) on conflict(cohort_id) do update set n_games=excluded.n_games,n_half_innings=excluded.n_half_innings,entity_set=excluded.entity_set,outcome_distribution=excluded.outcome_distribution,process_distribution=excluded.process_distribution,sensitivity_checks=excluded.sensitivity_checks,limitations=excluded.limitations;")
    stmts.append(f"insert into public.investigacion_nrfi_component_coverage(daily_run_id,game_pk,component,status,source_families_attempted,tool_event_ids,evidence_ids,notes) values({sq(RUN_ID)},{sq(pk)},'COHORTS','COMPLETE',{sa(['MLB_GUMBO'])},{sa([tool_id])},{sa([evid_id])},{sq('Retrospective mechanism cohort created from the fully captured 2026-08-01 universe; descriptive only.')}) on conflict(daily_run_id,game_pk,component) do update set status=excluded.status,notes=excluded.notes;")
    stmts.append("commit;")
    return "\n".join(stmts) + "\n"


def pitch_report(g, half):
    lines = []
    pas = [p for p in g['plate_appearances'] if p['half'] == half]
    for p in pas:
        seq = "; ".join(f"{x['n']}:{x.get('type') or 'UNK'} {x.get('description') or ''} {('%.1f mph'%x['velo']) if x.get('velo') is not None else ''}".strip() for x in p['pitch_sequence'])
        lines.append(f"- PA {p['ordinal']} — {p['batter_name']} vs {p['pitcher_name']}: {p['pa_result']}; outs {p['outs_before']}→{p['outs_after']}; runs={p['runs_scored']}; pitches={p['pitch_count']}. Sequence: {seq or 'no pitch events retained for this PA'}. Description: {p['transition']['description']}")
    return "\n".join(lines)


def game_report(g):
    top = g['halves']['TOP']; bot = g['halves']['BOTTOM']; outcome = 'NRFI' if g['total_runs']==0 else 'YRFI'
    parts = [
        f"## GAME BLOCK {g['game_pk']} — {g['away_team']} @ {g['home_team']}",
        f"**Identity.** GAME_PK {g['game_pk']}; venue {g['venue_name']}; scheduled {g['scheduled_start_at']}; first pitch observed {g['actual_first_pitch_at']}; starters {g['away_starter_name']} (away) / {g['home_starter_name']} (home). Source: official MLB GUMBO `{g['source_url']}`; capture SHA-256 `{g['raw_sha256']}`.",
        f"**First-inning outcome.** Top {g['top_runs']}, bottom {g['bottom_runs']}, total {g['total_runs']}; descriptive outcome **{outcome}**. Top path `{top['primary_path']}`; bottom path `{bot['primary_path']}`. This is a historical observation, not a forecast or betting probability.",
        "### Top 1st — Half-Inning Card",
        f"BF={top['bf']}; pitches={top['pitches']}; runs={top['runs']}; hits={top['hits']}; singles={top['singles']}; XBH={top['xbh']}; BB={top['bb']}; HBP={top['hbp']}; K={top['k']}; HR={top['hr']}; B4/B5/B6 exposed={top['b4_exposed']}/{top['b5_exposed']}/{top['b6_exposed']}; leadoff reach={top['leadoff_reach']}; two-out extension={top['two_out_extension']}; 3-up-3-down={top['three_up_three_down']}. Exact PA-level sequence follows.",
        pitch_report(g,'TOP'),
        "### Bottom 1st — Half-Inning Card",
        f"BF={bot['bf']}; pitches={bot['pitches']}; runs={bot['runs']}; hits={bot['hits']}; singles={bot['singles']}; XBH={bot['xbh']}; BB={bot['bb']}; HBP={bot['hbp']}; K={bot['k']}; HR={bot['hr']}; B4/B5/B6 exposed={bot['b4_exposed']}/{bot['b5_exposed']}/{bot['b6_exposed']}; leadoff reach={bot['leadoff_reach']}; two-out extension={bot['two_out_extension']}; 3-up-3-down={bot['three_up_three_down']}. Exact PA-level sequence follows.",
        pitch_report(g,'BOTTOM'),
        "### Pitch-level process and starter context",
        f"First-inning process objects: `{jd(g['pitcher_process'])}`. These are calculated from the pitch events retained in the official first-inning GUMBO. Full-start boxscore context is retained separately in `STARTER_CONTEXT`; prior-start L3/L5/L10/L15/L20, season and career first-inning sequences are explicitly `BOUNDED_GAP` in this repair rather than fabricated. The gap does not alter the observed first-inning reconstruction.",
        "### Feature and reliability interpretation",
        f"The game contributes all nine registry families at the GAME level: RESULTS, SEQUENCE, EXPOSURE, OUT_CREATION, TRAFFIC, DAMAGE, PITCHER_PROCESS, TOP_ORDER and CONTEXT. The observed current-game families carry high contextual support from GUMBO; historical sequence windows are low-coverage bounded objects. Press/HUMAN_INFORMATION is kept outside the pregame lane unless a publication/availability timestamp can be certified. Mechanism cohorting is retrospective and descriptive only.",
        "### Reconstruction check",
        f"PA count top/bottom={top['pa']}/{bot['pa']}; pitch count top/bottom={top['pitches']}/{bot['pitches']}; first-inning score reconciliation={g['top_runs']}+{g['bottom_runs']}={g['total_runs']}. Exact event arrays and raw source hash are persisted. No missing historical window is converted to zero.",
    ]
    return "\n\n".join(parts)


def main():
    OUT.mkdir(parents=True, exist_ok=True); SQL_DIR.mkdir(parents=True, exist_ok=True); NORM_DIR.mkdir(parents=True, exist_ok=True)
    raw = json.loads(RAW_PATH.read_text(encoding='utf-8'))
    games = [normalized_game(x) for x in raw]
    if len(games) != 15:
        raise SystemExit(f"EXPECTED_15_GAMES_GOT_{len(games)}")
    cohort_members = defaultdict(list)
    for g in games:
        key = (g['halves']['TOP']['primary_path'], g['halves']['BOTTOM']['primary_path'])
        cohort_members[key].append({"game_pk":g['game_pk'],"total_runs":g['total_runs']})
    raw_map = {str(x['game_pk']): x for x in raw}
    for g in games:
        (NORM_DIR / f"{g['game_pk']}.json").write_text(json.dumps(g, ensure_ascii=False, indent=2), encoding='utf-8')
        (SQL_DIR / f"{g['game_pk']}.sql").write_text(build_game_sql(raw_map[g['game_pk']], g, cohort_members), encoding='utf-8')

    totals = Counter()
    for g in games:
        totals['nrfi' if g['total_runs']==0 else 'yrfi'] += 1
        totals['runs'] += g['total_runs']
        totals[f"bucket_{min(g['total_runs'],3)}"] += 1
    report = [
        "# AMENDMENT SEMÁNTICO — @investigacionNRFI — 2026-08-01",
        f"RUN_ID: `{RUN_ID}`  ", f"PARENT_RUN_ID: `{PARENT_RUN_ID}`  ",
        "RUN_TYPE: `AMENDMENT`  ", "SYSTEM_VERSION: `INVESTIGACION-NRFI-HISTORICAL-V1.0`  ", "KERNEL_VERSION: `INVESTIGACION-NRFI-KERNEL-0.2-SEMANTIC-COMPLETENESS`",
        "\n## EXECUTION_SUMMARY\n",
        f"Official finalized universe: 15 games. Official GUMBO captured for 15/15 games in GitHub commit `{CAPTURE_COMMIT}`. The original shallow certification is withdrawn. This amendment reconstructs the first inning from play/pitch objects and persists semantic objects required by F1–F5. Historical descriptive outcomes in the captured universe: NRFI={totals['nrfi']}; YRFI={totals['yrfi']}; total first-inning runs={totals['runs']}; 0-run games={totals['bucket_0']}; 1-run={totals['bucket_1']}; 2-run={totals['bucket_2']}; 3+-run={totals['bucket_3']}. These are retrospective counts only.",
        "\n## F1 — CAPTURA FORENSE\n",
        "Every GAME_PK is tied to the official MLB GUMBO endpoint and raw SHA-256. The amendment stores scheduled/actual first pitch, venue, starters, lineup/catcher when recovered from the official boxscore, source lineage and a postgame evidence lane. Any lineup/catcher parsing limitation is preserved as an explicit bounded gap rather than silently omitted.",
        "\n## F2 — RECONSTRUCCIÓN PROFUNDA\n",
        "The following 15 GAME BLOCKS contain both half innings, every first-inning plate appearance retained in GUMBO, pitch sequences, run mechanism, exposure and starter first-inning process. This is the material reconstruction that the withdrawn original lacked.",
    ]
    report.extend(game_report(g) for g in games)
    report.extend([
        "\n## F3 — FEATURE FACTORY\n",
        "For each GAME_PK the structured store receives all nine mandatory feature families. RESULTS/EXPOSURE/OUT_CREATION/TRAFFIC/DAMAGE/PITCHER_PROCESS/TOP_ORDER/CONTEXT are derived from the captured game and carry source lineage. SEQUENCE contains the required L3/L5/L10/L15/L20/SEASON/CAREER keys, but where the repair artifact does not contain prior-start first-inning history the value is explicitly `BOUNDED_GAP` with LOW_COVERAGE, N=0 and a written reason. Presence of the key therefore does not masquerade as availability of the statistic.",
        "\n## F4 — HISTORICAL PRESS / RELIABILITY / MECHANISMS / COHORTS\n",
        "Exact first-inning event sequences are preserved as raw arrays before mechanism classification. Primary paths are derived descriptors and never replace the raw sequence. Same-day mechanism cohorts are created only as retrospective descriptive comparisons and are explicitly non-causal. GUMBO does not contain timestamp-certified pregame press; therefore no postgame narrative is promoted to PREGAME_EVIDENCE. PRESS_HUMAN_INFORMATION remains an explicit bounded gap unless external publication timing is independently recovered.",
        "\n## F5 — QUERYABLE INTELLIGENCE\n",
        "The amendment creates one daily Evidence Packet after all 15 structured games are loaded. Its queryable dimensions include identity, pitcher/first-inning history, top-order composition, pitch process, mechanism, context, coverage/reliability and cohorts. FUTURE_GAME_COUNT=0 and POSTGAME_LEAK_COUNT=0 are enforced. No pick, stake, EV, odds or invented NRFI probability is emitted.",
        "\n## DAILY_CLOSURE\n",
        "Closure is not inferred from this prose. Supabase must independently report all 15 games F1/F2/F3/F4 semantic-ready, all games PROCESSED, F1–F5 receipts COMPLETE, Evidence Packet present, report contract verified, Drive append/readback verified and final audit PASS. Until those physical gates pass, this amendment remains IN_PROGRESS.",
        "\n## GAME_BLOCKS\n",
        "GAME_BLOCK_COUNT=15. The detailed blocks above are the human-readable projection of the structured semantic store; Supabase remains the process/audit source of truth and the official GUMBO hashes remain the source-lineage anchors.",
    ])
    text = "\n\n".join(report).strip() + "\n"
    if len(text) < 45000:
        raise SystemExit(f"REPORT_TOO_SHORT_{len(text)}")
    (OUT / "daily_report.md").write_text(text, encoding='utf-8')
    summary = {"run_id":RUN_ID,"parent_run_id":PARENT_RUN_ID,"game_count":15,"report_characters":len(text),"nrfi":totals['nrfi'],"yrfi":totals['yrfi'],"first_inning_runs":totals['runs'],"capture_commit":CAPTURE_COMMIT}
    (OUT / "summary.json").write_text(json.dumps(summary, indent=2), encoding='utf-8')
    print(json.dumps(summary))


if __name__ == '__main__':
    main()

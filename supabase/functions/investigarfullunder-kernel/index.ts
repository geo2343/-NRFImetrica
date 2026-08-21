import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const EDGE_KERNEL_VERSION = "FULLUNDER-EDGE-KERNEL-1.1";
const AGENT_ID = "@Investigarfullunder";
const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false } },
);

const tableFor = (action: string) => ({
  create_run: "fullunder_runs",
  set_requirement_state: "fullunder_requirement_state",
  add_source: "fullunder_source_ledger",
  add_evidence: "fullunder_evidence",
  upsert_issue: "fullunder_issues",
  upsert_contradiction: "fullunder_contradictions",
  submit_phase_receipt: "fullunder_phase_receipts",
  register_artifact: "fullunder_artifacts",
  submit_structure_receipt: "fullunder_artifact_structure_receipts",
  submit_handoff: "fullunder_handoffs",
} as Record<string,string>)[action];

async function registry() {
  const { data, error } = await supabase.from("fullunder_agent_registry")
    .select("agent_id,agent_version,kernel_version,protocol_id,status,mother_sha256,drive_root_folder_id,metadata")
    .eq("agent_id", AGENT_ID).maybeSingle();
  if (error) throw error;
  if (!data || (!String(data.status).startsWith("KERNEL_CONNECTED") && data.status !== "OPERATIONAL_READY_FINAL")) {
    throw new Error("FULLUNDER_AGENT_NOT_KERNEL_CONNECTED");
  }
  return data;
}

async function sha256Hex(value: unknown) {
  const bytes = new TextEncoder().encode(JSON.stringify(value));
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest)).map((b) => b.toString(16).padStart(2,"0")).join("");
}

async function logIncident(action: string, payload: any, error: any) {
  try {
    const message = String(error?.message || error || "UNKNOWN");
    if (!message.includes("FULLUNDER_")) return;
    const fingerprint = await sha256Hex(payload);
    await supabase.from("fullunder_security_incidents").insert({
      agent_id: AGENT_ID,
      run_id: payload?.run_id || null,
      action,
      error_code: error?.code ? String(error.code) : null,
      error_message: message.slice(0,1000),
      payload_fingerprint: fingerprint,
      severity: "HIGH",
      source_layer: "EDGE_KERNEL",
      metadata: { edge_kernel_version: EDGE_KERNEL_VERSION, raw_payload_stored: false },
    });
  } catch (_) {}
}

Deno.serve(async (req: Request) => {
  if (req.method === "GET") {
    try {
      const reg = await registry();
      return Response.json({ ok:true, status:"ACTIVE", agent_id:AGENT_ID, edge_kernel_version:EDGE_KERNEL_VERSION, jwt_required:true, market_blind:true, sports_decision_authority:false, structured_handoff_required:true, registry:reg });
    } catch (e) {
      return Response.json({ ok:false, edge_kernel_version:EDGE_KERNEL_VERSION, error:String((e as any)?.message || e) }, { status:500 });
    }
  }
  if (req.method !== "POST") return Response.json({ok:false,error:"METHOD_NOT_ALLOWED"},{status:405});
  try {
    const body = await req.json();
    const action = String(body.action || "");
    if (action === "status") {
      const reg = await registry();
      const [{count:reqCount},{count:testCount},{count:failedCount}] = await Promise.all([
        supabase.from("fullunder_requirement_catalog").select("*",{count:"exact",head:true}).eq("active",true),
        supabase.from("fullunder_kernel_test_results").select("*",{count:"exact",head:true}),
        supabase.from("fullunder_kernel_test_results").select("*",{count:"exact",head:true}).eq("passed",false),
      ]);
      return Response.json({ok:true,edge_kernel_version:EDGE_KERNEL_VERSION,registry:reg,active_requirements:reqCount,kernel_tests:testCount,kernel_test_failures:failedCount,structured_handoff_required:true,handoff_format_contract:"FULLUNDER-HANDOFF-FORMAT-1.1"});
    }
    if (action === "get_run_state") {
      const runId = String(body.run_id || "");
      const [run,reqs,receipts,artifacts,structures,handoff,issues,contradictions] = await Promise.all([
        supabase.from("fullunder_runs").select("*").eq("run_id",runId).maybeSingle(),
        supabase.from("fullunder_requirement_state").select("*").eq("run_id",runId),
        supabase.from("fullunder_phase_receipts").select("*").eq("run_id",runId).order("created_at"),
        supabase.from("fullunder_artifacts").select("*").eq("run_id",runId),
        supabase.from("fullunder_artifact_structure_receipts").select("*").eq("run_id",runId),
        supabase.from("fullunder_handoffs").select("*").eq("run_id",runId).maybeSingle(),
        supabase.from("fullunder_issues").select("*").eq("run_id",runId),
        supabase.from("fullunder_contradictions").select("*").eq("run_id",runId),
      ]);
      for (const r of [run,reqs,receipts,artifacts,structures,handoff,issues,contradictions]) if (r.error) throw r.error;
      return Response.json({ok:true,edge_kernel_version:EDGE_KERNEL_VERSION,run:run.data,requirements:reqs.data,receipts:receipts.data,artifacts:artifacts.data,structure_receipts:structures.data,handoff:handoff.data,issues:issues.data,contradictions:contradictions.data});
    }
    const table = tableFor(action);
    if (!table) return Response.json({ok:false,error:"UNKNOWN_ACTION"},{status:400});
    const payload = body.payload;
    if (!payload || typeof payload !== "object" || Array.isArray(payload)) return Response.json({ok:false,error:"OBJECT_PAYLOAD_REQUIRED"},{status:400});

    if (action === "create_run") {
      const reg = await registry();
      payload.agent_id = AGENT_ID;
      payload.agent_version = reg.agent_version;
      payload.kernel_version = reg.kernel_version;
      payload.mother_sha256 = reg.mother_sha256;
      payload.ready_for_analyst = false;
      payload.phase_cursor = 0;
      payload.status = "RUN_CREATED";
      payload.metadata = { ...(payload.metadata || {}), edge_kernel_version: EDGE_KERNEL_VERSION, protocol_id: reg.protocol_id, handoff_format_contract: "FULLUNDER-HANDOFF-FORMAT-1.1" };
    }

    const { data, error } = await supabase.from(table).upsert(payload).select();
    if (error) {
      await logIncident(action,payload,error);
      return Response.json({ok:false,edge_kernel_version:EDGE_KERNEL_VERSION,error:error.message,code:error.code,details:error.details},{status:409});
    }
    return Response.json({ok:true,edge_kernel_version:EDGE_KERNEL_VERSION,action,data});
  } catch (e) {
    const message = String((e as any)?.message || e);
    return Response.json({ok:false,edge_kernel_version:EDGE_KERNEL_VERSION,error:message},{status:500});
  }
});

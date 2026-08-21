import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const EDGE_KERNEL_VERSION = "FULLUNDER-EDGE-KERNEL-1.2-COMMAND-BUS";
const CONTROL_PLANE_VERSION = "FULLUNDER-CONTROL-PLANE-1.2";
const AGENT_ID = "@Investigarfullunder";
const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false } },
);

async function registry() {
  const { data, error } = await supabase.from("fullunder_agent_registry")
    .select("agent_id,agent_version,kernel_version,protocol_id,status,mother_sha256,drive_root_folder_id,metadata")
    .eq("agent_id", AGENT_ID).maybeSingle();
  if (error) throw error;
  if (!data) throw new Error("FULLUNDER_REGISTRY_MISSING");
  return data;
}

async function activePolicy() {
  const { data, error } = await supabase.from("fullunder_policy_bundles")
    .select("policy_bundle_id,policy_version,policy_hash,mother_sha256,compiled_policy")
    .eq("agent_id", AGENT_ID).eq("active", true).maybeSingle();
  if (error) throw error;
  if (!data) throw new Error("FULLUNDER_ACTIVE_POLICY_MISSING");
  return data;
}

Deno.serve(async (req: Request) => {
  if (req.method === "GET") {
    try {
      const [reg, policy] = await Promise.all([registry(), activePolicy()]);
      return Response.json({
        ok: true,
        status: "ACTIVE",
        agent_id: AGENT_ID,
        edge_kernel_version: EDGE_KERNEL_VERSION,
        control_plane_version: CONTROL_PLANE_VERSION,
        write_model: "LLM_PROPOSES_KERNEL_VALIDATES_KERNEL_COMMITS",
        direct_canonical_write: false,
        reasoning_plane: "AI",
        control_plane: "KERNEL",
        jwt_required: true,
        registry: reg,
        active_policy: policy,
      });
    } catch (e) {
      return Response.json({ ok:false, edge_kernel_version:EDGE_KERNEL_VERSION, error:String((e as any)?.message || e) }, { status:500 });
    }
  }

  if (req.method !== "POST") return Response.json({ok:false,error:"METHOD_NOT_ALLOWED"},{status:405});
  try {
    const body = await req.json();
    const action = String(body.action || "");

    if (action === "status") {
      const [reg, policy, reqs, tests, fails] = await Promise.all([
        registry(), activePolicy(),
        supabase.from("fullunder_requirement_catalog").select("*",{count:"exact",head:true}).eq("active",true),
        supabase.from("fullunder_kernel_test_results").select("*",{count:"exact",head:true}),
        supabase.from("fullunder_kernel_test_results").select("*",{count:"exact",head:true}).eq("passed",false),
      ]);
      return Response.json({ok:true,agent_id:AGENT_ID,edge_kernel_version:EDGE_KERNEL_VERSION,control_plane_version:CONTROL_PLANE_VERSION,registry:reg,active_policy:policy,active_requirements:reqs.count,kernel_tests:tests.count,kernel_test_failures:fails.count,direct_canonical_write:false});
    }

    if (action === "get_run_state") {
      const runId = String(body.run_id || "");
      const [run, reqs, receipts, artifacts, handoff, manifest, grants, stale, commands, toolEvents, deterministicAudits, semanticAudits, publication] = await Promise.all([
        supabase.from("fullunder_runs").select("*").eq("run_id",runId).maybeSingle(),
        supabase.from("fullunder_requirement_state").select("*").eq("run_id",runId),
        supabase.from("fullunder_phase_receipts").select("*").eq("run_id",runId).order("created_at"),
        supabase.from("fullunder_artifacts").select("*").eq("run_id",runId),
        supabase.from("fullunder_handoffs").select("*").eq("run_id",runId).maybeSingle(),
        supabase.from("fullunder_handoff_manifests").select("*").eq("run_id",runId).maybeSingle(),
        supabase.from("fullunder_capability_grants").select("*").eq("run_id",runId).order("issued_at"),
        supabase.from("fullunder_stale_objects").select("*").eq("run_id",runId),
        supabase.from("fullunder_command_envelopes").select("command_id,action,phase_id,policy_version,expected_state_version,idempotency_key,status,validation_codes,result,created_at,committed_at,rejected_at").eq("run_id",runId).order("created_at"),
        supabase.from("fullunder_tool_events").select("*").eq("run_id",runId).order("requested_at"),
        supabase.from("fullunder_deterministic_audits").select("*").eq("run_id",runId).order("created_at"),
        supabase.from("fullunder_semantic_audits").select("*").eq("run_id",runId).order("created_at"),
        supabase.from("fullunder_publication_records").select("*").eq("run_id",runId).maybeSingle(),
      ]);
      for (const r of [run,reqs,receipts,artifacts,handoff,manifest,grants,stale,commands,toolEvents,deterministicAudits,semanticAudits,publication]) if (r.error) throw r.error;
      return Response.json({ok:true,edge_kernel_version:EDGE_KERNEL_VERSION,run:run.data,requirements:reqs.data,receipts:receipts.data,artifacts:artifacts.data,handoff:handoff.data,manifest:manifest.data,capability_grants:grants.data,stale_objects:stale.data,commands:commands.data,tool_events:toolEvents.data,deterministic_audits:deterministicAudits.data,semantic_audits:semanticAudits.data,publication:publication.data});
    }

    if (action === "submit_command") {
      const envelope = { ...(body.envelope || {}) };
      envelope.agent_id = AGENT_ID;
      envelope.proposed_by = String(envelope.proposed_by || "LLM").toUpperCase();
      const { data, error } = await supabase.rpc("fullunder_submit_command", { p_envelope: envelope });
      if (error) return Response.json({ok:false,edge_kernel_version:EDGE_KERNEL_VERSION,error:error.message,code:error.code,details:error.details},{status:409});
      return Response.json({ ...data, edge_kernel_version: EDGE_KERNEL_VERSION, control_plane_version: CONTROL_PLANE_VERSION });
    }

    const legacyWrites = new Set(["create_run","set_requirement_state","add_source","add_evidence","upsert_issue","upsert_contradiction","submit_phase_receipt","register_artifact","submit_handoff"]);
    if (legacyWrites.has(action)) {
      return Response.json({ok:false,error:"FULLUNDER_LEGACY_DIRECT_WRITE_DISABLED_USE_COMMAND_ENVELOPE",required_action:"submit_command",edge_kernel_version:EDGE_KERNEL_VERSION},{status:410});
    }

    return Response.json({ok:false,error:"UNKNOWN_ACTION"},{status:400});
  } catch (e) {
    return Response.json({ok:false,edge_kernel_version:EDGE_KERNEL_VERSION,error:String((e as any)?.message || e)},{status:500});
  }
});

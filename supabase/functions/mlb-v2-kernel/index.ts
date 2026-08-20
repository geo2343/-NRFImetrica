import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const KERNEL_VERSION = "MLB-V2-KERNEL-0.3-HARDENED";
const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false } });
const tableFor = (action: string) => ({create_mission:"mlb_v2_missions",add_mission_game:"mlb_v2_mission_games",create_run:"mlb_v2_runs",bind_analyst_input:"mlb_v2_analyst_inputs",set_requirement_state:"mlb_v2_requirement_state",set_mission_requirement_state:"mlb_v2_mission_requirement_state",upsert_source:"mlb_v2_source_ledger",upsert_evidence:"mlb_v2_evidence",upsert_issue:"mlb_v2_issues",upsert_contradiction:"mlb_v2_contradictions",submit_phase_receipt:"mlb_v2_phase_receipts",submit_mission_phase_receipt:"mlb_v2_mission_phase_receipts",register_artifact:"mlb_v2_artifacts",register_mission_artifact:"mlb_v2_mission_artifacts",submit_handoff:"mlb_v2_handoffs",finalize_mission:"mlb_v2_mission_finalizations"} as Record<string,string>)[action];

async function canonicalKernelForAgent(agentId: string) {
  const { data, error } = await supabase.from("mlb_v2_agent_registry").select("agent_id,agent_version,status,metadata").eq("agent_id",agentId).maybeSingle();
  if (error) throw error;
  if (!data || data.status !== "KERNEL_CONNECTED") throw new Error("AGENT_NOT_KERNEL_CONNECTED");
  const kernelVersion = String((data.metadata as any)?.kernel_version || "");
  if (!kernelVersion) throw new Error("AGENT_KERNEL_VERSION_MISSING");
  return { data, kernelVersion };
}

Deno.serve(async (req: Request) => {
  if (req.method === "GET") return Response.json({ ok:true, kernel_version:KERNEL_VERSION, status:"ACTIVE", jwt_required:true, registry_aware:true });
  if (req.method !== "POST") return Response.json({ok:false,error:"METHOD_NOT_ALLOWED"},{status:405});
  try {
    const body = await req.json();
    const action = String(body.action || "");
    if (action === "status") {
      const { data, error } = await supabase.from("mlb_v2_agent_registry").select("agent_id,agent_version,status,metadata").in("agent_id",["@InvestigadoraNRFI","@AnalistaaNRFI"]);
      if (error) throw error;
      return Response.json({ok:true,kernel_version:KERNEL_VERSION,registry_aware:true,agents:data});
    }
    if (action === "get_mission_state") {
      const mission_id = String(body.mission_id || "");
      const [m,g,a9,f] = await Promise.all([
        supabase.from("mlb_v2_missions").select("*").eq("mission_id",mission_id).maybeSingle(),
        supabase.from("mlb_v2_mission_games").select("*").eq("mission_id",mission_id),
        supabase.from("mlb_v2_mission_phase_receipts").select("*").eq("mission_id",mission_id),
        supabase.from("mlb_v2_mission_finalizations").select("*").eq("mission_id",mission_id).maybeSingle(),
      ]);
      for (const r of [m,g,a9,f]) if (r.error) throw r.error;
      return Response.json({ok:true,kernel_version:KERNEL_VERSION,mission:m.data,games:g.data,a9:a9.data,finalization:f.data});
    }
    const table = tableFor(action);
    if (!table) return Response.json({ok:false,error:"UNKNOWN_ACTION"},{status:400});
    const payload = body.payload;
    if (!payload || typeof payload !== "object" || Array.isArray(payload)) return Response.json({ok:false,error:"OBJECT_PAYLOAD_REQUIRED"},{status:400});

    if (action === "create_run") {
      const agentId = String(payload.agent_id || "");
      const { data: reg, kernelVersion } = await canonicalKernelForAgent(agentId);
      payload.metadata = { ...(payload.metadata || {}), kernel_version: kernelVersion, edge_kernel_version: KERNEL_VERSION };
      if (!payload.agent_version) payload.agent_version = reg.agent_version;
    }
    if (action === "create_mission") {
      const agentId = String(payload.agent_id || "@AnalistaaNRFI");
      const { kernelVersion } = await canonicalKernelForAgent(agentId);
      payload.agent_id = agentId;
      payload.metadata = { ...(payload.metadata || {}), kernel_version: kernelVersion, edge_kernel_version: KERNEL_VERSION };
    }

    const { data, error } = await supabase.from(table).upsert(payload).select();
    if (error) return Response.json({ok:false,kernel_version:KERNEL_VERSION,error:error.message,code:error.code,details:error.details},{status:409});
    return Response.json({ok:true,kernel_version:KERNEL_VERSION,action,data});
  } catch (e) {
    return Response.json({ok:false,kernel_version:KERNEL_VERSION,error:String((e as any)?.message || e)},{status:500});
  }
});

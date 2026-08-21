import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const VERSION="ANALISTADEPURACIONRNFI-D-KERNEL-1.1.1";
const AGENT="@AnalistaDepuracionRNFI_D";
const REASONING_HOST="CHATGPT_AGENT_RUNTIME";
const db=createClient(Deno.env.get("SUPABASE_URL")!,Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,{auth:{persistSession:false}});
async function rpc(fn:string,args:any){const {data,error}=await db.rpc(fn,args);if(error)throw error;return data;}
function decodeJwt(auth:string|null){if(!auth?.startsWith("Bearer "))throw new Error("AUTHORIZATION_BEARER_REQUIRED");const token=auth.slice(7);const parts=token.split(".");if(parts.length<2)throw new Error("JWT_INVALID");const raw=parts[1].replace(/-/g,"+").replace(/_/g,"/");const pad=raw+"=".repeat((4-raw.length%4)%4);const claims=JSON.parse(atob(pad));const role=String(claims.role||"");if(!["authenticated","service_role"].includes(role))throw new Error("JWT_ROLE_NOT_ALLOWED");return{sub:claims.sub?String(claims.sub):null,role};}
function getRunId(p:any){return String(p?.run_id||p?.payload?.run_id||"");}
function blockExternalProof(action:string,p:any){
 const a=action.toUpperCase();
 if(a==="REGISTER_DRIVE_READBACK") throw new Error("DRIVE_READBACK_MUST_COME_FROM_EXTERNAL_CHATGPT_GOOGLE_DRIVE_CONNECTOR_HOST");
 if(a==="REGISTER_TOOL_EVENT" && String(p?.connector||"").toLowerCase().includes("drive")) throw new Error("DRIVE_TOOL_EVENT_MUST_COME_FROM_EXTERNAL_CONNECTOR_HOST");
 if(a==="REGISTER_EVIDENCE" && ["TOOL_READBACK"].includes(String(p?.evidence_type||""))) throw new Error("TOOL_READBACK_EVIDENCE_MUST_COME_FROM_EXTERNAL_CONNECTOR_HOST");
}
Deno.serve(async(req:Request)=>{
 if(req.method==="GET")return Response.json({ok:true,agent_id:AGENT,version:VERSION,status:"ACTIVE",kernel_role:"CONTROL_PLANE_ONLY",reasoning_plane:REASONING_HOST,execution_mode:"HOST_AGENT_AUTONOMOUS_LOOP_UNTIL_REPORT",e1_receipts:true,semantic_requirement_attestations:true,drive_proof:"EXTERNAL_CONNECTOR_HOST_ONLY",manual_dialogue_authorization:true,auto_chain_dialogue:false});
 if(req.method!=="POST")return Response.json({ok:false,error:"METHOD_NOT_ALLOWED"},{status:405});
 try{
  const actor=decodeJwt(req.headers.get("authorization")); const body=await req.json(); const action=String(body.action||"").toLowerCase(); const p=(body.payload&&typeof body.payload==="object")?body.payload:{};
  if(action==="status")return Response.json({ok:true,agent_id:AGENT,version:VERSION,kernel_role:"CONTROL_PLANE_ONLY",reasoning_plane:REASONING_HOST,phase_execution:"CHATGPT_HOST_GENERATES_ANALYSIS; KERNEL_VALIDATES_AND_COMMITS",drive_readback:"NOT_SELF_CERTIFIABLE",command_bus:"depurnrfi_d_submit_command_v11"});
  if(action==="create_run"){const result=await rpc("depurnrfi_d_create_run_v11",{p_run_id:String(p.run_id||""),p_slate_date:p.slate_date,p_input_manifest:p.input_manifest||{},p_invocation_message_hash:String(p.invocation_message_hash||""),p_reasoning_host:REASONING_HOST});await rpc("depurnrfi_d_bind_actor_v11",{p_run_id:String(p.run_id||""),p_actor_sub:actor.sub,p_actor_role:actor.role});return Response.json({ok:true,result,next_action:"GET_EXECUTION_PLAN_AND_CONTINUE_AUTONOMOUSLY"});}
  if(action==="grant_user_authorization")return Response.json({ok:false,error:"AUTHORIZATION_MUST_COME_FROM_EXTERNAL_USER_CONTROL_PLANE",next_state:"STOP_WAITING_USER_AUTHORIZATION"},{status:403});
  const runId=getRunId(p);if(!runId)return Response.json({ok:false,error:"RUN_ID_REQUIRED"},{status:400});await rpc("depurnrfi_d_assert_actor_v11",{p_run_id:runId,p_actor_sub:actor.sub,p_actor_role:actor.role});
  if(action==="get_execution_plan")return Response.json({ok:true,result:await rpc("depurnrfi_d_get_execution_plan_v11",{p_run_id:runId})});
  if(action==="get_state")return Response.json({ok:true,result:await rpc("depurnrfi_d_get_state",{p_run_id:runId})});
  if(action==="register_drive_readback")throw new Error("DRIVE_READBACK_MUST_COME_FROM_EXTERNAL_CHATGPT_GOOGLE_DRIVE_CONNECTOR_HOST");
  if(action==="command"){const env=p.envelope||{};const ep=env.payload||{};blockExternalProof(String(env.action||""),ep);return Response.json({ok:true,result:await rpc("depurnrfi_d_submit_command_v11",{p_envelope:env})});}
  const aliases:any={register_tool_event:"REGISTER_TOOL_EVENT",register_evidence:"REGISTER_EVIDENCE",attest_requirement:"ATTEST_REQUIREMENT",submit_phase:"SUBMIT_PHASE",register_artifact:"REGISTER_ARTIFACT",commit_report:"COMMIT_REPORT",dialogue_turn:"DIALOGUE_TURN",close_dialogue:"CLOSE_DIALOGUE"};
  if(aliases[action]){blockExternalProof(aliases[action],p);return Response.json({ok:true,result:await rpc("depurnrfi_d_submit_command_v11",{p_envelope:{action:aliases[action],payload:p}})});}
  return Response.json({ok:false,error:"UNKNOWN_ACTION"},{status:400});
 }catch(e){const m=String((e as any)?.message||e);const code=/AUTH|JWT|ACTOR|EXTERNAL_CONNECTOR|SELF_CERTIFIABLE/.test(m)?403:/STALE/.test(m)?409:422;return Response.json({ok:false,agent_id:AGENT,version:VERSION,error:m},{status:code});}
});

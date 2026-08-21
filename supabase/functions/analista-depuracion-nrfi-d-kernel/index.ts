import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const VERSION="ANALISTADEPURACIONRNFI-D-KERNEL-1.0";
const AGENT="@AnalistaDepuracionRNFI_D";
const SOURCE_SHA="121f80c4569de1f87c438f96fbd48364a1756afee17a38f3f1f33698a67caea9";
const db=createClient(Deno.env.get("SUPABASE_URL")!,Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,{auth:{persistSession:false}});

async function rpc(fn:string,args:any){const {data,error}=await db.rpc(fn,args);if(error)throw error;return data;}
async function getState(runId:string){return await rpc("depurnrfi_d_get_state",{p_run_id:runId});}
function obj(x:any){return x&&typeof x==="object"&&!Array.isArray(x);}

Deno.serve(async(req:Request)=>{
 if(req.method==="GET") return Response.json({ok:true,agent_id:AGENT,display_name:"AnalistaDepuracionRNFI. D",version:VERSION,status:"ACTIVE",jwt_required:true,scope:"FULL_MLB_SLATE",source_sha256:SOURCE_SHA,requirements:1057,phase_order:["F1","F2","F3","F4","F5","F6","F7","F8","F9","D1","D2","F10","F11","REPORT_D","PRE_DIALOGUE_FREEZE","DIALOGUE"],execution_mode:{pre_dialogue:"AUTO_CONTINUOUS_UNTIL_FINAL_DEPURATION_REPORT_D",post_report:"STOP_WAITING_USER_AUTHORIZATION",dialogue:"ONE_USER_AUTHORIZATION_PER_D_RESPONSE",auto_chain:false,d_closes_first:true,a_closes_system:true}});
 if(req.method!=="POST") return Response.json({ok:false,error:"METHOD_NOT_ALLOWED"},{status:405});
 try{
  const body=await req.json(); const action=String(body.action||""); const p=obj(body.payload)?body.payload:{};
  if(action==="status") return Response.json({ok:true,agent_id:AGENT,version:VERSION,source_sha256:SOURCE_SHA,requirements:1057,auto_continuous_pre_dialogue:true,manual_dialogue_authorization:true,one_authorization_per_d_response:true,auto_chain_forbidden:true,d_closes_first:true,a_closes_system:true});
  if(action==="get_state"){if(!p.run_id)return Response.json({ok:false,error:"RUN_ID_REQUIRED"},{status:400});return Response.json({ok:true,state:await getState(String(p.run_id))});}
  if(action==="get_requirement_manifest"){
    const phase=String(p.phase_code||""); if(!phase)return Response.json({ok:false,error:"PHASE_REQUIRED"},{status:400});
    const {data,error}=await db.from("depurnrfi_d_requirement_catalog").select("requirement_id,source_code,title").eq("phase_code",phase).eq("binding",true).order("source_code"); if(error)throw error;
    return Response.json({ok:true,phase,requirements:data||[],count:(data||[]).length});
  }
  if(action==="create_run") return Response.json({ok:true,result:await rpc("depurnrfi_d_create_run",{p_run_id:String(p.run_id||""),p_slate_date:p.slate_date,p_input_manifest:p.input_manifest||{}})});
  if(action==="submit_phase") return Response.json({ok:true,result:await rpc("depurnrfi_d_submit_phase",{p_run_id:String(p.run_id||""),p_phase_code:String(p.phase_code||""),p_output:p.output||{},p_requirements_evaluated:p.requirements_evaluated||[]})});
  if(action==="register_artifact") return Response.json({ok:true,result:await rpc("depurnrfi_d_register_artifact",{p_artifact_id:String(p.artifact_id||""),p_run_id:String(p.run_id||""),p_artifact_type:String(p.artifact_type||""),p_drive_file_id:p.drive_file_id||null,p_content_hash:String(p.content_hash||""),p_metadata:p.metadata||{}})});
  if(action==="mark_artifact_readback") return Response.json({ok:true,result:await rpc("depurnrfi_d_mark_artifact_readback",{p_artifact_id:String(p.artifact_id||""),p_observed_hash:String(p.observed_hash||"")})});
  if(action==="commit_report") return Response.json({ok:true,result:await rpc("depurnrfi_d_commit_pre_dialogue_report",{p_run_id:String(p.run_id||""),p_artifact_id:String(p.artifact_id||""),p_report_sections:p.report_sections||{}})});
  if(action==="grant_user_authorization") return Response.json({ok:false,error:"AUTHORIZATION_MUST_COME_FROM_EXTERNAL_USER_CONTROL_PLANE",next_state:"STOP_WAITING_USER_AUTHORIZATION"},{status:403});
  if(action==="dialogue_turn"){
    if(!p.authorization_id)return Response.json({ok:false,error:"USER_AUTHORIZATION_REQUIRED",next_state:"STOP_WAITING_USER_AUTHORIZATION"},{status:428});
    const result=await rpc("depurnrfi_d_commit_dialogue_turn_authorized",{p_authorization_id:p.authorization_id,p_run_id:String(p.run_id||""),p_inbound_actor:String(p.inbound_actor||"USER_TRANSPORTED_A_MESSAGE"),p_inbound_text:String(p.inbound_text||""),p_outbound_text:String(p.outbound_text||""),p_topics:p.topics||[],p_evidence_refs:p.evidence_refs||[]});
    return Response.json({ok:true,result,next_state:"STOP_WAITING_USER_AUTHORIZATION",auto_continue:false});
  }
  if(action==="close_dialogue"){
    if(!p.authorization_id)return Response.json({ok:false,error:"USER_AUTHORIZATION_REQUIRED",next_state:"STOP_WAITING_USER_AUTHORIZATION"},{status:428});
    const result=await rpc("depurnrfi_d_commit_dialogue_closing_authorized",{p_authorization_id:p.authorization_id,p_run_id:String(p.run_id||""),p_artifact_id:p.artifact_id||null,p_closing_payload:p.closing_payload||{}});
    return Response.json({ok:true,result,next_state:"D_DIALOGUE_PARTICIPATION_COMPLETE_STOP",auto_continue:false});
  }
  return Response.json({ok:false,error:"UNKNOWN_ACTION"},{status:400});
 }catch(e){const m=String((e as any)?.message||e);const code=/USER_AUTH|KENDEL_USER_AUTH/.test(m)?428:409;return Response.json({ok:false,agent_id:AGENT,version:VERSION,error:m,next_state:m.includes("AUTH")?"STOP_WAITING_USER_AUTHORIZATION":undefined},{status:code});}
});

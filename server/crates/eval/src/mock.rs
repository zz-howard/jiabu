use crate::{agent_fixture::{call,done,text},dataset::{Behavior,Entry,RecordSpec}};
use anyhow::{Context,Result};
use jiabu_ai::mock::TurnScript;
use serde_json::{Value,json};
use std::collections::BTreeMap;
use uuid::Uuid;
#[derive(Default)]
pub struct Identities {
    pub accounts:BTreeMap<String,Uuid>,
    pub records:BTreeMap<String,Uuid>,
    pub versions:BTreeMap<String,i32>,
    pub tags:BTreeMap<String,Uuid>,
}
impl Identities {
    fn account(&self,key:&Option<String>)->Result<Option<Uuid>> {key.as_ref().map(|k|self.accounts.get(k).copied().context("unknown account alias")).transpose()}
    pub fn args(&self,r:&RecordSpec)->Result<(String,Value)> {
        let mut fields=json!({});
        for (key,value) in [("kind",r.kind.as_ref().map(|v|json!(v))),("amount_minor",r.amount_minor.map(|v|json!(v))),("occurred_on",r.occurred_on.map(|v|json!(v)))] {if let Some(v)=value {fields[key]=v;}}
        for (key,value) in [("account_id",self.account(&r.account)?),("purpose_id",self.account(&r.purpose)?),("to_account_id",self.account(&r.to_account)?),("to_purpose_id",self.account(&r.to_purpose)?)] {if let Some(v)=value {fields[key]=json!(v);}}
        if let Some(k)=&r.preset_key {fields["tag_ids"]=json!([self.tags.get(k).context("unknown preset")?]);}
        if let Some(k)=&r.refund_of {fields["refund_of_id"]=json!(self.records.get(k).context("unknown refund parent")?);}
        if r.operation=="create" {return Ok(("create_record".into(),fields));}
        let target=r.target.as_ref().context("missing target")?;
        let id=self.records.get(target).context("unknown target")?;
        let version=self.versions.get(target).copied().unwrap_or(1);
        let args=if r.operation=="update" {
            let patch=fields.as_object_mut().context("fields")?;
            patch.remove("kind");
            patch.remove("refund_of_id");
            json!({"id":id,"expected_version":version,"changes":fields})
        } else {json!({"id":id,"expected_version":version})};
        Ok((format!("{}_record",r.operation),args))
    }
}
pub fn scripts(e:&Entry,ids:&Identities)->Result<Vec<TurnScript>> {
    Ok(match e.expect.behavior {
        Behavior::AskUser=>vec![vec![call("question","ask_user",json!({"prompt":"请补充缺少的信息 / Please clarify the missing information","options":[],"fields":[]})),done()]],
        Behavior::NoWrite=>vec![vec![text("你好 / Hello"),done()]],
        _=>{
            let mut turn=Vec::new();
            for (i,r) in e.expect.records.iter().enumerate() {let (tool,args)=ids.args(r)?;turn.push(call(&format!("record-{i}"),&tool,args));}
            turn.push(done());
            vec![turn,vec![text("已保存 / Saved"),done()]]
        }
    })
}

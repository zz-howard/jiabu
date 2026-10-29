use anyhow::{Context, Result, bail, ensure};
use chrono::NaiveDate;
use serde::{Deserialize, Serialize};
use serde_json::{Map, Value, json};
use std::{collections::{BTreeMap, BTreeSet}, path::Path};
use yaml_rust2::{Yaml, YamlLoader};

pub const CATEGORIES: &[&str] = &["colloquial_single", "multi_record", "relative_date", "income", "transfer", "reallocation", "refund", "receipt", "insufficient", "confirmation", "chat", "english", "ambiguous_date"];
#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
pub struct Entry {
    pub schema_version: u8,
    pub id: String,
    pub locale: String,
    pub category: String,
    pub today: NaiveDate,
    pub timezone: String,
    pub input: Input,
    pub setup: Setup,
    pub expect: Expect,
    pub ambiguity_reason: Option<String>,
}
#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
pub struct Input {
    pub text: String,
    #[serde(default)]
    pub images: Vec<String>,
}
#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
pub struct Setup {
    pub currency: String,
    pub accounts: Vec<Account>,
    #[serde(default)]
    pub records: Vec<SeedRecord>,
}
#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
pub struct Account {
    pub key: String,
    pub kind: String,
    pub name: String,
    pub opening_on: NaiveDate,
}
#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
pub struct SeedRecord {
    pub key: String,
    pub record: RecordSpec,
}
#[derive(Clone, Copy, Debug, Deserialize, Serialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum Behavior { Write, AskUser, ConfirmThenWrite, NoWrite }
impl Behavior {
    pub fn as_str(self) -> &'static str {
        match self { Self::Write=>"write", Self::AskUser=>"ask_user", Self::ConfirmThenWrite=>"confirm_then_write", Self::NoWrite=>"no_write" }
    }
}
#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
pub struct Expect {
    pub behavior: Behavior,
    pub hard: bool,
    pub records: Vec<RecordSpec>,
}
/// Optional fields are assertions only when present. operation is always required.
#[derive(Clone, Debug, Default, Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
pub struct RecordSpec {
    pub operation: String,
    pub target: Option<String>,
    pub kind: Option<String>,
    pub amount_minor: Option<i64>,
    pub currency: Option<String>,
    pub occurred_on: Option<NaiveDate>,
    pub preset_key: Option<String>,
    pub account: Option<String>,
    pub purpose: Option<String>,
    pub to_account: Option<String>,
    pub to_purpose: Option<String>,
    pub refund_of: Option<String>,
    pub status: Option<String>,
}
fn convert(y: &Yaml) -> Result<Value> {
    Ok(match y {
        Yaml::Null => Value::Null,
        Yaml::Boolean(v) => json!(v),
        Yaml::Integer(v) => json!(v),
        Yaml::String(v) => json!(v),
        Yaml::Array(a) => Value::Array(a.iter().map(convert).collect::<Result<_>>()?),
        Yaml::Hash(h) => {
            let mut o=Map::new();
            for (k,v) in h { let Yaml::String(k)=k else {bail!("YAML keys must be strings")}; ensure!(o.insert(k.clone(),convert(v)?).is_none(),"duplicate YAML key"); }
            Value::Object(o)
        }
        _ => bail!("unsupported YAML scalar, alias or tag"),
    })
}
// Detect duplicate keys before YamlLoader can collapse a mapping. Composite keys,
// anchors and tags are deliberately outside this dataset's small YAML dialect.
fn check_keys(source: &str) -> Result<()> {
    use yaml_rust2::parser::{Event, EventReceiver, Parser};
    #[derive(Default)]
    struct Keys { stack: Vec<Option<(bool,BTreeSet<String>)>>, invalid: bool }
    impl EventReceiver for Keys {
        fn on_event(&mut self, event: Event) {
            match event {
                Event::MappingStart(anchor,tag) => {
                    if anchor != 0 || tag.is_some() { self.invalid=true; }
                    if let Some(Some((key,_)))=self.stack.last_mut() { if *key {self.invalid=true;} else {*key=true;} }
                    self.stack.push(Some((true,BTreeSet::new())));
                }
                Event::SequenceStart(anchor,tag) => {
                    if anchor != 0 || tag.is_some() {self.invalid=true;}
                    if let Some(Some((key,_)))=self.stack.last_mut() { if *key {self.invalid=true;} else {*key=true;} }
                    self.stack.push(None);
                }
                Event::MappingEnd | Event::SequenceEnd => { self.stack.pop(); }
                Event::Scalar(s,_,anchor,tag) => {
                    if anchor != 0 || tag.is_some() {self.invalid=true;}
                    if let Some(Some((key,seen)))=self.stack.last_mut() { if *key && !seen.insert(s) {self.invalid=true;} *key=!*key; }
                }
                Event::Alias(_) => self.invalid=true,
                _=>{}
            }
        }
    }
    let mut keys=Keys::default();
    Parser::new_from_str(source).load(&mut keys,true).map_err(|_|anyhow::anyhow!("invalid YAML"))?;
    ensure!(!keys.invalid,"duplicate/composite key, anchor or tag in YAML");
    Ok(())
}
pub fn parse(source: &str) -> Result<Entry> {
    check_keys(source)?;
    let docs=YamlLoader::load_from_str(source).map_err(|_|anyhow::anyhow!("invalid YAML"))?;
    ensure!(docs.len()==1,"one YAML document required");
    Ok(serde_json::from_value(convert(&docs[0])?)?)
}
pub fn load(root: &Path) -> Result<Vec<Entry>> {
    let mut paths=std::fs::read_dir(root.join("entries"))?.map(|p|p.map(|p|p.path())).collect::<std::io::Result<Vec<_>>>()?;
    paths.sort();
    let mut entries=Vec::new();
    for path in paths { if path.extension().is_some_and(|s|s=="yaml") { entries.push(parse(&std::fs::read_to_string(&path)?).with_context(||format!("dataset file {}",path.file_name().unwrap_or_default().to_string_lossy()))?); } }
    validate(&entries,root)?;
    Ok(entries)
}
pub fn validate(entries: &[Entry],root: &Path) -> Result<()> {
    ensure!(entries.len()>=60,"dataset needs at least 60 entries");
    let outputs=std::fs::read_to_string(root.join("tool/receipt_outputs.txt"))?;
    let outputs: BTreeSet<_>=outputs.lines().filter(|s|!s.is_empty()).collect();
    ensure!(outputs.len()==3,"receipt manifest needs three images");
    // The build host generates and commits these before running any test.
    for file in &outputs {
        ensure!(!file.contains('/') && file.ends_with(".jpg"),"invalid receipt manifest");
        let bytes=std::fs::read(root.join("fixtures").join(file)).context("generate receipts before tests")?;
        ensure!(image::guess_format(&bytes)?==image::ImageFormat::Jpeg,"receipt is not JPEG");
        image::load_from_memory_with_format(&bytes,image::ImageFormat::Jpeg)?;
    }
    let mut referenced_images=BTreeSet::new();
    let mut ids=BTreeSet::new(); let mut categories=BTreeSet::new(); let mut ambiguous=BTreeMap::<&str,usize>::new();
    for e in entries {
        ensure!(e.schema_version==1 && !e.id.is_empty() && e.id.bytes().all(|b|b.is_ascii_alphanumeric()||b==b'-'),"invalid entry identity");
        ensure!(ids.insert(&e.id),"duplicate id: {}",e.id);
        ensure!(matches!(e.locale.as_str(),"zh-Hans"|"en"),"invalid locale");
        ensure!(matches!(e.timezone.as_str(),"UTC"|"Asia/Shanghai"|"Asia/Singapore"),"unsupported timezone");
        ensure!(CATEGORIES.contains(&e.category.as_str()),"unknown category"); categories.insert(e.category.as_str());
        ensure!(!e.input.text.trim().is_empty() && e.input.text.len()<=32000 && e.input.images.len()<=8,"invalid input size");
        ensure!(e.setup.currency=="CNY","initial corpus uses CNY");
        for file in &e.input.images {
            let file=file.strip_prefix("fixtures/").context("image path must begin with fixtures/")?;
            ensure!(outputs.contains(file),"image absent from manifest");referenced_images.insert(file);
        }
        if e.category=="receipt" {ensure!(!e.input.images.is_empty(),"receipt needs an image");}
        if e.category=="ambiguous_date" {
            *ambiguous.entry(&e.locale).or_default()+=1;
            ensure!(e.ambiguity_reason.as_ref().is_some_and(|s|!s.trim().is_empty()),"missing ambiguity explanation");
        }
        if matches!(e.category.as_str(),"ambiguous_date"|"insufficient") { ensure!(e.expect.hard && e.expect.behavior==Behavior::AskUser,"question must be hard"); }
        if e.expect.behavior==Behavior::AskUser {ensure!(e.expect.hard,"question behavior is a hard standard");}
        if e.expect.records.iter().any(|r|r.operation!="create") {ensure!(e.expect.behavior==Behavior::ConfirmThenWrite && e.expect.hard,"existing-record operations require hard confirmation");}
        if e.expect.behavior==Behavior::ConfirmThenWrite {ensure!(e.expect.hard,"confirmation is a hard standard");ensure!(e.expect.records.len()==1 && e.expect.records[0].operation!="create","confirmation corpus needs one existing-record operation");}
        if e.category=="confirmation" { ensure!(e.expect.hard && e.expect.behavior==Behavior::ConfirmThenWrite,"confirmation must be hard"); }
        if matches!(e.expect.behavior,Behavior::AskUser|Behavior::NoWrite) {ensure!(e.expect.records.is_empty(),"non-write records must be empty");} else {ensure!(!e.expect.records.is_empty(),"write records missing");}
        let mut accounts=BTreeMap::new();
        for a in &e.setup.accounts {ensure!(matches!(a.kind.as_str(),"real"|"purpose") && !a.key.is_empty() && !a.name.is_empty() && a.name.chars().count()<=30,"invalid account");ensure!(accounts.insert(a.key.as_str(),a.kind.as_str()).is_none(),"duplicate account alias");}
        let mut records=BTreeSet::new();
        for r in &e.setup.records { validate_record(&r.record,&accounts,&records,&e.setup.currency)?; ensure!(!r.key.is_empty() && r.record.operation=="create" && records.insert(r.key.as_str()),"invalid setup record"); }
        let mut targets=BTreeSet::new();
        for r in &e.expect.records {
            validate_record(r,&accounts,&records,&e.setup.currency)?;
            if let Some(target)=&r.target {ensure!(targets.insert(target),"one expected operation per existing target");}
            if r.operation=="create" {ensure!(r.status.as_deref()!=Some("voided"),"new expected records must be active");}
        }
    }
    ensure!(outputs.iter().all(|file|referenced_images.contains(file)),"all receipt variants must be referenced");
    ensure!(ambiguous.get("zh-Hans")==Some(&10) && ambiguous.get("en")==Some(&10),"need exactly 10 ambiguous dates per language");
    ensure!(CATEGORIES.iter().all(|c|categories.contains(c)),"category coverage incomplete");
    Ok(())
}
fn validate_record(r:&RecordSpec,accounts:&BTreeMap<&str,&str>,records:&BTreeSet<&str>,currency:&str)->Result<()> {
    ensure!(matches!(r.operation.as_str(),"create"|"update"|"void"|"restore"),"invalid operation");
    if r.operation!="create" {ensure!(r.target.as_deref().is_some_and(|s|records.contains(s)),"missing target");}
    if r.operation=="create" {ensure!(r.kind.is_some() && r.amount_minor.is_some() && r.occurred_on.is_some(),"mock creates require kind/amount/date");}
    if r.operation=="create" {
        ensure!(r.target.is_none(),"creates cannot target an existing record");
        match r.kind.as_deref() {
            Some("expense")=>ensure!(r.account.is_some() && r.purpose.is_some() && r.to_account.is_none() && r.to_purpose.is_none() && r.refund_of.is_none(),"expense shape invalid"),
            Some("income")=>ensure!(r.account.is_some() && r.purpose.is_none() && r.to_account.is_none() && r.to_purpose.is_none() && r.refund_of.is_none(),"income shape invalid"),
            Some("transfer")=>ensure!(r.account.is_some() && r.to_account.is_some() && r.account!=r.to_account && r.purpose.is_none() && r.to_purpose.is_none() && r.refund_of.is_none(),"transfer needs distinct accounts"),
            Some("reallocation")=>ensure!(r.purpose.is_some() && r.to_purpose.is_some() && r.purpose!=r.to_purpose && r.account.is_none() && r.to_account.is_none() && r.refund_of.is_none(),"reallocation needs distinct purposes"),
            Some("refund")=>ensure!(r.refund_of.is_some() && r.to_account.is_none() && r.to_purpose.is_none(),"refund needs parent"),
            _=>bail!("invalid create kind"),
        }
    }
    if let Some(k)=&r.kind {ensure!(matches!(k.as_str(),"expense"|"income"|"transfer"|"reallocation"|"refund"),"invalid record kind");}
    if let Some(a)=r.amount_minor {ensure!(a>0 && a<=1_000_000_000_000,"invalid amount");}
    if let Some(c)=&r.currency {ensure!(c==currency,"currency mismatch");}
    if let Some(k)=&r.preset_key {ensure!(jiabu_domain::presets::PRESETS.iter().any(|p|p.preset_key==k),"unknown preset");}
    for (a,kind) in [(&r.account,"real"),(&r.to_account,"real"),(&r.purpose,"purpose"),(&r.to_purpose,"purpose")] {if let Some(a)=a {ensure!(accounts.get(a.as_str())==Some(&kind),"invalid account reference");}}
    if let Some(parent)=&r.refund_of {ensure!(records.contains(parent.as_str()),"invalid refund parent");}
    if let Some(s)=&r.status {ensure!(matches!(s.as_str(),"active"|"voided"),"invalid status");}
    Ok(())
}

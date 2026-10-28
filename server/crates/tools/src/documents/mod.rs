//! One S6 inventory generates registration and the push discriminated union.
use crate::{
    Effect, Exposure, Module, StepKind, StepLabel, ToolCtx, ToolError, ToolRegistry, TypedTool,
    templates::TemplateStore, tool::ToolFuture,
};
use jiabu_db::SpaceTx;
use jiabu_domain::documents::*;
use serde_json::{Value, json};
use std::sync::Arc;
fn subject_example() -> Value {
    json!({"id":"00000000-0000-7000-8000-000000000011","space_id":"00000000-0000-7000-8000-000000000006","module":"documents","visibility":null,"kind":"family_member","name":"示例家人甲","member_id":null,"archived_at":null,"deleted_at":null,"created_by_member_id":"00000000-0000-7000-8000-000000000005","version":1,"change_seq":10,"created_at":"2026-10-12T00:00:00Z","updated_at":"2026-10-12T00:00:00Z"})
}
fn document_example() -> Value {
    json!({"id":"00000000-0000-7000-8000-000000000012","space_id":"00000000-0000-7000-8000-000000000006","module":"documents","visibility":null,"template_id":null,"template_version":null,"title":"虚构资料","event_date":"2026-10-12","subject_ids":[],"content":{"v":1,"items":[{"key":"note","type":"text","label":"备注","value":"虚构样例"}]},"status":"active","origin":"api","run_id":null,"created_by_member_id":"00000000-0000-7000-8000-000000000005","updated_by_member_id":"00000000-0000-7000-8000-000000000005","version":1,"change_seq":12,"created_at":"2026-10-12T00:00:00Z","updated_at":"2026-10-12T00:00:00Z"})
}
macro_rules! document_tools {
    ($($tool:ident:$args:ty=>$result:ty {
        name:$name:literal,effect:$effect:ident,exposure:$exposure:ident,confirm:$confirm:literal,kind:$kind:ident,
        description:$description:literal,example_args:$example_args:expr,example_output:$example_output:expr,
        execute:|$a:ident,$c:ident,$t:ident,$catalog:ident,$audit:ident|$execute:expr
    };)+)=>{
        $(struct $tool {templates:Arc<TemplateStore>}
        impl TypedTool for $tool {
            type Args=$args;type Output=$result;
            fn name(&self)->&'static str{$name}fn description(&self)->&'static str{$description}
            fn module(&self)->Module{Module::Documents}fn effect(&self)->Effect{Effect::$effect}fn exposure(&self)->Exposure{Exposure::$exposure}
            fn requires_confirmation(&self,_:&Self::Args)->bool{$confirm}fn step_kind(&self)->StepKind{StepKind::$kind}
            fn step_label(&self,_:&Self::Args,_:&ToolCtx)->StepLabel{StepLabel($description)}
            fn example_args(&self)->Value{$example_args}fn example_output(&self)->Value{$example_output}
            fn execute<'a>(&'a self,args:Self::Args,ctx:&'a ToolCtx,tx:&'a SpaceTx)->ToolFuture<'a,Result<Self::Output,ToolError>>{
                Box::pin(async move{let $a=args;let $c=ctx;let $t=tx;let $catalog=self.templates.snapshot().await;
                    let mut audit=ctx.audit(tx.member(ctx.space_id));
                    audit.origin=if ctx.run_id.is_some(){"chat"}else if matches!(ctx.principal.via,jiabu_db::Via::ApiKey{..}){"api"}else{"manual"};
                    let $audit=audit;$execute})
            }
        })+
        #[derive(serde::Serialize,serde::Deserialize,schemars::JsonSchema)]
        #[serde(tag="tool",content="args",deny_unknown_fields)]
        pub enum ToolCall {$(#[serde(rename=$name)]$kind($args)),+}
        impl ToolCall {pub fn name(&self)->&'static str{match self{$(Self::$kind(_)=>$name),+}}}
        pub(super) fn register(registry:&mut ToolRegistry,templates:Arc<TemplateStore>)->Result<(),ToolError>{
            $(registry.register($tool{templates:templates.clone()})?;)+Ok(())
        }
    }
}
document_tools! {
    ListSubjectsTool:ListSubjects=>SubjectsResult {
        name:"list_subjects",effect:Read,exposure:AgentAndApi,confirm:false,kind:ListSubjects,
        description:"列出当前空间的资料对象；默认不含归档，按名称和 ID 排序并分页",example_args:json!({}),example_output:json!({"subjects":[subject_example()],"has_more":false}),
        execute:|args,ctx,tx,_catalog,_audit|tx.documents_list_subjects(ctx.space_id,args).await
    };
    SearchDocumentsTool:SearchDocuments=>DocumentsResult {
        name:"search_documents",effect:Read,exposure:AgentAndApi,confirm:false,kind:SearchDocuments,
        description:"按对象或未关联、模板、事件日期和创建人筛选资料；日期及 ID 倒序分页，默认有效资料",example_args:json!({}),example_output:json!({"documents":[document_example()],"has_more":false}),
        execute:|args,ctx,tx,_catalog,_audit|tx.documents_search(ctx.space_id,args).await
    };
    GetDocumentTool:GetDocument=>Document {
        name:"get_document",effect:Read,exposure:AgentAndApi,confirm:false,kind:GetDocument,
        description:"读取当前空间的一份资料，包括已作废资料",example_args:json!({"id":"00000000-0000-7000-8000-000000000012"}),example_output:document_example(),
        execute:|args,ctx,tx,_catalog,_audit|tx.documents_get(ctx.space_id,args).await
    };
    DocumentMetricSeriesTool:MetricSeries=>MetricResult {
        name:"document_metric_series",effect:Read,exposure:AgentAndApi,confirm:false,kind:DocumentMetricSeries,
        description:"查询同一对象同一指标的历次有效数值；以范围内最近一次单位为准，其他单位列入 excluded，不换算",example_args:json!({"subject_id":"00000000-0000-7000-8000-000000000011","metric":"body.weight"}),example_output:json!({"subject_id":"00000000-0000-7000-8000-000000000011","metric":"body.weight","unit":"kg","points":[],"excluded":[]}),
        execute:|args,ctx,tx,catalog,_audit|tx.documents_metric(ctx.space_id,args,&catalog.templates).await
    };
    CreateDocumentTool:CreateDocument=>Document {
        name:"create_document",effect:LocalWrite,exposure:AgentAndApi,confirm:false,kind:CreateDocument,
        description:"新建资料；按模板校验内容、对象和原图，必填缺项仍可保存",example_args:json!({"title":"虚构资料","content":{"v":1,"items":[]}}),example_output:document_example(),
        execute:|args,ctx,tx,catalog,audit|tx.documents_create(ctx.space_id,ctx.new_id(args.id)?,args,&catalog.templates,&audit,&ctx.principal.user.locale).await
    };
    UpdateDocumentTool:UpdateDocument=>Document {
        name:"update_document",effect:LocalWrite,exposure:AgentAndApi,confirm:true,kind:UpdateDocument,
        description:"修改有效资料；expected_version 冲突返回 current；更正关联对象保留完整修改快照",example_args:json!({"id":"00000000-0000-7000-8000-000000000012","expected_version":1,"changes":{"title":"虚构更正"}}),example_output:document_example(),
        execute:|args,ctx,tx,catalog,audit|tx.documents_update(ctx.space_id,args,&catalog.templates,&audit,&ctx.principal.user.locale).await
    };
    VoidDocumentTool:Versioned=>Document {
        name:"void_document",effect:LocalWrite,exposure:AgentAndApi,confirm:true,kind:VoidDocument,
        description:"作废资料并保留历史；需要 expected_version",example_args:json!({"id":"00000000-0000-7000-8000-000000000012","expected_version":1}),example_output:document_example(),
        execute:|args,ctx,tx,_catalog,audit|tx.documents_status(ctx.space_id,args,false,&audit).await
    };
    RestoreDocumentTool:Versioned=>Document {
        name:"restore_document",effect:LocalWrite,exposure:AgentAndApi,confirm:false,kind:RestoreDocument,
        description:"恢复已作废资料；需要 expected_version",example_args:json!({"id":"00000000-0000-7000-8000-000000000012","expected_version":2}),example_output:document_example(),
        execute:|args,ctx,tx,_catalog,audit|tx.documents_status(ctx.space_id,args,true,&audit).await
    };
    CreateSubjectTool:CreateSubject=>Subject {
        name:"create_subject",effect:LocalWrite,exposure:AgentAndApi,confirm:false,kind:CreateSubject,
        description:"新建资料对象；规范化同种类同名对象直接沿用，已归档则自动取消归档",example_args:json!({"kind":"family_member","name":"虚构家人"}),example_output:subject_example(),
        execute:|args,ctx,tx,_catalog,audit|tx.documents_create_subject(ctx.space_id,ctx.new_id(args.id)?,args,&audit).await
    };
    UpdateSubjectTool:UpdateSubject=>Subject {
        name:"update_subject",effect:LocalWrite,exposure:AgentAndApi,confirm:false,kind:UpdateSubject,
        description:"修改资料对象名字或空间成员绑定；种类固定，不合并同名对象",example_args:json!({"id":"00000000-0000-7000-8000-000000000011","expected_version":1,"name":"虚构新名字"}),example_output:subject_example(),
        execute:|args,ctx,tx,_catalog,audit|tx.documents_update_subject(ctx.space_id,args,&audit).await
    };
    ArchiveSubjectTool:Versioned=>Subject {
        name:"archive_subject",effect:LocalWrite,exposure:AgentAndApi,confirm:false,kind:ArchiveSubject,
        description:"归档资料对象；有关联资料也允许归档",example_args:json!({"id":"00000000-0000-7000-8000-000000000011","expected_version":1}),example_output:subject_example(),
        execute:|args,ctx,tx,_catalog,audit|tx.documents_archive_subject(ctx.space_id,args,&audit).await
    };
    DeleteSubjectTool:Versioned=>Subject {
        name:"delete_subject",effect:LocalWrite,exposure:ApiOnly,confirm:false,kind:DeleteSubject,
        description:"删除没有任何资料关联的对象；已作废资料的关联也会阻止删除",example_args:json!({"id":"00000000-0000-7000-8000-000000000011","expected_version":1}),example_output:subject_example(),
        execute:|args,ctx,tx,_catalog,audit|tx.documents_delete_subject(ctx.space_id,args,&audit).await
    };
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn inventory_examples_exposure_and_confirmation() -> Result<(), ToolError> {
        let registry = ToolRegistry::with_templates(Arc::new(TemplateStore::empty()?))?;
        assert_eq!(
            registry
                .tools()
                .filter(|t| matches!(t.module(), Module::Documents))
                .count(),
            12
        );
        for tool in registry
            .tools()
            .filter(|t| matches!(t.module(), Module::Documents))
        {
            assert_eq!(
                tool.effect(),
                if matches!(
                    tool.name(),
                    "list_subjects"
                        | "search_documents"
                        | "get_document"
                        | "document_metric_series"
                ) {
                    Effect::Read
                } else {
                    Effect::LocalWrite
                }
            );
            let args = tool.example_args();
            let call = tool.validate(args.clone())?;
            assert_eq!(
                tool.requires_confirmation(call.as_ref()),
                matches!(tool.name(), "update_document" | "void_document")
            );
            let mut injected = args;
            injected["space_id"] = json!(uuid::Uuid::nil());
            assert!(tool.validate(injected).is_err());
            assert!(
                jsonschema::validator_for(tool.output_schema())
                    .map_err(|_| ToolError::internal())?
                    .is_valid(&tool.example_output()),
                "{}",
                tool.name()
            );
            let typed: crate::ToolCall =
                serde_json::from_value(json!({"tool":tool.name(),"args":tool.example_args()}))
                    .map_err(|_| ToolError::invalid())?;
            assert_eq!(typed.name(), tool.name());
        }
        assert_eq!(
            registry.get("delete_subject")?.exposure(),
            Exposure::ApiOnly
        );
        assert!(!registry.agent_tools().any(|t| t.name() == "delete_subject"));
        Ok(())
    }
}

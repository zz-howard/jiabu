//! One inventory generates typed implementations, startup registration and S4's
//! tagged call type. HTTP paths and OpenAPI operations derive from this inventory.
use crate::{
    Effect, Exposure, StepKind, StepLabel, ToolCtx, ToolError, ToolRegistry, TypedTool,
    tool::ToolFuture,
};
use jiabu_db::SpaceTx;
use jiabu_domain::ledger::*;
use serde_json::{Value, json};

macro_rules! ledger_tools {
    ($( $tool:ident : $args:ty => $result:ty {
        name: $name:literal, effect: $effect:ident, exposure: $exposure:ident,
        confirm: $confirm:literal, kind: $kind:ident,
        description: $description:literal, label: $label:literal,
        example_args: $example_args:expr, example_output: $example_output:expr,
        execute: |$args_var:ident, $ctx_var:ident, $tx_var:ident| $execute:expr
    }; )+) => {
        $(struct $tool;
        impl TypedTool for $tool {
            type Args=$args;
            type Output=$result;
            fn name(&self)->&'static str {$name}
            fn description(&self)->&'static str {$description}
            fn effect(&self)->Effect {Effect::$effect}
            fn exposure(&self)->Exposure {Exposure::$exposure}
            fn requires_confirmation(&self,_args:&Self::Args)->bool {$confirm}
            fn step_kind(&self)->StepKind {StepKind::$kind}
            fn step_label(&self,_args:&Self::Args,_ctx:&ToolCtx)->StepLabel {StepLabel($label)}
            fn example_args(&self)->Value {$example_args}
            fn example_output(&self)->Value {$example_output}
            fn execute<'a>(&'a self,args:Self::Args,ctx:&'a ToolCtx,tx:&'a SpaceTx)->ToolFuture<'a,Result<Self::Output,ToolError>> {
                Box::pin(async move {let $args_var=args;let $ctx_var=ctx;let $tx_var=tx;$execute})
            }
        })+
        /// S4 can consume this typed discriminated union; S3 exposes no push route.
        #[derive(serde::Serialize,serde::Deserialize,schemars::JsonSchema)]
        #[serde(tag="tool",content="args",deny_unknown_fields)]
        pub enum ToolCall {$(#[serde(rename=$name)] $kind($args)),+}
        pub(super) fn register(registry:&mut ToolRegistry)->Result<(),ToolError> {
            $(registry.register($tool)?;)+
            Ok(())
        }
    };
}
ledger_tools! {
    ListAccountsTool: ListAccounts => AccountsResult {
        name: "list_accounts", effect: Read, exposure: AgentAndApi,
        confirm: false, kind: ListAccounts,
        description: "列出当前空间的账户", label: "列出当前空间的账户",
        example_args: json!({}),
        example_output: json!({"accounts":[{"id":"00000000-0000-7000-8000-000000000001","space_id":"00000000-0000-7000-8000-000000000006","module":"ledger","visibility":null,"kind":"real","name":"示例银行卡","is_reserve":false,"opening_balance_minor":0,"opening_on":"2026-01-01","sort_key":0,"created_by_member_id":"00000000-0000-7000-8000-000000000005","archived_at":null,"version":1,"change_seq":1,"created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}],"has_more":false}),
        execute: |args,ctx,tx| tx.ledger_accounts(ctx.space_id,args).await
    };
    ListTagsTool: ListTags => TagsResult {
        name: "list_tags", effect: Read, exposure: AgentAndApi,
        confirm: false, kind: ListTags,
        description: "列出当前空间的标签", label: "列出当前空间的标签",
        example_args: json!({}),
        example_output: json!({"tags":[{"id":"00000000-0000-7000-8000-000000000003","space_id":"00000000-0000-7000-8000-000000000006","module":"ledger","preset_key":null,"name":"示例标签","created_by_member_id":"00000000-0000-7000-8000-000000000005","deleted_at":null,"version":1,"change_seq":2}],"has_more":false}),
        execute: |args,ctx,tx| tx.ledger_tags(ctx.space_id,args).await
    };
    QueryBalanceTool: QueryBalance => BalanceResult {
        name: "query_balance", effect: Read, exposure: AgentAndApi,
        confirm: false, kind: QueryBalance,
        description: "查询当前空间实时余额", label: "查询当前空间实时余额",
        example_args: json!({}),
        example_output: json!({"currency":"CNY","balances":[{"account_id":"00000000-0000-7000-8000-000000000001","balance_minor":0}]}),
        execute: |args,ctx,tx| tx.ledger_balance(ctx.space_id,args).await
    };
    QueryStatsTool: QueryStats => StatsResult {
        name: "query_stats", effect: Read, exposure: AgentAndApi,
        confirm: false, kind: QueryStats,
        description: "按期间与条件统计；消费金额按支出减退款，退款按退款日期计入；标签各组合计可能超过总额", label: "按期间与条件统计",
        example_args: json!({"measure":"sum","period":{"from":"2026-01-01","through":"2026-01-31"}}),
        example_output: json!({"currency":"CNY","total":0,"groups":[],"tag_groups_may_overlap":false}),
        execute: |args,ctx,tx| tx.ledger_stats(ctx.space_id,args).await
    };
    SearchRecordsTool: SearchRecords => RecordsResult {
        name: "search_records", effect: Read, exposure: AgentAndApi,
        confirm: false, kind: SearchRecords,
        description: "筛选记录；日期及 ID 倒序，使用 limit/offset 分页", label: "筛选记录",
        example_args: json!({}),
        example_output: json!({"records":[{"id":"00000000-0000-7000-8000-000000000004","space_id":"00000000-0000-7000-8000-000000000006","module":"ledger","visibility":null,"kind":"expense","amount_minor":100,"occurred_on":"2026-01-01","account_id":"00000000-0000-7000-8000-000000000001","to_account_id":null,"purpose_id":"00000000-0000-7000-8000-000000000002","to_purpose_id":null,"refund_of_id":null,"tag_ids":[],"note":null,"attachments":[],"status":"active","void_reason":null,"origin":"api","run_id":null,"created_by_member_id":"00000000-0000-7000-8000-000000000005","updated_by_member_id":"00000000-0000-7000-8000-000000000005","version":1,"change_seq":3,"created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}],"has_more":false}),
        execute: |args,ctx,tx| tx.ledger_search(ctx.space_id,args).await
    };
    GetRecordTool: GetRecord => Record {
        name: "get_record", effect: Read, exposure: AgentAndApi,
        confirm: false, kind: GetRecord,
        description: "读取本空间的一条记录", label: "读取本空间的一条记录",
        example_args: json!({"id":"00000000-0000-7000-8000-000000000004"}),
        example_output: json!({"id":"00000000-0000-7000-8000-000000000004","space_id":"00000000-0000-7000-8000-000000000006","module":"ledger","visibility":null,"kind":"expense","amount_minor":100,"occurred_on":"2026-01-01","account_id":"00000000-0000-7000-8000-000000000001","to_account_id":null,"purpose_id":"00000000-0000-7000-8000-000000000002","to_purpose_id":null,"refund_of_id":null,"tag_ids":[],"note":null,"attachments":[],"status":"active","void_reason":null,"origin":"api","run_id":null,"created_by_member_id":"00000000-0000-7000-8000-000000000005","updated_by_member_id":"00000000-0000-7000-8000-000000000005","version":1,"change_seq":3,"created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}),
        execute: |args,ctx,tx| tx.ledger_record(ctx.space_id,args).await
    };
    CreateRecordTool: CreateRecord => Record {
        name: "create_record", effect: LocalWrite, exposure: AgentAndApi,
        confirm: false, kind: CreateRecord,
        description: "记支出、收入、转账、调拨或退款；归档的原账户或用途须显式更换", label: "记支出、收入、转账、调拨或退款",
        example_args: json!({"id":"00000000-0000-7000-8000-000000000004","kind":"expense","amount_minor":100,"occurred_on":"2026-01-01","account_id":"00000000-0000-7000-8000-000000000001","purpose_id":"00000000-0000-7000-8000-000000000002"}),
        example_output: json!({"id":"00000000-0000-7000-8000-000000000004","space_id":"00000000-0000-7000-8000-000000000006","module":"ledger","visibility":null,"kind":"expense","amount_minor":100,"occurred_on":"2026-01-01","account_id":"00000000-0000-7000-8000-000000000001","to_account_id":null,"purpose_id":"00000000-0000-7000-8000-000000000002","to_purpose_id":null,"refund_of_id":null,"tag_ids":[],"note":null,"attachments":[],"status":"active","void_reason":null,"origin":"api","run_id":null,"created_by_member_id":"00000000-0000-7000-8000-000000000005","updated_by_member_id":"00000000-0000-7000-8000-000000000005","version":1,"change_seq":3,"created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}),
        execute: |args,ctx,tx| tx.ledger_create_record(ctx.space_id,ctx.new_id(args.id)?,args,&ctx.audit(tx.member(ctx.space_id))).await
    };
    UpdateRecordTool: UpdateRecord => Record {
        name: "update_record", effect: LocalWrite, exposure: AgentAndApi,
        confirm: true, kind: UpdateRecord,
        description: "修改已有有效记录；种类和退款父关联不可改", label: "修改已有有效记录",
        example_args: json!({"id":"00000000-0000-7000-8000-000000000004","expected_version":1,"changes":{"amount_minor":90}}),
        example_output: json!({"id":"00000000-0000-7000-8000-000000000004","space_id":"00000000-0000-7000-8000-000000000006","module":"ledger","visibility":null,"kind":"expense","amount_minor":90,"occurred_on":"2026-01-01","account_id":"00000000-0000-7000-8000-000000000001","to_account_id":null,"purpose_id":"00000000-0000-7000-8000-000000000002","to_purpose_id":null,"refund_of_id":null,"tag_ids":[],"note":null,"attachments":[],"status":"active","void_reason":null,"origin":"api","run_id":null,"created_by_member_id":"00000000-0000-7000-8000-000000000005","updated_by_member_id":"00000000-0000-7000-8000-000000000005","version":2,"change_seq":3,"created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}),
        execute: |args,ctx,tx| tx.ledger_update_record(ctx.space_id,args,&ctx.audit(tx.member(ctx.space_id))).await
    };
    VoidRecordTool: VersionedRecord => Record {
        name: "void_record", effect: LocalWrite, exposure: AgentAndApi,
        confirm: true, kind: VoidRecord,
        description: "撤销记录；有有效退款的支出须先撤销退款", label: "撤销记录",
        example_args: json!({"id":"00000000-0000-7000-8000-000000000004","expected_version":1}),
        example_output: json!({"id":"00000000-0000-7000-8000-000000000004","space_id":"00000000-0000-7000-8000-000000000006","module":"ledger","visibility":null,"kind":"expense","amount_minor":100,"occurred_on":"2026-01-01","account_id":"00000000-0000-7000-8000-000000000001","to_account_id":null,"purpose_id":"00000000-0000-7000-8000-000000000002","to_purpose_id":null,"refund_of_id":null,"tag_ids":[],"note":null,"attachments":[],"status":"voided","void_reason":"user","origin":"api","run_id":null,"created_by_member_id":"00000000-0000-7000-8000-000000000005","updated_by_member_id":"00000000-0000-7000-8000-000000000005","version":2,"change_seq":3,"created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}),
        execute: |args,ctx,tx| tx.ledger_record_status(ctx.space_id,args,false,&ctx.audit(tx.member(ctx.space_id))).await
    };
    RestoreRecordTool: VersionedRecord => Record {
        name: "restore_record", effect: LocalWrite, exposure: AgentAndApi,
        confirm: true, kind: RestoreRecord,
        description: "恢复已撤销记录；退款须重新满足父支出及金额限制", label: "恢复已撤销记录",
        example_args: json!({"id":"00000000-0000-7000-8000-000000000004","expected_version":2}),
        example_output: json!({"id":"00000000-0000-7000-8000-000000000004","space_id":"00000000-0000-7000-8000-000000000006","module":"ledger","visibility":null,"kind":"expense","amount_minor":100,"occurred_on":"2026-01-01","account_id":"00000000-0000-7000-8000-000000000001","to_account_id":null,"purpose_id":"00000000-0000-7000-8000-000000000002","to_purpose_id":null,"refund_of_id":null,"tag_ids":[],"note":null,"attachments":[],"status":"active","void_reason":null,"origin":"api","run_id":null,"created_by_member_id":"00000000-0000-7000-8000-000000000005","updated_by_member_id":"00000000-0000-7000-8000-000000000005","version":3,"change_seq":3,"created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}),
        execute: |args,ctx,tx| tx.ledger_record_status(ctx.space_id,args,true,&ctx.audit(tx.member(ctx.space_id))).await
    };
    CreateAccountTool: CreateAccount => Account {
        name: "create_account", effect: LocalWrite, exposure: AgentAndApi,
        confirm: false, kind: CreateAccount,
        description: "新建真实资金账户或用途账户及起始余额", label: "新建真实资金账户或用途账户及起始余额",
        example_args: json!({"id":"00000000-0000-7000-8000-000000000001","kind":"real","name":"示例银行卡","opening_on":"2026-01-01"}),
        example_output: json!({"id":"00000000-0000-7000-8000-000000000001","space_id":"00000000-0000-7000-8000-000000000006","module":"ledger","visibility":null,"kind":"real","name":"示例银行卡","is_reserve":false,"opening_balance_minor":0,"opening_on":"2026-01-01","sort_key":0,"created_by_member_id":"00000000-0000-7000-8000-000000000005","archived_at":null,"version":1,"change_seq":1,"created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}),
        execute: |args,ctx,tx| tx.ledger_create_account(ctx.space_id,ctx.new_id(args.id)?,args,&ctx.audit(tx.member(ctx.space_id))).await
    };
    UpdateAccountTool: UpdateAccount => Account {
        name: "update_account", effect: LocalWrite, exposure: AgentAndApi,
        confirm: false, kind: UpdateAccount,
        description: "修改账户名称、起始余额、日期或排序；账户类型不可改", label: "修改账户名称、起始余额、日期或排序",
        example_args: json!({"id":"00000000-0000-7000-8000-000000000001","expected_version":1,"name":"示例现金"}),
        example_output: json!({"id":"00000000-0000-7000-8000-000000000001","space_id":"00000000-0000-7000-8000-000000000006","module":"ledger","visibility":null,"kind":"real","name":"示例现金","is_reserve":false,"opening_balance_minor":0,"opening_on":"2026-01-01","sort_key":0,"created_by_member_id":"00000000-0000-7000-8000-000000000005","archived_at":null,"version":2,"change_seq":1,"created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}),
        execute: |args,ctx,tx| tx.ledger_update_account(ctx.space_id,args,&ctx.audit(tx.member(ctx.space_id))).await
    };
    ArchiveAccountTool: ArchiveAccount => Account {
        name: "archive_account", effect: LocalWrite, exposure: AgentAndApi,
        confirm: true, kind: ArchiveAccount,
        description: "归档零余额账户并停用其拨入计划", label: "归档零余额账户并停用其拨入计划",
        example_args: json!({"id":"00000000-0000-7000-8000-000000000001","expected_version":1}),
        example_output: json!({"id":"00000000-0000-7000-8000-000000000001","space_id":"00000000-0000-7000-8000-000000000006","module":"ledger","visibility":null,"kind":"real","name":"示例银行卡","is_reserve":false,"opening_balance_minor":0,"opening_on":"2026-01-01","sort_key":0,"created_by_member_id":"00000000-0000-7000-8000-000000000005","archived_at":"2026-01-01T00:00:00Z","version":2,"change_seq":1,"created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}),
        execute: |args,ctx,tx| tx.ledger_archive_account(ctx.space_id,args,&ctx.audit(tx.member(ctx.space_id))).await
    };
    SetAllocationPlanTool: SetAllocationPlan => AllocationPlan {
        name: "set_allocation_plan", effect: LocalWrite, exposure: AgentAndApi,
        confirm: false, kind: SetAllocationPlan,
        description: "设置、修改或停用每月拨入；启用或修改先补旧计划已到期月份，停用不补拨", label: "设置、修改或停用每月拨入",
        example_args: json!({"account_id":"00000000-0000-7000-8000-000000000002","amount_minor":1000,"day_of_month":15,"enabled":true}),
        example_output: json!({"account_id":"00000000-0000-7000-8000-000000000002","space_id":"00000000-0000-7000-8000-000000000006","amount_minor":1000,"day_of_month":15,"enabled":true,"next_run_on":"2026-01-15","last_run_month":null,"version":1,"change_seq":4,"updated_at":"2026-01-01T00:00:00Z"}),
        execute: |args,ctx,tx| tx.ledger_set_plan(ctx.space_id,args,&ctx.audit(tx.member(ctx.space_id))).await
    };
    CreateTagTool: CreateTag => Tag {
        name: "create_tag", effect: LocalWrite, exposure: AgentAndApi,
        confirm: false, kind: CreateTag,
        description: "新建本空间自定义标签", label: "新建本空间自定义标签",
        example_args: json!({"id":"00000000-0000-7000-8000-000000000003","name":"示例标签"}),
        example_output: json!({"id":"00000000-0000-7000-8000-000000000003","space_id":"00000000-0000-7000-8000-000000000006","module":"ledger","preset_key":null,"name":"示例标签","created_by_member_id":"00000000-0000-7000-8000-000000000005","deleted_at":null,"version":1,"change_seq":2}),
        execute: |args,ctx,tx| tx.ledger_create_tag(ctx.space_id,ctx.new_id(args.id)?,args,&ctx.audit(tx.member(ctx.space_id))).await
    };
    RenameTagTool: RenameTag => Tag {
        name: "rename_tag", effect: LocalWrite, exposure: AgentAndApi,
        confirm: false, kind: RenameTag,
        description: "修改标签的共同名称；保留预置标签身份", label: "修改标签的共同名称",
        example_args: json!({"id":"00000000-0000-7000-8000-000000000003","expected_version":1,"name":"示例新标签"}),
        example_output: json!({"id":"00000000-0000-7000-8000-000000000003","space_id":"00000000-0000-7000-8000-000000000006","module":"ledger","preset_key":null,"name":"示例新标签","created_by_member_id":"00000000-0000-7000-8000-000000000005","deleted_at":null,"version":2,"change_seq":2}),
        execute: |args,ctx,tx| tx.ledger_rename_tag(ctx.space_id,args,&ctx.audit(tx.member(ctx.space_id))).await
    };
    DeleteTagTool: DeleteTag => Tag {
        name: "delete_tag", effect: LocalWrite, exposure: ApiOnly,
        confirm: false, kind: DeleteTag,
        description: "软删除标签，保留历史记录中的标签引用", label: "软删除标签，保留历史记录中的标签引用",
        example_args: json!({"id":"00000000-0000-7000-8000-000000000003","expected_version":1}),
        example_output: json!({"id":"00000000-0000-7000-8000-000000000003","space_id":"00000000-0000-7000-8000-000000000006","module":"ledger","preset_key":null,"name":"示例标签","created_by_member_id":"00000000-0000-7000-8000-000000000005","deleted_at":"2026-01-01T00:00:00Z","version":2,"change_seq":2}),
        execute: |args,ctx,tx| tx.ledger_delete_tag(ctx.space_id,args,&ctx.audit(tx.member(ctx.space_id))).await
    };
}

use super::*;
use jiabu_domain::ledger::*;

const BALANCE_SQL: &str = "select to_jsonb(x) data from (
 select a.id account_id, (a.opening_balance_minor::numeric + coalesce((
 select sum(case
 when a.kind='real' and r.account_id=a.id and r.kind in ('income','refund') then r.amount_minor::numeric
 when a.kind='real' and r.account_id=a.id and r.kind in ('expense','transfer') then -r.amount_minor::numeric
 when a.kind='real' and r.to_account_id=a.id and r.kind='transfer' then r.amount_minor::numeric
 when a.kind='purpose' and r.purpose_id=a.id and r.kind in ('allocation','refund') then r.amount_minor::numeric
 when a.kind='purpose' and r.purpose_id=a.id and r.kind in ('expense','reallocation') then -r.amount_minor::numeric
 when a.kind='purpose' and r.to_purpose_id=a.id and r.kind='reallocation' then r.amount_minor::numeric
 else 0 end) from records r where r.space_id=$1 and r.status='active'
 and (r.account_id=a.id or r.to_account_id=a.id or r.purpose_id=a.id or r.to_purpose_id=a.id)),0))::text balance_minor
 from accounts a where a.space_id=$1 and ($2::uuid is null or a.id=$2) order by a.sort_key,a.id) x";

// All filter references are checked separately, including member IDs and foreign IDs
// belonging to another space the same user can access.
impl SpaceTx {
    async fn check_filters(&self, space: SpaceId, filters: &Filters) -> Result<(), Error> {
        for id in [filters.account_id, filters.purpose_id]
            .into_iter()
            .flatten()
        {
            self.ledger_snapshot(space, Entity::Account, id).await?;
        }
        if let Some(id) = filters.tag_id {
            self.ledger_snapshot(space, Entity::Tag, id).await?;
        }
        if let Some(id) = filters.member_id {
            one(
                &self.tx,
                "select to_jsonb(m) data from space_members m where space_id=$1 and id=$2",
                vec![space.0.into(), id.into()],
            )
            .await?;
        }
        if filters
            .from
            .zip(filters.through)
            .is_some_and(|(a, b)| a > b)
        {
            return Err(Error::invalid());
        }
        Ok(())
    }
    pub async fn ledger_accounts(
        &self,
        space: SpaceId,
        args: ListAccounts,
    ) -> Result<AccountsResult, Error> {
        self.member(space);
        let rows = self.tx.query_all_raw(Statement::from_sql_and_values(DbBackend::Postgres,
            "select to_jsonb(a) data from accounts a where space_id=$1 and ($2 or archived_at is null) order by sort_key,id limit $3 offset $4",
            vec![space.0.into(), args.include_archived.into(), (i64::from(args.page.limit)+1).into(), i64::from(args.page.offset).into()])).await?;
        let mut accounts: Vec<Account> = rows
            .into_iter()
            .map(|r| decode(r.try_get("", "data")?))
            .collect::<Result<_, Error>>()?;
        let has_more = accounts.len() > args.page.limit as usize;
        accounts.truncate(args.page.limit as usize);
        Ok(AccountsResult { accounts, has_more })
    }
    pub async fn ledger_tags(&self, space: SpaceId, args: ListTags) -> Result<TagsResult, Error> {
        self.member(space);
        let rows = self.tx.query_all_raw(Statement::from_sql_and_values(DbBackend::Postgres,
            "select to_jsonb(t) data from tags t where space_id=$1 and ($2 or deleted_at is null) order by id limit $3 offset $4",
            vec![space.0.into(), args.include_deleted.into(), (i64::from(args.page.limit)+1).into(), i64::from(args.page.offset).into()])).await?;
        let mut tags: Vec<Tag> = rows
            .into_iter()
            .map(|r| decode(r.try_get("", "data")?))
            .collect::<Result<_, Error>>()?;
        let has_more = tags.len() > args.page.limit as usize;
        tags.truncate(args.page.limit as usize);
        Ok(TagsResult { tags, has_more })
    }
    pub async fn ledger_balance(
        &self,
        space: SpaceId,
        args: QueryBalance,
    ) -> Result<BalanceResult, Error> {
        self.member(space);
        if let Some(id) = args.account_id {
            self.ledger_snapshot(space, Entity::Account, id).await?;
        }
        let rows = self
            .tx
            .query_all_raw(Statement::from_sql_and_values(
                DbBackend::Postgres,
                BALANCE_SQL,
                vec![space.0.into(), args.account_id.into()],
            ))
            .await?;
        let balances = rows
            .into_iter()
            .map(|r| {
                let mut value: Value = r.try_get("", "data")?;
                value["balance_minor"] = json!(aggregate_minor(&value["balance_minor"])?);
                decode(value)
            })
            .collect::<Result<Vec<Balance>, Error>>()?;
        Ok(BalanceResult {
            currency: self.ledger_currency(space).await?,
            balances,
        })
    }
    pub async fn ledger_currency(&self, space: SpaceId) -> Result<String, Error> {
        let row = self
            .tx
            .query_one_raw(Statement::from_sql_and_values(
                DbBackend::Postgres,
                "select currency from spaces where id=$1 and deleted_at is null",
                [space.0.into()],
            ))
            .await?
            .ok_or_else(Error::not_found)?;
        row.try_get("", "currency").map_err(Error::from)
    }
    pub async fn ledger_record(&self, space: SpaceId, args: GetRecord) -> Result<Record, Error> {
        decode(self.ledger_snapshot(space, Entity::Record, args.id).await?)
    }
    pub async fn ledger_search(
        &self,
        space: SpaceId,
        args: SearchRecords,
    ) -> Result<RecordsResult, Error> {
        self.member(space);
        self.check_filters(space, &args.filters).await?;
        let sql = format!("select to_jsonb(r) data from records r where r.space_id=$1 and {} and
            (jsonb_array_length($2::jsonb->'kinds')=0 or r.kind in (select jsonb_array_elements_text($2::jsonb->'kinds')))
            order by r.occurred_on desc,r.id desc limit $3 offset $4", filter_sql("r.tag_ids"));
        let rows = self
            .tx
            .query_all_raw(Statement::from_sql_and_values(
                DbBackend::Postgres,
                sql,
                vec![
                    space.0.into(),
                    encode(args.filters)?.into(),
                    (i64::from(args.page.limit) + 1).into(),
                    i64::from(args.page.offset).into(),
                ],
            ))
            .await?;
        let mut records: Vec<Record> = rows
            .into_iter()
            .map(|r| decode(r.try_get("", "data")?))
            .collect::<Result<_, Error>>()?;
        let has_more = records.len() > args.page.limit as usize;
        records.truncate(args.page.limit as usize);
        Ok(RecordsResult { records, has_more })
    }
    pub async fn ledger_stats(
        &self,
        space: SpaceId,
        mut args: QueryStats,
    ) -> Result<StatsResult, Error> {
        self.member(space);
        if args.period.from > args.period.through {
            return Err(Error::invalid());
        }
        args.filters.from = Some(args.period.from);
        args.filters.through = Some(args.period.through);
        args.filters.status = Some(RecordStatus::Active);
        self.check_filters(space, &args.filters).await?;
        if args.kinds.is_empty() {
            args.kinds = if args.filters.kinds.is_empty() {
                vec![RecordKind::Expense]
            } else {
                args.filters.kinds.clone()
            };
        } else if !args.filters.kinds.is_empty() {
            args.kinds.retain(|kind| args.filters.kinds.contains(kind));
        }
        let value = match args.measure {
            Measure::Sum => {
                "case when r.kind='refund' and not ($3::jsonb ? 'refund') then -r.amount_minor::numeric else r.amount_minor::numeric end"
            }
            Measure::Count => {
                "case when r.kind='refund' and not ($3::jsonb ? 'refund') then 0::numeric else 1::numeric end"
            }
        };
        let key = match args.group_by {
            Some(GroupBy::Tag) => "tag::text",
            Some(GroupBy::Purpose) => "purpose_id::text",
            Some(GroupBy::Account) => "account_id::text",
            Some(GroupBy::Member) => "created_by_member_id::text",
            Some(GroupBy::Month) => "to_char(occurred_on,'YYYY-MM')",
            None => "null::text",
        };
        let join = if matches!(args.group_by, Some(GroupBy::Tag)) {
            "left join lateral unnest(stats_tag_ids) tag on true"
        } else {
            ""
        };
        let sql = format!("with source as (
            select r.*,case when r.kind='refund' then coalesce(parent.tag_ids,'{{}}'::uuid[]) else r.tag_ids end stats_tag_ids
            from records r left join records parent on parent.space_id=r.space_id and parent.id=r.refund_of_id and parent.kind='expense'
            where r.space_id=$1
            ), selected as (
            select r.*, {value} metric from source r where r.space_id=$1 and {} and r.status='active'
            and ($3::jsonb ? r.kind or (r.kind='refund' and $3::jsonb ? 'expense' and not ($3::jsonb ? 'refund')))
            ), grouped as (select {key} key,sum(metric)::text value from selected {join} group by 1)
            select jsonb_build_object('total',coalesce((select sum(metric) from selected),0)::text,
            'groups',coalesce((select jsonb_agg(to_jsonb(g) order by key nulls first) from grouped g),'[]'::jsonb)) data", filter_sql("r.stats_tag_ids"));
        let mut value = one(
            &self.tx,
            &sql,
            vec![
                space.0.into(),
                encode(args.filters)?.into(),
                encode(args.kinds)?.into(),
            ],
        )
        .await?;
        let total = aggregate_minor(&value["total"])?;
        for group in value["groups"].as_array_mut().ok_or_else(Error::internal)? {
            group["value"] = json!(aggregate_minor(&group["value"])?);
        }
        Ok(StatsResult {
            currency: self.ledger_currency(space).await?,
            total,
            groups: decode(value["groups"].clone())?,
            tag_groups_may_overlap: matches!(args.group_by, Some(GroupBy::Tag)),
        })
    }
}
fn filter_sql(tag_column: &str) -> String {
    // Only fixed SQL expressions from this module are supplied here.
    format!("(($2::jsonb->>'text') is null or strpos(lower(coalesce(r.note,'')),lower($2::jsonb->>'text'))>0)
    and (($2::jsonb->>'account_id') is null or r.account_id=($2::jsonb->>'account_id')::uuid or r.to_account_id=($2::jsonb->>'account_id')::uuid)
    and (($2::jsonb->>'purpose_id') is null or r.purpose_id=($2::jsonb->>'purpose_id')::uuid or r.to_purpose_id=($2::jsonb->>'purpose_id')::uuid)
    and (($2::jsonb->>'tag_id') is null or ($2::jsonb->>'tag_id')::uuid=any({tag_column}))
    and (($2::jsonb->>'member_id') is null or r.created_by_member_id=($2::jsonb->>'member_id')::uuid)
    and (($2::jsonb->>'from') is null or r.occurred_on>=($2::jsonb->>'from')::date)
    and (($2::jsonb->>'through') is null or r.occurred_on<=($2::jsonb->>'through')::date)
    and (($2::jsonb->>'status') is null or r.status=$2::jsonb->>'status')")
}

// A per-record cap cannot bound an unbounded ledger's sum. Keep PostgreSQL's
// numeric intermediate through transport (text), then reject both i64 overflow
// and integers which JavaScript could not represent exactly. Never cast the sum
// to bigint in SQL: that would abort the transaction before a structured error.
fn aggregate_minor(value: &Value) -> Result<i64, Error> {
    const MAX_SAFE_INTEGER: i64 = 9_007_199_254_740_991;
    let amount = value
        .as_str()
        .ok_or_else(Error::internal)?
        .parse::<i64>()
        .map_err(|_| Error::new(422, "aggregate_out_of_range"))?;
    if !(-MAX_SAFE_INTEGER..=MAX_SAFE_INTEGER).contains(&amount) {
        return Err(Error::new(422, "aggregate_out_of_range"));
    }
    Ok(amount)
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn aggregate_guard_preserves_exact_js_integers_and_rejects_bigint_overflow() {
        for text in ["0", "9007199254740991", "-9007199254740991"] {
            assert!(aggregate_minor(&json!(text)).is_ok());
        }
        for text in [
            "9007199254740992",
            "-9007199254740992",
            "9223372036854775808",
            "-9223372036854775809",
        ] {
            let error = aggregate_minor(&json!(text)).err().unwrap();
            assert_eq!(error.status, 422);
            assert_eq!(error.code, "aggregate_out_of_range");
        }
    }
}

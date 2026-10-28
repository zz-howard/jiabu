use super::*;
impl SpaceTx {
    pub async fn documents_list_subjects(
        &self,
        space: SpaceId,
        args: ListSubjects,
    ) -> Result<SubjectsResult, Error> {
        self.member(space);
        let rows=self.tx.query_all_raw(Statement::from_sql_and_values(DbBackend::Postgres,
            "select to_jsonb(s) data from subjects s where space_id=$1 and deleted_at is null and ($2::text is null or kind=$2) and ($3 or archived_at is null) order by lower(name),id limit $4 offset $5",
            vec![space.0.into(),args.kind.map(encode).transpose()?.and_then(|v|v.as_str().map(str::to_owned)).into(),args.include_archived.into(),(i64::from(args.page.limit)+1).into(),i64::from(args.page.offset).into()])).await?;
        let mut subjects: Vec<Subject> = rows
            .into_iter()
            .map(|r| decode(r.try_get("", "data")?))
            .collect::<Result<_, Error>>()?;
        let has_more = subjects.len() > args.page.limit as usize;
        subjects.truncate(args.page.limit as usize);
        Ok(SubjectsResult { subjects, has_more })
    }
    pub async fn documents_search(
        &self,
        space: SpaceId,
        args: SearchDocuments,
    ) -> Result<DocumentsResult, Error> {
        self.member(space);
        let f = &args.filters;
        if f.subject_id.is_some() && f.unassociated || f.from.zip(f.to).is_some_and(|(a, b)| a > b)
        {
            return Err(Error::invalid());
        }
        if let Some(id) = f.subject_id {
            self.documents_subject(space, id).await?;
        }
        if let Some(id) = f.created_by_member_id
            && self
                .documents_optional(
                    space,
                    "select to_jsonb(m) data from space_members m where space_id=$1 and id=$2",
                    vec![space.0.into(), id.into()],
                )
                .await?
                .is_none()
        {
            return Err(Error::not_found());
        }
        let rows=self.tx.query_all_raw(Statement::from_sql_and_values(DbBackend::Postgres,
            "select to_jsonb(d) data from documents d where space_id=$1 and ($2::uuid is null or subject_ids @> array[$2]) and (not $3 or cardinality(subject_ids)=0) and ($4::text is null or template_id=$4) and ($5::date is null or event_date >= $5) and ($6::date is null or event_date <= $6) and ($7::uuid is null or created_by_member_id=$7) and status=$8 order by event_date desc,id desc limit $9 offset $10",
            vec![space.0.into(),f.subject_id.into(),f.unassociated.into(),f.template_id.clone().into(),f.from.into(),f.to.into(),f.created_by_member_id.into(),encode(f.status.unwrap_or(Status::Active))?.as_str().ok_or_else(Error::internal)?.into(),(i64::from(args.page.limit)+1).into(),i64::from(args.page.offset).into()])).await?;
        let mut documents: Vec<Document> = rows
            .into_iter()
            .map(|r| decode(r.try_get("", "data")?))
            .collect::<Result<_, Error>>()?;
        let has_more = documents.len() > args.page.limit as usize;
        documents.truncate(args.page.limit as usize);
        Ok(DocumentsResult {
            documents,
            has_more,
        })
    }
    pub async fn documents_metric(
        &self,
        space: SpaceId,
        args: MetricSeries,
        templates: &BTreeMap<String, Template>,
    ) -> Result<MetricResult, Error> {
        self.documents_subject(space, args.subject_id).await?;
        if args.metric.is_empty() || args.from.zip(args.to).is_some_and(|(a, b)| a > b) {
            return Err(Error::invalid());
        }
        let rows=self.tx.query_all_raw(Statement::from_sql_and_values(DbBackend::Postgres,
            "select to_jsonb(d) data from documents d where space_id=$1 and subject_ids @> array[$2::uuid] and status='active' and template_id is not null and ($3::date is null or event_date >= $3) and ($4::date is null or event_date <= $4) order by event_date,created_at,id",
            vec![space.0.into(),args.subject_id.into(),args.from.into(),args.to.into()])).await?;
        let mut declarations = templates.clone();
        let mut values = Vec::new();
        for row in rows {
            let document: Document = decode(row.try_get("", "data")?)?;
            let Some(id) = document.template_id.as_ref() else {
                continue;
            };
            if !declarations.contains_key(id)
                && let Some(template) = self.document_template_snapshot(space, id).await?
            {
                declarations.insert(id.clone(), template);
            }
            if let Some(template) = declarations.get(id) {
                for (value, unit) in metric_values(&document, template, &args.metric) {
                    values.push((
                        MetricPoint {
                            document_id: document.id,
                            event_date: document.event_date,
                            value,
                        },
                        unit,
                    ));
                }
            }
        }
        let unit = values.last().and_then(|(_, u)| u.clone());
        let mut points = Vec::new();
        let mut excluded = Vec::new();
        let mut seen = std::collections::BTreeSet::new();
        for (point, actual) in values {
            if actual == unit {
                points.push(point);
            } else if seen.insert((point.document_id, actual.clone())) {
                excluded.push(Excluded {
                    document_id: point.document_id,
                    unit: actual,
                });
            }
        }
        Ok(MetricResult {
            subject_id: args.subject_id,
            metric: args.metric,
            unit,
            points,
            excluded,
        })
    }
}

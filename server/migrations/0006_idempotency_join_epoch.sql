-- Bind space-content replay to the membership generation that performed it.
-- NULL is used by account/bootstrap operations. Old content rows with no known
-- generation fail closed instead of returning results from an earlier join.
alter table idempotency add column join_epoch integer;

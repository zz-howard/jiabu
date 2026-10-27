// sqlx::migrate! embeds the migration files at compile time; rebuild when any of them changes.
fn main() {
    println!("cargo:rerun-if-changed=../../migrations");
}

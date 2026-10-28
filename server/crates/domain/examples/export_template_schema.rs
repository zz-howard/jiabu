fn main() -> Result<(), Box<dyn std::error::Error>> {
    println!(
        "{}",
        serde_json::to_string_pretty(&jiabu_domain::templates::schema())?
    );
    Ok(())
}

fn main() -> Result<(), serde_json::Error> {
    println!(
        "{}",
        serde_json::to_string_pretty(jiabu_domain::presets::PRESETS)?
    );
    Ok(())
}

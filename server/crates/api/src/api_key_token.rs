//! Personal token wire format. Never log the returned secret.
const PREFIX: &str = "jiabu_pat_";
const ALPHABET: &[u8; 62] = b"0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";

fn finish(random: &str) -> String {
    let mut token = format!("{PREFIX}{random}");
    let mut crc = crc32fast::hash(token.as_bytes());
    let mut checksum = [b'0'; 6];
    for byte in checksum.iter_mut().rev() {
        *byte = ALPHABET[(crc % 62) as usize];
        crc /= 62;
    }
    for byte in checksum {
        token.push(char::from(byte));
    }
    token
}
pub(crate) fn generate() -> String {
    let mut random = String::with_capacity(40);
    while random.len() < 40 {
        // rand::random uses the OS-seeded generator; rejection avoids modulo bias.
        let byte: u8 = rand::random();
        if byte < 248 {
            random.push(char::from(ALPHABET[usize::from(byte % 62)]));
        }
    }
    finish(&random)
}
pub(crate) fn valid(token: &str) -> bool {
    token.len() == 56
        && token.starts_with(PREFIX)
        && token.as_bytes()[10..].iter().all(u8::is_ascii_alphanumeric)
        && finish(&token[10..50]) == token
}
pub(crate) fn display_prefix(token: &str) -> String {
    token[..16].to_owned()
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn fixed_wire_vector_and_mutations() {
        // Expected suffix calculated independently with Python zlib's IEEE CRC32.
        let random = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcd";
        let expected = "jiabu_pat_0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcd4Fd4Rn";
        assert_eq!(finish(random), expected);
        assert!(valid(expected));
        assert_eq!(crc32fast::hash(b"123456789"), 0xcbf4_3926);
        for index in 0..expected.len() {
            let mut bytes = expected.as_bytes().to_vec();
            bytes[index] = if bytes[index] == b'0' { b'1' } else { b'0' };
            assert!(!valid(&String::from_utf8(bytes).unwrap()));
        }
        for invalid in ["", "jiabu_pat_", &"é".repeat(28), &"x".repeat(56)] {
            assert!(!valid(invalid));
        }
        for _ in 0..32 {
            let token = generate();
            assert!(valid(&token));
            assert_eq!(display_prefix(&token), token[..16]);
        }
    }
}

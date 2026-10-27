use axum::{extract::ConnectInfo, http::HeaderMap};
use std::{
    collections::{HashMap, VecDeque},
    net::{IpAddr, SocketAddr},
    sync::Mutex,
    time::{Duration, Instant},
};
/// Sliding-window counter over string keys; every check that passes records one hit
/// per key, and a check fails if any key is already at the limit.
pub(crate) struct WindowLimiter {
    buckets: Mutex<HashMap<String, VecDeque<Instant>>>,
    limit: usize,
    window: Duration,
}
impl WindowLimiter {
    pub(crate) fn new(limit: usize, window: Duration) -> Self {
        Self {
            buckets: Mutex::default(),
            limit,
            window,
        }
    }
    pub(crate) fn hit(&self, keys: &[String]) -> Result<(), u64> {
        self.hit_at(keys, Instant::now())
    }
    fn hit_at(&self, keys: &[String], now: Instant) -> Result<(), u64> {
        let window = self.window;
        let mut buckets = self.buckets.lock().map_err(|_| window.as_secs())?;
        buckets.retain(|_, times| {
            while times
                .front()
                .is_some_and(|t| now.duration_since(*t) >= window)
            {
                times.pop_front();
            }
            !times.is_empty()
        });
        let mut retry = 0;
        for key in keys {
            if let Some(times) = buckets.get(key)
                && times.len() >= self.limit
                && let Some(first) = times.front()
            {
                let remaining = window - now.duration_since(*first);
                retry = retry.max(remaining.as_secs() + u64::from(remaining.subsec_nanos() != 0));
            }
        }
        if retry > 0 {
            return Err(retry);
        }
        for key in keys {
            buckets.entry(key.clone()).or_default().push_back(now);
        }
        Ok(())
    }
}
/// Password guesses (login and `POST /me/password`): five per minute per source
/// network and per normalized username, shared by both endpoints.
pub(crate) struct LoginLimiter(WindowLimiter);
impl Default for LoginLimiter {
    fn default() -> Self {
        Self(WindowLimiter::new(5, Duration::from_secs(60)))
    }
}
impl LoginLimiter {
    pub(crate) fn check(&self, ip: IpAddr, username: &str) -> Result<(), u64> {
        self.0.hit(&Self::keys(ip, username))
    }
    #[cfg(test)]
    fn check_at(&self, ip: IpAddr, username: &str, now: Instant) -> Result<(), u64> {
        self.0.hit_at(&Self::keys(ip, username), now)
    }
    fn keys(ip: IpAddr, username: &str) -> [String; 2] {
        [
            ip_key(ip),
            format!("user:{}", username.trim().to_lowercase()),
        ]
    }
}
/// One IPv6 client normally controls a whole /64, so it is one bucket.
pub(crate) fn ip_key(ip: IpAddr) -> String {
    match ip.to_canonical() {
        IpAddr::V4(v4) => format!("ip:{v4}"),
        IpAddr::V6(v6) => {
            let prefix = u128::from(v6) & !((1_u128 << 64) - 1);
            format!("ip:{}/64", std::net::Ipv6Addr::from(prefix))
        }
    }
}
pub(crate) fn source_ip(peer: Option<ConnectInfo<SocketAddr>>, headers: &HeaderMap) -> IpAddr {
    let peer = peer
        .map(|p| p.0.ip())
        .unwrap_or(IpAddr::V4(std::net::Ipv4Addr::UNSPECIFIED));
    if peer.is_loopback()
        && headers.get_all("x-real-ip").iter().count() == 1
        && let Some(ip) = headers
            .get("x-real-ip")
            .and_then(|v| v.to_str().ok())
            .and_then(|v| v.parse().ok())
    {
        return ip;
    }
    peer
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn independent_buckets_and_expiry() {
        let l = LoginLimiter::default();
        let now = Instant::now();
        for i in 1..=5 {
            assert!(
                l.check_at(
                    IpAddr::V4(std::net::Ipv4Addr::new(192, 0, 2, i)),
                    "Case",
                    now
                )
                .is_ok()
            );
        }
        assert_eq!(
            l.check_at("192.0.2.6".parse().unwrap(), "case", now),
            Err(60)
        );
        assert!(
            l.check_at(
                "192.0.2.6".parse().unwrap(),
                "case",
                now + Duration::from_secs(60)
            )
            .is_ok()
        );
        let l = LoginLimiter::default();
        for i in 0..5 {
            assert!(
                l.check_at("192.0.2.1".parse().unwrap(), &i.to_string(), now)
                    .is_ok()
            );
        }
        assert!(
            l.check_at("192.0.2.1".parse().unwrap(), "another", now)
                .is_err()
        );
    }
    #[test]
    fn ipv6_clients_share_a_slash_64_bucket() {
        let l = LoginLimiter::default();
        let now = Instant::now();
        for i in 1..=5_u16 {
            let ip = IpAddr::V6(std::net::Ipv6Addr::new(0x2001, 0xdb8, 0, 1, 0, 0, 0, i));
            assert!(l.check_at(ip, &format!("user{i}"), now).is_ok());
        }
        let same_64 = "2001:db8:0:1:ffff:ffff:ffff:ffff".parse().unwrap();
        assert!(l.check_at(same_64, "fresh", now).is_err());
        let next_64 = "2001:db8:0:2::1".parse().unwrap();
        assert!(l.check_at(next_64, "fresh", now).is_ok());
        // IPv4-mapped addresses are keyed as the IPv4 address, not as a /64.
        assert_eq!(ip_key("::ffff:192.0.2.1".parse().unwrap()), "ip:192.0.2.1");
        assert_eq!(
            ip_key("2001:db8:0:1:2:3:4:5".parse().unwrap()),
            "ip:2001:db8:0:1::/64"
        );
    }
    #[test]
    fn real_ip_requires_loopback_peer() {
        let mut headers = HeaderMap::new();
        headers.insert("x-real-ip", "198.51.100.9".parse().unwrap());
        assert_eq!(
            source_ip(
                Some(ConnectInfo("192.0.2.1:1234".parse().unwrap())),
                &headers
            )
            .to_string(),
            "192.0.2.1"
        );
        assert_eq!(
            source_ip(
                Some(ConnectInfo("127.0.0.1:1234".parse().unwrap())),
                &headers
            )
            .to_string(),
            "198.51.100.9"
        );
        headers.insert("x-real-ip", "malformed".parse().unwrap());
        headers.insert("x-forwarded-for", "198.51.100.9".parse().unwrap());
        assert_eq!(
            source_ip(
                Some(ConnectInfo("127.0.0.1:1234".parse().unwrap())),
                &headers
            )
            .to_string(),
            "127.0.0.1"
        );
        headers.insert("x-real-ip", "198.51.100.9".parse().unwrap());
        headers.append("x-real-ip", "198.51.100.10".parse().unwrap());
        assert_eq!(
            source_ip(
                Some(ConnectInfo("127.0.0.1:1234".parse().unwrap())),
                &headers
            )
            .to_string(),
            "127.0.0.1"
        );
    }
}

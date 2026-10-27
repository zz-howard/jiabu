use axum::{extract::ConnectInfo, http::HeaderMap};
use std::{
    collections::{HashMap, VecDeque},
    net::{IpAddr, SocketAddr},
    sync::Mutex,
    time::{Duration, Instant},
};
#[derive(Default)]
pub(crate) struct LoginLimiter {
    buckets: Mutex<HashMap<String, VecDeque<Instant>>>,
}
impl LoginLimiter {
    pub(crate) fn check(&self, ip: IpAddr, username: &str) -> Result<(), u64> {
        self.check_at(ip, username, Instant::now())
    }
    fn check_at(&self, ip: IpAddr, username: &str, now: Instant) -> Result<(), u64> {
        let mut buckets = self.buckets.lock().map_err(|_| 60_u64)?;
        let window = Duration::from_secs(60);
        buckets.retain(|_, times| {
            while times
                .front()
                .is_some_and(|t| now.duration_since(*t) >= window)
            {
                times.pop_front();
            }
            !times.is_empty()
        });
        let keys = [
            format!("ip:{ip}"),
            format!("user:{}", username.trim().to_lowercase()),
        ];
        let mut retry = 0;
        for key in &keys {
            if let Some(times) = buckets.get(key)
                && times.len() >= 5
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
            buckets.entry(key).or_default().push_back(now);
        }
        Ok(())
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

/**
 * CIDR and IP range validation utilities.
 * Supports: exact IPs ("192.168.1.1"), CIDR notation ("192.168.1.0/24"),
 * wildcard suffix ("192.168.1.*"), and plain prefix ("192.168.1.").
 */

function ipToInt(ip: string): number {
  const parts = ip.split(".").map(Number);
  return ((parts[0] << 24) | (parts[1] << 16) | (parts[2] << 8) | parts[3]) >>> 0;
}

function isValidIpv4(ip: string): boolean {
  return /^(\d{1,3}\.){3}\d{1,3}$/.test(ip) &&
    ip.split(".").every((p) => Number(p) >= 0 && Number(p) <= 255);
}

/**
 * Check whether a given IP address is within any of the allowed ranges.
 * Each range may be:
 *  - Exact IP:        "192.168.1.1"
 *  - CIDR block:      "192.168.1.0/24"
 *  - Wildcard:        "192.168.1.*"
 *  - Prefix:          "192.168.1."
 */
export function isAddressInRanges(address: string, ranges: string[]): boolean {
  if (!ranges.length) return true; // no restriction = allow all

  // Only validate IPv4 for now; domains/subnets always pass
  if (!isValidIpv4(address)) return true;

  const addrInt = ipToInt(address);

  return ranges.some((range) => {
    const trimmed = range.trim();

    // CIDR notation: "192.168.1.0/24"
    if (trimmed.includes("/")) {
      const [network, prefixStr] = trimmed.split("/");
      const prefix = Number(prefixStr);
      if (!isValidIpv4(network) || isNaN(prefix) || prefix < 0 || prefix > 32) return false;
      const mask = prefix === 0 ? 0 : (~0 << (32 - prefix)) >>> 0;
      const networkInt = ipToInt(network) & mask;
      return (addrInt & mask) === networkInt;
    }

    // Wildcard: "192.168.1.*"
    if (trimmed.endsWith(".*")) {
      return address.startsWith(trimmed.slice(0, -1));
    }

    // Trailing dot prefix: "192.168.1."
    if (trimmed.endsWith(".")) {
      return address.startsWith(trimmed);
    }

    // Exact IP match
    return address === trimmed;
  });
}

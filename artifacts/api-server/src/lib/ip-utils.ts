const PRIVATE_RANGES = [
  /^10\.\d+\.\d+\.\d+$/,
  /^172\.(1[6-9]|2\d|3[01])\.\d+\.\d+$/,
  /^192\.168\.\d+\.\d+$/,
  /^127\.\d+\.\d+\.\d+$/,
  /^169\.254\.\d+\.\d+$/,
  /^fc[0-9a-f]{2}:/i,
  /^fd[0-9a-f]{2}:/i,
  /^::1$/,
  /^localhost$/i,
];

export function isPrivateIp(address: string): boolean {
  const addr = address.trim();
  return PRIVATE_RANGES.some((re) => re.test(addr));
}

export function isSubnet(address: string): boolean {
  return address.includes("/");
}

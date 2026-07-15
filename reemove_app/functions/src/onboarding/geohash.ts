const base32 = "0123456789bcdefghjkmnpqrstuvwxyz";

export function encodeGeohash(
  latitude: number,
  longitude: number,
  precision = 7,
): string {
  let latitudeRange: [number, number] = [-90, 90];
  let longitudeRange: [number, number] = [-180, 180];
  let hash = "";
  let bits = 0;
  let bitCount = 0;
  let useLongitude = true;

  while (hash.length < precision) {
    const range = useLongitude ? longitudeRange : latitudeRange;
    const value = useLongitude ? longitude : latitude;
    const midpoint = (range[0] + range[1]) / 2;
    bits <<= 1;
    if (value >= midpoint) {
      bits |= 1;
      range[0] = midpoint;
    } else {
      range[1] = midpoint;
    }
    useLongitude = !useLongitude;
    bitCount += 1;

    if (bitCount === 5) {
      hash += base32[bits];
      bits = 0;
      bitCount = 0;
    }
  }

  return hash;
}

export function roundCoordinate(value: number, decimals = 2): number {
  const factor = 10 ** decimals;
  return Math.round(value * factor) / factor;
}

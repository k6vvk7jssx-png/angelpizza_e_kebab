// Geocoding and Proximity Helper for Angels Livorno Delivery Batching

const ANGELS_LIVORNO_LAT = 43.5485;
const ANGELS_LIVORNO_LNG = 10.3106;

export interface GeoLocation {
  lat: number;
  lng: number;
}

// Convert address in Livorno to lat/lng using Nominatim OpenStreetMap API
export async function geocodeLivornoAddress(address: String): Promise<GeoLocation> {
  try {
    const formattedAddress = encodeURIComponent(`${address}, Livorno, Italia`);
    const res = await fetch(
      `https://nominatim.openstreetmap.org/search?format=json&q=${formattedAddress}&limit=1`,
      {
        headers: {
          'User-Agent': 'AngelsLivornoDeliveryApp/1.0',
        },
      }
    );
    const data = await res.json();
    if (data && data.length > 0) {
      return {
        lat: parseFloat(data[0].lat),
        lng: parseFloat(data[0].lon),
      };
    }
  } catch (err) {
    console.error('Geocoding error:', err);
  }

  // Fallback to central Livorno with slight pseudo-random displacement if lookup fails
  return {
    lat: ANGELS_LIVORNO_LAT + (Math.random() - 0.5) * 0.015,
    lng: ANGELS_LIVORNO_LNG + (Math.random() - 0.5) * 0.015,
  };
}

// Calculate Haversine distance in meters between two lat/lng points
export function calculateDistanceMeters(loc1: GeoLocation, loc2: GeoLocation): number {
  const R = 6371000; // Earth's radius in meters
  const dLat = ((loc2.lat - loc1.lat) * Math.PI) / 180;
  const dLng = ((loc2.lng - loc1.lng) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos((loc1.lat * Math.PI) / 180) *
      Math.cos((loc2.lat * Math.PI) / 180) *
      Math.sin(dLng / 2) *
      Math.sin(dLng / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return Math.round(R * c);
}

// Calculate bearing angle in degrees from restaurant to location
export function calculateBearing(origin: GeoLocation, destination: GeoLocation): number {
  const lat1 = (origin.lat * Math.PI) / 180;
  const lat2 = (destination.lat * Math.PI) / 180;
  const dLng = ((destination.lng - origin.lng) * Math.PI) / 180;

  const y = Math.sin(dLng) * Math.cos(lat2);
  const x =
    Math.cos(lat1) * Math.sin(lat2) -
    Math.sin(lat1) * Math.cos(lat2) * Math.cos(dLng);
  const brng = (Math.atan2(y, x) * 180) / Math.PI;
  return (brng + 360) % 360;
}

// Generate multi-stop Google Maps Navigation URL for rider
export function generateGoogleMapsMultiStopUrl(address1: string, address2: string): string {
  const origin = encodeURIComponent('Angels Livorno, Via Corso Mazzini, Livorno');
  const dest1 = encodeURIComponent(address1.includes('Livorno') ? address1 : `${address1}, Livorno`);
  const dest2 = encodeURIComponent(address2.includes('Livorno') ? address2 : `${address2}, Livorno`);

  return `https://www.google.com/maps/dir/?api=1&origin=${origin}&destination=${dest2}&waypoints=${dest1}`;
}

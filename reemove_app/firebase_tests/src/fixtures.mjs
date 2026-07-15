import {Timestamp, serverTimestamp} from "firebase/firestore";

const seededAt = Timestamp.fromDate(new Date("2026-07-13T12:00:00.000Z"));

export function publicUser(uid, visibility = "public") {
  return {
    uid,
    username: uid.replaceAll("-", "_"),
    usernameNormalized: uid.replaceAll("-", "_"),
    displayName: `User ${uid}`,
    bio: "",
    role: "athlete",
    isVerified: false,
    verificationType: "none",
    favoriteSportIds: ["football"],
    sportLevels: {football: "intermediate"},
    goals: ["community"],
    discoveryRadiusKm: 25,
    visibility,
    followersCount: 0,
    followingCount: 0,
    postsCount: 0,
    onboardingCompleted: true,
    moderationState: "active",
    createdAt: seededAt,
    updatedAt: seededAt,
    schemaVersion: 1,
  };
}

export function newClientUser(uid) {
  return {
    ...publicUser(uid),
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  };
}

export function activePlace(id, visibility = "public") {
  return {
    name: `Place ${id}`,
    description: "Seed place",
    type: "gym",
    sportIds: ["gym"],
    location: {latitude: 32.8, longitude: 35.0},
    geohash: "sv8x",
    addressLine: "1 Sport Street",
    city: "Haifa",
    countryCode: "IL",
    media: [],
    rating: 4.7,
    reviewCount: 12,
    isVerified: true,
    visibility,
    moderationState: "active",
    createdAt: seededAt,
    updatedAt: seededAt,
    schemaVersion: 1,
  };
}

export function activeListing(id) {
  return {
    sellerId: "seller",
    seller: {
      uid: "seller",
      username: "seller",
      displayName: "Seller",
      isVerified: false,
    },
    title: `Listing ${id}`,
    description: "Seed listing",
    categoryId: "weights",
    sportId: "gym",
    condition: "good",
    price: {amountMinor: 12000, currency: "ILS"},
    media: [],
    location: {latitude: 32.8, longitude: 35.0},
    geohash: "sv8x",
    deliveryOptions: ["pickup"],
    status: "active",
    favoriteCount: 0,
    viewCount: 0,
    moderationState: "active",
    createdAt: seededAt,
    updatedAt: seededAt,
    schemaVersion: 1,
  };
}

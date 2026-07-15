const assert = require('node:assert/strict');
const {describe, it} = require('node:test');

const {
  distanceKm,
  hasProhibitedMarketplaceLanguage,
  parseListingInput,
  parseSearchRequest,
  listingActions,
  normalizeMarketplaceSearchText,
  searchPrefixes,
} = require('../lib/marketplace/marketplacePolicy.js');

function validListing(overrides = {}) {
  return {
    listingId: 'listing-1',
    title: 'Adjustable dumbbells',
    description: 'A clean pair with plates and secure collars included.',
    categoryId: 'gym_equipment',
    sportId: 'gym',
    condition: 'good',
    price: {amountMinor: 45000, currency: 'ils'},
    isNegotiable: true,
    deliveryOptions: ['pickup', 'meetup'],
    media: [{
      id: 'asset-1',
      storagePath: 'marketplace/alice/listing-1/asset-1.jpg',
      downloadUrl: 'https://example.com/asset-1.jpg',
      contentType: 'image/jpeg',
      sizeBytes: 1024,
    }],
    location: {latitude: 32.81234, longitude: 34.99876},
    locality: 'Haifa',
    countryCode: 'il',
    ...overrides,
  };
}

describe('marketplace listing policy', () => {
  it('normalizes a valid listing and exposes only coarse coordinates', () => {
    const listing = parseListingInput(validListing());
    assert.equal(listing.price.currency, 'ILS');
    assert.deepEqual(listing.location, {latitude: 32.812, longitude: 34.999});
    assert.equal(listing.deliveryOptions.length, 2);
    assert.ok(listing.geohash.length > 0);
  });

  it('rejects prohibited and regulated product language', () => {
    assert.throws(() => parseListingInput(validListing({
      title: 'Nicotine vape training accessory',
    })));
    assert.equal(hasProhibitedMarketplaceLanguage('Used football boots'), false);
    assert.equal(hasProhibitedMarketplaceLanguage('Counterfeit designer shirt'), true);
  });

  it('rejects invalid prices, unsupported currencies, and missing delivery', () => {
    assert.throws(() => parseListingInput(validListing({price: {amountMinor: -1, currency: 'ILS'}})));
    assert.throws(() => parseListingInput(validListing({price: {amountMinor: 1000, currency: 'BTC'}})));
    assert.throws(() => parseListingInput(validListing({deliveryOptions: []})));
  });

  it('limits photos and validates photo type and size', () => {
    assert.throws(() => parseListingInput(validListing({
      media: Array.from({length: 9}, (_, index) => ({
        id: `asset-${index}`,
        storagePath: `marketplace/alice/listing-1/asset-${index}.jpg`,
        downloadUrl: `https://example.com/${index}.jpg`,
        contentType: 'image/jpeg',
        sizeBytes: 1024,
      })),
    })));
    assert.throws(() => parseListingInput(validListing({
      media: [{
        id: 'asset-1', storagePath: 'marketplace/alice/listing-1/asset-1.mp4',
        downloadUrl: 'https://example.com/video.mp4', contentType: 'video/mp4', sizeBytes: 1024,
      }],
    })));
  });
});

describe('marketplace search policy', () => {
  it('accepts bounded filters and pagination', () => {
    const request = parseSearchRequest({
      query: 'dumbbells', sportId: 'gym', categoryId: 'gym_equipment',
      condition: 'good', minimumPriceMinor: 10000, maximumPriceMinor: 50000,
      deliveryOptions: ['pickup'], sort: 'nearest', latitude: 32.8,
      longitude: 35, radiusKm: 25, cursor: '24', limit: 24,
    });
    assert.equal(request.cursor, 24);
    assert.equal(request.sort, 'nearest');
  });

  it('rejects malformed ranges, coordinates, radius, and page limits', () => {
    assert.throws(() => parseSearchRequest({minimumPriceMinor: 500, maximumPriceMinor: 100}));
    assert.throws(() => parseSearchRequest({latitude: 32.8}));
    assert.throws(() => parseSearchRequest({latitude: 95, longitude: 35}));
    assert.throws(() => parseSearchRequest({sort: 'nearest'}));
    assert.throws(() => parseSearchRequest({minimumPriceMinor: 2.5}));
    assert.throws(() => parseSearchRequest({radiusKm: 101}));
    assert.throws(() => parseSearchRequest({cursor: 10001}));
    assert.throws(() => parseSearchRequest({limit: 41}));
  });

  it('creates bounded search prefixes and calculates distance', () => {
    const prefixes = searchPrefixes('Adjustable Dumbbells', 'Gym weights in good condition');
    assert.ok(prefixes.includes('du'));
    assert.ok(prefixes.includes('dumbbells'));
    assert.ok(prefixes.length <= 120);
    const distance = distanceKm(32.794, 34.99, 32.82, 34.99);
    assert.ok(distance > 2.5 && distance < 3.5);
  });

  it("normalizes Arabic and Hebrew search text and policy terms", () => {
    const prefixes = searchPrefixes("كرة قدم احترافية", "נעלי כדורגל חדשות");
    assert.ok(prefixes.includes("كرة"));
    assert.ok(prefixes.includes("כדורגל"));
    assert.equal(normalizeMarketplaceSearchText("Ádjustable—Dumbbells"), "adjustable dumbbells");
    assert.equal(hasProhibitedMarketplaceLanguage("سلاح رياضي"), true);
    assert.equal(hasProhibitedMarketplaceLanguage("אקדח לאימון"), true);
  });

  it("supports the complete server-owned lifecycle action set", () => {
    assert.deepEqual(listingActions, ["activate", "pause", "reserve", "sold", "remove"]);
  });

});

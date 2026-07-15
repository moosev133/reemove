const assert = require('node:assert/strict');
const {describe, it} = require('node:test');

const {
  distanceLabel,
  parseDiscoveryLocation,
  parseNearbySearchInput,
} = require('../lib/nearby/nearbyPolicy.js');

describe('nearby search policy', () => {
  it('normalizes types, sports, and result limits', () => {
    const result = parseNearbySearchInput({
      latitude: 32.794,
      longitude: 34.9896,
      radiusKm: 25,
      types: ['place', 'event', 'place'],
      sportIds: ['Running', 'running', 'GYM'],
      limit: 60,
    });

    assert.deepEqual(result.types, ['place', 'event']);
    assert.deepEqual(result.sportIds, ['running', 'gym']);
    assert.equal(result.limit, 60);
  });

  it('defaults to every nearby entity type', () => {
    const result = parseNearbySearchInput({
      latitude: 32.794,
      longitude: 34.9896,
    });
    assert.deepEqual(result.types, ['place', 'person', 'event', 'route']);
    assert.equal(result.radiusKm, 25);
    assert.equal(result.limit, 50);
  });

  it('rejects invalid coordinates, radius, type, and oversized limits', () => {
    assert.throws(() => parseNearbySearchInput({latitude: 91, longitude: 0}));
    assert.throws(() => parseNearbySearchInput({latitude: 32, longitude: 35, radiusKm: 0}));
    assert.throws(() => parseNearbySearchInput({latitude: 32, longitude: 35, types: ['restaurant']}));
    assert.throws(() => parseNearbySearchInput({latitude: 32, longitude: 35, limit: 101}));
  });
});

describe('discovery location policy', () => {
  it('normalizes coarse location metadata without trusting a geohash', () => {
    const result = parseDiscoveryLocation({
      latitude: 32.794,
      longitude: 34.9896,
      locality: '  Haifa   ',
      administrativeArea: ' Haifa District ',
      countryCode: 'il',
      geohash: 'client-controlled',
    });
    assert.equal(result.locality, 'Haifa');
    assert.equal(result.administrativeArea, 'Haifa District');
    assert.equal(result.countryCode, 'IL');
    assert.equal(Object.hasOwn(result, 'geohash'), false);
  });

  it('rejects malformed country codes', () => {
    assert.throws(() => parseDiscoveryLocation({
      latitude: 32.794,
      longitude: 34.9896,
      countryCode: 'ISR',
    }));
  });
});

describe('nearby distance labels', () => {
  it('does not imply precise distance for approximate people markers', () => {
    assert.equal(distanceLabel(0.18, true), 'About 1 km away');
    assert.equal(distanceLabel(4.6, true), 'About 5 km away');
  });

  it('uses useful precision for public places, events, and routes', () => {
    assert.equal(distanceLabel(0.42, false), '400 m away');
    assert.equal(distanceLabel(3.26, false), '3.3 km away');
    assert.equal(distanceLabel(14.2, false), '14 km away');
  });
});

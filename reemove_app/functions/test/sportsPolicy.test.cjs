const assert = require('node:assert/strict');
const {describe, it} = require('node:test');

const {
  parseCommunityInput,
  parseEventInput,
  parseTrainerServiceInput,
} = require('../lib/sports/sportsPolicy.js');

describe('sports community policy', () => {
  it('normalizes a valid scalable community request', () => {
    const result = parseCommunityInput({
      sportId: 'football',
      name: '  Tamra   Weekend FC  ',
      description: 'A friendly football team for weekly competitive matches.',
      type: 'team',
      joinPolicy: 'approvalRequired',
      capacity: 24,
      tags: ['competitive', 'competitive', 'weekend'],
      city: 'Tamra',
      countryCode: 'il',
      pricingText: 'Shared pitch cost',
    });

    assert.equal(result.name, 'Tamra Weekend FC');
    assert.equal(result.countryCode, 'IL');
    assert.deepEqual(result.tags, ['competitive', 'weekend']);
  });

  it('rejects invalid capacity, type, and short descriptions', () => {
    assert.throws(() => parseCommunityInput({
      sportId: 'football', name: 'FC', description: 'short', type: 'league',
      joinPolicy: 'open', capacity: 1, tags: [], city: 'Tamra', countryCode: 'IL',
    }));
  });
});

describe('sports event policy', () => {
  it('accepts a future event with a valid level range and money', () => {
    const startAt = new Date(Date.now() + 2 * 60 * 60_000);
    const endAt = new Date(startAt.getTime() + 90 * 60_000);
    const result = parseEventInput({
      sportId: 'running', type: 'meetup', title: 'Sunset 5K',
      description: 'A social five kilometre run for local runners.',
      startAt: startAt.toISOString(), endAt: endAt.toISOString(),
      timezone: 'Asia/Jerusalem', latitude: 32.805, longitude: 35.169,
      geohash: 'svb8example', locality: 'Tamra', countryCode: 'IL',
      capacity: 40, minimumLevel: 'beginner', maximumLevel: 'advanced',
      price: {amountMinor: 2500, currency: 'ils'},
    });

    assert.equal(result.price.currency, 'ILS');
    assert.equal(result.capacity, 40);
  });

  it('rejects reversed skill ranges and invalid durations', () => {
    const startAt = new Date(Date.now() + 2 * 60 * 60_000);
    const endAt = new Date(startAt.getTime() + 5 * 60_000);
    assert.throws(() => parseEventInput({
      sportId: 'gym', type: 'training', title: 'Strength Session',
      description: 'A structured strength training session for the group.',
      startAt: startAt.toISOString(), endAt: endAt.toISOString(),
      timezone: 'Asia/Jerusalem', latitude: 32.8, longitude: 35.1,
      geohash: 'svb8example', capacity: 10,
      minimumLevel: 'professional', maximumLevel: 'beginner',
    }));
  });
});

describe('trainer service policy', () => {
  it('normalizes a valid hybrid service', () => {
    const result = parseTrainerServiceInput({
      sportId: 'gym', title: 'Strength Coaching',
      description: 'A personalized strength plan with technique feedback.',
      type: 'personalTraining', deliveryMode: 'hybrid', durationMinutes: 60,
      price: {amountMinor: 18000, currency: 'ils'},
    });

    assert.equal(result.deliveryMode, 'hybrid');
    assert.deepEqual(result.price, {amountMinor: 18000, currency: 'ILS'});
  });

  it('requires a positive price and bounded duration', () => {
    assert.throws(() => parseTrainerServiceInput({
      sportId: 'gym', title: 'Coaching',
      description: 'A personalized coaching service for athletes.',
      type: 'consultation', deliveryMode: 'online', durationMinutes: 5,
      price: {amountMinor: 0, currency: 'ILS'},
    }));
  });
});

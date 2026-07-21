const assert = require('node:assert/strict');
const {describe, it} = require('node:test');

const {
  parsePrivacy,
  parseProfileUpdate,
  safeString,
  sanitizedCallableProfile,
} = require('../lib/profile/profilePolicy.js');

describe('profile privacy policy', () => {
  it('applies safe defaults', () => {
    assert.deepEqual(parsePrivacy({}), {
      followApprovalPolicy: 'automatic',
      messageAudience: 'everyone',
      mentionAudience: 'everyone',
      tagAudience: 'followers',
      showActivityStatus: true,
      showSportLevels: true,
      showGoals: true,
      showLocation: true,
      followerListAudience: 'everyone',
      showFollowerLists: true,
      hideLikeCounts: false,
      discoverableByUsername: true,
      personalizedSuggestions: true,
    });
  });

  it('maps legacy showFollowerLists to followerListAudience', () => {
    assert.deepEqual(parsePrivacy({showFollowerLists: false}), {
      followApprovalPolicy: 'automatic',
      messageAudience: 'everyone',
      mentionAudience: 'everyone',
      tagAudience: 'followers',
      showActivityStatus: true,
      showSportLevels: true,
      showGoals: true,
      showLocation: true,
      followerListAudience: 'owner',
      showFollowerLists: false,
      hideLikeCounts: false,
      discoverableByUsername: true,
      personalizedSuggestions: true,
    });
  });

  it('rejects unsupported audiences and non-boolean settings', () => {
    assert.throws(() => parsePrivacy({messageAudience: 'friends'}));
    assert.throws(() => parsePrivacy({showGoals: 'yes'}));
  });
});

describe('profile update policy', () => {
  const valid = {
    displayName: 'Mostafa Athlete',
    username: 'mostafa.move',
    bio: 'Football and strength training.',
    websiteUrl: 'https://reemove.app/athletes/mostafa',
    primarySportId: 'football',
    favoriteSportIds: ['football', 'gym'],
    goals: ['performance'],
    visibility: 'public',
    professionalDetails: {
      headline: 'Competitive athlete',
      specialties: ['football'],
      acceptingClients: false,
    },
    privacy: {},
  };

  it('normalizes valid identity and profile data', () => {
    const parsed = parseProfileUpdate(valid);
    assert.equal(parsed.displayName, 'Mostafa Athlete');
    assert.equal(parsed.usernameNormalized, 'mostafa.move');
    assert.equal(parsed.primarySportId, 'football');
    assert.deepEqual(parsed.favoriteSportIds, ['football', 'gym']);
    assert.equal(parsed.websiteUrl, 'https://reemove.app/athletes/mostafa');
  });

  it('requires HTTPS and a selected primary sport', () => {
    assert.throws(() => parseProfileUpdate({...valid, websiteUrl: 'http://example.com'}));
    assert.throws(() => parseProfileUpdate({...valid, primarySportId: 'running'}));
  });

  it('bounds professional fields and removes duplicate list values', () => {
    const parsed = parseProfileUpdate({
      ...valid,
      favoriteSportIds: ['football', 'football'],
      professionalDetails: {
        specialties: ['Speed', 'Speed'],
        yearsExperience: 4,
      },
    });
    assert.deepEqual(parsed.favoriteSportIds, ['football']);
    assert.deepEqual(parsed.professionalDetails.specialties, ['Speed']);
    assert.equal(parsed.professionalDetails.yearsExperience, 4);
    assert.throws(() => parseProfileUpdate({
      ...valid,
      professionalDetails: {specialties: [], yearsExperience: 81},
    }));
  });

  it('normalizes safe profile text', () => {
    assert.equal(safeString('  Athlete   Name ', 'Name', 80, 1), 'Athlete Name');
  });
});


describe('public profile sanitization', () => {
  const snapshot = {
    id: 'profile-1',
    data: () => ({
      uid: 'profile-1',
      displayName: 'Private Runner',
      sportLevels: {running: 'advanced'},
      goals: ['performance'],
      location: {latitude: 32.8, longitude: 35.0},
      geohash: 'sv8x',
      locality: 'Haifa',
      countryCode: 'IL',
      discoveryRadiusKm: 25,
    }),
  };

  it('removes fields disabled by private display preferences', () => {
    const profile = sanitizedCallableProfile(snapshot, {
      showSportLevels: false,
      showGoals: false,
      showLocation: false,
    }, false);
    assert.deepEqual(profile.sportLevels, {});
    assert.deepEqual(profile.goals, []);
    assert.equal('location' in profile, false);
    assert.equal('geohash' in profile, false);
    assert.equal('discoveryRadiusKm' in profile, false);
  });

  it('preserves the complete document for its owner', () => {
    const profile = sanitizedCallableProfile(snapshot, {
      showSportLevels: false,
      showGoals: false,
      showLocation: false,
    }, true);
    assert.deepEqual(profile.sportLevels, {running: 'advanced'});
    assert.deepEqual(profile.goals, ['performance']);
    assert.equal(profile.discoveryRadiusKm, 25);
  });
});

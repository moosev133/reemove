const assert = require('node:assert/strict');
const {describe, it} = require('node:test');

const {
  boundedPushBody,
  categoryEnabled,
  isWithinQuietHours,
  notificationBucket,
  parseNotificationPreferencesUpdate,
  parseStoredNotificationPreferences,
  quietHoursEnd,
  safeNotificationRoute,
} = require('../lib/notifications/notificationPolicy.js');

describe('notification preferences policy', () => {
  it('keeps backwards-compatible category defaults', () => {
    const value = parseStoredNotificationPreferences({
      masterEnabled: true,
      activity: false,
      messages: true,
    });
    assert.equal(value.marketplace, false);
    assert.equal(value.events, true);
    assert.equal(value.system, true);
    assert.equal(categoryEnabled(value, 'messages'), true);
    assert.equal(categoryEnabled(value, 'activity'), false);
  });

  it('blocks every push category when the master switch is off', () => {
    const value = parseStoredNotificationPreferences({masterEnabled: false});
    assert.equal(categoryEnabled(value, 'messages'), false);
    assert.equal(categoryEnabled(value, 'system'), false);
  });

  it('validates complete preference updates and UTC offsets', () => {
    const valid = {
      masterEnabled: true, showPreviews: false, activity: true,
      messages: true, events: true, challenges: true,
      marketplace: true, system: true, productUpdates: false,
      quietHours: {enabled: true, startMinutes: 1320, endMinutes: 420, utcOffsetMinutes: 180},
    };
    assert.equal(parseNotificationPreferencesUpdate(valid).quietHours.utcOffsetMinutes, 180);
    assert.throws(() => parseNotificationPreferencesUpdate({...valid, quietHours: {...valid.quietHours, startMinutes: 1440}}));
    assert.throws(() => parseNotificationPreferencesUpdate({...valid, activity: 'yes'}));
  });
});

describe('quiet hours and payload policy', () => {
  const quiet = {enabled: true, startMinutes: 22 * 60, endMinutes: 7 * 60, utcOffsetMinutes: 180};

  it('handles quiet hours crossing midnight', () => {
    assert.equal(isWithinQuietHours(new Date('2026-07-14T20:30:00Z'), quiet), true);
    assert.equal(isWithinQuietHours(new Date('2026-07-14T09:00:00Z'), quiet), false);
  });

  it('calculates the next quiet-hours end in UTC', () => {
    assert.equal(
      quietHoursEnd(new Date('2026-07-14T20:30:00Z'), quiet).toISOString(),
      '2026-07-15T04:00:00.000Z',
    );
  });

  it('hides private previews and bounds visible text', () => {
    assert.equal(boundedPushBody('Private message', false), 'Open ReeMove to view this update.');
    assert.equal(boundedPushBody('x'.repeat(300), true).length, 160);
  });

  it('accepts only local application routes', () => {
    assert.equal(safeNotificationRoute('/messages/abc'), '/messages/abc');
    assert.equal(safeNotificationRoute('https://example.com'), '/home/activity');
    assert.equal(safeNotificationRoute('//example.com'), '/home/activity');
  });

  it('uses stable twelve-hour grouping buckets', () => {
    const first = notificationBucket(new Date('2026-07-14T01:00:00Z'));
    const second = notificationBucket(new Date('2026-07-14T10:59:00Z'));
    const third = notificationBucket(new Date('2026-07-14T13:00:00Z'));
    assert.equal(first, second);
    assert.notEqual(second, third);
  });
});

const assert = require('node:assert/strict');
const {describe, it} = require('node:test');

const {
  groupNotificationCategoryForKind,
  parseGroupNotificationPreferencesUpdate,
  parseStoredGroupNotificationPreferences,
} = require('../lib/notifications/groupNotificationPolicy.js');

describe('group notification preferences policy', () => {
  it('keeps backwards-compatible defaults when stored doc is missing', () => {
    const prefs = parseStoredGroupNotificationPreferences(undefined);
    assert.equal(prefs.muted, false);
    assert.equal(prefs.memberChatEnabled, true);
    assert.equal(prefs.announcementsEnabled, true);
    assert.equal(prefs.sessionsEnabled, true);
    assert.equal(prefs.invitationsEnabled, true);
  });

  it('validates complete preference updates', () => {
    const ok = parseGroupNotificationPreferencesUpdate({
      muted: true,
      memberChatEnabled: false,
      announcementsEnabled: false,
      sessionsEnabled: true,
      invitationsEnabled: false,
    });
    assert.equal(ok.muted, true);
    assert.equal(ok.memberChatEnabled, false);

    assert.throws(() => parseGroupNotificationPreferencesUpdate({
      muted: true,
      memberChatEnabled: 'nope',
      announcementsEnabled: true,
      sessionsEnabled: true,
      invitationsEnabled: true,
    }));
  });

  it('maps notification kinds into group categories', () => {
    assert.equal(
      groupNotificationCategoryForKind('conversation_message'),
      'member_chat',
    );
    assert.equal(
      groupNotificationCategoryForKind('group_announcement'),
      'announcements',
    );
    assert.equal(
      groupNotificationCategoryForKind('group_session_scheduled'),
      'sessions',
    );
    assert.equal(
      groupNotificationCategoryForKind('group_join_request'),
      'invitations',
    );
  });
});



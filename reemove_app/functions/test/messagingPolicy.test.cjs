const assert = require('node:assert/strict');
const {describe, it} = require('node:test');

const {
  directConversationId,
  groupTitle,
  messageKind,
  messagePreview,
  normalizedMessageText,
  parseAttachments,
  reactionEmoji,
  reportReason,
  safeId,
  uniqueIds,
} = require('../lib/messaging/messagingPolicy.js');

describe('messaging identity and group policy', () => {
  it('creates a stable direct conversation id regardless of user order', () => {
    assert.equal(
      directConversationId('alice', 'bob'),
      directConversationId('bob', 'alice'),
    );
    assert.match(directConversationId('alice', 'bob'), /^direct_[a-f0-9]{40}$/);
  });

  it('normalizes group names and unique member ids', () => {
    assert.equal(groupTitle('  Saturday   Football  '), 'Saturday Football');
    assert.deepEqual(uniqueIds(['alice', 'alice', 'bob'], 'memberIds', 10), [
      'alice',
      'bob',
    ]);
    assert.throws(() => groupTitle('x'));
    assert.throws(() => safeId('bad/id', 'id'));
  });
});

describe('message content policy', () => {
  it('removes control characters and bounds text', () => {
    assert.equal(normalizedMessageText('  hello\u0000\r\nteam  '), 'hello\nteam');
    assert.throws(() => normalizedMessageText('x'.repeat(4001)));
  });

  it('accepts image carousels and rejects mixed video attachments', () => {
    const images = parseAttachments([
      {id: 'a', storagePath: 'messages/c/m/a/a.png', contentType: 'image/png', sizeBytes: 10, kind: 'image'},
      {id: 'b', storagePath: 'messages/c/m/b/b.png', contentType: 'image/png', sizeBytes: 12, kind: 'image'},
    ]);
    assert.equal(images.length, 2);
    assert.equal(messageKind('', images), 'image');
    assert.throws(() => parseAttachments([
      {id: 'a', storagePath: 'messages/c/m/a/a.mp4', contentType: 'video/mp4', sizeBytes: 10, kind: 'video'},
      {id: 'b', storagePath: 'messages/c/m/b/b.png', contentType: 'image/png', sizeBytes: 12, kind: 'image'},
    ]));
  });

  it('creates privacy-safe previews', () => {
    assert.equal(messagePreview('image', ''), 'Photo');
    assert.equal(messagePreview('text', 'Hello team'), 'Hello team');
    assert.equal(messagePreview('text', 'x'.repeat(130)).length, 120);
  });

  it('accepts only allowlisted reactions and report reasons', () => {
    assert.equal(reactionEmoji('🔥'), '🔥');
    assert.equal(reportReason('harassment'), 'harassment');
    assert.throws(() => reactionEmoji('🚫'));
    assert.throws(() => reportReason('inappropriate_content'));
  });
});

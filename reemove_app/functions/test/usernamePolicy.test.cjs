const assert = require('node:assert/strict');
const {describe, it} = require('node:test');

const {
  normalizeUsername,
  validateDisplayName,
  validateUsername,
} = require('../lib/account/usernamePolicy.js');

describe('username policy', () => {
  it('normalizes case and whitespace', () => {
    assert.equal(normalizeUsername('  Move.Runner  '), 'move.runner');
  });

  it('accepts valid usernames', () => {
    assert.equal(validateUsername('runner_26'), null);
    assert.equal(validateUsername('move.fast'), null);
  });

  it('rejects reserved, malformed, and repeated separators', () => {
    assert.notEqual(validateUsername('admin'), null);
    assert.notEqual(validateUsername('_runner'), null);
    assert.notEqual(validateUsername('runner..fast'), null);
    assert.notEqual(validateUsername('runner-fast'), null);
  });

  it('validates display-name length', () => {
    assert.equal(validateDisplayName('Mostafa AbuElhija'), null);
    assert.notEqual(validateDisplayName(''), null);
    assert.notEqual(validateDisplayName('x'.repeat(81)), null);
  });
});

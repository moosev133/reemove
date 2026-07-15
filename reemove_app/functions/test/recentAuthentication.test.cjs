const assert = require('node:assert/strict');
const test = require('node:test');

const {
  requireRecentAuthentication,
} = require('../lib/account/recentAuthentication.js');

function assertFailedPrecondition(action) {
  assert.throws(action, (error) => {
    assert.equal(error.code, 'failed-precondition');
    return true;
  });
}

test('accepts authentication from the current security window', () => {
  const nowSeconds = Math.floor(Date.now() / 1000);
  assert.doesNotThrow(() => requireRecentAuthentication(nowSeconds));
  assert.doesNotThrow(() => requireRecentAuthentication(nowSeconds - 599));
});

test('rejects missing authentication time', () => {
  assertFailedPrecondition(() => requireRecentAuthentication(undefined));
});

test('rejects authentication older than ten minutes', () => {
  const nowSeconds = Math.floor(Date.now() / 1000);
  assertFailedPrecondition(() => requireRecentAuthentication(nowSeconds - 601));
});

test('rejects an authentication time too far in the future', () => {
  const nowSeconds = Math.floor(Date.now() / 1000);
  assertFailedPrecondition(() => requireRecentAuthentication(nowSeconds + 61));
});

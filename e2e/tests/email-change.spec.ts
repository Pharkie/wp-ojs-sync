import { test, expect } from '@playwright/test';
import {
  createUser,
  deleteUser,
  createSubscription,
  deleteSubscription,
  getSubscriptionProductId,
  changeUserEmail,
  clearTestSyncData,
} from '../helpers/wp';
import {
  findOjsUser,
  hasActiveSubscription,
  getOjsUserEmail,
  deleteOjsUser,
  waitForSync,
} from '../helpers/ojs';

const TS = Date.now();
const ORIGINAL_EMAIL = `e2e_emailchg_${TS}@test.invalid`;
const NEW_EMAIL = `e2e_emailchg_new_${TS}@test.invalid`;
const LOGIN = `e2e_emailchg_${TS}`;

let wpUserId: number;
let subId: number;
let productId: number;

test.describe('Email change sync', () => {
  test.beforeAll(() => {
    productId = getSubscriptionProductId();
    wpUserId = createUser(LOGIN, ORIGINAL_EMAIL);
    subId = createSubscription(wpUserId, productId, 'active');
    waitForSync();
  });

  test.afterAll(() => {
    try { deleteSubscription(subId); } catch { /* may already be gone */ }
    try { deleteUser(wpUserId); } catch { /* may already be gone */ }
    deleteOjsUser(ORIGINAL_EMAIL);
    deleteOjsUser(NEW_EMAIL);
    clearTestSyncData();
  });

  test('WP email change → OJS user email updated', () => {
    // Verify initial sync created OJS user with original email
    const ojsUserId = findOjsUser(ORIGINAL_EMAIL);
    expect(ojsUserId).not.toBeNull();
    expect(hasActiveSubscription(ojsUserId!)).toBe(true);

    // Change email in WP (fires profile_update hook)
    changeUserEmail(wpUserId, NEW_EMAIL);
    waitForSync();

    // OJS user should now have the new email
    const updatedEmail = getOjsUserEmail(ojsUserId!);
    expect(updatedEmail).toBe(NEW_EMAIL);

    // Subscription should still be active
    expect(hasActiveSubscription(ojsUserId!)).toBe(true);
  });
});

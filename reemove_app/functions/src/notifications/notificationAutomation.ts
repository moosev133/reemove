import {getFirestore, Timestamp} from "firebase-admin/firestore";
import {logger} from "firebase-functions";
import {onSchedule} from "firebase-functions/v2/scheduler";

import {primaryRegion} from "../core/functionOptions";
import {collections} from "../core/schema";
import {
  purgeDeletedNotifications,
  purgeExpiredNotificationEvents,
} from "./notificationCallables";
import {deliverDeferredNotification} from "./notificationService";

export const flushDeferredNotifications = onSchedule(
  {
    region: primaryRegion,
    schedule: "every 15 minutes",
    timeZone: "UTC",
    retryCount: 3,
  },
  async () => {
    const database = getFirestore();
    const snapshot = await database.collection(collections.notificationDeliveries)
      .where("status", "==", "deferred_quiet_hours")
      .where("deliverAfter", "<=", Timestamp.now())
      .limit(200)
      .get();
    let delivered = 0;
    for (const document of snapshot.docs) {
      try {
        await deliverDeferredNotification(document);
        delivered += 1;
      } catch (error: unknown) {
        logger.error("Deferred notification delivery failed.", {
          deliveryId: document.id,
          error: error instanceof Error ? error.message : String(error),
        });
      }
    }
    logger.info("Deferred notification flush completed.", {
      candidates: snapshot.size,
      delivered,
    });
  },
);

export const cleanupNotificationData = onSchedule(
  {
    region: primaryRegion,
    schedule: "every day 03:25",
    timeZone: "UTC",
    retryCount: 2,
  },
  async () => {
    const [events, notifications] = await Promise.all([
      purgeExpiredNotificationEvents(),
      purgeDeletedNotifications(),
    ]);
    logger.info("Notification cleanup completed.", {events, notifications});
  },
);

const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const {initializeApp, applicationDefault} = require("firebase-admin/app");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");

initializeApp({credential: applicationDefault()});

const db = getFirestore();

// --- Existing Function: processReferral ---
exports.processReferral = onDocumentCreated("users/{userId}", async (event) => {
  const snap = event.data;
  const newUser = snap.data();
  const referredBy = newUser.referredBy;

  if (!referredBy) return;

  const bonusAmount = 0.05;

  const referrerWalletRef = db.collection("wallets").doc(referredBy);
  const referrerTransRef = db
      .collection("users")
      .doc(referredBy)
      .collection("transactions");

  try {
    await db.runTransaction(async (transaction) => {
      const walletDoc = await transaction.get(referrerWalletRef);

      if (!walletDoc.exists) {
        console.log("Referrer wallet does not exist.");
        return;
      }

      transaction.update(referrerWalletRef, {
        bonusBalance: FieldValue.increment(bonusAmount),
        referralCount: FieldValue.increment(1),
      });

      transaction.set(referrerTransRef.doc(), {
        type: "referral_bonus",
        amount: bonusAmount,
        timestamp: FieldValue.serverTimestamp(),
        status: "completed",
      });
    });

    console.log("Referral bonus applied to:", referredBy);
  } catch (error) {
    console.error("Error processing referral:", error);
  }

  return;
});

// --- New Callable Function: startMiningSession ---
// Triggered by the client to start a mining session.
exports.startMiningSession = onCall(async (request) => {
  const userId = request.auth?.uid;
  if (!userId) {
    throw new HttpsError("unauthenticated", "User must be authenticated to start mining.");
  }

  const miningRatePerDay = 0.05; // NERG per 24 hours
  const miningDurationHours = 24;

  const startTime = FieldValue.serverTimestamp();
  const expectedEndTime = new Date();
  expectedEndTime.setHours(expectedEndTime.getHours() + miningDurationHours);

  const miningSessionRef = db.collection("miningSessions").doc(userId);

  try {
    await db.runTransaction(async (transaction) => {
      const sessionDoc = await transaction.get(miningSessionRef);

      if (sessionDoc.exists && sessionDoc.data().status === "in_progress") {
        throw new HttpsError("failed-precondition", "Mining session already in progress.");
      }

      transaction.set(miningSessionRef, {
        userId: userId,
        startTime: startTime,
        expectedEndTime: expectedEndTime,
        currentMinedAmount: 0.0,
        status: "in_progress",
        lastProcessedAt: startTime,
        miningRatePerDay: miningRatePerDay,
        miningDurationHours: miningDurationHours,
      });
    });

    console.log(`Mining session started for user: ${userId}`);
    return {status: "success", message: "Mining session started."};
  } catch (error) {
    console.error(`Error starting mining session for ${userId}:`, error);
    if (error instanceof HttpsError) {
      throw error;
    } else {
      throw new HttpsError("internal", "Failed to start mining session.", error.message);
    }
  }
});

// --- Shared Mining Processing Logic ---
async function processMiningActivityForUser(userId) {
  const miningSessionRef = db.collection("miningSessions").doc(userId);
  const walletRef = db.collection("wallets").doc(userId);
  const transactionsRef = db.collection("users").doc(userId).collection("transactions");

  try {
    await db.runTransaction(async (transaction) => {
      const sessionDoc = await transaction.get(miningSessionRef);

      if (!sessionDoc.exists || sessionDoc.data().status !== "in_progress") {
        console.log(`No active mining session for user ${userId}.`);
        return;
      }

      const sessionData = sessionDoc.data();

      const walletDoc = await transaction.get(walletRef);
      if (!walletDoc.exists) {
        console.warn(`Wallet not found for user ${userId}. Skipping mining update.`);
        transaction.update(miningSessionRef, {status: "failed", lastProcessedAt: FieldValue.serverTimestamp(), errorMessage: "Wallet not found."});
        return;
      }

      const now = new Date();
      const startTime = sessionData.startTime.toDate();
      const expectedEndTime = sessionData.expectedEndTime.toDate();
      const miningRatePerDay = sessionData.miningRatePerDay;
      const miningDurationHours = sessionData.miningDurationHours;

      // Calculate elapsed time for this processing interval
      const lastProcessedAt = sessionData.lastProcessedAt.toDate();
      const intervalStart = lastProcessedAt > startTime ? lastProcessedAt : startTime; // Ensure we don't re-process time before start
      const intervalEnd = now < expectedEndTime ? now : expectedEndTime; // Ensure we don't process beyond expected end

      if (intervalEnd <= intervalStart) {
        // No time to process in this interval, or session already ended
        if (now >= expectedEndTime) {
          // Session should be completed
          const finalMinedAmount = (miningDurationHours / 24) * miningRatePerDay; // Total possible amount
          const amountToAdd = finalMinedAmount - sessionData.currentMinedAmount; // Only add what's missing

          if (amountToAdd > 0) {
            transaction.update(walletRef, {
              balance: FieldValue.increment(amountToAdd),
              lastMined: FieldValue.serverTimestamp(),
            });
            // Fix: Use transaction.set with a new doc reference for adding
            transaction.set(transactionsRef.doc(), {
              userId: userId,
              type: "mining_reward",
              amount: amountToAdd,
              timestamp: FieldValue.serverTimestamp(),
              status: "completed",
              isIncoming: true,
              counterparty: "System",
              description: "Offline mining completion reward",
            });
          }
          transaction.update(miningSessionRef, {
            status: "completed",
            currentMinedAmount: finalMinedAmount,
            lastProcessedAt: FieldValue.serverTimestamp(),
            completionTime: FieldValue.serverTimestamp(),
          });
          console.log(`Mining session completed for user: ${userId}`);
        } else {
          console.log(`No new time to process for user ${userId}. Session still in progress.`);
        }
        return;
      }

      const durationToProcessMs = intervalEnd.getTime() - intervalStart.getTime();
      const durationToProcessHours = durationToProcessMs / (1000 * 60 * 60);

      const minedAmountThisInterval = (durationToProcessHours / 24) * miningRatePerDay;
      const newCurrentMinedAmount = sessionData.currentMinedAmount + minedAmountThisInterval;

      // Ensure we don't exceed the total possible amount for the duration
      const totalPossibleAmount = (miningDurationHours / 24) * miningRatePerDay;
      const finalMinedAmountForSession = Math.min(newCurrentMinedAmount, totalPossibleAmount);
      const actualAmountToAdd = finalMinedAmountForSession - sessionData.currentMinedAmount;

      if (actualAmountToAdd > 0) {
        transaction.update(walletRef, {
          balance: FieldValue.increment(actualAmountToAdd),
          lastMined: FieldValue.serverTimestamp(),
        });

        // Update existing in_progress transaction or create a new one if not found
        const existingTxSnapshot = await transactionsRef
            .where("type", "==", "mining_in_progress")
            .where("userId", "==", userId)
            .where("status", "==", "in_progress")
            .limit(1)
            .get();

        if (!existingTxSnapshot.empty) {
          const txDoc = existingTxSnapshot.docs[0];
          transaction.update(txDoc.ref, {
            amount: finalMinedAmountForSession,
            lastUpdate: FieldValue.serverTimestamp(),
          });
        } else {
          // This case should ideally not happen if startMiningSession creates it
          // but as a fallback, create a new one
          // Fix: Use transaction.set with a new doc reference for adding
          transaction.set(transactionsRef.doc(), {
            userId: userId,
            type: "mining_in_progress",
            amount: finalMinedAmountForSession,
            targetAmount: totalPossibleAmount,
            startTime: startTime,
            lastUpdate: FieldValue.serverTimestamp(),
            status: "in_progress",
            isIncoming: true,
            counterparty: "System",
            description: "Offline mining progress update",
          });
        }
      }

      let newStatus = "in_progress";
      if (now >= expectedEndTime) {
        newStatus = "completed";
      }

      const updateData = {
        currentMinedAmount: finalMinedAmountForSession,
        lastProcessedAt: FieldValue.serverTimestamp(),
        status: newStatus,
      };

      if (newStatus === "completed") {
        updateData.completionTime = FieldValue.serverTimestamp();
      }

      transaction.update(miningSessionRef, updateData);

      console.log(`Processed mining for user ${userId}. Mined: ${finalMinedAmountForSession.toFixed(5)} NERG`);
    });
  } catch (error) {
    console.error(`Error processing mining for user ${userId}:`, error);
    // Update session status to failed if an error occurs during processing
    await miningSessionRef.update({
      status: "failed",
      lastProcessedAt: FieldValue.serverTimestamp(),
      errorMessage: error.message || "Unknown error during processing.",
    });
  }
}

// --- New Scheduled Function: processMiningActivity ---
// Runs periodically to process active mining sessions.
// Schedule: Every 5 minutes (adjust as needed)
exports.processMiningActivity = onSchedule("*/1 * * * *", async (event) => {
  console.log("Running scheduled mining activity processing.");

  const activeSessionsSnapshot = await db
      .collection("miningSessions")
      .where("status", "==", "in_progress")
      .get();

  if (activeSessionsSnapshot.empty) {
    console.log("No active mining sessions to process.");
    return null;
  }

  for (const doc of activeSessionsSnapshot.docs) {
    const sessionData = doc.data();
    const userId = sessionData.userId;
    await processMiningActivityForUser(userId);
  }
  return null;
});

// --- New Callable Function: processMiningActivity ---
// Triggered by the client (web) to process mining activity for a specific user.
exports.processMiningActivityCallable = onCall(async (request) => {
  const userId = request.auth?.uid;
  if (!userId) {
    throw new HttpsError("unauthenticated", "User must be authenticated to process mining activity.");
  }

  console.log(`Processing mining activity for user: ${userId} (called by client)`);

  try {
    await processMiningActivityForUser(userId);
    return {status: "success", message: "Mining activity processed."};
  } catch (error) {
    console.error(`Error processing mining activity for user ${userId}:`, error);
    throw new HttpsError("internal", "Failed to process mining activity.", error.message);
  }
});

// --- New Callable Function: finalizeMiningSession ---
// Triggered by the client to stop a mining session (e.g., on logout or manual stop).
exports.finalizeMiningSession = onCall(async (request) => {
  const userId = request.auth?.uid;
  if (!userId) {
    throw new HttpsError("unauthenticated", "User must be authenticated to finalize mining.");
  }

  const miningSessionRef = db.collection("miningSessions").doc(userId);
  const walletRef = db.collection("wallets").doc(userId);
  const transactionsRef = db.collection("users").doc(userId).collection("transactions");

  try {
    await db.runTransaction(async (transaction) => {
      const sessionDoc = await transaction.get(miningSessionRef);
      if (!sessionDoc.exists || sessionDoc.data().status !== "in_progress") {
        throw new HttpsError("failed-precondition", "No active mining session to finalize.");
      }

      const sessionData = sessionDoc.data();
      const startTime = sessionData.startTime.toDate();
      const miningRatePerDay = sessionData.miningRatePerDay;
      const expectedEndTime = sessionData.expectedEndTime.toDate();

      const now = new Date();
      const actualEndTime = now < expectedEndTime ? now : expectedEndTime; // Don't process beyond expected end

      const durationProcessedMs = actualEndTime.getTime() - startTime.getTime();
      const durationProcessedHours = durationProcessedMs / (1000 * 60 * 60);

      const totalMinedAmount = (durationProcessedHours / 24) * miningRatePerDay;

      // Ensure we don't exceed the total possible amount for the duration
      const finalMinedAmount = Math.min(totalMinedAmount, (sessionData.miningDurationHours / 24) * miningRatePerDay);
      const amountToAdd = finalMinedAmount - sessionData.currentMinedAmount; // Only add what's missing

      if (amountToAdd > 0) {
        transaction.update(walletRef, {
          balance: FieldValue.increment(amountToAdd),
          lastMined: FieldValue.serverTimestamp(),
        });

        // Update existing in_progress transaction to completed
        const existingTxSnapshot = await transactionsRef
            .where("type", "==", "mining_in_progress")
            .where("userId", "==", userId)
            .where("status", "==", "in_progress")
            .limit(1)
            .get();

        if (!existingTxSnapshot.empty) {
          const txDoc = existingTxSnapshot.docs[0];
          transaction.update(txDoc.ref, {
            type: "mining_reward",
            amount: finalMinedAmount,
            status: "completed",
            completionTime: FieldValue.serverTimestamp(),
            lastUpdate: FieldValue.serverTimestamp(),
            description: "Offline mining manual completion reward",
          });
        } else {
          // Fallback: create a new completed transaction if in_progress not found
          // Fix: Use transaction.set with a new doc reference for adding
          transaction.set(transactionsRef.doc(), {
            userId: userId,
            type: "mining_reward",
            amount: finalMinedAmount,
            timestamp: FieldValue.serverTimestamp(),
            status: "completed",
            isIncoming: true,
            counterparty: "System",
            description: "Offline mining manual completion reward (new transaction)",
          });
        }
      }

      const updateData = {
        status: "stopped",
        currentMinedAmount: finalMinedAmount,
        lastProcessedAt: FieldValue.serverTimestamp(),
      };
      updateData.completionTime = FieldValue.serverTimestamp();

      transaction.update(miningSessionRef, updateData);

      console.log(`Mining session finalized for user: ${userId}. Total mined: ${finalMinedAmount.toFixed(5)} NERG`);
      return {status: "success", message: "Mining session finalized."};
    });
  } catch (error) {
    console.error(`Error finalizing mining session for ${userId}:`, error);
    if (error instanceof HttpsError) {
      throw error;
    } else {
      throw new HttpsError("internal", "Failed to finalize mining session.", error.message);
    }
  }
});

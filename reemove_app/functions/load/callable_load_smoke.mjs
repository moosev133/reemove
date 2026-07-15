import process from 'node:process';
import { initializeApp } from 'firebase/app';
import { connectAuthEmulator, getAuth, signInWithEmailAndPassword } from 'firebase/auth';
import { connectFunctionsEmulator, getFunctions, httpsCallable } from 'firebase/functions';

const projectId = process.env.FIREBASE_PROJECT_ID || 'demo-reemove';
if (/prod|production/i.test(projectId)) {
  throw new Error('Production load testing is blocked.');
}

const host = process.env.FIREBASE_EMULATOR_HOST || '127.0.0.1';
const iterations = Math.min(Number(process.env.ITERATIONS || 5), 50);
const callableName = process.env.CALLABLE_NAME || 'aiCoach';
const email = process.env.TEST_EMAIL;
const password = process.env.TEST_PASSWORD;
if (!email || !password) {
  throw new Error('TEST_EMAIL and TEST_PASSWORD are required.');
}

const app = initializeApp({ apiKey: 'test', appId: 'test', projectId });
const auth = getAuth(app);
connectAuthEmulator(auth, `http://${host}:9099`, { disableWarnings: true });
await signInWithEmailAndPassword(auth, email, password);
const functions = getFunctions(
  app,
  process.env.FUNCTIONS_REGION || 'europe-west1',
);
connectFunctionsEmulator(functions, host, 5001);
const callable = httpsCallable(functions, callableName, { timeout: 30000 });

const latencies = [];
let failures = 0;
for (let i = 0; i < iterations; i += 1) {
  const start = performance.now();
  try {
    await callable({
      message: 'Give a brief safe sports recovery tip.',
      ageGroup: 'adult',
    });
    latencies.push(performance.now() - start);
  } catch (error) {
    failures += 1;
    console.error(`Iteration ${i + 1} failed:`, error.code || error.message);
  }
}
latencies.sort((a, b) => a - b);
const percentile = (p) =>
  latencies[Math.max(0, Math.ceil(latencies.length * p) - 1)] || 0;
console.log(
  JSON.stringify(
    {
      iterations,
      success: latencies.length,
      failures,
      p50Ms: percentile(0.5),
      p95Ms: percentile(0.95),
    },
    null,
    2,
  ),
);
if (failures > 0) {
  process.exitCode = 1;
}

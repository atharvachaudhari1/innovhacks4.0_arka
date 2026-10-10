/**
 * FitGuru Web Application
 * On-Device Multi-Modal AI Workout Coach (Innovhacks 4.0)
 */

// ========================================================
// 1. APP STATE & LOCAL STORAGE DATABASE
// ========================================================
const DB_KEYS = {
  SESSIONS: 'fitguru_workout_sessions',
  GOAL: 'fitguru_weekly_goal',
  USER_NAME: 'fitguru_user_name',
  CHALLENGE_DATE: 'fitguru_challenge_completed_date'
};

const DEFAULT_CHALLENGES = [
  { title: "Quick 15", desc: "Do 15 push-ups in a single session.", target: 15, type: "Push-ups" },
  { title: "Morning Burst", desc: "Get your blood pumping with 20 push-ups.", target: 20, type: "Push-ups" },
  { title: "Solid Strength", desc: "Show your strength with 25 push-ups.", target: 25, type: "Push-ups" },
  { title: "The Challenger", desc: "Push your limits with 30 push-ups.", target: 30, type: "Push-ups" },
  { title: "Endurance Test", desc: "Go the distance with 35 push-ups.", target: 35, type: "Push-ups" }
];

const EXERCISE_CONFIG = {
  PUSH_UP: { name: "Push-ups", calPerRep: 2.8, unit: "reps", target: "Chest & Core" },
  SQUAT: { name: "Squats", calPerRep: 3.2, unit: "reps", target: "Legs & Glutes" },
  DEADLIFT: { name: "Barbell Deadlift", calPerRep: 4.5, unit: "reps", target: "Back & Hamstrings" },
  PULL_UP: { name: "Pull-ups", calPerRep: 3.8, unit: "reps", target: "Lats & Back" },
  CHIN_UP: { name: "Chin-ups", calPerRep: 3.8, unit: "reps", target: "Biceps & Back" },
  BICEP_CURL: { name: "Bicep Curls", calPerRep: 2.2, unit: "reps", target: "Biceps" },
  LUNGE: { name: "Lunges", calPerRep: 3.0, unit: "reps", target: "Quads & Glutes" },
  PLANK: { name: "Plank Hold", calPerRep: 0.2, unit: "sec", target: "Core & Stability" },
  BENCH_PRESS: { name: "Bench Press", calPerRep: 3.5, unit: "reps", target: "Chest & Triceps" },
  CHEST_PRESS: { name: "Chest Press", calPerRep: 3.2, unit: "reps", target: "Chest" },
  SHOULDER_PRESS: { name: "Shoulder Press", calPerRep: 3.0, unit: "reps", target: "Delts & Shoulders" },
  LEG_PRESS: { name: "Leg Press", calPerRep: 4.0, unit: "reps", target: "Quads & Glutes" },
  LEG_EXTENSION: { name: "Leg Extension", calPerRep: 2.5, unit: "reps", target: "Quads" },
  LEG_CURL: { name: "Leg Curl", calPerRep: 2.5, unit: "reps", target: "Hamstrings" },
  LAT_PULLDOWN: { name: "Lat Pulldown", calPerRep: 3.2, unit: "reps", target: "Lats & Upper Back" },
  SEATED_ROW: { name: "Seated Cable Row", calPerRep: 3.2, unit: "reps", target: "Back & Rhomboids" },
  TRICEPS_PUSHDOWN: { name: "Triceps Pushdown", calPerRep: 2.0, unit: "reps", target: "Triceps" },
  RUNNING: { name: "Running Cadence", calPerRep: 0.08, unit: "steps", target: "Cardio & Gait" }
};

let appState = {
  currentTab: 'dashboard',
  currentWorkoutType: 'PUSH_UP',
  isWorkoutActive: false,
  workoutState: 'ready',
  repCount: 0,
  currentScore: 100,
  formDeductions: 0,
  lastFeedbackTime: 0,
  lastReflexTime: 0,
  lastCognitiveTime: 0,
  isGenerativeAiEnabled: true,
  isAiThinking: false,
  isTtsEnabled: true,
  isCameraMirrored: true,
  autoSimInterval: null,
  watchHeartRate: 124,
  activeCalories: 385,
  dailySteps: 6840,
  lastLeadingFoot: null,
  lastStepTime: 0,
  runningCadenceSpm: 165,
  lastPlankTick: 0
};

// Database Helpers (Mirroring Room Dao)
function getSavedSessions() {
  const data = localStorage.getItem(DB_KEYS.SESSIONS);
  if (!data) {
    // Initial mock data matching Kotlin app default state
    const initial = [
      { id: 1, date: new Date(Date.now() - 86400000 * 2).toISOString(), exerciseType: "Push-ups", reps: 20, score: 95, calories: 56, avgBpm: 128 },
      { id: 2, date: new Date(Date.now() - 86400000).toISOString(), exerciseType: "Squats", reps: 30, score: 98, calories: 84, avgBpm: 135 }
    ];
    localStorage.setItem(DB_KEYS.SESSIONS, JSON.stringify(initial));
    return initial;
  }
  try {
    return JSON.parse(data);
  } catch (e) {
    return [];
  }
}

function saveSession(session) {
  const sessions = getSavedSessions();
  sessions.unshift({
    id: Date.now(),
    date: new Date().toISOString(),
    ...session
  });
  localStorage.setItem(DB_KEYS.SESSIONS, JSON.stringify(sessions));
  updateDashboardUI();
  updateProfileUI();
  renderHistoryList();
}

function getWeeklyGoal() {
  return parseInt(localStorage.getItem(DB_KEYS.GOAL), 10) || 200;
}

function setWeeklyGoal(val) {
  localStorage.setItem(DB_KEYS.GOAL, val);
  updateDashboardUI();
}

function getUserName() {
  return localStorage.getItem(DB_KEYS.USER_NAME) || "Athrava";
}

function setUserName(name) {
  localStorage.setItem(DB_KEYS.USER_NAME, name);
  document.getElementById('dashUserName').innerText = name;
  document.getElementById('profileNameDisplay').innerText = name;
}

// ========================================================
// 2. SPEECH & FEEDBACK LOGIC
// ========================================================
function speak(text) {
  if (!appState.isTtsEnabled || !text) return;

  // 1. iOS Native Bridge (AVSpeechSynthesizer)
  if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.nativeBridge) {
    try {
      window.webkit.messageHandlers.nativeBridge.postMessage({ action: 'speak', text: text });
      return;
    } catch (err) {
      console.warn("iOS Native Bridge speak failed, falling back to Web Speech:", err);
    }
  }

  // 2. Browser Web Speech Synthesis fallback
  if (!('speechSynthesis' in window)) return;

  try {
    window.speechSynthesis.cancel();
    const utterance = new SpeechSynthesisUtterance(text);
    utterance.rate = 1.05;
    utterance.pitch = 1.0;
    
    // Pick standard English voice if available
    const voices = window.speechSynthesis.getVoices();
    const engVoice = voices.find(v => v.lang.startsWith('en') && !v.name.includes('Google'));
    if (engVoice) utterance.voice = engVoice;
    
    window.speechSynthesis.speak(utterance);
  } catch (err) {
    console.warn("TTS speak failed:", err);
  }
}

function triggerNativeHaptic(type = 'impact') {
  if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.nativeBridge) {
    try {
      window.webkit.messageHandlers.nativeBridge.postMessage({ action: 'haptic', type: type });
    } catch (e) {}
  }
}

// ========================================================
// 3. MEDIAPIPE POSE & CAMERA ENGINE
// ========================================================
let pose = null;
let cameraInstance = null;
let mediaPipeInitAttempts = 0;
const videoElement = document.getElementById('webcam');
const canvasElement = document.getElementById('poseCanvas');
const canvasCtx = canvasElement ? canvasElement.getContext('2d') : null;

function initMediaPipePose() {
  if (typeof Pose === 'undefined') {
    if (mediaPipeInitAttempts < 30) {
      mediaPipeInitAttempts++;
      setTimeout(initMediaPipePose, 500);
    } else {
      console.warn("MediaPipe Pose library is loading or offline, simulator available.");
    }
    return;
  }

  if (pose) return;

  try {
    pose = new Pose({
      locateFile: (file) => `https://cdn.jsdelivr.net/npm/@mediapipe/pose/${file}`
    });

    pose.setOptions({
      modelComplexity: 1,
      smoothLandmarks: true,
      enableSegmentation: false,
      minDetectionConfidence: 0.5,
      minTrackingConfidence: 0.5
    });

    pose.onResults(onPoseResults);
    console.log("MediaPipe Pose engine initialized.");
  } catch (err) {
    console.error("Error initializing MediaPipe Pose:", err);
  }
}

async function startCamera() {
  if (!pose && typeof Pose !== 'undefined') {
    initMediaPipePose();
  }

  if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
    setAiFeedback("Camera not supported on this browser. Use Test Simulator below!");
    return;
  }

  try {
    const stream = await navigator.mediaDevices.getUserMedia({
      video: { width: { ideal: 640 }, height: { ideal: 480 }, facingMode: 'user' },
      audio: false
    });

    videoElement.srcObject = stream;
    await videoElement.play();

    // Use MediaPipe Camera utils or requestAnimationFrame loop
    if (typeof Camera !== 'undefined' && pose) {
      cameraInstance = new Camera(videoElement, {
        onFrame: async () => {
          if (appState.isWorkoutActive && pose) {
            await pose.send({ image: videoElement });
          }
        },
        width: 640,
        height: 480
      });
      cameraInstance.start();
    } else {
      // Fallback RAF loop
      processVideoFrameLoop();
    }
  } catch (err) {
    console.warn("Camera access denied or error:", err);
    setAiFeedback("Camera access blocked. Click 'Test Mode Simulator' below to test live rep counting!");
  }
}

function stopCamera() {
  if (cameraInstance) {
    try { cameraInstance.stop(); } catch (e) {}
    cameraInstance = null;
  }
  if (videoElement && videoElement.srcObject) {
    const tracks = videoElement.srcObject.getTracks();
    tracks.forEach(track => track.stop());
    videoElement.srcObject = null;
  }
}

async function processVideoFrameLoop() {
  if (!appState.isWorkoutActive) return;
  if (!pose && typeof Pose !== 'undefined') {
    initMediaPipePose();
  }
  if (pose && videoElement && videoElement.readyState >= 2) {
    try {
      await pose.send({ image: videoElement });
    } catch (e) {}
  }
  requestAnimationFrame(processVideoFrameLoop);
}

// Landmark Angle Math (Exact interior joint angle using vector dot product, matching Kotlin CameraFragment)
function getAngle(p1, p2, p3) {
  if (!p1 || !p2 || !p3) return 180;
  const v1x = p1.x - p2.x;
  const v1y = p1.y - p2.y;
  const v2x = p3.x - p2.x;
  const v2y = p3.y - p2.y;
  const dot = v1x * v2x + v1y * v2y;
  const mag1 = Math.hypot(v1x, v1y);
  const mag2 = Math.hypot(v2x, v2y);
  if (mag1 * mag2 === 0) return 180;
  const cosAngle = Math.max(-1, Math.min(1, dot / (mag1 * mag2)));
  return Math.acos(cosAngle) * (180 / Math.PI);
}

// Resolve best visible limbs (left vs right profile)
function getActiveJoints(landmarks) {
  if (!landmarks || landmarks.length < 28) return null;
  const leftScore = (landmarks[11]?.visibility || 0.5) + (landmarks[23]?.visibility || 0.5);
  const rightScore = (landmarks[12]?.visibility || 0.5) + (landmarks[24]?.visibility || 0.5);
  const useRight = rightScore > (leftScore + 0.15);

  return {
    nose: landmarks[0],
    shoulder: useRight ? (landmarks[12] || landmarks[11]) : (landmarks[11] || landmarks[12]),
    elbow: useRight ? (landmarks[14] || landmarks[13]) : (landmarks[13] || landmarks[14]),
    wrist: useRight ? (landmarks[16] || landmarks[15]) : (landmarks[15] || landmarks[16]),
    hip: useRight ? (landmarks[24] || landmarks[23]) : (landmarks[23] || landmarks[24]),
    knee: useRight ? (landmarks[26] || landmarks[25]) : (landmarks[25] || landmarks[26]),
    ankle: useRight ? (landmarks[28] || landmarks[27]) : (landmarks[27] || landmarks[28]),
    leftAnkle: landmarks[27],
    rightAnkle: landmarks[28]
  };
}

// ========================================================
// GYM MULTI-PERSON & PASSERBY SHIELD
// ========================================================
const gymShield = {
  anchor: null, // { centerX, centerY, torsoHeight, isLocked: false, confirmFrames: 0, occlusionFrames: 0 }
  maxJumpThreshold: 0.32,
  maxOcclusionGraceFrames: 45,
  filteredPasserbyCount: 0
};

function resetGymSubjectLock() {
  gymShield.anchor = null;
  gymShield.filteredPasserbyCount = 0;
  updateGymShieldBadge('SEARCHING');
}

function updateGymShieldBadge(status, count = 0) {
  const pill = document.getElementById('camShieldPill');
  const icon = document.getElementById('camShieldIcon');
  const text = document.getElementById('camShieldText');
  if (!pill || !text) return;

  pill.classList.remove('holding', 'searching');

  if (status === 'LOCKED') {
    if (icon) icon.textContent = '🛡️';
    text.textContent = count > 0 ? `LOCKED • ${count} BYSTANDERS` : 'LIFTER LOCKED';
  } else if (status === 'HOLDING') {
    pill.classList.add('holding');
    if (icon) icon.textContent = '⏸️';
    text.textContent = 'HOLDING REP (OCCLUSION)';
  } else {
    pill.classList.add('searching');
    if (icon) icon.textContent = '🔍';
    text.textContent = 'ACQUIRING LIFTER...';
  }
}

function drawGymLockReticle(ctx, x, y, radius, isHolding = false) {
  ctx.save();
  ctx.strokeStyle = isHolding ? '#FFB300' : '#A4FF2E';
  ctx.lineWidth = 2.5;
  ctx.shadowColor = isHolding ? 'rgba(255, 179, 0, 0.6)' : 'rgba(164, 255, 46, 0.7)';
  ctx.shadowBlur = 10;

  // Outer target ring
  ctx.beginPath();
  ctx.arc(x, y, radius, 0, Math.PI * 2);
  ctx.stroke();

  // 4 corner targeting brackets
  const bracketLen = 14;
  const offset = radius + 6;

  // Top-left
  ctx.beginPath();
  ctx.moveTo(x - offset, y - offset + bracketLen);
  ctx.lineTo(x - offset, y - offset);
  ctx.lineTo(x - offset + bracketLen, y - offset);
  ctx.stroke();

  // Top-right
  ctx.beginPath();
  ctx.moveTo(x + offset - bracketLen, y - offset);
  ctx.lineTo(x + offset, y - offset);
  ctx.lineTo(x + offset, y - offset + bracketLen);
  ctx.stroke();

  // Bottom-left
  ctx.beginPath();
  ctx.moveTo(x - offset, y + offset - bracketLen);
  ctx.lineTo(x - offset, y + offset);
  ctx.lineTo(x - offset + bracketLen, y + offset);
  ctx.stroke();

  // Bottom-right
  ctx.beginPath();
  ctx.moveTo(x + offset - bracketLen, y + offset);
  ctx.lineTo(x + offset, y + offset);
  ctx.lineTo(x + offset, y + offset - bracketLen);
  ctx.stroke();

  // Center crosshair dot
  ctx.fillStyle = isHolding ? '#FFB300' : '#A4FF2E';
  ctx.beginPath();
  ctx.arc(x, y, 4, 0, Math.PI * 2);
  ctx.fill();

  // Target tag label
  ctx.font = 'bold 11px system-ui, -apple-system, sans-serif';
  ctx.fillStyle = isHolding ? '#FFB300' : '#A4FF2E';
  ctx.shadowBlur = 0;
  ctx.textAlign = 'center';
  ctx.fillText(isHolding ? 'HOLDING STATE' : 'LOCKED LIFTER', x, y - offset - 8);

  ctx.restore();
}

// MediaPipe Pose Results Handler
function onPoseResults(results) {
  if (!canvasElement || !canvasCtx) return;

  // Match canvas dimensions to video
  canvasElement.width = videoElement.videoWidth || 640;
  canvasElement.height = videoElement.videoHeight || 480;

  canvasCtx.save();
  canvasCtx.clearRect(0, 0, canvasElement.width, canvasElement.height);

  const hasLandmarks = results.poseLandmarks && results.poseLandmarks.length >= 25;

  if (hasLandmarks) {
    const landmarks = results.poseLandmarks;

    // Calculate torso centroid & scale
    const leftShoulder = landmarks[11] || landmarks[12];
    const rightShoulder = landmarks[12] || landmarks[11];
    const leftHip = landmarks[23] || landmarks[24];
    const rightHip = landmarks[24] || landmarks[23];

    const shoulderX = (leftShoulder.x + rightShoulder.x) / 2;
    const shoulderY = (leftShoulder.y + rightShoulder.y) / 2;
    const hipX = (leftHip.x + rightHip.x) / 2;
    const hipY = (leftHip.y + rightHip.y) / 2;

    const candCenterX = (shoulderX + hipX) / 2;
    const candCenterY = (shoulderY + hipY) / 2;
    const torsoHeight = Math.hypot(hipX - shoulderX, hipY - shoulderY);

    if (!gymShield.anchor || !gymShield.anchor.isLocked) {
      // Acquiring primary lifter lock
      if (!gymShield.anchor) {
        gymShield.anchor = {
          centerX: candCenterX,
          centerY: candCenterY,
          torsoHeight: torsoHeight,
          isLocked: false,
          confirmFrames: 1,
          occlusionFrames: 0
        };
      } else {
        gymShield.anchor.confirmFrames++;
        if (gymShield.anchor.confirmFrames >= 4) {
          gymShield.anchor.isLocked = true;
          updateGymShieldBadge('LOCKED');
        }
      }

      // Draw primary skeleton & lock reticle
      drawConnections(canvasCtx, landmarks, POSE_CONNECTIONS, { color: '#007F8B', lineWidth: 4 });
      drawLandmarks(canvasCtx, landmarks, { color: '#FFE600', fillColor: '#FFE600', radius: 5 });
      drawGymLockReticle(canvasCtx, candCenterX * canvasElement.width, candCenterY * canvasElement.height, Math.max(35, torsoHeight * canvasElement.height * 0.45));

      if (appState.isWorkoutActive) {
        analyzePoseLandmarks(landmarks);
      }
    } else {
      // Subject is locked - evaluate if candidate matches the lifter
      const anchor = gymShield.anchor;
      const dist = Math.hypot(candCenterX - anchor.centerX, candCenterY - anchor.centerY);
      const scaleDiff = Math.abs(torsoHeight - anchor.torsoHeight) / Math.max(0.05, anchor.torsoHeight);
      const cost = dist + (scaleDiff * 0.4);

      if (cost < gymShield.maxJumpThreshold) {
        // MATCH: Active Lifter confirmed
        anchor.centerX = anchor.centerX * 0.82 + candCenterX * 0.18;
        anchor.centerY = anchor.centerY * 0.82 + candCenterY * 0.18;
        anchor.torsoHeight = anchor.torsoHeight * 0.85 + torsoHeight * 0.15;
        anchor.occlusionFrames = 0;

        updateGymShieldBadge('LOCKED', gymShield.filteredPasserbyCount);

        // Draw primary skeleton
        drawConnections(canvasCtx, landmarks, POSE_CONNECTIONS, { color: '#007F8B', lineWidth: 4 });
        drawLandmarks(canvasCtx, landmarks, { color: '#FFE600', fillColor: '#FFE600', radius: 5 });

        // Draw HUD targeting reticle on active lifter
        const targetX = anchor.centerX * canvasElement.width;
        const targetY = anchor.centerY * canvasElement.height;
        const targetRadius = Math.max(38, anchor.torsoHeight * canvasElement.height * 0.48);
        drawGymLockReticle(canvasCtx, targetX, targetY, targetRadius, false);

        if (appState.isWorkoutActive) {
          analyzePoseLandmarks(landmarks);
        }
      } else {
        // BYSTANDER / PASSERBY DETECTED!
        gymShield.filteredPasserbyCount++;
        anchor.occlusionFrames++;

        // Draw passerby skeleton in faint dashed grey (shield filtered)
        drawConnections(canvasCtx, landmarks, POSE_CONNECTIONS, { color: 'rgba(156, 163, 175, 0.45)', lineWidth: 2 });
        drawLandmarks(canvasCtx, landmarks, { color: 'rgba(156, 163, 175, 0.5)', fillColor: 'rgba(156, 163, 175, 0.5)', radius: 3 });

        if (anchor.occlusionFrames <= gymShield.maxOcclusionGraceFrames) {
          // Grace period: Hold rep state, do not interrupt workout!
          updateGymShieldBadge('HOLDING');
          const lastTargetX = anchor.centerX * canvasElement.width;
          const lastTargetY = anchor.centerY * canvasElement.height;
          const lastRadius = Math.max(38, anchor.torsoHeight * canvasElement.height * 0.48);
          drawGymLockReticle(canvasCtx, lastTargetX, lastTargetY, lastRadius, true);
        } else {
          // Lifter left gym zone, reset and re-lock
          resetGymSubjectLock();
        }
      }
    }
  } else {
    // No landmarks visible (passerby walked directly in front occluding lifter)
    if (gymShield.anchor && gymShield.anchor.isLocked) {
      gymShield.anchor.occlusionFrames++;
      if (gymShield.anchor.occlusionFrames <= gymShield.maxOcclusionGraceFrames) {
        updateGymShieldBadge('HOLDING');
        const lastTargetX = gymShield.anchor.centerX * canvasElement.width;
        const lastTargetY = gymShield.anchor.centerY * canvasElement.height;
        const lastRadius = Math.max(38, gymShield.anchor.torsoHeight * canvasElement.height * 0.48);
        drawGymLockReticle(canvasCtx, lastTargetX, lastTargetY, lastRadius, true);
      } else {
        resetGymSubjectLock();
      }
    } else {
      updateGymShieldBadge('SEARCHING');
    }
  }

  canvasCtx.restore();
}

// Form & Rep Analysis Pipeline
function analyzePoseLandmarks(landmarks) {
  if (!landmarks || landmarks.length < 28) return;

  switch (appState.currentWorkoutType) {
    case 'SQUAT':
      checkSquatForm(landmarks);
      break;
    case 'DEADLIFT':
      checkDeadliftForm(landmarks);
      break;
    case 'PULL_UP':
    case 'CHIN_UP':
      checkPullUpForm(landmarks);
      break;
    case 'RUNNING':
      checkRunningCadence(landmarks);
      break;
    case 'BICEP_CURL':
      checkBicepCurlForm(landmarks);
      break;
    case 'LUNGE':
      checkLungeForm(landmarks);
      break;
    case 'PLANK':
      checkPlankForm(landmarks);
      break;
    case 'BENCH_PRESS':
    case 'CHEST_PRESS':
      checkBenchPressForm(landmarks);
      break;
    case 'SHOULDER_PRESS':
      checkShoulderPressForm(landmarks);
      break;
    case 'LEG_PRESS':
    case 'LEG_EXTENSION':
    case 'LEG_CURL':
      checkLegPressForm(landmarks);
      break;
    case 'LAT_PULLDOWN':
    case 'SEATED_ROW':
    case 'TRICEPS_PUSHDOWN':
      checkLatPulldownForm(landmarks);
      break;
    case 'PUSH_UP':
    default:
      checkPushupForm(landmarks);
      break;
  }
}

// 1. Push-ups State Machine & Form Check
function checkPushupForm(landmarks) {
  const joints = getActiveJoints(landmarks);
  if (!joints || !joints.shoulder || !joints.elbow || !joints.wrist || !joints.hip || !joints.knee) return;

  const elbowAngle = getAngle(joints.shoulder, joints.elbow, joints.wrist);
  const hipAngle = getAngle(joints.shoulder, joints.hip, joints.knee);

  document.getElementById('primaryAngleName').innerText = "Elbow Angle:";
  document.getElementById('primaryAngleVal').innerText = `${Math.round(elbowAngle)}°`;
  document.getElementById('hipAngleVal').innerText = `${Math.round(hipAngle)}°`;

  if (elbowAngle < 95) {
    if (appState.workoutState === 'up' || appState.workoutState === 'ready') {
      appState.workoutState = 'down';
      updateWorkoutStateBadge('DOWN (FLEX)');
    }
  } else if (elbowAngle > 155) {
    if (appState.workoutState === 'down') {
      appState.repCount++;
      appState.workoutState = 'up';
      updateWorkoutStateBadge('UP (LOCKED)');
      updateRepCounterUI();
      triggerGoodRep("Good push-up!");
    }
  }

  let feedback = "GOOD_FORM";
  if (hipAngle < 145) {
    feedback = "HIPS_LOW";
  } else if (hipAngle > 195) {
    feedback = "HIPS_HIGH";
  }

  handleAiFeedback(feedback, {
    HIPS_LOW: "Lift your hips!",
    HIPS_HIGH: "Lower your hips!",
    GOOD_FORM: "Great form!"
  });
}

// 2. Squats State Machine & Form Check
function checkSquatForm(landmarks) {
  const joints = getActiveJoints(landmarks);
  if (!joints || !joints.shoulder || !joints.hip || !joints.knee || !joints.ankle) return;

  const kneeAngle = getAngle(joints.hip, joints.knee, joints.ankle);
  const hipAngle = getAngle(joints.shoulder, joints.hip, joints.knee);

  document.getElementById('primaryAngleName').innerText = "Knee Angle:";
  document.getElementById('primaryAngleVal').innerText = `${Math.round(kneeAngle)}°`;
  document.getElementById('hipAngleVal').innerText = `${Math.round(hipAngle)}°`;

  if (kneeAngle < 105 && hipAngle < 115) {
    if (appState.workoutState === 'up' || appState.workoutState === 'ready') {
      appState.workoutState = 'down';
      updateWorkoutStateBadge('DOWN (DEEP SQUAT)');
    }
  } else if (kneeAngle > 155 && hipAngle > 155) {
    if (appState.workoutState === 'down') {
      appState.repCount++;
      appState.workoutState = 'up';
      updateWorkoutStateBadge('UP (STANDING)');
      updateRepCounterUI();
      triggerGoodRep("Great squat depth!");
    }
  }

  let feedback = "GOOD_FORM";
  if (appState.workoutState === 'down' && hipAngle < 75) {
    feedback = "CHEST_UP";
  }

  handleAiFeedback(feedback, {
    CHEST_UP: "Keep your chest up!",
    GOOD_FORM: "Great form!"
  });
}

// 3. Deadlift State Machine & Hip Hinge Check
function checkDeadliftForm(landmarks) {
  const joints = getActiveJoints(landmarks);
  if (!joints || !joints.shoulder || !joints.hip || !joints.knee || !joints.ankle) return;

  const hipAngle = getAngle(joints.shoulder, joints.hip, joints.knee);
  const kneeAngle = getAngle(joints.hip, joints.knee, joints.ankle);

  document.getElementById('primaryAngleName').innerText = "Hip Hinge:";
  document.getElementById('primaryAngleVal').innerText = `${Math.round(hipAngle)}°`;
  document.getElementById('hipAngleVal').innerText = `${Math.round(kneeAngle)}°`;

  if (hipAngle < 115 && kneeAngle < 125) {
    if (appState.workoutState === 'ready' || appState.workoutState === 'up') {
      appState.workoutState = 'down';
      updateWorkoutStateBadge('DOWN (HINGE)');
    }
  } else if (hipAngle > 165 && kneeAngle > 165) {
    if (appState.workoutState === 'down') {
      appState.repCount++;
      appState.workoutState = 'up';
      updateWorkoutStateBadge('UP (LOCKOUT)');
      updateRepCounterUI();
      triggerGoodRep("Solid deadlift lockout!");
    }
  }

  let feedback = "GOOD_FORM";
  if (appState.workoutState === 'down' && hipAngle < 85 && kneeAngle > 140) {
    feedback = "HIPS_FAST";
  } else if (appState.workoutState === 'up' && Math.abs(joints.shoulder.x - joints.hip.x) > 0.08) {
    feedback = "HYPEREXTEND";
  }

  handleAiFeedback(feedback, {
    HIPS_FAST: "Hips rising too fast! Drive chest up.",
    HYPEREXTEND: "Don't hyperextend lower back at lockout!",
    GOOD_FORM: "Great form!"
  });
}

// 4. Pull-up & Chin-up State Machine
function checkPullUpForm(landmarks) {
  const joints = getActiveJoints(landmarks);
  if (!joints || !joints.shoulder || !joints.elbow || !joints.wrist) return;

  const elbowAngle = getAngle(joints.shoulder, joints.elbow, joints.wrist);
  const nose = joints.nose;
  const wrist = joints.wrist;

  document.getElementById('primaryAngleName').innerText = "Elbow Flex:";
  document.getElementById('primaryAngleVal').innerText = `${Math.round(elbowAngle)}°`;
  document.getElementById('hipAngleVal').innerText = `${Math.round(elbowAngle)}°`;

  const isChinOverBar = nose && wrist && (nose.y < wrist.y);
  if (elbowAngle < 75 || (isChinOverBar && elbowAngle < 90)) {
    if (appState.workoutState === 'ready' || appState.workoutState === 'down') {
      appState.workoutState = 'up';
      updateWorkoutStateBadge('UP (CHIN OVER)');
    }
  } else if (elbowAngle > 155) {
    if (appState.workoutState === 'up') {
      appState.repCount++;
      appState.workoutState = 'down';
      updateWorkoutStateBadge('DOWN (DEAD HANG)');
      updateRepCounterUI();
      triggerGoodRep("Great pull-up! Full extension.");
    }
  }

  let feedback = "GOOD_FORM";
  if (appState.workoutState === 'up' && elbowAngle > 85 && elbowAngle < 140) {
    feedback = "DEAD_HANG";
  }

  handleAiFeedback(feedback, {
    DEAD_HANG: "Lower all the way to dead hang!",
    GOOD_FORM: "Great form!"
  });
}

// 5. Bicep Curl State Machine
function checkBicepCurlForm(landmarks) {
  const joints = getActiveJoints(landmarks);
  if (!joints || !joints.shoulder || !joints.elbow || !joints.wrist || !joints.hip) return;

  const elbowAngle = getAngle(joints.shoulder, joints.elbow, joints.wrist);
  const upperArmSwing = getAngle(joints.hip, joints.shoulder, joints.elbow);

  document.getElementById('primaryAngleName').innerText = "Elbow Angle:";
  document.getElementById('primaryAngleVal').innerText = `${Math.round(elbowAngle)}°`;
  document.getElementById('hipAngleVal').innerText = `${Math.round(upperArmSwing)}°`;

  if (elbowAngle < 65) {
    if (appState.workoutState === 'ready' || appState.workoutState === 'down') {
      appState.workoutState = 'up';
      updateWorkoutStateBadge('UP (PEAK SQUEEZE)');
    }
  } else if (elbowAngle > 145) {
    if (appState.workoutState === 'up') {
      appState.repCount++;
      appState.workoutState = 'down';
      updateWorkoutStateBadge('DOWN (EXTENDED)');
      updateRepCounterUI();
      triggerGoodRep("Great bicep squeeze!");
    }
  }

  let feedback = "GOOD_FORM";
  if (upperArmSwing > 35) {
    feedback = "PIN_ELBOWS";
  }

  handleAiFeedback(feedback, {
    PIN_ELBOWS: "Keep elbows pinned to your sides!",
    GOOD_FORM: "Great form!"
  });
}

// 6. Lunge State Machine
function checkLungeForm(landmarks) {
  const joints = getActiveJoints(landmarks);
  if (!joints || !joints.shoulder || !joints.hip || !joints.knee || !joints.ankle) return;

  const kneeAngle = getAngle(joints.hip, joints.knee, joints.ankle);
  const torsoAngle = getAngle(joints.shoulder, joints.hip, joints.knee);

  document.getElementById('primaryAngleName').innerText = "Knee Angle:";
  document.getElementById('primaryAngleVal').innerText = `${Math.round(kneeAngle)}°`;
  document.getElementById('hipAngleVal').innerText = `${Math.round(torsoAngle)}°`;

  if (kneeAngle < 100) {
    if (appState.workoutState === 'ready' || appState.workoutState === 'up') {
      appState.workoutState = 'down';
      updateWorkoutStateBadge('DOWN (DEEP LUNGE)');
    }
  } else if (kneeAngle > 155) {
    if (appState.workoutState === 'down') {
      appState.repCount++;
      appState.workoutState = 'up';
      updateWorkoutStateBadge('UP (STANDING)');
      updateRepCounterUI();
      triggerGoodRep("Strong lunge!");
    }
  }

  let feedback = "GOOD_FORM";
  if (appState.workoutState === 'down' && torsoAngle < 85) {
    feedback = "TORSO_UP";
  }

  handleAiFeedback(feedback, {
    TORSO_UP: "Keep your upper body upright!",
    GOOD_FORM: "Great form!"
  });
}

// 7. Plank Hold Timer & Spine Check
function checkPlankForm(landmarks) {
  const joints = getActiveJoints(landmarks);
  if (!joints || !joints.shoulder || !joints.hip || !joints.ankle) return;

  const bodyLineAngle = getAngle(joints.shoulder, joints.hip, joints.ankle);
  const now = Date.now();

  document.getElementById('primaryAngleName').innerText = "Spine Angle:";
  document.getElementById('primaryAngleVal').innerText = `${Math.round(bodyLineAngle)}°`;
  document.getElementById('hipAngleVal').innerText = `${appState.repCount}s`;

  if (bodyLineAngle >= 150 && bodyLineAngle <= 195) {
    updateWorkoutStateBadge('HOLDING PLANK');
    if (!appState.lastPlankTick || (now - appState.lastPlankTick >= 1000)) {
      appState.lastPlankTick = now;
      appState.repCount++;
      updateRepCounterUI();
      if (appState.repCount > 0 && appState.repCount % 10 === 0) {
        speak(`${appState.repCount} seconds hold! Stay tight!`);
        triggerNativeHaptic('impact');
      }
    }
    handleAiFeedback("GOOD_FORM", { GOOD_FORM: "Great plank hold!" });
  } else {
    updateWorkoutStateBadge(bodyLineAngle < 150 ? 'HIPS SAGGING' : 'HIPS TOO HIGH');
    const key = bodyLineAngle < 150 ? "HIPS_LOW" : "HIPS_HIGH";
    handleAiFeedback(key, {
      HIPS_LOW: "Hips are sagging! Lift your hips.",
      HIPS_HIGH: "Hips are too high! Lower to a straight line."
    });
  }
}

// 8. Running Cadence & Step Tracker
function checkRunningCadence(landmarks) {
  const leftAnkle = landmarks[27];
  const rightAnkle = landmarks[28];
  const joints = getActiveJoints(landmarks);
  if (!leftAnkle || !rightAnkle || !joints) return;

  const now = Date.now();
  const leadingFoot = leftAnkle.y > rightAnkle.y ? "LEFT" : "RIGHT";

  if (leadingFoot !== appState.lastLeadingFoot && (!appState.lastStepTime || (now - appState.lastStepTime > 220))) {
    appState.repCount++;
    if (appState.lastStepTime > 0) {
      const interval = now - appState.lastStepTime;
      const instantSpm = Math.round(60000 / interval);
      appState.runningCadenceSpm = Math.max(120, Math.min(220, instantSpm));
    }
    appState.lastStepTime = now;
    appState.lastLeadingFoot = leadingFoot;
    updateRepCounterUI();
    triggerNativeHaptic('impact');
  }

  document.getElementById('primaryAngleName').innerText = "Cadence:";
  document.getElementById('primaryAngleVal').innerText = `${appState.runningCadenceSpm || 165} SPM`;
  document.getElementById('hipAngleVal').innerText = `${appState.repCount} Steps`;
  updateWorkoutStateBadge(`${appState.runningCadenceSpm || 165} SPM`);

  let feedback = "GOOD_FORM";
  if ((appState.runningCadenceSpm || 165) < 155) {
    feedback = "LOW_CADENCE";
  }

  handleAiFeedback(feedback, {
    LOW_CADENCE: "Increase cadence! Aim for 170+ SPM.",
    GOOD_FORM: "Great running rhythm!"
  });
}

// 9. Bench Press & Chest Press
function checkBenchPressForm(landmarks) {
  const joints = getActiveJoints(landmarks);
  if (!joints || !joints.shoulder || !joints.elbow || !joints.wrist) return;

  const elbowAngle = getAngle(joints.shoulder, joints.elbow, joints.wrist);

  document.getElementById('primaryAngleName').innerText = "Elbow Angle:";
  document.getElementById('primaryAngleVal').innerText = `${Math.round(elbowAngle)}°`;
  document.getElementById('hipAngleVal').innerText = `180°`;

  if (elbowAngle < 90) {
    if (appState.workoutState === 'ready' || appState.workoutState === 'up') {
      appState.workoutState = 'down';
      updateWorkoutStateBadge('DOWN (TOUCH CHEST)');
    }
  } else if (elbowAngle > 155) {
    if (appState.workoutState === 'down') {
      appState.repCount++;
      appState.workoutState = 'up';
      updateWorkoutStateBadge('UP (LOCKOUT)');
      updateRepCounterUI();
      triggerGoodRep("Clean press!");
    }
  }

  handleAiFeedback("GOOD_FORM", { GOOD_FORM: "Solid bar path!" });
}

// 10. Shoulder Press
function checkShoulderPressForm(landmarks) {
  const joints = getActiveJoints(landmarks);
  if (!joints || !joints.shoulder || !joints.elbow || !joints.wrist) return;

  const elbowAngle = getAngle(joints.shoulder, joints.elbow, joints.wrist);

  document.getElementById('primaryAngleName').innerText = "Elbow Angle:";
  document.getElementById('primaryAngleVal').innerText = `${Math.round(elbowAngle)}°`;
  document.getElementById('hipAngleVal').innerText = `180°`;

  if (elbowAngle < 95) {
    if (appState.workoutState === 'ready' || appState.workoutState === 'up') {
      appState.workoutState = 'down';
      updateWorkoutStateBadge('DOWN (SHOULDERS)');
    }
  } else if (elbowAngle > 155) {
    if (appState.workoutState === 'down') {
      appState.repCount++;
      appState.workoutState = 'up';
      updateWorkoutStateBadge('UP (OVERHEAD)');
      updateRepCounterUI();
      triggerGoodRep("Great overhead push!");
    }
  }

  handleAiFeedback("GOOD_FORM", { GOOD_FORM: "Great overhead drive!" });
}

// 11. Leg Press, Extension & Curl
function checkLegPressForm(landmarks) {
  const joints = getActiveJoints(landmarks);
  if (!joints || !joints.hip || !joints.knee || !joints.ankle) return;

  const kneeAngle = getAngle(joints.hip, joints.knee, joints.ankle);

  document.getElementById('primaryAngleName').innerText = "Knee Angle:";
  document.getElementById('primaryAngleVal').innerText = `${Math.round(kneeAngle)}°`;
  document.getElementById('hipAngleVal').innerText = `180°`;

  if (kneeAngle < 100) {
    if (appState.workoutState === 'ready' || appState.workoutState === 'up') {
      appState.workoutState = 'down';
      updateWorkoutStateBadge('DOWN (FLEXED)');
    }
  } else if (kneeAngle > 155) {
    if (appState.workoutState === 'down') {
      appState.repCount++;
      appState.workoutState = 'up';
      updateWorkoutStateBadge('UP (DRIVE)');
      updateRepCounterUI();
      triggerGoodRep("Great leg drive!");
    }
  }

  let feedback = "GOOD_FORM";
  if (kneeAngle > 175) {
    feedback = "NO_LOCKOUT";
  }

  handleAiFeedback(feedback, {
    NO_LOCKOUT: "Do not hyperextend or lock knees!",
    GOOD_FORM: "Smooth knee drive!"
  });
}

// 12. Lat Pulldown, Row & Triceps
function checkLatPulldownForm(landmarks) {
  const joints = getActiveJoints(landmarks);
  if (!joints || !joints.shoulder || !joints.elbow || !joints.wrist) return;

  const elbowAngle = getAngle(joints.shoulder, joints.elbow, joints.wrist);

  document.getElementById('primaryAngleName').innerText = "Pull Angle:";
  document.getElementById('primaryAngleVal').innerText = `${Math.round(elbowAngle)}°`;
  document.getElementById('hipAngleVal').innerText = `180°`;

  if (elbowAngle < 85) {
    if (appState.workoutState === 'ready' || appState.workoutState === 'up') {
      appState.workoutState = 'down';
      updateWorkoutStateBadge('DOWN (CONTRACTED)');
    }
  } else if (elbowAngle > 155) {
    if (appState.workoutState === 'down') {
      appState.repCount++;
      appState.workoutState = 'up';
      updateWorkoutStateBadge('UP (FULL STRETCH)');
      updateRepCounterUI();
      triggerGoodRep("Great contraction!");
    }
  }

  handleAiFeedback("GOOD_FORM", { GOOD_FORM: "Great lats squeeze!" });
}

// Real-time Feedback & Generative AI Fallback Engine
// ========================================================
// ON-DEVICE COGNITIVE ENGINE (GEMMA AI REASONING MATRIX)
// Comprehensive biomechanical knowledge base for all 12 exercises
// ========================================================
const COGNITIVE_REASONING_KNOWLEDGE_BASE = {
  PUSH_UP: {
    HIPS_LOW: "Gemma AI: Your hips are sagging below the spine. Squeeze your glutes and brace your core tight to maintain an unbroken straight line from shoulders to heels.",
    HIPS_HIGH: "Gemma AI: Your hips are piking upward into a triangle. Lower your pelvis level with your shoulders so your chest takes the full load.",
    CHEST_LOW: "Gemma AI: Descend deeper until elbows reach a 90-degree angle for full pectoral and tricep stimulation.",
    GOOD_FORM: "Gemma AI: Exceptional push-up mechanics! Plank alignment and joint stability are optimal."
  },
  SQUAT: {
    CHEST_UP: "Gemma AI: You are leaning too far forward. Drive your chest high and sit back into your hips to transfer load through your quads and glutes, sparing your lower back.",
    KNEE_CAVE: "Gemma AI: Valgus knee collapse detected. Actively drive your knees outward over your mid-toes to protect your ligaments.",
    NOT_DEEP_ENOUGH: "Gemma AI: Squat depth is too shallow. Lower your hip crease until it dips level with the top of your knees.",
    GOOD_FORM: "Gemma AI: Textbook squat depth and vertical spine path! Excellent quad activation."
  },
  DEADLIFT: {
    HIPS_FAST: "Gemma AI: Your hips are shooting up before the bar clears your knees. Push through the mid-foot and keep your back angle uniform.",
    HYPEREXTEND: "Gemma AI: Hyperextension at lockout. Finish standing tall with locked glutes without arching your lumbar spine.",
    GOOD_FORM: "Gemma AI: Powerful hip hinge with neutral cervical spine! High glute and hamstring power."
  },
  PULL_UP: {
    DEAD_HANG: "Gemma AI: Incomplete descent. Lower all the way to a full dead hang to engage the full kinetic chain of your lats.",
    INCOMPLETE_PULL: "Gemma AI: Drive your elbows into your back pockets to bring your chin completely over the bar.",
    GOOD_FORM: "Gemma AI: Clean, smooth vertical pull with complete range of motion!"
  },
  CHIN_UP: {
    DEAD_HANG: "Gemma AI: Lower down to full elbow extension to maximize bicep and lats stretch.",
    INCOMPLETE_PULL: "Gemma AI: Pull your chin clearly over the bar at the summit of each repetition.",
    GOOD_FORM: "Gemma AI: Strict supinated pull with outstanding arm and back engagement!"
  },
  BICEP_CURL: {
    PIN_ELBOWS: "Gemma AI: Elbow drift detected. Pin your elbows tight against your ribs to stop shoulder momentum from robbing your biceps.",
    INCOMPLETE_CURL: "Gemma AI: Squeeze hard at the peak contraction and control a full 2-second eccentric descent.",
    GOOD_FORM: "Gemma AI: Strict biceps isolation with zero compensatory torso swing!"
  },
  LUNGE: {
    TORSO_UP: "Gemma AI: Your torso is tilting forward. Keep your chest vertical and distribute body weight evenly through both legs.",
    KNEE_OVER_TOES: "Gemma AI: Front knee is tracking too far forward. Take a slightly wider stride so your shin stays perpendicular to the floor.",
    GOOD_FORM: "Gemma AI: Superb knee and ankle tracking with vertical posture!"
  },
  PLANK: {
    HIPS_LOW: "Gemma AI: Lumbar hyperextension detected. Pull your navel toward your spine and squeeze your glutes tight to restore a straight diagonal line.",
    HIPS_HIGH: "Gemma AI: Piked hips reduce core tension. Drop your pelvis to shoulder level and press the ground away through your forearms.",
    GOOD_FORM: "Gemma AI: Rock-solid isometric bracing! Core and glutes are fully engaged."
  },
  RUNNING: {
    LOW_CADENCE: "Gemma AI: Cadence dropped below optimal. Shorten your stride and aim for 170 to 180 steps per minute to reduce ground impact stress.",
    GOOD_FORM: "Gemma AI: Quick, springy foot strikes with efficient cadence!"
  },
  BENCH_PRESS: {
    ELBOWS_FLARING: "Gemma AI: Elbows are flared wide. Angle your elbows roughly 45 degrees to your torso to protect your shoulders.",
    GOOD_FORM: "Gemma AI: Stable scapular retraction with a clean bar path!"
  },
  SHOULDER_PRESS: {
    ARCHED_BACK: "Gemma AI: Lumbar arching under overhead weight. Squeeze your glutes tightly and lock your ribcage down to press overhead safely.",
    GOOD_FORM: "Gemma AI: Symmetrical overhead drive with full elbow lockout!"
  },
  LEG_PRESS: {
    NO_LOCKOUT: "Gemma AI: Avoid violently locking your knees. Keep a soft micro-bend at the top to keep tension in the quadriceps.",
    GOOD_FORM: "Gemma AI: Controlled descent with powerful quad extension!"
  },
  LAT_PULLDOWN: {
    LEAN_BACK: "Gemma AI: Excessive torso swing. Maintain a slight 10-degree lean and pull directly through your elbows.",
    GOOD_FORM: "Gemma AI: Deep scapular pull with powerful lat contraction!"
  }
};

// Real-time Feedback & Dual-AI Engine (Reflex + Cognitive)
function handleAiFeedback(feedbackKey, library) {
  const now = Date.now();

  if (feedbackKey === 'GOOD_FORM') {
    if (now - (appState.lastReflexTime || 0) > 6000 && !appState.isAiThinking) {
      setAiFeedback("Great posture! Maintain steady breathing.", 'normal');
    }
    return;
  }

  // Reflex Engine: Immediate warning + haptic (2.5-sec debounce)
  if (now - (appState.lastReflexTime || 0) > 2500) {
    appState.lastReflexTime = now;
    const reflexMsg = (library && library[feedbackKey]) || feedbackKey || "Watch your form!";
    setAiFeedback(reflexMsg, 'warning');
    triggerNativeHaptic('warning');
    appState.formDeductions++;

    // Cognitive Engine (Gemma AI): Synthesize deep biomechanical cues in background
    if (appState.isGenerativeAiEnabled && (now - (appState.lastCognitiveTime || 0) > 3500)) {
      triggerGenerativeAiReasoning(feedbackKey);
    } else {
      speak(reflexMsg);
    }
  }
}

function triggerGenerativeAiReasoning(feedbackKey) {
  if (appState.isAiThinking) return;
  appState.isAiThinking = true;
  appState.lastCognitiveTime = Date.now();

  const thinkingElem = document.getElementById('aiThinkingIndicator');
  if (thinkingElem) thinkingElem.style.display = 'flex';

  setTimeout(() => {
    const workout = appState.currentWorkoutType || 'PUSH_UP';
    const exerciseDict = COGNITIVE_REASONING_KNOWLEDGE_BASE[workout] || COGNITIVE_REASONING_KNOWLEDGE_BASE['PUSH_UP'];
    let advice = exerciseDict[feedbackKey] || exerciseDict['HIPS_LOW'] || "Gemma AI: Focus on maintaining core tension, rhythmic breathing, and joint alignment.";

    // Multi-modal wearable integration: inject heart rate / fatigue telemetry
    if (appState.watchHeartRate > 140 && appState.repCount >= 3) {
      advice += ` Watch HR: ${appState.watchHeartRate} BPM — control your breathing!`;
    }

    if (thinkingElem) thinkingElem.style.display = 'none';
    setAiFeedback(advice, 'genai');
    speak(advice);
    appState.isAiThinking = false;
  }, 750);
}

function triggerMilestoneCognitiveCoaching() {
  const workoutConfig = EXERCISE_CONFIG[appState.currentWorkoutType] || EXERCISE_CONFIG['PUSH_UP'];
  const bpm = appState.watchHeartRate || 128;
  const reps = appState.repCount;
  const advice = `Gemma AI: ${reps} ${workoutConfig.name} reps logged at ${bpm} BPM! Excellent pace — keep your core tight!`;

  setAiFeedback(advice, 'genai');
  speak(advice);
}

function triggerGoodRep(spokenText) {
  const config = EXERCISE_CONFIG[appState.currentWorkoutType] || EXERCISE_CONFIG['PUSH_UP'];
  const unit = config.unit || 'reps';
  triggerNativeHaptic('success');
  setAiFeedback(`${unit === 'sec' ? 'Hold' : 'Rep'} ${appState.repCount} complete! 👏`, 'success');
  appState.watchHeartRate = Math.min(160, appState.watchHeartRate + 2);
  updateLiveBiometrics();

  // Milestone Cognitive Reasoning every 5 reps
  if (appState.isGenerativeAiEnabled && appState.repCount > 0 && appState.repCount % 5 === 0) {
    triggerMilestoneCognitiveCoaching();
  } else {
    const speech = spokenText || "Great form!";
    speak(speech);
  }
}

function setAiFeedback(text, type = 'normal') {
  const elem = document.getElementById('aiFeedbackText');
  const icon = document.getElementById('feedbackIcon');
  if (!elem) return;

  elem.innerText = text;
  if (type === 'warning') {
    icon.innerText = '⚠️';
    elem.style.color = '#FF9500';
  } else if (type === 'genai') {
    icon.innerText = '✨';
    elem.style.color = '#D0BCFF';
  } else if (type === 'success') {
    icon.innerText = '✅';
    elem.style.color = '#A4FF2E';
  } else {
    icon.innerText = '💡';
    elem.style.color = '#FFFFFF';
  }
}

function updateWorkoutStateBadge(text) {
  const badge = document.getElementById('stateText');
  if (badge) badge.innerText = text;
}

function updateRepCounterUI() {
  const repElem = document.getElementById('camRepCount');
  if (repElem) {
    repElem.innerText = appState.repCount;
    repElem.style.transform = 'scale(1.3)';
    setTimeout(() => { repElem.style.transform = 'scale(1)'; }, 200);
  }
}

// ========================================================
// 4. TEST SIMULATOR (Instant testing without webcam)
// ========================================================
function simulateRep(type = 'perfect') {
  if (!appState.isWorkoutActive) return;

  if (type === 'hip_low') {
    handleAiFeedback('HIPS_LOW', { HIPS_LOW: "Lift your hips!" });
    if (appState.isGenerativeAiEnabled) {
      triggerGenerativeAiReasoning('HIPS_LOW');
    }
    return;
  }
  if (type === 'hip_high') {
    handleAiFeedback('HIPS_HIGH', { HIPS_HIGH: "Lower your hips!" });
    if (appState.isGenerativeAiEnabled) {
      triggerGenerativeAiReasoning('HIPS_HIGH');
    }
    return;
  }
  if (type === 'chest_lean') {
    handleAiFeedback('CHEST_UP', { CHEST_UP: "Keep your chest up!" });
    if (appState.isGenerativeAiEnabled) {
      triggerGenerativeAiReasoning('CHEST_UP');
    }
    return;
  }

  // Perfect rep sequence
  updateWorkoutStateBadge('DOWN (FLEX)');
  setTimeout(() => {
    appState.repCount++;
    updateWorkoutStateBadge('UP (COMPLETED)');
    updateRepCounterUI();
    const config = EXERCISE_CONFIG[appState.currentWorkoutType] || EXERCISE_CONFIG['PUSH_UP'];
    triggerGoodRep(`Great ${config.name} rep!`);
  }, 600);
}

function toggleAutoSimulation() {
  const btn = document.getElementById('autoSimBtn');
  if (appState.autoSimInterval) {
    clearInterval(appState.autoSimInterval);
    appState.autoSimInterval = null;
    if (btn) {
      btn.innerText = "▶ Auto Run";
      btn.classList.remove('active');
    }
  } else {
    if (btn) {
      btn.innerText = "⏹ Stop Auto";
      btn.classList.add('active');
    }
    let count = 0;
    appState.autoSimInterval = setInterval(() => {
      count++;
      if (count % 3 === 0) {
        simulateRep(appState.currentWorkoutType === 'SQUAT' ? 'chest_lean' : 'hip_low');
      } else {
        simulateRep('perfect');
      }
    }, 2500);
  }
}

// Fallback drawing utilities if MediaPipe drawing utils not loaded
const POSE_CONNECTIONS = [
  [11, 12], [11, 13], [13, 15], [12, 14], [14, 16],
  [11, 23], [12, 24], [23, 24],
  [23, 25], [24, 26], [25, 27], [26, 28]
];

function drawConnections(ctx, landmarks, connections, style) {
  ctx.strokeStyle = style.color || '#007F8B';
  ctx.lineWidth = style.lineWidth || 3;
  ctx.beginPath();
  for (const [start, end] of connections) {
    const p1 = landmarks[start];
    const p2 = landmarks[end];
    if (p1 && p2 && p1.visibility > 0.4 && p2.visibility > 0.4) {
      ctx.moveTo(p1.x * ctx.canvas.width, p1.y * ctx.canvas.height);
      ctx.lineTo(p2.x * ctx.canvas.width, p2.y * ctx.canvas.height);
    }
  }
  ctx.stroke();
}

function drawLandmarks(ctx, landmarks, style) {
  ctx.fillStyle = style.fillColor || '#FFE600';
  for (const p of landmarks) {
    if (p && p.visibility > 0.4) {
      ctx.beginPath();
      ctx.arc(p.x * ctx.canvas.width, p.y * ctx.canvas.height, style.radius || 4, 0, 2 * Math.PI);
      ctx.fill();
    }
  }
}

// ========================================================
// 5. WORKOUT WORKFLOW & MODALS
// ========================================================
function startWorkout(type = 'PUSH_UP') {
  appState.currentWorkoutType = type;
  appState.isWorkoutActive = true;
  appState.repCount = 0;
  appState.formDeductions = 0;
  appState.workoutState = 'ready';
  appState.lastLeadingFoot = null;
  appState.lastStepTime = 0;
  appState.runningCadenceSpm = 165;
  appState.lastPlankTick = 0;

  // Initialize Gym Multi-Person Shield for this session
  resetGymSubjectLock();

  const config = EXERCISE_CONFIG[type] || EXERCISE_CONFIG['PUSH_UP'];

  // Switch to camera screen
  document.querySelectorAll('.screen-view').forEach(s => s.classList.remove('active'));
  document.getElementById('tab-camera-room').classList.add('active');

  // Hide bottom nav while in workout camera room
  const bottomNav = document.getElementById('bottomNav');
  if (bottomNav) bottomNav.style.display = 'none';

  updateRepCounterUI();
  updateWorkoutStateBadge('READY');
  setAiFeedback(`Position camera for ${config.name} coaching!`);

  speak(`Starting ${config.name} session. Get ready!`);

  // Start Camera
  startCamera();
}

function finishWorkout() {
  appState.isWorkoutActive = false;
  if (appState.autoSimInterval) {
    clearInterval(appState.autoSimInterval);
    appState.autoSimInterval = null;
  }
  stopCamera();

  const config = EXERCISE_CONFIG[appState.currentWorkoutType] || EXERCISE_CONFIG['PUSH_UP'];
  const exerciseName = config.name;
  const reps = appState.repCount;
  const score = Math.max(70, 100 - (appState.formDeductions * 4));
  const calories = Math.round(reps * config.calPerRep);

  // Save session
  saveSession({
    exerciseType: exerciseName,
    reps: reps,
    score: score,
    calories: calories,
    avgBpm: appState.watchHeartRate
  });

  // Show summary modal
  document.getElementById('summaryTitle').innerText = `${exerciseName} Complete!`;
  document.getElementById('summaryReps').innerText = `${reps} ${config.unit || 'reps'}`;
  document.getElementById('summaryScore').innerText = `${score}%`;
  document.getElementById('summaryCalories').innerText = calories;
  document.getElementById('summaryAvgBpm').innerText = appState.watchHeartRate;
  document.getElementById('summaryModal').classList.add('active');
}

function closeSummaryModal() {
  document.getElementById('summaryModal').classList.remove('active');
  document.getElementById('bottomNav').style.display = 'flex';
  switchTab('dashboard');
}

// ========================================================
// 6. UI NAVIGATION & TABS
// ========================================================
function switchTab(tabId) {
  if (appState.isWorkoutActive) {
    stopCamera();
    appState.isWorkoutActive = false;
  }

  document.getElementById('bottomNav').style.display = 'flex';

  // Update tabs
  document.querySelectorAll('.screen-view').forEach(s => s.classList.remove('active'));
  const target = document.getElementById(`tab-${tabId}`);
  if (target) target.classList.add('active');

  // Update bottom nav items
  document.querySelectorAll('.nav-item').forEach(item => {
    if (item.getAttribute('data-tab') === tabId) {
      item.classList.add('active');
    } else {
      item.classList.remove('active');
    }
  });

  appState.currentTab = tabId;

  if (tabId === 'dashboard') updateDashboardUI();
  if (tabId === 'profile') updateProfileUI();
  if (tabId === 'history') renderHistoryList();
}

// 7-Day Calendar Renderer (Matching DashboardFragment.kt)
function renderCalendarBar() {
  const container = document.getElementById('calendarBar');
  if (!container) return;

  const now = new Date();
  const dayOfWeek = now.getDay(); // 0 = Sun, 1 = Mon ...
  const currentDayOfMonth = now.getDate();

  // Days list: Mon, Tue, Wed, Thu, Fri, Sat, Sun
  const dayNames = ["M", "T", "W", "T", "F", "S", "S"];
  const startOffset = (dayOfWeek === 0) ? 6 : dayOfWeek - 1; // Mon = index 0

  let html = '';
  for (let i = 0; i < 7; i++) {
    const dayNumber = currentDayOfMonth - startOffset + i;
    const isToday = (i === startOffset);

    html += `
      <div class="calendar-day-item ${isToday ? 'today' : ''}">
        <span class="cal-day-label">${dayNames[i]}</span>
        <div class="cal-date-pill">${dayNumber}</div>
      </div>
    `;
  }
  container.innerHTML = html;

  // Header month
  const monthName = now.toLocaleString('default', { month: 'long', year: 'numeric' });
  const dateElem = document.getElementById('currentDateHeader');
  if (dateElem) dateElem.innerText = monthName;
}

// Daily Challenge Loader (Day of Year mod 5 logic)
function updateDailyChallengeUI() {
  const now = new Date();
  const start = new Date(now.getFullYear(), 0, 0);
  const diff = now - start;
  const oneDay = 1000 * 60 * 60 * 24;
  const dayOfYear = Math.floor(diff / oneDay);

  const challengeIndex = dayOfYear % DEFAULT_CHALLENGES.length;
  const challenge = DEFAULT_CHALLENGES[challengeIndex];

  document.getElementById('challengeTitle').innerText = challenge.title;
  document.getElementById('challengeDesc').innerText = challenge.desc;
  document.getElementById('challengeTarget').innerText = `${challenge.target} ${challenge.type}`;
}

// Dashboard Stats & Goal Progress
function updateDashboardUI() {
  renderCalendarBar();
  updateDailyChallengeUI();

  const sessions = getSavedSessions();
  const totalRepsThisWeek = sessions.reduce((acc, s) => acc + (s.reps || 0), 0);
  const goal = getWeeklyGoal();
  const progressPercent = Math.min(100, Math.round((totalRepsThisWeek / goal) * 100));

  document.getElementById('weeklyProgressFill').style.width = `${progressPercent}%`;
  document.getElementById('currentRepsText').innerHTML = `Current: <strong>${totalRepsThisWeek} reps</strong>`;
  document.getElementById('goalRepsText').innerHTML = `Goal: <strong>${goal} reps</strong>`;
  document.getElementById('goalPercent').innerText = `${progressPercent}%`;
  document.getElementById('repsRemaining').innerText = Math.max(0, goal - totalRepsThisWeek);

  updateLiveBiometrics();
}

function updateLiveBiometrics() {
  const bpm = appState.watchHeartRate;
  const dashBpm = document.getElementById('dashBpm');
  const liveHeartRate = document.getElementById('liveHeartRate');
  const camHeartRate = document.getElementById('camHeartRate');

  if (dashBpm) dashBpm.innerText = `${bpm} BPM`;
  if (liveHeartRate) liveHeartRate.innerText = bpm;
  if (camHeartRate) camHeartRate.innerText = `${bpm} BPM`;
}

// Profile UI
function updateProfileUI() {
  const sessions = getSavedSessions();
  const totalReps = sessions.reduce((acc, s) => acc + (s.reps || 0), 0);
  const totalWorkouts = sessions.length;
  const totalCalories = sessions.reduce((acc, s) => acc + (s.calories || 0), 0);
  const avgAccuracy = sessions.length > 0 
    ? Math.round(sessions.reduce((acc, s) => acc + (s.score || 95), 0) / sessions.length) 
    : 98;

  document.getElementById('totalRepsLifetime').innerText = totalReps;
  document.getElementById('totalWorkoutsLifetime').innerText = totalWorkouts;
  document.getElementById('totalCaloriesLifetime').innerText = totalCalories;
  document.getElementById('avgAccuracyLifetime').innerText = `${avgAccuracy}%`;
}

// History List Renderer
function renderHistoryList(filter = 'ALL') {
  const container = document.getElementById('historyListContainer');
  const emptyNotice = document.getElementById('emptyHistoryNotice');
  if (!container) return;

  const sessions = getSavedSessions();
  let filtered = sessions;
  if (filter !== 'ALL') {
    filtered = sessions.filter(s => s.exerciseType === filter);
  }

  if (filtered.length === 0) {
    container.innerHTML = '';
    if (emptyNotice) emptyNotice.style.display = 'block';
    return;
  }

  if (emptyNotice) emptyNotice.style.display = 'none';

  container.innerHTML = filtered.map(item => {
    const dateObj = new Date(item.date);
    const dateStr = dateObj.toLocaleDateString('en-US', { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' });

    return `
      <div class="history-card">
        <div class="history-info">
          <h4>${item.exerciseType}</h4>
          <span class="history-date">${dateStr}</span>
        </div>
        <div class="history-stats-pill">
          <span class="history-reps">${item.reps} Reps</span>
          <span class="history-score">${item.score}% Form</span>
        </div>
      </div>
    `;
  }).join('');
}

function filterHistory(type) {
  document.querySelectorAll('.filter-pills .pill').forEach(p => {
    if (p.innerText.toLowerCase() === type.toLowerCase()) {
      p.classList.add('active');
    } else {
      p.classList.remove('active');
    }
  });
  renderHistoryList(type);
}

// ========================================================
// 7. MODALS & SETTINGS
// ========================================================
function openGoalModal() {
  document.getElementById('weeklyGoalInput').value = getWeeklyGoal();
  document.getElementById('goalModal').classList.add('active');
}

function closeGoalModal() {
  document.getElementById('goalModal').classList.remove('active');
}

function saveGoalModal() {
  const val = parseInt(document.getElementById('weeklyGoalInput').value, 10) || 200;
  setWeeklyGoal(val);
  closeGoalModal();
}

function openProfileModal() {
  document.getElementById('profileNameInput').value = getUserName();
  document.getElementById('profileModal').classList.add('active');
}

function closeProfileModal() {
  document.getElementById('profileModal').classList.remove('active');
}

function saveProfileModal() {
  const name = document.getElementById('profileNameInput').value.trim() || "Athrava";
  setUserName(name);
  closeProfileModal();
}

// ========================================================
// 8. INITIALIZATION & LISTENERS
// ========================================================
function triggerNativeHaptic(type = 'impact') {
  if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.nativeBridge) {
    try {
      window.webkit.messageHandlers.nativeBridge.postMessage({ action: 'haptic', type: type });
    } catch(e) { /* ignore */ }
  }
}

document.addEventListener('DOMContentLoaded', async () => {
  // Check if running on iOS or inside native wrapper
  if (window.webkit || navigator.userAgent.includes('FitGuru-iOS') || /iPad|iPhone|iPod/.test(navigator.userAgent)) {
    document.body.classList.remove('frame-mode');
    document.body.classList.add('native-ios');
  }

  // Update user name from DB
  setUserName(getUserName());

  // Init Pose Landmarker
  initMediaPipePose();

  // Splash Screen Transition
  setTimeout(() => {
    const splash = document.getElementById('splashScreen');
    if (splash) {
      splash.style.transition = 'opacity 0.5s ease';
      splash.style.opacity = '0';
      setTimeout(() => {
        splash.classList.remove('active');
        switchTab('dashboard');
      }, 500);
    }
  }, 1200);

  // Status Bar Clock
  setInterval(() => {
    const timeElem = document.getElementById('statusTime');
    if (timeElem) {
      const d = new Date();
      timeElem.innerText = `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
    }
  }, 1000);

  // Biometric Heart Rate Simulation Jitter
  setInterval(() => {
    if (appState.isWorkoutActive) {
      const delta = (Math.random() - 0.45) * 2;
      appState.watchHeartRate = Math.round(Math.min(165, Math.max(115, appState.watchHeartRate + delta)));
    } else {
      const delta = (Math.random() - 0.5) * 2;
      appState.watchHeartRate = Math.round(Math.min(85, Math.max(68, appState.watchHeartRate + delta)));
    }
    updateLiveBiometrics();
  }, 2000);

  // Button Listeners
  document.getElementById('closeWorkoutBtn')?.addEventListener('click', finishWorkout);
  document.getElementById('editGoalBtn')?.addEventListener('click', openGoalModal);
  document.getElementById('editProfileNameBtn')?.addEventListener('click', openProfileModal);
  document.getElementById('startChallengeBtn')?.addEventListener('click', () => startWorkout('PUSH_UP'));

  // Toggle Frame vs Fullscreen
  document.getElementById('toggleFrameBtn')?.addEventListener('click', () => {
    const body = document.body;
    const text = document.getElementById('frameText');
    const icon = document.getElementById('frameIcon');

    if (body.classList.contains('frame-mode')) {
      body.classList.remove('frame-mode');
      body.classList.add('fullscreen-mode');
      text.innerText = "Mobile Frame View";
      icon.innerText = "📱";
    } else {
      body.classList.remove('fullscreen-mode');
      body.classList.add('frame-mode');
      text.innerText = "Fullscreen View";
      icon.innerText = "🖥️";
    }
  });

  // Generative AI Coach Toggle
  document.getElementById('toggleGenAiBtn')?.addEventListener('click', function() {
    appState.isGenerativeAiEnabled = !appState.isGenerativeAiEnabled;
    const textElem = document.getElementById('genAiBtnText');
    if (appState.isGenerativeAiEnabled) {
      this.classList.add('active');
      textElem.innerText = "GenAI (ON)";
      speak("Generative AI Coach Activated!");
      setAiFeedback("✨ Cognitive Engine Active: Gemma LLM ready.", "genai");
    } else {
      this.classList.remove('active');
      textElem.innerText = "GenAI (OFF)";
      speak("Reflex Engine Active.");
      setAiFeedback("Reflex Engine Active (Instantaneous rep tracking)", "normal");
    }
  });

  // Audio Voice Coach Toggle
  document.getElementById('toggleTtsBtn')?.addEventListener('click', function() {
    appState.isTtsEnabled = !appState.isTtsEnabled;
    const textElem = document.getElementById('ttsBtnText');
    if (appState.isTtsEnabled) {
      this.classList.add('active');
      textElem.innerText = "Voice: ON";
    } else {
      this.classList.remove('active');
      textElem.innerText = "Voice: OFF";
      window.speechSynthesis.cancel();
    }
  });

  // Switch / Mirror Camera
  document.getElementById('switchCameraBtn')?.addEventListener('click', () => {
    appState.isCameraMirrored = !appState.isCameraMirrored;
    videoElement.style.transform = appState.isCameraMirrored ? 'scaleX(-1)' : 'scaleX(1)';
  });

  // Toggle Simulator Controls
  document.getElementById('toggleSimControls')?.addEventListener('click', () => {
    const group = document.getElementById('simButtonsGroup');
    if (group) {
      group.style.display = (group.style.display === 'none') ? 'grid' : 'none';
    }
  });

  // Clear History
  document.getElementById('clearHistoryBtn')?.addEventListener('click', () => {
    if (confirm("Clear all recorded workout history?")) {
      localStorage.removeItem(DB_KEYS.SESSIONS);
      renderHistoryList();
      updateProfileUI();
      updateDashboardUI();
    }
  });

  // Fetch Server Info & Generate QR Code for Mobile Connect
  try {
    const res = await fetch('/api/info');
    const info = await res.json();
    if (info && info.ipAddresses && info.ipAddresses.length > 0) {
      const wifiIp = info.ipAddresses.find(a => a.name.toLowerCase().includes('wi-fi') || a.name.toLowerCase().includes('wlan')) || info.ipAddresses[0];
      const lanUrl = `http://${wifiIp.ip}:${info.port}`;
      
      const lanUrlElem = document.getElementById('mobileLanUrl');
      if (lanUrlElem) lanUrlElem.innerText = lanUrl;

      const qrElem = document.getElementById('qrcode');
      if (qrElem && typeof QRCode !== 'undefined') {
        qrElem.innerHTML = '';
        new QRCode(qrElem, {
          text: lanUrl,
          width: 140,
          height: 140,
          colorDark: "#000000",
          colorLight: "#ffffff",
          correctLevel: QRCode.CorrectLevel.M
        });
      }
    }
  } catch (e) {
    console.log("Could not load /api/info", e);
  }
});

// ======================================================
// GYM EQUIPMENT GUIDE - Loads from catalog.json
// ======================================================
let gymCatalog = null;

async function loadGymCatalog() {
  try {
    const res = await fetch('assets/gym_catalog.json');
    gymCatalog = await res.json();
    renderGymEquipmentList();
  } catch (e) {
    console.warn('Could not load gym_catalog.json:', e);
  }
}

function mapExIdToWorkoutType(exId) {
  const map = {
    squat:'SQUAT', push_up:'PUSH_UP', bicep_curl:'BICEP_CURL',
    lunge:'LUNGE', plank:'PLANK', bench_press:'BENCH_PRESS',
    shoulder_press:'SHOULDER_PRESS', leg_press:'LEG_PRESS',
    lat_pulldown:'LAT_PULLDOWN', chest_press:'CHEST_PRESS',
    seated_cable_row:'SEATED_ROW', leg_extension:'LEG_EXTENSION',
    leg_curl:'LEG_CURL', triceps_pushdown:'TRICEPS_PUSHDOWN'
  };
  return map[exId] || null;
}

function renderGymEquipmentList() {
  const container = document.getElementById('gymEquipmentList');
  if (!container || !gymCatalog) return;
  let html = '';
  for (const machine of gymCatalog.machines) {
    const exId = machine.exercises && machine.exercises[0];
    const ex = exId && gymCatalog.exercises[exId];
    const muscles = ex && ex.muscles ? ex.muscles.slice(0,2).join(' � ') : machine.id.replace(/_/g,' ');
    const desc = machine.what || (ex && ex.plan) || '';
    const hasCoach = ex && ex.analysis != null;
    const badge = hasCoach ? 'AI COACH' : 'GUIDE';
    html += `<div class="equip-guide-card" onclick="showEquipGuide('${machine.id}')">
      <div class="equip-guide-icon">${machine.icon||'???'}</div>
      <div style="flex:1;min-width:0;">
        <div class="equip-guide-name">${machine.name}</div>
        <div class="equip-guide-muscles">${muscles}</div>
        <div class="equip-guide-desc">${desc}</div>
        <div class="equip-guide-badge">${badge}</div>
      </div>
      <div style="color:#A4FF2E;font-size:18px;align-self:center;">�</div>
    </div>`;
  }
  container.innerHTML = html;
}

function showEquipGuide(machineId) {
  if (!gymCatalog) return;
  const machine = gymCatalog.machines.find(m => m.id === machineId);
  if (!machine) return;
  const exId = machine.exercises && machine.exercises[0];
  const ex = exId ? gymCatalog.exercises[exId] : null;
  document.getElementById('egIcon').textContent = machine.icon || '???';
  document.getElementById('egTitle').textContent = machine.name;
  const muscles = ex && ex.muscles ? ex.muscles.join(', ') : '';
  document.getElementById('egCategory').textContent = muscles || machineId.replace(/_/g,' ');
  document.getElementById('egWhat').textContent = machine.what || '';
  if (ex) {
    document.getElementById('egSetup').textContent = ex.setup ? ex.setup.map((s,i) => (i+1)+'. '+s).join('\n') : '�';
    document.getElementById('egSteps').textContent = ex.steps ? ex.steps.map((s,i) => (i+1)+'. '+s).join('\n') : '�';
    document.getElementById('egMistakes').textContent = ex.mistakes ? ex.mistakes.map(m => '� '+m).join('\n') : '�';
    document.getElementById('egSafety').textContent = ex.safety || '�';
    document.getElementById('egCamera').textContent = (ex.camera && ex.camera.tip) || 'Place phone 2-3m away at joint height.';
    const workoutType = mapExIdToWorkoutType(exId);
    const btn = document.getElementById('egStartBtn');
    if (workoutType && ex.analysis) {
      btn.textContent = '? Start AI Coach � ' + ex.name;
      btn.style.background = '#A4FF2E';
      btn.style.color = '#050505';
      btn.style.display = 'block';
      btn.onclick = function() {
        document.getElementById('equipGuideModal').style.display = 'none';
        startWorkout(workoutType);
      };
    } else {
      btn.textContent = '?? No real-time AI coach for this machine yet';
      btn.style.background = '#27272A';
      btn.style.color = '#94A3B8';
      btn.onclick = null;
    }
  } else {
    document.getElementById('egSetup').textContent = 'Adjust machine to comfortable height.';
    document.getElementById('egSteps').textContent = 'Maintain smooth, controlled movement.';
    document.getElementById('egMistakes').textContent = '� Rushing through reps\n� Improper posture';
    document.getElementById('egSafety').textContent = 'Start lightweight until movement is mastered.';
    document.getElementById('egCamera').textContent = 'Position phone 2-3m away.';
    document.getElementById('egStartBtn').style.display = 'none';
  }
  document.getElementById('equipGuideModal').style.display = 'block';
}

loadGymCatalog();

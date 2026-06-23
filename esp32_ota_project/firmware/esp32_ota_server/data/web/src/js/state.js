/**
 * state.js — Global application state
 */
var otaUnlocked = false;
var otaExpiresAt = 0;
var otaCountdownTimer = null;
var refreshTimer = null;
var currentHbInterval = 0;

// Heartbeat alive detection
var lastTickCount = -1;
var isAlive = true;
var staleCount = 0;
var STALE_THRESHOLD = 3;
var hbFastTimer = null;

// Time-series data for charts (rolling window, max 120 samples ≈ 10 min at 5s)
var MAX_SAMPLES = 120;
var heapHistory = [];
var uptimeHistory = [];
var tickHistory = [];
var timestampHistory = [];
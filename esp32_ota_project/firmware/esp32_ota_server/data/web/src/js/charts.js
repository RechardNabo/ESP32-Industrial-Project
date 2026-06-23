/**
 * charts.js — Lightweight canvas chart rendering
 */
function drawLineChart(canvasId, data, opts) {
  var canvas = document.getElementById(canvasId);
  if (!canvas) return;
  var ctx = canvas.getContext('2d');
  var dpr = window.devicePixelRatio || 1;
  var rect = canvas.getBoundingClientRect();

  canvas.width = rect.width * dpr;
  canvas.height = rect.height * dpr;
  ctx.scale(dpr, dpr);

  var w = rect.width;
  var h = rect.height;
  var pad = { top: 20, right: 16, bottom: 28, left: 52 };
  var plotW = w - pad.left - pad.right;
  var plotH = h - pad.top - pad.bottom;

  ctx.fillStyle = '#12182a';
  ctx.fillRect(0, 0, w, h);

  if (data.length < 2) {
    ctx.fillStyle = '#7a82a0';
    ctx.font = '13px -apple-system, BlinkMacSystemFont, sans-serif';
    ctx.textAlign = 'center';
    ctx.fillText('Collecting data...', w / 2, h / 2);
    return;
  }

  var minVal = opts.minVal !== undefined ? opts.minVal : Math.min.apply(null, data);
  var maxVal = opts.maxVal !== undefined ? opts.maxVal : Math.max.apply(null, data);
  if (maxVal === minVal) { maxVal = minVal + 1; }
  var range = maxVal - minVal;
  var rangePad = range * 0.1;
  var yMin = minVal - rangePad;
  var yMax = maxVal + rangePad;

  function xPos(i) { return pad.left + (i / (data.length - 1)) * plotW; }
  function yPos(v) { return pad.top + plotH - ((v - yMin) / (yMax - yMin)) * plotH; }

  // Grid lines
  ctx.strokeStyle = '#1e2640';
  ctx.lineWidth = 1;
  var gridLines = 5;
  for (var g = 0; g <= gridLines; g++) {
    var gVal = yMin + (yMax - yMin) * (g / gridLines);
    var gy = yPos(gVal);
    ctx.beginPath();
    ctx.moveTo(pad.left, gy);
    ctx.lineTo(pad.left + plotW, gy);
    ctx.stroke();
    ctx.fillStyle = '#7a82a0';
    ctx.font = '10px -apple-system, monospace';
    ctx.textAlign = 'right';
    ctx.fillText(opts.format ? opts.format(gVal) : Math.round(gVal), pad.left - 6, gy + 3);
  }

  // X-axis labels
  if (timestampHistory.length >= 2) {
    var tMin = timestampHistory[0];
    var tMax = timestampHistory[timestampHistory.length - 1];
    var tRange = tMax - tMin;
    var xLabels = 5;
    ctx.font = '10px -apple-system, monospace';
    ctx.fillStyle = '#7a82a0';
    ctx.textAlign = 'center';
    for (var xl = 0; xl <= xLabels; xl++) {
      var t = tMin + tRange * (xl / xLabels);
      var x = pad.left + plotW * (xl / xLabels);
      var ago = Math.round((tMax - t) / 1000);
      ctx.fillText(ago <= 0 ? 'now' : '-' + ago + 's', x, h - 4);
    }
  }

  // Gradient fill
  var grad = ctx.createLinearGradient(0, pad.top, 0, pad.top + plotH);
  grad.addColorStop(0, opts.color + '40');
  grad.addColorStop(1, opts.color + '05');

  ctx.beginPath();
  ctx.moveTo(xPos(0), pad.top + plotH);
  for (var i = 0; i < data.length; i++) {
    ctx.lineTo(xPos(i), yPos(data[i]));
  }
  ctx.lineTo(xPos(data.length - 1), pad.top + plotH);
  ctx.closePath();
  ctx.fillStyle = grad;
  ctx.fill();

  // Line
  ctx.beginPath();
  ctx.moveTo(xPos(0), yPos(data[0]));
  for (var i = 1; i < data.length; i++) {
    ctx.lineTo(xPos(i), yPos(data[i]));
  }
  ctx.strokeStyle = opts.color || '#5b8def';
  ctx.lineWidth = 2;
  ctx.lineJoin = 'round';
  ctx.stroke();

  // Dots
  ctx.fillStyle = opts.color || '#5b8def';
  for (var i = 0; i < data.length; i++) {
    if (data.length <= 30 || i % 3 === 0) {
      ctx.beginPath();
      ctx.arc(xPos(i), yPos(data[i]), 3, 0, Math.PI * 2);
      ctx.fill();
    }
  }

  // Current value label
  var lastVal = data[data.length - 1];
  ctx.fillStyle = opts.color || '#5b8def';
  ctx.font = 'bold 12px -apple-system, monospace';
  ctx.textAlign = 'right';
  ctx.fillText(opts.format ? opts.format(lastVal) : Math.round(lastVal), pad.left + plotW, yPos(lastVal) - 8);

  // Title
  if (opts.label) {
    ctx.fillStyle = '#e4e6ef';
    ctx.font = 'bold 13px -apple-system, BlinkMacSystemFont, sans-serif';
    ctx.textAlign = 'left';
    ctx.fillText(opts.label, pad.left, 14);
  }
}
/**
 * modbus.js — Modbus RTU/TCP Protocol tab logic
 */

// Modbus simulation state
var mbSimData = {
  status: 'Simulating',
  mode: 'RTU',
  baud: 9600,
  slaveCount: 8,
  pollRate: '1000 ms',
  requests: 12487,
  responses: 12391,
  errors: 23,
  timeouts: 73
};

var mbSlaves = [
  { id: 1, type: 'Power Meter', regs: 12, lastPoll: '0.2 s', resp: 'OK' },
  { id: 2, type: 'VFD Drive', regs: 20, lastPoll: '0.3 s', resp: 'OK' },
  { id: 3, type: 'Temperature', regs: 8, lastPoll: '0.1 s', resp: 'OK' },
  { id: 4, type: 'Flow Meter', regs: 6, lastPoll: '0.2 s', resp: 'Timeout' },
  { id: 5, type: 'Pressure XDCR', regs: 4, lastPoll: '0.15 s', resp: 'OK' },
  { id: 6, type: 'Power Analyzer', regs: 24, lastPoll: '0.4 s', resp: 'OK' },
  { id: 7, type: 'UPS Monitor', regs: 16, lastPoll: '0.2 s', resp: 'Error' },
  { id: 8, type: 'HVAC Controller', regs: 32, lastPoll: '0.5 s', resp: 'OK' }
];

var mbRegisters = [
  { addr: 40001, instance: 1, dtype: 'FLOAT32', value: '237.8 V', unit: 'Volts' },
  { addr: 40003, instance: 2, dtype: 'FLOAT32', value: '15.3 A', unit: 'Amps' },
  { addr: 40005, instance: 3, dtype: 'UINT16', value: '3671', unit: 'W' },
  { addr: 40007, instance: 4, dtype: 'FLOAT32', value: '0.87', unit: 'PF' },
  { addr: 40009, instance: 5, dtype: 'FLOAT32', value: '50.00', unit: 'Hz' },
  { addr: 40011, instance: 6, dtype: 'UINT16', value: '28415', unit: 'kWh' },
  { addr: 40013, instance: 7, dtype: 'FLOAT32', value: '24.7 °C', unit: 'Temp' },
  { addr: 40015, instance: 8, dtype: 'FLOAT32', value: '3.45 bar', unit: 'Press' },
  { addr: 40017, instance: 9, dtype: 'UINT16', value: '523', unit: 'RPM' },
  { addr: 40019, instance: 10, dtype: 'FLOAT32', value: '98.2 %', unit: 'RH' }
];

function refreshModbus() {
  var el;
  el = document.getElementById('mb-status');
  if (el) el.textContent = mbSimData.status;
  el = document.getElementById('mb-mode');
  if (el) el.textContent = mbSimData.mode;
  el = document.getElementById('mb-slaves');
  if (el) el.textContent = mbSimData.slaveCount;
  el = document.getElementById('mb-pollrate');
  if (el) el.textContent = mbSimData.pollRate;

  // Increment sim counters
  mbSimData.requests += Math.floor(Math.random() * 5) + 1;
  mbSimData.responses += Math.floor(Math.random() * 5);
  if (Math.random() < 0.02) mbSimData.errors++;
  if (Math.random() < 0.05) mbSimData.timeouts++;

  el = document.getElementById('mb-requests');
  if (el) el.textContent = mbSimData.requests.toLocaleString();
  el = document.getElementById('mb-responses');
  if (el) el.textContent = mbSimData.responses.toLocaleString();
  el = document.getElementById('mb-errors');
  if (el) el.textContent = mbSimData.errors;
  el = document.getElementById('mb-timeout');
  if (el) el.textContent = mbSimData.timeouts;

  // Slave table
  var tbody = document.getElementById('mb-slave-table');
  if (tbody) {
    tbody.innerHTML = '';
    mbSlaves.forEach(function(s) {
      var badge = s.resp === 'OK' ? 'green' : (s.resp === 'Timeout' ? 'orange' : 'red');
      tbody.innerHTML += '<tr><td><code>' + s.id + '</code></td><td>' + s.type +
        '</td><td>' + s.regs + '</td><td>' + s.lastPoll +
        '</td><td><span class="badge ' + badge + '">' + s.resp + '</span></td></tr>';
    });
  }

  // Register table
  tbody = document.getElementById('mb-reg-table');
  if (tbody) {
    tbody.innerHTML = '';
    mbRegisters.forEach(function(r) {
      tbody.innerHTML += '<tr><td><code>' + r.addr + '</code></td><td>' + r.instance +
        '</td><td>' + r.dtype + '</td><td><code>' + r.value +
        '</code></td><td>' + r.unit + '</td></tr>';
    });
  }
}
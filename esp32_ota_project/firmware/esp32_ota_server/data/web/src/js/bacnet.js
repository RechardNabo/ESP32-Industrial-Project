/**
 * bacnet.js — BACnet MS/TP Protocol tab logic
 */

var bnSimData = {
  status: 'Online',
  deviceId: 100,
  baud: '38400',
  maxMaster: 127,
  tokenPass: 5842,
  tokenRecvd: 5839,
  retries: 17,
  lost: 3
};

var bnObjects = [
  { inst: 1, type: 'Analog Input', name: 'AI-1 SupplyTemp', value: '24.7 °C', unit: '°C' },
  { inst: 2, type: 'Analog Input', name: 'AI-2 ReturnTemp', value: '28.3 °C', unit: '°C' },
  { inst: 3, type: 'Analog Input', name: 'AI-3 FlowRate', value: '12.4 L/s', unit: 'L/s' },
  { inst: 4, type: 'Analog Output', name: 'AO-1 ValveCmd', value: '67.2 %', unit: '%' },
  { inst: 5, type: 'Analog Value', name: 'AV-1 Setpoint', value: '22.0 °C', unit: '°C' },
  { inst: 6, type: 'Analog Value', name: 'AV-2 Offset', value: '-0.5 °C', unit: '°C' },
  { inst: 7, type: 'Binary Input', name: 'BI-1 PumpStatus', value: 'ACTIVE', unit: '—' },
  { inst: 8, type: 'Binary Input', name: 'BI-2 Alarm', value: 'NORMAL', unit: '—' },
  { inst: 9, type: 'Binary Output', name: 'BO-1 FanCmd', value: 'ON', unit: '—' },
  { inst: 10, type: 'Binary Value', name: 'BV-1 Override', value: 'INACTIVE', unit: '—' },
  { inst: 11, type: 'Analog Input', name: 'AI-4 Humidity', value: '54.1 %RH', unit: '%RH' },
  { inst: 12, type: 'Analog Output', name: 'AO-2 DamperCmd', value: '45.0 %', unit: '%' }
];

var bnCovSubs = [
  { sub: '192.168.0.50', obj: 'AI-1', prop: 'PresentValue', incr: '0.5 °C', conf: true },
  { sub: '192.168.0.50', obj: 'AI-4', prop: 'PresentValue', incr: '1.0 %', conf: true },
  { sub: '192.168.0.101', obj: 'BV-1', prop: 'PresentValue', incr: '—', conf: false },
  { sub: '192.168.0.102', obj: 'AI-2', prop: 'PresentValue', incr: '0.2 °C', conf: true }
];

function refreshBacnet() {
  var el;
  el = document.getElementById('bn-status');
  if (el) el.textContent = bnSimData.status;
  el = document.getElementById('bn-device-id');
  if (el) el.textContent = bnSimData.deviceId;
  el = document.getElementById('bn-baud');
  if (el) el.textContent = bnSimData.baud;
  el = document.getElementById('bn-max-master');
  if (el) el.textContent = bnSimData.maxMaster;

  // Increment sim counters
  bnSimData.tokenPass += Math.floor(Math.random() * 3) + 1;
  bnSimData.tokenRecvd += Math.floor(Math.random() * 3);
  if (Math.random() < 0.005) bnSimData.retries++;
  if (Math.random() < 0.003) bnSimData.lost++;

  el = document.getElementById('bn-token-pass');
  if (el) el.textContent = bnSimData.tokenPass.toLocaleString();
  el = document.getElementById('bn-token-recvd');
  if (el) el.textContent = bnSimData.tokenRecvd.toLocaleString();
  el = document.getElementById('bn-retries');
  if (el) el.textContent = bnSimData.retries;
  el = document.getElementById('bn-lost');
  if (el) el.textContent = bnSimData.lost;

  // Object table
  var tbody = document.getElementById('bn-object-table');
  if (tbody) {
    tbody.innerHTML = '';
    bnObjects.forEach(function(o) {
      var typeColor = o.type.startsWith('Analog Input') ? 'green' :
                      o.type.startsWith('Analog Output') ? 'blue' :
                      o.type.startsWith('Binary') ? 'orange' : '';
      tbody.innerHTML += '<tr><td>' + o.inst + '</td><td><span class="badge ' + typeColor + '">' + o.type + '</span></td><td>' +
        o.name + '</td><td><code>' + o.value + '</code></td><td>' + o.unit + '</td></tr>';
    });
  }

  // COV table
  tbody = document.getElementById('bn-cov-table');
  if (tbody) {
    tbody.innerHTML = '';
    bnCovSubs.forEach(function(c) {
      tbody.innerHTML += '<tr><td><code>' + c.sub + '</code></td><td>' + c.obj +
        '</td><td>' + c.prop + '</td><td>' + c.incr +
        '</td><td><span class="badge ' + (c.conf ? 'green' : 'orange') + '">' +
        (c.conf ? 'Confirmed' : 'Unconfirmed') + '</span></td></tr>';
    });
  }
}
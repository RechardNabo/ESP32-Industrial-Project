/**
 * snmp.js — SNMP Protocol tab logic
 */

var snSimData = {
  status: 'Listening',
  version: 'v2c',
  community: 'public',
  port: 161,
  getCount: 8432,
  getNextCount: 5210,
  setCount: 147,
  trapCount: 289
};

var snMib = [
  { oid: '1.3.6.1.2.1.1.1.0', inst: 'sysDescr', name: 'System Description', value: 'ESP32 Gateway v1.0.0', type: 'STRING' },
  { oid: '1.3.6.1.2.1.1.2.0', inst: 'sysObjectID', name: 'System Object ID', value: '1.3.6.1.4.1.99999', type: 'OID' },
  { oid: '1.3.6.1.2.1.1.3.0', inst: 'sysUpTime', name: 'System Uptime', value: '—', type: 'Timeticks' },
  { oid: '1.3.6.1.2.1.1.4.0', inst: 'sysContact', name: 'Contact', value: 'admin@building.local', type: 'STRING' },
  { oid: '1.3.6.1.2.1.1.5.0', inst: 'sysName', name: 'System Name', value: 'my-esp32', type: 'STRING' },
  { oid: '1.3.6.1.2.1.1.6.0', inst: 'sysLocation', name: 'Location', value: 'HVAC Plant Room', type: 'STRING' },
  { oid: '1.3.6.1.2.1.2.1.0', inst: 'ifNumber', name: 'Interface Count', value: '1', type: 'INTEGER' },
  { oid: '1.3.6.1.2.1.2.2.1.2.1', inst: 'ifDescr.1', name: 'Interface Name', value: 'WiFi STA', type: 'STRING' },
  { oid: '1.3.6.1.2.1.2.2.1.8.1', inst: 'ifOperStatus.1', name: 'Link Status', value: 'Up(1)', type: 'INTEGER' },
  { oid: '1.3.6.1.2.1.4.1.0', inst: 'ipForwarding', name: 'IP Forwarding', value: 'Disabled(2)', type: 'INTEGER' }
];

var snTraps = [
  { dest: '192.168.0.10', port: 162, ver: 'v2c', comm: 'public', events: 'LinkDown, LinkUp' },
  { dest: '192.168.0.50', port: 162, ver: 'v2c', comm: 'monitor', events: 'ColdStart, AuthFail' },
  { dest: '192.168.0.101', port: 1162, ver: 'v2c', comm: 'public', events: 'All' }
];

function refreshSnmp() {
  var el;
  el = document.getElementById('sn-status');
  if (el) el.textContent = snSimData.status;
  el = document.getElementById('sn-version');
  if (el) el.textContent = snSimData.version;
  el = document.getElementById('sn-community');
  if (el) el.textContent = snSimData.community;
  el = document.getElementById('sn-port');
  if (el) el.textContent = snSimData.port;

  // Increment sim counters
  snSimData.getCount += Math.floor(Math.random() * 3) + 1;
  snSimData.getNextCount += Math.floor(Math.random() * 2);
  if (Math.random() < 0.03) snSimData.setCount++;
  if (Math.random() < 0.01) snSimData.trapCount++;

  el = document.getElementById('sn-get-count');
  if (el) el.textContent = snSimData.getCount.toLocaleString();
  el = document.getElementById('sn-getnext-count');
  if (el) el.textContent = snSimData.getNextCount.toLocaleString();
  el = document.getElementById('sn-set-count');
  if (el) el.textContent = snSimData.setCount;
  el = document.getElementById('sn-trap-count');
  if (el) el.textContent = snSimData.trapCount;

  // MIB table — update sysUpTime dynamically
  if (snMib[2]) {
    var uptimeSec = Math.floor(Date.now() / 1000) - 170000;
    snMib[2].value = fmtUptime(uptimeSec > 0 ? uptimeSec : 0);
  }

  var tbody = document.getElementById('sn-mib-table');
  if (tbody) {
    tbody.innerHTML = '';
    snMib.forEach(function(m) {
      tbody.innerHTML += '<tr><td><code style="font-size:11px">' + m.oid + '</code></td><td>' + m.inst +
        '</td><td>' + m.name + '</td><td><code>' + m.value +
        '</code></td><td><span class="badge blue">' + m.type + '</span></td></tr>';
    });
  }

  // Trap table
  tbody = document.getElementById('sn-trap-table');
  if (tbody) {
    tbody.innerHTML = '';
    snTraps.forEach(function(t) {
      tbody.innerHTML += '<tr><td><code>' + t.dest + '</code></td><td>' + t.port +
        '</td><td>' + t.ver + '</td><td>' + t.comm + '</td><td>' + t.events + '</td></tr>';
    });
  }
}
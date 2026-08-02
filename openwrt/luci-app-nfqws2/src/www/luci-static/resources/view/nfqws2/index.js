'use strict';
'require view';

const CGI = '/cgi-bin/nfqws2.sh';

function nfqws2Rpc(action, params) {
	return new Promise(function(resolve) {
		var xhr = new XMLHttpRequest();
		xhr.open('POST', CGI, true);
		xhr.setRequestHeader('Content-Type', 'application/json');
		xhr.onload = function() {
			try { resolve(JSON.parse(xhr.responseText)); }
			catch(e) { resolve(null); }
		};
		xhr.send(JSON.stringify({ action: action, params: params || {} }));
	});
}

var configFields = [
	{ opt: 'general.enabled', label: 'Enabled', type: 'flag', desc: 'Enable nfqws2 service' },
	{ opt: 'general.isp_interface', label: 'Network Interface', type: 'text', desc: 'Provider interface, e.g. eth3 or ppp0' },
	{ opt: 'general.tcp_ports', label: 'TCP Ports', type: 'text', desc: 'TCP ports for iptables rules' },
	{ opt: 'general.udp_ports', label: 'UDP Ports', type: 'text', desc: 'UDP ports for iptables rules' },
	{ opt: 'general.ipv6_enabled', label: 'IPv6 Enabled', type: 'flag', desc: 'Process IPv6 connections' },
	{ opt: 'general.policy_name', label: 'Policy Name', type: 'text', desc: 'Keenetic access policy name' },
	{ opt: 'general.policy_exclude', label: 'Policy Exclude', type: 'flag', desc: 'Exclude devices in policy instead of including' },
	{ opt: 'general.nfqueue_num', label: 'NFQueue Number', type: 'text', desc: 'Netfilter NFQUEUE queue number' },
	{ opt: 'general.user', label: 'Run As User', type: 'text', desc: 'User to run nfqws2 process as' },
	{ opt: 'general.log_level', label: 'Debug Logging', type: 'flag', desc: 'Enable debug-level syslog' },
	{ opt: 'general.nfqws_mode', label: 'Working Mode', type: 'select', options: ['MODE_AUTO', 'MODE_LIST', 'MODE_ALL'], desc: 'How nfqws2 selects domains' },
	{ opt: 'strategies.nfqws_base_args', label: 'Startup Arguments', type: 'textarea', rows: 6, desc: 'Lua init, blobs, base args' },
	{ opt: 'strategies.nfqws_args', label: 'Base Strategy', type: 'textarea', rows: 10, desc: 'HTTPS/HTTP DPI bypass' },
	{ opt: 'strategies.nfqws_args_quic', label: 'QUIC Strategy', type: 'textarea', rows: 5, desc: 'QUIC/UDP DPI bypass' },
	{ opt: 'strategies.nfqws_args_udp', label: 'UDP Strategy', type: 'textarea', rows: 8, desc: 'UDP: WireGuard, STUN, etc.' },
	{ opt: 'strategies.nfqws_args_custom', label: 'Custom Strategy', type: 'textarea', rows: 4, desc: 'Additional custom strategies' },
	{ opt: 'strategies.nfqws_args_ipset', label: 'IPSET Arguments', type: 'textarea', rows: 2, desc: 'IP list paths' },
];

var state = {
	currentTab: 'config',
	statusInterval: null,
	listFile: '',
	listDirty: false,
	logFile: '',
	scriptFile: '',
	scriptDirty: false,
	configData: {}
};

return view.extend({
	load: function() {
		return Promise.resolve();
	},

	render: function() {
		var self = this;
		var css = [
			'.nfqws2-tabs { display: flex; border-bottom: 2px solid #ddd; margin-bottom: 1em; }',
			'.nfqws2-tab { padding: 8px 16px; cursor: pointer; border: 1px solid transparent; border-bottom: none; margin-bottom: -2px; background: #f5f5f5; border-radius: 4px 4px 0 0; margin-right: 2px; font-size: 13px; }',
			'.nfqws2-tab.active { background: #fff; border-color: #ddd; font-weight: bold; border-bottom: 2px solid #fff; }',
			'.nfqws2-tab:hover { background: #e8e8e8; }',
			'.nfqws2-panel { display: none; }',
			'.nfqws2-panel.active { display: block; }',
			'.nfqws2-status-panel { background: #f5f5f5; border: 1px solid #ddd; border-radius: 6px; padding: 16px; margin-bottom: 16px; display: flex; align-items: center; gap: 16px; flex-wrap: wrap; }',
			'.nfqws2-status-indicator { width: 14px; height: 14px; border-radius: 50%; display: inline-block; margin-right: 8px; }',
			'.nfqws2-status-running { background: #4CAF50; box-shadow: 0 0 6px #4CAF50; }',
			'.nfqws2-status-stopped { background: #F44336; }',
			'.nfqws2-status-text { font-size: 15px; font-weight: 500; }',
			'.nfqws2-status-version { font-size: 12px; color: #888; margin-left: 8px; }',
			'.nfqws2-buttons { display: flex; gap: 8px; margin-left: auto; }',
			'.nfqws2-toolbar { display: flex; gap: 8px; margin-bottom: 8px; align-items: center; flex-wrap: wrap; }',
			'.nfqws2-toolbar .file-select { flex: 1; min-width: 200px; }',
			'.nfqws2-status-bar { font-size: 12px; color: #666; margin-left: auto; }',
			'.nfqws2-editor { font-family: monospace; font-size: 13px; width: 100%; min-height: 400px; resize: vertical; border: 1px solid #ccc; padding: 8px; border-radius: 4px; tab-size: 4; box-sizing: border-box; }',
			'.nfqws2-log-editor { font-family: monospace; font-size: 12px; width: 100%; min-height: 500px; resize: vertical; border: 1px solid #ccc; padding: 8px; border-radius: 4px; background: #1e1e1e; color: #d4d4d4; white-space: pre-wrap; word-break: break-all; tab-size: 4; box-sizing: border-box; }',
			'.nfqws2-msg-box { display: none; padding: 8px 12px; border-radius: 4px; margin-bottom: 8px; font-size: 13px; }',
			'.nfqws2-msg-ok { background: #C8E6C9; color: #2E7D32; border: 1px solid #A5D6A7; }',
			'.nfqws2-msg-err { background: #FFCDD2; color: #C62828; border: 1px solid #EF9A9A; }',
			'.nfqws2-cfg-table { width: 100%; border-collapse: collapse; }',
			'.nfqws2-cfg-table td { padding: 6px 8px; vertical-align: middle; }',
			'.nfqws2-cfg-table tr:nth-child(even) { background: #f9f9f9; }',
			'.nfqws2-cfg-label { width: 220px; font-weight: 500; }',
			'.nfqws2-cfg-desc { font-size: 11px; color: #888; margin-top: 2px; }',
		].join('\n');

		function showMsg(id, text, type) {
			var el = document.getElementById(id);
			if (!el) return;
			el.textContent = text;
			el.className = 'nfqws2-msg-box nfqws2-msg-' + (type === 'ok' ? 'ok' : 'err');
			el.style.display = 'block';
			setTimeout(function() { el.style.display = 'none'; }, 3000);
		}

		function switchTab(name) {
			state.currentTab = name;
			var tabs = document.querySelectorAll('.nfqws2-tab');
			for (var i = 0; i < tabs.length; i++) tabs[i].classList.remove('active');
			var panels = document.querySelectorAll('.nfqws2-panel');
			for (var i = 0; i < panels.length; i++) panels[i].classList.remove('active');
			var tabEl = document.getElementById('tab-' + name);
			var panelEl = document.getElementById('panel-' + name);
			if (tabEl) tabEl.classList.add('active');
			if (panelEl) panelEl.classList.add('active');

			if (name === 'config') loadConfig();
			if (name === 'lists') loadFileList('list');
			if (name === 'logs') loadLogFileList();
			if (name === 'scripts') loadScriptList();
		}

		/* ===== STATUS ===== */
		function updateStatus() {
			return nfqws2Rpc('status', null).then(function(data) {
				if (!data) return;
				var ind = document.getElementById('nfqws2-indicator');
				var txt = document.getElementById('nfqws2-status-text');
				var ver = document.getElementById('nfqws2-version');
				if (!ind) return;
				if (data.running) {
					ind.className = 'nfqws2-status-indicator nfqws2-status-running';
					if (txt) txt.textContent = _('Running');
				} else {
					ind.className = 'nfqws2-status-indicator nfqws2-status-stopped';
					if (txt) txt.textContent = _('Stopped');
				}
				if (data.version && ver) ver.textContent = 'v' + data.version;
			});
		}

		function svcAction(action) {
			return nfqws2Rpc('service', { action: action }).then(function() {
				setTimeout(updateStatus, 1000);
			});
		}

		function doUpgrade() {
			if (!confirm(_('Update nfqws2 package?'))) return;
			nfqws2Rpc('upgrade', {}).then(function(data) {
				if (data && data.output) alert(data.output.join('\n'));
				setTimeout(updateStatus, 2000);
			});
		}

		/* ===== CONFIG ===== */
		function createInput(field, val) {
			if (field.type === 'flag') {
				return E('select', {
					'class': 'cbi-input-select',
					'data-uciopt': field.opt,
					'style': 'width:100%;box-sizing:border-box;padding:4px 8px;'
				}, [
					E('option', { value: '0' }, _('No')),
					E('option', { value: '1', selected: (val === '1') }, _('Yes'))
				]);
			} else if (field.type === 'select') {
				var opts = field.options.map(function(v) {
					return E('option', { value: v, selected: (val === v) }, v);
				});
				return E('select', {
					'class': 'cbi-input-select',
					'data-uciopt': field.opt,
					'style': 'width:100%;box-sizing:border-box;padding:4px 8px;'
				}, opts);
			} else if (field.type === 'textarea') {
				return E('textarea', {
					'rows': field.rows || 4,
					'data-uciopt': field.opt,
					'style': 'width:100%;font-family:monospace;font-size:13px;padding:6px;border:1px solid #ccc;border-radius:4px;box-sizing:border-box;resize:vertical;',
					'spellcheck': 'false'
				}, [val]);
			} else {
				return E('input', {
					'type': 'text',
					'class': 'cbi-input-text',
					'data-uciopt': field.opt,
					'value': val || '',
					'style': 'width:100%;box-sizing:border-box;padding:4px 8px;'
				});
			}
		}

		function loadConfig() {
			var tbody = document.getElementById('config-body');
			if (!tbody) return;
			var rows = [];

			return Promise.all(configFields.map(function(f) {
				return nfqws2Rpc('uciget', { option: f.opt }).then(function(data) {
					return (data && data.value) ? data.value : '';
				});
			})).then(function(values) {
				tbody.innerHTML = '';
				configFields.forEach(function(f, idx) {
					var val = values[idx] || '';
					var input = createInput(f, val);
					state.configData[f.opt] = val;
					var tr = E('tr', [
						E('td', { 'class': 'nfqws2-cfg-label' }, [
							f.label,
							E('div', { 'class': 'nfqws2-cfg-desc' }, [f.desc])
						]),
						E('td', [input])
					]);
					tbody.appendChild(tr);
				});
			});
		}

		function saveConfig() {
			var inputs = document.querySelectorAll('[data-uciopt]');
			var promises = [];
			for (var i = 0; i < inputs.length; i++) {
				var el = inputs[i];
				var opt = el.getAttribute('data-uciopt');
				var val = el.value;
				promises.push(nfqws2Rpc('uciset', { option: opt, value: val }));
			}
			return Promise.all(promises).then(function() {
				showMsg('cfg-msg', _('Configuration saved'), 'ok');
			});
		}

		/* ===== LIST FILES ===== */
		function loadFileList(type) {
			return nfqws2Rpc('filenames', { type: type || 'list' }).then(function(data) {
				var files = (data && data.files) ? data.files : [];
				var sel = document.getElementById('file-select');
				if (!sel) return;
				sel.innerHTML = '';
				files.forEach(function(f) {
					sel.appendChild(E('option', { value: f }, f));
				});
				if (files.length > 0 && !state.listFile) {
					loadEditorFile(files[0]);
				} else if (files.length === 0) {
					state.listFile = '';
					var ed = document.getElementById('nfqws2-editor');
					if (ed) ed.value = '';
				}
			});
		}

		function loadEditorFile(filename) {
			if (state.listDirty) {
				if (!confirm(_('Current file is not saved. Really close?'))) return;
			}
			state.listFile = filename;
			state.listDirty = false;
			return nfqws2Rpc('filecontent', { filename: filename }).then(function(data) {
				var content = (data && data.content) ? data.content : '';
				var ed = document.getElementById('nfqws2-editor');
				if (ed) ed.value = content;
				var st = document.getElementById('file-status');
				if (st) {
					var lines = content.split('\n').filter(function(l) {
						var t = l.trim();
						return t && t.charAt(0) !== '#';
					});
					st.textContent = filename + ' \u2014 ' + lines.length + ' ' + _('entries');
				}
			});
		}

		function saveEditorFile() {
			if (!state.listFile) return;
			var ed = document.getElementById('nfqws2-editor');
			return nfqws2Rpc('savefile', { filename: state.listFile, content: ed ? ed.value : '' }).then(function(data) {
				if (data && data.status === 0) {
					state.listDirty = false;
					showMsg('editor-msg', _('File saved'), 'ok');
				} else {
					showMsg('editor-msg', _('Failed to save'), 'err');
				}
			});
		}

		function createEditorFile() {
			var name = prompt(_('Enter filename (e.g., custom.list):'));
			if (!name) return;
			return nfqws2Rpc('createfile', { filename: name }).then(function(data) {
				if (data && data.status === 0) {
					loadFileList('list');
					loadEditorFile(name);
				} else {
					showMsg('editor-msg', _('Failed to create file'), 'err');
				}
			});
		}

		function removeEditorFile() {
			if (!state.listFile) return;
			if (!confirm(_('Really delete this file?'))) return;
			return nfqws2Rpc('removefile', { filename: state.listFile }).then(function(data) {
				if (data && data.status === 0) {
					var ed = document.getElementById('nfqws2-editor');
					if (ed) ed.value = '';
					state.listFile = '';
					loadFileList('list');
				}
			});
		}

		function removeDuplicates() {
			var ed = document.getElementById('nfqws2-editor');
			if (!ed) return;
			var lines = ed.value.split('\n');
			var seen = {};
			var unique = [];
			lines.forEach(function(l) {
				var t = l.trim().toLowerCase();
				if (t && t.charAt(0) !== '#' && !seen[t]) {
					seen[t] = true;
					unique.push(l);
				} else if (!t || t.charAt(0) === '#') {
					unique.push(l);
				}
			});
			ed.value = unique.join('\n');
			state.listDirty = true;
		}

		/* ===== LOG FILES ===== */
		function loadLogFileList() {
			return nfqws2Rpc('filenames', { type: 'log' }).then(function(data) {
				var files = (data && data.files) ? data.files : [];
				var sel = document.getElementById('log-file-select');
				if (!sel) return;
				sel.innerHTML = '';
				files.forEach(function(f) {
					sel.appendChild(E('option', { value: f }, f));
				});
				if (files.length > 0) {
					loadLog(files[0]);
				} else {
					state.logFile = '';
					var ed = document.getElementById('nfqws2-log-editor');
					if (ed) ed.value = '';
				}
			});
		}

		function loadLog(filename) {
			state.logFile = filename || state.logFile;
			return nfqws2Rpc('filecontent', { filename: state.logFile }).then(function(data) {
				var ed = document.getElementById('nfqws2-log-editor');
				if (ed) ed.value = (data && data.content) ? data.content : '';
			});
		}

		function clearLog() {
			if (!state.logFile) return;
			if (!confirm(_('Really clear this log?'))) return;
			return nfqws2Rpc('savefile', { filename: state.logFile, content: '' }).then(function() {
				var ed = document.getElementById('nfqws2-log-editor');
				if (ed) ed.value = '';
			});
		}

		/* ===== SCRIPT FILES ===== */
		function loadScriptList() {
			return nfqws2Rpc('filenames', { type: 'lua' }).then(function(data) {
				var files = (data && data.files) ? data.files : [];
				var sel = document.getElementById('script-select');
				if (!sel) return;
				sel.innerHTML = '';
				files.forEach(function(f) {
					sel.appendChild(E('option', { value: f }, f));
				});
				if (files.length > 0 && !state.scriptFile) {
					loadScript(files[0]);
				} else if (files.length === 0) {
					state.scriptFile = '';
					var ed = document.getElementById('nfqws2-script-editor');
					if (ed) ed.value = '';
				}
			});
		}

		function loadScript(filename) {
			if (state.scriptDirty) {
				if (!confirm(_('Current file is not saved. Really close?'))) return;
			}
			state.scriptFile = filename;
			state.scriptDirty = false;
			return nfqws2Rpc('filecontent', { filename: filename }).then(function(data) {
				var ed = document.getElementById('nfqws2-script-editor');
				if (ed) ed.value = (data && data.content) ? data.content : '';
				var st = document.getElementById('script-status');
				if (st) st.textContent = filename;
			});
		}

		function saveScript() {
			if (!state.scriptFile) return;
			var ed = document.getElementById('nfqws2-script-editor');
			return nfqws2Rpc('savefile', { filename: state.scriptFile, content: ed ? ed.value : '' }).then(function(data) {
				if (data && data.status === 0) {
					state.scriptDirty = false;
					showMsg('script-msg', _('File saved'), 'ok');
				} else {
					showMsg('script-msg', _('Failed to save'), 'err');
				}
			});
		}

		function createScript() {
			var name = prompt(_('Enter filename (e.g., custom.lua):'));
			if (!name) return;
			return nfqws2Rpc('createfile', { filename: name }).then(function(data) {
				if (data && data.status === 0) {
					loadScriptList();
					loadScript(name);
				} else {
					showMsg('script-msg', _('Failed to create'), 'err');
				}
			});
		}

		function removeScript() {
			if (!state.scriptFile) return;
			if (!confirm(_('Really delete this file?'))) return;
			return nfqws2Rpc('removefile', { filename: state.scriptFile }).then(function(data) {
				if (data && data.status === 0) {
					var ed = document.getElementById('nfqws2-script-editor');
					if (ed) ed.value = '';
					state.scriptFile = '';
					loadScriptList();
				}
			});
		}

		/* ===== BUILD DOM ===== */
		var dom = E('div', [
			E('style', { 'type': 'text/css' }, [ css ]),
			/* Tabs */
			E('div', { 'class': 'nfqws2-tabs' }, [
				E('div', { 'class': 'nfqws2-tab', 'id': 'tab-config', 'click': function() { switchTab('config'); } }, [ _('Configuration') ]),
				E('div', { 'class': 'nfqws2-tab', 'id': 'tab-lists', 'click': function() { switchTab('lists'); } }, [ _('Domain Lists') ]),
				E('div', { 'class': 'nfqws2-tab', 'id': 'tab-logs', 'click': function() { switchTab('logs'); } }, [ _('Logs') ]),
				E('div', { 'class': 'nfqws2-tab', 'id': 'tab-scripts', 'click': function() { switchTab('scripts'); } }, [ _('Lua Scripts') ])
			]),

			/* Config Panel */
			E('div', { 'class': 'nfqws2-panel', 'id': 'panel-config' }, [
				E('div', { 'class': 'nfqws2-status-panel' }, [
					E('span', { 'class': 'nfqws2-status-indicator nfqws2-status-stopped', 'id': 'nfqws2-indicator' }),
					E('span', { 'class': 'nfqws2-status-text', 'id': 'nfqws2-status-text' }, [ _('Checking...') ]),
					E('span', { 'class': 'nfqws2-status-version', 'id': 'nfqws2-version' }),
					E('div', { 'class': 'nfqws2-buttons' }, [
						E('button', { 'class': 'btn cbi-button cbi-button-apply', 'click': function() { svcAction('start'); } }, [ _('Start') ]),
						E('button', { 'class': 'btn cbi-button cbi-button-remove', 'click': function() { svcAction('stop'); } }, [ _('Stop') ]),
						E('button', { 'class': 'btn cbi-button cbi-button-reload', 'click': function() { svcAction('restart'); } }, [ _('Restart') ]),
						E('button', { 'class': 'btn cbi-button', 'click': function() { doUpgrade(); } }, [ _('Update') ])
					])
				]),
				E('div', { 'class': 'cbi-section' }, [
					E('h3', { 'name': 'content' }, [ _('General Settings') ]),
					E('div', { 'id': 'cfg-msg', 'class': 'nfqws2-msg-box' }),
					E('table', { 'class': 'nfqws2-cfg-table' }, [
						E('tbody', { 'id': 'config-body' }, [
							E('tr', [ E('td', { colspan: '2' }, [ _('Loading...') ]) ])
						])
					]),
					E('div', { 'style': 'margin-top: 12px;' }, [
						E('button', { 'class': 'btn cbi-button cbi-button-apply', 'click': function() { saveConfig(); } }, [ _('Save Configuration') ])
					])
				])
			]),

			/* Lists Panel */
			E('div', { 'class': 'nfqws2-panel', 'id': 'panel-lists' }, [
				E('div', { 'class': 'cbi-section' }, [
					E('div', { 'class': 'nfqws2-toolbar' }, [
						E('select', { 'id': 'file-select', 'class': 'cbi-input-select file-select' }, [
							E('option', [ _('Loading...') ])
						]),
						E('button', { 'class': 'btn cbi-button cbi-button-add', 'click': function() { saveEditorFile(); } }, [ _('Save') ]),
						E('button', { 'class': 'btn cbi-button cbi-button-add', 'click': function() { createEditorFile(); } }, [ _('Create') ]),
						E('button', { 'class': 'btn cbi-button cbi-button-remove', 'click': function() { removeEditorFile(); } }, [ _('Delete') ]),
						E('button', { 'class': 'btn cbi-button', 'click': function() { removeDuplicates(); } }, [ _('Remove Duplicates') ]),
						E('span', { 'class': 'nfqws2-status-bar', 'id': 'file-status' })
					]),
					E('div', { 'id': 'editor-msg', 'class': 'nfqws2-msg-box' }),
					E('textarea', { 'id': 'nfqws2-editor', 'class': 'nfqws2-editor', 'spellcheck': 'false' })
				])
			]),

			/* Logs Panel */
			E('div', { 'class': 'nfqws2-panel', 'id': 'panel-logs' }, [
				E('div', { 'class': 'cbi-section' }, [
					E('h3', { 'name': 'content' }, [ _('Log Files') ]),
					E('div', { 'class': 'nfqws2-toolbar' }, [
						E('select', { 'id': 'log-file-select', 'class': 'cbi-input-select file-select' }, [
							E('option', [ _('Loading...') ])
						]),
						E('button', { 'class': 'btn cbi-button cbi-button-remove', 'click': function() { clearLog(); } }, [ _('Clear Log') ]),
						E('button', { 'class': 'btn cbi-button cbi-button-reload', 'click': function() { loadLog(state.logFile); } }, [ _('Refresh') ])
					]),
					E('textarea', { 'id': 'nfqws2-log-editor', 'class': 'nfqws2-log-editor', 'readonly': true, 'spellcheck': 'false' })
				])
			]),

			/* Scripts Panel */
			E('div', { 'class': 'nfqws2-panel', 'id': 'panel-scripts' }, [
				E('div', { 'class': 'cbi-section' }, [
					E('h3', { 'name': 'content' }, [ _('Lua Script Editor') ]),
					E('div', { 'class': 'nfqws2-toolbar' }, [
						E('select', { 'id': 'script-select', 'class': 'cbi-input-select file-select' }, [
							E('option', [ _('Loading...') ])
						]),
						E('button', { 'class': 'btn cbi-button cbi-button-add', 'click': function() { saveScript(); } }, [ _('Save') ]),
						E('button', { 'class': 'btn cbi-button cbi-button-add', 'click': function() { createScript(); } }, [ _('Create') ]),
						E('button', { 'class': 'btn cbi-button cbi-button-remove', 'click': function() { removeScript(); } }, [ _('Delete') ]),
						E('span', { 'class': 'nfqws2-status-bar', 'id': 'script-status' })
					]),
					E('div', { 'id': 'script-msg', 'class': 'nfqws2-msg-box' }),
					E('textarea', { 'id': 'nfqws2-script-editor', 'class': 'nfqws2-editor', 'spellcheck': 'false' })
				])
			])
		]);

		/* Register event handlers */
		setTimeout(function() {
			updateStatus();
			state.statusInterval = setInterval(updateStatus, 10000);

			switchTab('config');

			var listEd = document.getElementById('nfqws2-editor');
			if (listEd) {
				listEd.addEventListener('input', function() { state.listDirty = true; });
			}

			var listSel = document.getElementById('file-select');
			if (listSel) {
				listSel.addEventListener('change', function() { loadEditorFile(this.value); });
			}

			var logSel = document.getElementById('log-file-select');
			if (logSel) {
				logSel.addEventListener('change', function() { loadLog(this.value); });
			}

			var scriptSel = document.getElementById('script-select');
			if (scriptSel) {
				scriptSel.addEventListener('change', function() { loadScript(this.value); });
			}

			var scriptEd = document.getElementById('nfqws2-script-editor');
			if (scriptEd) {
				scriptEd.addEventListener('input', function() { state.scriptDirty = true; });
			}
		}, 0);

		return dom;
	},

	handleCleanup: function() {
		if (state.statusInterval) {
			clearInterval(state.statusInterval);
			state.statusInterval = null;
		}
	}
});

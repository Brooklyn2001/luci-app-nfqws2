local http = require "luci.http"

http [[
<style>
#nfqws2-log-editor {
	font-family: monospace; font-size: 12px; width: 100%; min-height: 500px;
	resize: vertical; border: 1px solid #ccc; padding: 8px;
	border-radius: 4px; background: #1e1e1e; color: #d4d4d4;
	white-space: pre-wrap; word-break: break-all; tab-size: 4;
}
.nfqws2-log-toolbar { display: flex; gap: 8px; margin-bottom: 8px; align-items: center; flex-wrap: wrap; }
.nfqws2-log-toolbar .file-select { flex: 1; min-width: 200px; }
.log-line-error { color: #f44336; }
.log-line-warn  { color: #ff9800; }
.log-line-ok    { color: #4caf50; }
</style>

<script type="text/javascript">//<![CDATA[

var currentLogFile = "";

function getLogFileList() {
	return new Promise(function(resolve) {
		var xhr = new XMLHttpRequest();
		xhr.open("POST", "./filenames");
		xhr.setRequestHeader("Content-Type", "application/x-www-form-urlencoded");
		xhr.onload = function() {
			try {
				var data = JSON.parse(xhr.responseText);
				resolve(data.files || []);
			} catch(e) { resolve([]); }
		};
		xhr.send("type=log");
	});
}

function loadLogFile(filename) {
	currentLogFile = filename;
	var xhr = new XMLHttpRequest();
	xhr.open("POST", "./filecontent");
	xhr.setRequestHeader("Content-Type", "application/x-www-form-urlencoded");
	xhr.onload = function() {
		try {
			var data = JSON.parse(xhr.responseText);
			var content = data.content || "";
			content = highlightLog(content);
			document.getElementById("nfqws2-log-editor").value = data.content || "";
		} catch(e) {
			document.getElementById("nfqws2-log-editor").value = "";
		}
	};
	xhr.send("filename=" + encodeURIComponent(filename));
}

function highlightLog(content) {
	// Simple syntax highlighting could be applied here
	return content;
}

function clearLog() {
	if (!currentLogFile) return;
	if (!confirm("%%unescaped:translate('Really clear this log file?')%%")) return;

	var xhr = new XMLHttpRequest();
	xhr.open("POST", "./savefile");
	xhr.setRequestHeader("Content-Type", "application/x-www-form-urlencoded");
	xhr.onload = function() {
		try {
			var data = JSON.parse(xhr.responseText);
			if (data.status === 0) {
				document.getElementById("nfqws2-log-editor").value = "";
			}
		} catch(e) {}
	};
	xhr.send("filename=" + encodeURIComponent(currentLogFile) + "&content=");
}

function loadLogs() {
	getLogFileList().then(function(files) {
		var sel = document.getElementById("log-file-select");
		sel.innerHTML = "";
		for (var i = 0; i < files.length; i++) {
			var opt = document.createElement("option");
			opt.value = files[i];
			opt.textContent = files[i];
			sel.appendChild(opt);
		}
		if (files.length > 0) {
			loadLogFile(files[0]);
		}
	});
}

document.addEventListener("DOMContentLoaded", loadLogs);

//]]>
</script>

<div class="cbi-section cbi-tblsection">
	<h3 name="content">%%unescaped:translate("Log Files")%%</h3>

	<div class="nfqws2-log-toolbar">
		<select id="log-file-select" class="cbi-input-select file-select" onchange="loadLogFile(this.value)">
			<option>%%unescaped:translate("Loading...")%%</option>
		</select>
		<button class="btn cbi-button cbi-button-remove" onclick="clearLog()">
			%%unescaped:translate("Clear Log")%%
		</button>
		<button class="btn cbi-button cbi-button-reload" onclick="loadLogFile(currentLogFile)">
			%%unescaped:translate("Refresh")%%
		</button>
	</div>

	<textarea id="nfqws2-log-editor" readonly spellcheck="false"></textarea>
</div>
]]

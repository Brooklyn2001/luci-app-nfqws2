local fs = require "luci.fs"
local http = require "luci.http"

local m
m = Map("nfqws2", translate("NFQWS2"),
	translate("Web interface for managing nfqws2 DPI bypass utility. " ..
		"Settings are stored in UCI and auto-generated into nfqws2.conf on service start."))

-- Build file tabs
local file_types = {
	{type = "list", label = translate("Lists")},
}

-- Get active tab from query
local active_tab = http.formvalue("tab") or "list"

http [[
<style>
.nfqws2-tabs { display: flex; border-bottom: 2px solid #ddd; margin-bottom: 1em; }
.nfqws2-tab {
	padding: 8px 16px; cursor: pointer; border: 1px solid transparent;
	border-bottom: none; margin-bottom: -2px; background: #f5f5f5;
	border-radius: 4px 4px 0 0; margin-right: 2px; font-size: 13px;
}
.nfqws2-tab.active {
	background: #fff; border-color: #ddd; font-weight: bold;
	border-bottom: 2px solid #fff;
}
.nfqws2-tab:hover { background: #e8e8e8; }
.nfqws2-editor-wrap { position: relative; }
.nfqws2-toolbar {
	display: flex; gap: 8px; margin-bottom: 8px; align-items: center; flex-wrap: wrap;
}
.nfqws2-toolbar .file-select { flex: 1; min-width: 200px; }
.nfqws2-status { font-size: 12px; color: #666; margin-left: auto; }
#nfqws2-editor {
	font-family: monospace; font-size: 13px; width: 100%; min-height: 400px;
	resize: vertical; border: 1px solid #ccc; padding: 8px;
	border-radius: 4px; tab-size: 4;
}
.file-item { display: flex; align-items: center; gap: 6px; padding: 4px 0; }
.file-item .file-name { cursor: pointer; color: #2196F3; text-decoration: underline; }
.file-item .file-name:hover { color: #1565C0; }
.file-actions { display: flex; gap: 4px; }
.status-indicator { display: inline-block; width: 10px; height: 10px; border-radius: 50%; margin-right: 6px; }
.status-running { background: #4CAF50; }
.status-stopped { background: #F44336; }
.check-result { font-size: 12px; padding: 2px 6px; border-radius: 3px; margin-left: 6px; display: inline-block; }
.check-available { background: #C8E6C9; color: #2E7D32; }
.check-blocked { background: #FFCDD2; color: #C62828; }
.check-pending { background: #FFF9C4; color: #F57F17; }
.duplicate-banner {
	background: #FFF3E0; border: 1px solid #FFE0B2; padding: 8px 12px;
	margin-bottom: 8px; border-radius: 4px; font-size: 13px; display: none;
}
</style>

<script type="text/javascript">
//<![CDATA[

var currentFile = "";
var originalContent = "";
var fileDirty = false;
var currentFileType = "list";

function getFileList(fileType) {
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
		xhr.send("type=" + fileType);
	});
}

function loadFile(filename) {
	if (fileDirty) {
		if (!confirm("%%unescaped:translate('Current file is not saved. Really close?')%%")) {
			return;
		}
	}
	currentFile = filename;
	originalContent = "";
	fileDirty = false;

	var xhr = new XMLHttpRequest();
	xhr.open("POST", "./filecontent");
	xhr.setRequestHeader("Content-Type", "application/x-www-form-urlencoded");
	xhr.onload = function() {
		try {
			var data = JSON.parse(xhr.responseText);
			document.getElementById("nfqws2-editor").value = data.content || "";
			originalContent = data.content || "";
			updateStatus(filename, data.content || "");
		} catch(e) {
			document.getElementById("nfqws2-editor").value = "";
		}
	};
	xhr.send("filename=" + encodeURIComponent(filename));
}

function saveFile() {
	if (!currentFile) return;
	var content = document.getElementById("nfqws2-editor").value;

	var xhr = new XMLHttpRequest();
	xhr.open("POST", "./savefile");
	xhr.setRequestHeader("Content-Type", "application/x-www-form-urlencoded");
	xhr.onload = function() {
		try {
			var data = JSON.parse(xhr.responseText);
			if (data.status === 0) {
				originalContent = content;
				fileDirty = false;
				updateStatus(currentFile, content);
				showMessage("%%unescaped:translate('File saved successfully')%%", "ok");
			} else {
				showMessage("%%unescaped:translate('Failed to save file')%%", "error");
			}
		} catch(e) {
			showMessage("%%unescaped:translate('Failed to save file')%%", "error");
		}
	};
	xhr.send("filename=" + encodeURIComponent(currentFile) + "&content=" + encodeURIComponent(content));
}

function createFile() {
	var name = prompt("%%unescaped:translate('Enter filename (e.g., custom.list):')%%");
	if (!name) return;

	var xhr = new XMLHttpRequest();
	xhr.open("POST", "./createfile");
	xhr.setRequestHeader("Content-Type", "application/x-www-form-urlencoded");
	xhr.onload = function() {
		try {
			var data = JSON.parse(xhr.responseText);
			if (data.status === 0) {
				loadFileList();
				loadFile(name);
			} else {
				showMessage("%%unescaped:translate('Failed to create file')%%", "error");
			}
		} catch(e) {
			showMessage("%%unescaped:translate('Failed to create file')%%", "error");
		}
	};
	xhr.send("filename=" + encodeURIComponent(name));
}

function removeFile(filename) {
	if (!confirm("%%unescaped:translate('Really delete this file?')%%")) return;

	var xhr = new XMLHttpRequest();
	xhr.open("POST", "./removefile");
	xhr.setRequestHeader("Content-Type", "application/x-www-form-urlencoded");
	xhr.onload = function() {
		try {
			var data = JSON.parse(xhr.responseText);
			if (data.status === 0) {
				if (currentFile === filename) {
					currentFile = "";
					document.getElementById("nfqws2-editor").value = "";
				}
				loadFileList();
			}
		} catch(e) {}
	};
	xhr.send("filename=" + encodeURIComponent(filename));
}

function removeDuplicates() {
	var editor = document.getElementById("nfqws2-editor");
	var content = editor.value;
	var lines = content.split("\n");
	var seen = {};
	var unique = [];
	for (var i = 0; i < lines.length; i++) {
		var line = lines[i].trim().toLowerCase();
		if (line && line.charAt(0) !== "#" && !seen[line]) {
			seen[line] = true;
			unique.push(lines[i]);
		} else if (!line || line.charAt(0) === "#") {
			unique.push(lines[i]);
		}
	}
	editor.value = unique.join("\n");
	fileDirty = true;
}

function updateStatus(filename, content) {
	var el = document.getElementById("file-status");
	if (!el) return;
	var lines = content.split("\n").filter(function(l) {
		var t = l.trim();
		return t && t.charAt(0) !== "#";
	});
	el.textContent = filename + " — " + lines.length + " " + translate("entries");
}

function showMessage(msg, type) {
	var el = document.getElementById("editor-message");
	el.textContent = msg;
	el.className = type === "ok" ? "message ok" : "message error";
	el.style.display = "block";
	setTimeout(function() { el.style.display = "none"; }, 3000);
}

function loadFileList() {
	getFileList(currentFileType).then(function(files) {
		var sel = document.getElementById("file-select");
		sel.innerHTML = "";
		for (var i = 0; i < files.length; i++) {
			var opt = document.createElement("option");
			opt.value = files[i];
			opt.textContent = files[i];
			sel.appendChild(opt);
		}
		if (files.length > 0 && !currentFile) {
			loadFile(files[0]);
		}
	});
}

function checkDomains() {
	var editor = document.getElementById("nfqws2-editor");
	var content = editor.value;
	var lines = content.split("\n").filter(function(l) {
		var t = l.trim();
		return t && t.charAt(0) !== "#";
	});

	if (!lines.length) {
		alert("%%unescaped:translate('No domains to check')%%");
		return;
	}

	alert(%%unescaped:translate('Domain check initiated for')%% + " " + lines.length + " " + %%unescaped:translate('domains. This may take a while.')%%);

	var results = {};
	var done = 0;
	var total = lines.length;

	function checkOne(idx) {
		if (idx >= total) return;
		var domain = lines[idx].trim();
		var xhr = new XMLHttpRequest();
		xhr.open("POST", "./checkdomain");
		xhr.setRequestHeader("Content-Type", "application/x-www-form-urlencoded");
		xhr.onload = function() {
			try {
				var data = JSON.parse(xhr.responseText);
				results[domain] = data.result;
			} catch(e) { results[domain] = null; }
			done++;
			updateCheckProgress(done, total);
			if (done < total && idx + 1 < total) {
				setTimeout(function() { checkOne(idx + 1); }, 200);
			} else {
				showCheckResults(results, lines);
			}
		};
		xhr.send("url=https://" + domain);
	}
	checkOne(0);
}

function updateCheckProgress(done, total) {
	var el = document.getElementById("check-progress");
	if (el) el.textContent = done + " / " + total;
}

function showCheckResults(results, domains) {
	var available = 0, blocked = 0, unknown = 0;
	for (var d in results) {
		if (results[d]) available++;
		else if (results[d] === false) blocked++;
		else unknown++;
	}

	var msg = translate("Check complete:") + "\n";
	msg += translate("Total:") + " " + Object.keys(results).length + "\n";
	msg += translate("Available:") + " " + available + "\n";
	msg += translate("Blocked:") + " " + blocked + "\n";
	msg += translate("Unknown:") + " " + unknown;
	alert(msg);
}

function switchTab(tab) {
	currentFileType = tab;
	document.querySelectorAll(".nfqws2-tab").forEach(function(t) { t.classList.remove("active"); });
	document.getElementById("tab-" + tab).classList.add("active");
	currentFile = "";
	originalContent = "";
	fileDirty = false;
	document.getElementById("nfqws2-editor").value = "";
	loadFileList();
}

document.addEventListener("DOMContentLoaded", function() {
	loadFileList();
	document.getElementById("nfqws2-editor").addEventListener("input", function() {
		fileDirty = this.value !== originalContent;
	});
});

window.addEventListener("beforeunload", function(e) {
	if (fileDirty) {
		e.returnValue = %%unescaped:translate('Unsaved changes')%%;
	}
});

//]]>
</script>

<div class="cbi-section cbi-tblsection">
	<div class="nfqws2-tabs">
		<div class="nfqws2-tab active" id="tab-list" onclick="switchTab('list')">
			%%unescaped:translate("Domain Lists")%%
		</div>
	</div>

	<div class="nfqws2-toolbar">
		<select id="file-select" class="cbi-input-select file-select" onchange="loadFile(this.value)">
			<option>%%unescaped:translate("Loading...")%%</option>
		</select>

		<button class="btn cbi-button cbi-button-add" onclick="saveFile()">
			%%unescaped:translate("Save")%%
		</button>
		<button class="btn cbi-button cbi-button-add" onclick="createFile()">
			%%unescaped:translate("Create")%%
		</button>
		<button class="btn cbi-button cbi-button-remove" onclick="removeFile(currentFile)">
			%%unescaped:translate("Delete")%%
		</button>
		<button class="btn cbi-button" onclick="removeDuplicates()">
			%%unescaped:translate("Remove Duplicates")%%
		</button>
		<button class="btn cbi-button cbi-button-action" onclick="checkDomains()">
			%%unescaped:translate("Check Domains")%%
		</button>
		<span class="nfqws2-status" id="file-status"></span>
	</div>

	<div id="editor-message" style="display:none;"></div>

	<div class="nfqws2-editor-wrap">
		<textarea id="nfqws2-editor" spellcheck="false"></textarea>
	</div>

	<div style="margin-top: 8px; font-size: 12px; color: #888;">
		<span id="check-progress"></span>
	</div>
</div>
]]

return m

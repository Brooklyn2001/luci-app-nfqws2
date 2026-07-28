local http = require "luci.http"

http [[
<style>
#nfqws2-script-editor {
	font-family: monospace; font-size: 13px; width: 100%; min-height: 400px;
	resize: vertical; border: 1px solid #ccc; padding: 8px;
	border-radius: 4px; tab-size: 4;
}
.nfqws2-script-toolbar { display: flex; gap: 8px; margin-bottom: 8px; align-items: center; flex-wrap: wrap; }
.nfqws2-script-toolbar .file-select { flex: 1; min-width: 200px; }
</style>

<script type="text/javascript">//<![CDATA[

var currentScript = "";
var originalScriptContent = "";
var scriptDirty = false;

function getScriptList() {
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
		xhr.send("type=lua");
	});
}

function loadScript(filename) {
	if (scriptDirty) {
		if (!confirm("%%unescaped:translate('Current file is not saved. Really close?')%%")) {
			return;
		}
	}
	currentScript = filename;
	originalScriptContent = "";
	scriptDirty = false;

	var xhr = new XMLHttpRequest();
	xhr.open("POST", "./filecontent");
	xhr.setRequestHeader("Content-Type", "application/x-www-form-urlencoded");
	xhr.onload = function() {
		try {
			var data = JSON.parse(xhr.responseText);
			document.getElementById("nfqws2-script-editor").value = data.content || "";
			originalScriptContent = data.content || "";
			var el = document.getElementById("script-status");
			if (el) el.textContent = filename;
		} catch(e) {
			document.getElementById("nfqws2-script-editor").value = "";
		}
	};
	xhr.send("filename=" + encodeURIComponent(filename));
}

function saveScript() {
	if (!currentScript) return;
	var content = document.getElementById("nfqws2-script-editor").value;

	var xhr = new XMLHttpRequest();
	xhr.open("POST", "./savefile");
	xhr.setRequestHeader("Content-Type", "application/x-www-form-urlencoded");
	xhr.onload = function() {
		try {
			var data = JSON.parse(xhr.responseText);
			if (data.status === 0) {
				originalScriptContent = content;
				scriptDirty = false;
				showMessage("%%unescaped:translate('File saved successfully')%%", "ok");
			} else {
				showMessage("%%unescaped:translate('Failed to save file')%%", "error");
			}
		} catch(e) {
			showMessage("%%unescaped:translate('Failed to save file')%%", "error");
		}
	};
	xhr.send("filename=" + encodeURIComponent(currentScript) + "&content=" + encodeURIComponent(content));
}

function createScript() {
	var name = prompt("%%unescaped:translate('Enter filename (e.g., custom.lua):')%%");
	if (!name) return;

	var xhr = new XMLHttpRequest();
	xhr.open("POST", "./createfile");
	xhr.setRequestHeader("Content-Type", "application/x-www-form-urlencoded");
	xhr.onload = function() {
		try {
			var data = JSON.parse(xhr.responseText);
			if (data.status === 0) {
				loadScriptList();
				loadScript(name);
			} else {
				showMessage("%%unescaped:translate('Failed to create file')%%", "error");
			}
		} catch(e) {
			showMessage("%%unescaped:translate('Failed to create file')%%", "error");
		}
	};
	xhr.send("filename=" + encodeURIComponent(name));
}

function removeScript(filename) {
	if (!confirm("%%unescaped:translate('Really delete this file?')%%")) return;

	var xhr = new XMLHttpRequest();
	xhr.open("POST", "./removefile");
	xhr.setRequestHeader("Content-Type", "application/x-www-form-urlencoded");
	xhr.onload = function() {
		try {
			var data = JSON.parse(xhr.responseText);
			if (data.status === 0) {
				if (currentScript === filename) {
					currentScript = "";
					document.getElementById("nfqws2-script-editor").value = "";
				}
				loadScriptList();
			}
		} catch(e) {}
	};
	xhr.send("filename=" + encodeURIComponent(filename));
}

function showMessage(msg, type) {
	var el = document.getElementById("script-message");
	el.textContent = msg;
	el.style.color = type === "ok" ? "#2E7D32" : "#C62828";
	el.style.display = "block";
	setTimeout(function() { el.style.display = "none"; }, 3000);
}

function loadScriptList() {
	getScriptList().then(function(files) {
		var sel = document.getElementById("script-select");
		sel.innerHTML = "";
		for (var i = 0; i < files.length; i++) {
			var opt = document.createElement("option");
			opt.value = files[i];
			opt.textContent = files[i];
			sel.appendChild(opt);
		}
		if (files.length > 0 && !currentScript) {
			loadScript(files[0]);
		}
	});
}

document.addEventListener("DOMContentLoaded", function() {
	loadScriptList();
	document.getElementById("nfqws2-script-editor").addEventListener("input", function() {
		scriptDirty = this.value !== originalScriptContent;
	});
});

//]]>
</script>

<div class="cbi-section cbi-tblsection">
	<h3 name="content">%%unescaped:translate("Lua Script Editor")%%</h3>

	<div class="nfqws2-script-toolbar">
		<select id="script-select" class="cbi-input-select file-select" onchange="loadScript(this.value)">
			<option>%%unescaped:translate("Loading...")%%</option>
		</select>
		<button class="btn cbi-button cbi-button-add" onclick="saveScript()">
			%%unescaped:translate("Save")%%
		</button>
		<button class="btn cbi-button cbi-button-add" onclick="createScript()">
			%%unescaped:translate("Create")%%
		</button>
		<button class="btn cbi-button cbi-button-remove" onclick="removeScript(currentScript)">
			%%unescaped:translate("Delete")%%
		</button>
		<span style="margin-left:auto; font-size:12px; color:#666;" id="script-status"></span>
	</div>

	<div id="script-message" style="display:none; margin-bottom:8px;"></div>

	<textarea id="nfqws2-script-editor" spellcheck="false"></textarea>
</div>
]]

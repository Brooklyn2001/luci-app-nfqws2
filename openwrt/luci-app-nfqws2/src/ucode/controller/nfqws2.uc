'use strict';

import { lsdir, open, stat, read, write, unlink, access } from 'fs';

function json_response(data) {
	http.prepare_content('application/json; charset=UTF-8');
	http.write_json(data);
}

function action_status() {
	const fs = {};
	let ret = { running: false, nfqws2: !!stat('/usr/bin/nfqws2') };

	let f = popen('pidof nfqws2 2>/dev/null');
	if (f) {
		const pid = read(f)?.trim();
		f.close();
		ret.running = !!pid && pid.length > 0;
	}

	f = popen('apk list --installed nfqws2-keenetic 2>/dev/null | awk \'{print $2}\' | sed \'s/-r[0-9]*$//\'');
	if (f) {
		ret.version = read(f)?.trim();
		f.close();
	}

	json_response(ret);
}

function action_service() {
	const action = http.formvalue('action');
	if (!action) {
		json_response({ status: 1, output: ['No action specified'] });
		return;
	}

	const cmd = `/etc/init.d/nfqws2 ${action} 2>&1`;
	const output = [];
	let f = popen(cmd);
	if (f) {
		for (let line of read(f)?.split('\n') ?? []) {
			if (line)
				output.push(line);
		}
		f.close();
	}
	if (!output.length)
		output.push('Executed: ' + cmd);

	json_response({ status: 0, output });
}

function action_filenames() {
	const ftype = http.formvalue('type');
	const paths = {
		conf: '/etc/nfqws2',
		list: '/etc/nfqws2/lists',
		log: '/var/log',
		lua: '/etc/nfqws2/lua',
	};

	const base_dir = paths[ftype] ?? paths.conf;
	const files = [];

	const dir = lsdir(base_dir);
	for (let f of dir ?? []) {
		if (!f || f.startsWith('.'))
			continue;

		const gz = f.replace(/\.gz$/, '');
		const dot = gz.lastIndexOf('.');
		const ext = dot >= 0 ? gz.slice(dot + 1) : null;

		let ok = false;
		if (ftype == 'conf' && ['conf', 'conf-opkg', 'conf-old'].includes(ext))
			ok = true;
		if (ftype == 'list' && ['list', 'list-opkg', 'list-old'].includes(ext))
			ok = true;
		if (ftype == 'lua' && ext == 'lua')
			ok = true;
		if (ftype == 'log' && ext == 'log' && gz.startsWith('nfqws'))
			ok = true;

		if (ok)
			files.push(gz);
	}

	files.sort();
	json_response({ status: 0, files });
}

function resolve_path(filename) {
	const base = filename.replace(/\.gz$/, '');
	if (base.endsWith('.list'))
		return '/etc/nfqws2/lists/' + base;
	if (base.endsWith('.log'))
		return '/var/log/' + base;
	if (base.endsWith('.lua'))
		return '/etc/nfqws2/lua/' + base;
	return '/etc/nfqws2/' + base;
}

function action_filecontent() {
	const filename = http.formvalue('filename');
	if (!filename) {
		json_response({ status: 1, content: '' });
		return;
	}

	const path = resolve_path(filename);
	const base = filename.replace(/\.gz$/, '');
	let content = '';

	const fd = open(path, 'r');
	if (fd) {
		content = read(fd) ?? '';
		fd.close();
	}

	if (base.endsWith('.log')) {
		const lines = content.split(/\r?\n/).filter(l => l);
		content = lines.reverse().join('\n');
	}

	json_response({ status: 0, content, filename });
}

function action_savefile() {
	const filename = http.formvalue('filename');
	const content = http.formvalue('content');

	if (!filename || !content) {
		json_response({ status: 1, filename });
		return;
	}

	const base = filename.replace(/\.gz$/, '');
	if (base.endsWith('.log')) {
		json_response({ status: 1, filename });
		return;
	}

	const path = resolve_path(filename);
	let clean = content.replace(/\r\n/g, '\n').replace(/\r/g, '\n');
	clean = clean.replace(/\n{3,}/g, '\n\n');
	if (clean.length > 0 && !clean.endsWith('\n'))
		clean = clean + '\n';

	const fd = open(path, 'w');
	if (fd) {
		write(fd, clean);
		fd.close();
		json_response({ status: 0, filename });
	} else {
		json_response({ status: 1, filename });
	}
}

function action_createfile() {
	const filename = http.formvalue('filename');
	if (!filename || !match(filename, /^[a-zA-Z0-9_%-]+\.(list|lua|conf)$/)) {
		json_response({ status: 1, filename });
		return;
	}

	const path = resolve_path(filename);
	if (access(path)) {
		json_response({ status: 1, filename });
		return;
	}

	const fd = open(path, 'w');
	if (fd) {
		fd.close();
		json_response({ status: 0, filename });
	} else {
		json_response({ status: 1, filename });
	}
}

function action_removefile() {
	const filename = http.formvalue('filename');
	if (!filename) {
		json_response({ status: 1, filename: '' });
		return;
	}

	const path = resolve_path(filename);
	if (access(path)) {
		unlink(path);
		json_response({ status: 0, filename });
	} else {
		json_response({ status: 1, filename });
	}
}

function action_checkdomain() {
	const url = http.formvalue('url');
	if (!url) {
		json_response({ status: 1, result: false });
		return;
	}

	if (!access('/usr/bin/curl')) {
		json_response({ status: 0, result: false, note: 'curl not installed' });
		return;
	}

	let f = popen(`curl -sIL --max-time 5 --max-redirs 5 "${url}" 2>/dev/null | head -1`);
	let result = false;
	if (f) {
		const line = read(f)?.split('\n')[0];
		f.close();
		result = !!line && match(line, /^HTTP\/\d+\.\d+ \d+/);
	}

	json_response({ status: 0, result });
}

function action_upgrade() {
	const output = [];
	let f = popen('apk --update-cache upgrade nfqws2-keenetic 2>&1');
	if (f) {
		for (let line of read(f)?.split('\n') ?? []) {
			if (line)
				output.push(line);
		}
		f.close();
	}
	if (!output.length)
		output.push('Nothing to update');

	json_response({ status: 0, output });
}

function action_uciget() {
	const option = http.formvalue('option');
	if (!option) {
		json_response({ status: 1 });
		return;
	}
	let f = popen(`uci get nfqws2.${option} 2>/dev/null`);
	let val = '';
	if (f) {
		val = read(f)?.trim() ?? '';
		f.close();
	}
	json_response({ status: 0, value: val });
}

function action_uciset() {
	const option = http.formvalue('option');
	const value = http.formvalue('value');
	if (!option || value === undefined) {
		json_response({ status: 1 });
		return;
	}
	let f = popen(`uci set nfqws2.${option}='${value}' && uci commit nfqws2 2>&1`);
	let out = '';
	if (f) {
		out = read(f)?.trim() ?? '';
		f.close();
	}
	json_response({ status: out.length ? 1 : 0, output: out });
}

function action_ucichanges() {
	const output = [];
	let f = popen('uci changes nfqws2 2>&1');
	if (f) {
		for (let line of read(f)?.split('\n') ?? []) {
			if (line)
				output.push(line);
		}
		f.close();
	}
	json_response({ status: 0, changes: output });
}

return {
	action_status,
	action_service,
	action_filenames,
	action_filecontent,
	action_savefile,
	action_createfile,
	action_removefile,
	action_checkdomain,
	action_upgrade,
	action_uciget,
	action_uciset,
	action_ucichanges,
};

#!/bin/sh
printf "Content-Type: application/json; charset=UTF-8\r\nAccess-Control-Allow-Origin: *\r\n\r\n"

CONTENT_LENGTH=${CONTENT_LENGTH:-0}
if [ "$CONTENT_LENGTH" -gt 0 ] 2>/dev/null; then
	POST_DATA=$(head -c "$CONTENT_LENGTH")
else
	POST_DATA=""
fi

ACTION=$(echo "$POST_DATA" | jsonfilter -e '@.action' 2>/dev/null)
PARAMS=$(echo "$POST_DATA" | jsonfilter --strip-bom 2>/dev/null)

case "$ACTION" in
	status)
		RUNNING=0
		pidof nfqws2 >/dev/null 2>&1 && RUNNING=1
		INSTALLED=0
		apk list --installed nfqws2-keenetic >/dev/null 2>&1 && INSTALLED=1
		VERSION=$(apk list --installed nfqws2-keenetic 2>/dev/null | awk '{print $2}' | sed 's/-r[0-9]*$//')
		printf '{"running":%d,"nfqws2":%d,"version":"%s"}' "$RUNNING" "$INSTALLED" "$VERSION"
		;;
	service)
		SVC=$(echo "$POST_DATA" | jsonfilter -e '@.params.action' 2>/dev/null)
		if [ -z "$SVC" ]; then
			printf '{"status":1,"output":["No action specified"]}'
		else
			OUTPUT=$(/etc/init.d/nfqws2 $SVC 2>&1)
			printf '{"status":0,"output":["%s"]}' "$OUTPUT"
		fi
		;;
	filenames)
		FTYPE=$(echo "$POST_DATA" | jsonfilter -e '@.params.type' 2>/dev/null)
		case "$FTYPE" in
			list) BASE_DIR="/etc/nfqws2/lists" ;;
			log) BASE_DIR="/var/log" ;;
			lua) BASE_DIR="/etc/nfqws2/lua" ;;
			*) BASE_DIR="/etc/nfqws2" ;;
		esac
		FILES=""
		if [ -d "$BASE_DIR" ]; then
			for f in "$BASE_DIR"/*; do
				[ -f "$f" ] || continue
				BASENAME=$(basename "$f" .gz)
				EXT="${BASENAME##*.}"
				[ "$EXT" = "$BASENAME" ] && EXT=""
				OK=0
				[ "$FTYPE" = "conf" ] && { [ "$EXT" = "conf" ] || [ "$EXT" = "list" ] || [ "$EXT" = "txt" ]; } && OK=1
				[ "$FTYPE" = "list" ] && [ "$EXT" = "list" ] && OK=1
				[ "$FTYPE" = "lua" ] && [ "$EXT" = "lua" ] && OK=1
				[ "$FTYPE" = "log" ] && echo "$BASENAME" | grep -q "^nfqws" && [ "$EXT" = "log" ] && OK=1
				[ "$OK" = "1" ] && FILES="$FILES\"$BASENAME\","
			done
		fi
		FILES=$(echo "$FILES" | sed 's/,$//')
		printf '{"status":0,"files":[%s]}' "$FILES"
		;;
	filecontent)
		FRNAME=$(echo "$POST_DATA" | jsonfilter -e '@.params.filename' 2>/dev/null)
		[ -z "$FRNAME" ] && printf '{"status":1,"content":""}' && exit 0
		FRBASE=$(echo "$FRNAME" | sed 's/\.gz$//')
		case "$FRBASE" in
			*.list) FPATH="/etc/nfqws2/lists/$FRBASE" ;;
			*.log) FPATH="/var/log/$FRBASE" ;;
			*.lua) FPATH="/etc/nfqws2/lua/$FRBASE" ;;
			*) FPATH="/etc/nfqws2/$FRBASE" ;;
		esac
		if [ -f "$FPATH" ]; then
			CONTENT=$(cat "$FPATH")
			case "$FRBASE" in
				*.log) CONTENT=$(echo "$CONTENT" | grep -v '^$' | tail -500 | tac) ;;
			esac
			printf '{"status":0,"content":"%s","filename":"%s"}' "$CONTENT" "$FRNAME"
		else
			printf '{"status":1,"content":"","filename":"%s"}' "$FRNAME"
		fi
		;;
	savefile)
		FRNAME=$(echo "$POST_DATA" | jsonfilter -e '@.params.filename' 2>/dev/null)
		FCONTENT=$(echo "$POST_DATA" | jsonfilter -e '@.params.content' 2>/dev/null)
		[ -z "$FRNAME" ] && printf '{"status":1,"filename":"%s"}' "$FRNAME" && exit 0
		FRBASE=$(echo "$FRNAME" | sed 's/\.gz$//')
		case "$FRBASE" in
			*.list) FPATH="/etc/nfqws2/lists/$FRBASE" ;;
			*.log) printf '{"status":1,"filename":"%s"}' "$FRNAME" && exit 0 ;;
			*.lua) FPATH="/etc/nfqws2/lua/$FRBASE" ;;
			*) FPATH="/etc/nfqws2/$FRBASE" ;;
		esac
		echo "$FCONTENT" > "$FPATH"
		printf '{"status":0,"filename":"%s"}' "$FRNAME"
		;;
	createfile)
		FRNAME=$(echo "$POST_DATA" | jsonfilter -e '@.params.filename' 2>/dev/null)
		echo "$FRNAME" | grep -qE '^[a-zA-Z0-9_%-]+\.(list|lua|conf)$' || { printf '{"status":1,"filename":"%s"}' "$FRNAME"; exit 0; }
		FRBASE=$(echo "$FRNAME" | sed 's/\.gz$//')
		case "$FRBASE" in
			*.list) FPATH="/etc/nfqws2/lists/$FRBASE" ;;
			*.lua) FPATH="/etc/nfqws2/lua/$FRBASE" ;;
			*) FPATH="/etc/nfqws2/$FRBASE" ;;
		esac
		[ -f "$FPATH" ] && printf '{"status":1,"filename":"%s"}' "$FRNAME" && exit 0
		touch "$FPATH" && printf '{"status":0,"filename":"%s"}' "$FRNAME" || printf '{"status":1,"filename":"%s"}' "$FRNAME"
		;;
	removefile)
		FRNAME=$(echo "$POST_DATA" | jsonfilter -e '@.params.filename' 2>/dev/null)
		[ -z "$FRNAME" ] && printf '{"status":1,"filename":""}' && exit 0
		FRBASE=$(echo "$FRNAME" | sed 's/\.gz$//')
		case "$FRBASE" in
			*.list) FPATH="/etc/nfqws2/lists/$FRBASE" ;;
			*.log) FPATH="/var/log/$FRBASE" ;;
			*.lua) FPATH="/etc/nfqws2/lua/$FRBASE" ;;
			*) FPATH="/etc/nfqws2/$FRBASE" ;;
		esac
		[ -f "$FPATH" ] && rm -f "$FPATH" && printf '{"status":0,"filename":"%s"}' "$FRNAME" || printf '{"status":1,"filename":"%s"}' "$FRNAME"
		;;
	checkdomain)
		URL=$(echo "$POST_DATA" | jsonfilter -e '@.params.url' 2>/dev/null)
		[ -z "$URL" ] && printf '{"status":1,"result":false}' && exit 0
		[ -x "/usr/bin/curl" ] || { printf '{"status":0,"result":false,"note":"curl not installed"}'; exit 0; }
		LINE=$(curl -sIL --max-time 5 --max-redirs 5 "$URL" 2>/dev/null | head -1)
		echo "$LINE" | grep -qE '^HTTP/[0-9]+\.[0-9]+ [0-9]+' && printf '{"status":0,"result":true}' || printf '{"status":0,"result":false}'
		;;
	upgrade)
		OUTPUT=$(apk --update-cache upgrade nfqws2-keenetic 2>&1)
		[ -z "$OUTPUT" ] && OUTPUT="Nothing to update"
		printf '{"status":0,"output":["%s"]}' "$OUTPUT"
		;;
	uciget)
		OPTION=$(echo "$POST_DATA" | jsonfilter -e '@.params.option' 2>/dev/null)
		[ -z "$OPTION" ] && printf '{"status":1,"value":""}' && exit 0
		VAL=$(uci get nfqws2.$OPTION 2>/dev/null)
		printf '{"status":0,"value":"%s"}' "$VAL"
		;;
	uciset)
		OPTION=$(echo "$POST_DATA" | jsonfilter -e '@.params.option' 2>/dev/null)
		VALUE=$(echo "$POST_DATA" | jsonfilter -e '@.params.value' 2>/dev/null)
		[ -z "$OPTION" ] && printf '{"status":1}' && exit 0
		OUT=$(uci set "nfqws2.${OPTION}='${VALUE}'" && uci commit nfqws2 2>&1)
		[ -z "$OUT" ] && printf '{"status":0}' || printf '{"status":1,"output":"%s"}' "$OUT"
		;;
	ucichanges)
		CHANGES=$(uci changes nfqws2 2>&1)
		printf '{"status":0,"changes":["%s"]}' "$CHANGES"
		;;
	*)
		printf '{"status":1,"error":"unknown action: %s"}' "$ACTION"
		;;
esac

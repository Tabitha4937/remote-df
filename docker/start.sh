#!/usr/bin/env bash
# Boot the display stack, audio streaming, then Dwarf Fortress.
#
# We use TigerVNC's Xvnc (a real X server with integrated VNC) for display+VNC.
# The SDL2/XInput2 input problem (cursor never registers over VNC) is handled in
# the Dockerfile by shadowing libXi for DF (see there); no X-server flag works
# because Xvnc refuses to disable the XInput extension at runtime.
#
# Audio: PulseAudio virtual sink -> ffmpeg Opus encode -> Icecast (:8000) ->
# nginx /audio. Icecast fans the stream out to many listeners and survives
# reloads/reconnects (ffmpeg's old `-listen 1` server handled only one client).
#
# DF is auto-restarted if it exits/crashes (a streamed instance should return
# to the title, not die), and auto-paused (SIGSTOP) when no one is connected.
set -u

export DISPLAY=:99
# Geometry must be >= DF's window or the bottom clips; matchbox maximizes it.
GEOM="${GEOM:-1280x800}"
VNC_PORT="${VNC_PORT:-5900}"
WEB_PORT="${WEB_PORT:-6080}"

# DF v50 saves to the XDG user-data dir (root's home in the container).
SAVE_DIR="/root/.local/share/Bay 12 Games/Dwarf Fortress/save"
# Periodic save backups (tarballs). 0 disables. Keep the newest N.
BACKUP_DIR="${BACKUP_DIR:-/backups}"
BACKUP_INTERVAL="${BACKUP_INTERVAL:-1800}"
BACKUP_KEEP="${BACKUP_KEEP:-48}"
# Auto-pause dwarfort when no VNC client is connected (saves CPU). Set to 0 to
# keep the simulation running while disconnected. IDLE_GRACE seconds of no
# clients before pausing.
DF_AUTOPAUSE="${DF_AUTOPAUSE:-1}"
IDLE_GRACE="${IDLE_GRACE:-30}"

mkdir -p /var/log/df "$BACKUP_DIR"

# --- PulseAudio virtual sink ------------------------------------------------
echo "[start] PulseAudio (virtual sink, no hardware needed)"
export XDG_RUNTIME_DIR=/tmp/pulse-runtime
mkdir -p "$XDG_RUNTIME_DIR"
# Minimal PulseAudio config: null sink (no real audio device), TCP disabled.
pulseaudio --daemonize --exit-idle-time=-1 \
  --load="module-null-sink sink_name=virtual_out sink_properties=device.description=VirtualOutput" \
  --load="module-always-sink" \
  >/var/log/df/pulse.log 2>&1 || true
# Wait for PulseAudio to come up.
for _ in $(seq 1 50); do
  pactl info >/dev/null 2>&1 && break
  sleep 0.1
done
# Set the virtual sink as default so SDL/fmod use it.
pactl set-default-sink virtual_out 2>/dev/null || true

# --- Audio: Icecast fan-out + ffmpeg source ---------------------------------
# Icecast accepts the ffmpeg source on /df.ogg and serves it to many listeners
# (nginx proxies it at /audio). Bound to loopback in docker/icecast.xml.
echo "[start] Icecast audio server on internal :8000 (/df.ogg)"
icecast2 -c /etc/icecast2/icecast.xml >/var/log/df/icecast.log 2>&1 &
# Wait for Icecast to accept connections before ffmpeg tries to push to it.
# Any HTTP response means it's listening (the root path itself may 404).
for _ in $(seq 1 50); do
  curl -s -o /dev/null "http://127.0.0.1:8000/" 2>/dev/null && break
  sleep 0.1
done

# Ogg/Opus: best cross-browser support (Firefox, Chrome, Edge). ffmpeg reads the
# PulseAudio monitor and pushes to Icecast as a source. Supervised: if it drops
# (PulseAudio hiccup, Icecast restart) it reconnects, and Icecast keeps serving.
echo "[start] audio source (Ogg/Opus via ffmpeg -> Icecast); auto-restart on exit"
(
  while true; do
    ffmpeg -nostdin -f pulse -i virtual_out.monitor \
      -ac 2 -b:a 96k -c:a libopus -f ogg \
      -content_type audio/ogg \
      "icecast://source:dfsource@127.0.0.1:8000/df.ogg" \
      >>/var/log/df/audio.log 2>&1
    echo "[start] !!! ffmpeg audio source exited rc=$? — reconnecting in 1s" >>/var/log/df/audio.log
    sleep 1
  done
) &

# --- Periodic save backups --------------------------------------------------
# Tarball the save dir on an interval and keep the newest BACKUP_KEEP. Browse
# and download them at /backups (see nginx.conf). BACKUP_INTERVAL=0 disables.
if [ "$BACKUP_INTERVAL" -gt 0 ] 2>/dev/null; then
  echo "[start] save backups every ${BACKUP_INTERVAL}s -> $BACKUP_DIR (keep $BACKUP_KEEP)"
  (
    while true; do
      sleep "$BACKUP_INTERVAL"
      # Only back up if there's actually a save to capture.
      if [ -d "$SAVE_DIR" ] && [ -n "$(ls -A "$SAVE_DIR" 2>/dev/null)" ]; then
        ts=$(date +%Y%m%d-%H%M%S)
        tmp="$BACKUP_DIR/.df-saves-$ts.tar.gz.tmp"
        if tar -czf "$tmp" -C "$SAVE_DIR" . 2>>/var/log/df/backup.log; then
          mv -f "$tmp" "$BACKUP_DIR/df-saves-$ts.tar.gz"
          echo "[backup] wrote df-saves-$ts.tar.gz" >>/var/log/df/backup.log
        else
          rm -f "$tmp"
          echo "[backup] FAILED at $ts" >>/var/log/df/backup.log
        fi
        # Rotate: delete all but the newest BACKUP_KEEP archives.
        ls -1t "$BACKUP_DIR"/df-saves-*.tar.gz 2>/dev/null \
          | tail -n +"$((BACKUP_KEEP + 1))" | xargs -r rm -f
      fi
    done
  ) >/dev/null 2>&1 &
fi

echo "[start] Xvnc ${GEOM} on :99 (rfb :$VNC_PORT)"
Xvnc :99 -geometry "$GEOM" -depth 24 \
     -SecurityTypes None -AlwaysShared -rfbport "$VNC_PORT" \
     -desktop DwarfFortress >/var/log/df/xvnc.log 2>&1 &

# Wait for the X server to accept connections.
for _ in $(seq 1 100); do
  xdpyinfo -display :99 >/dev/null 2>&1 && break
  sleep 0.1
done
if ! xdpyinfo -display :99 >/dev/null 2>&1; then
  echo "[start] ERROR: Xvnc did not come up"; cat /var/log/df/xvnc.log || true
fi

echo "[start] keep keyboard focus on the DF window (no reparenting WM)"
( while true; do
    WID=$(DISPLAY=:99 xdotool search --name "Dwarf Fortress" 2>/dev/null | head -1)
    [ -n "$WID" ] && DISPLAY=:99 xdotool windowfocus "$WID" 2>/dev/null
    sleep 2
  done ) >/var/log/df/focus.log 2>&1 &

echo "[start] noVNC/websockify on internal :6081 -> localhost:$VNC_PORT"
websockify 6081 "localhost:$VNC_PORT" \
       >/var/log/df/websockify.log 2>&1 &

echo "[start] nginx on :$WEB_PORT (noVNC + audio unified)"
nginx -g 'daemon off;' >/var/log/df/nginx.log 2>&1 &

echo "[start] launching Dwarf Fortress (PRINT_MODE:2D, SOUND:YES); auto-restart on exit"
cd /opt/df
EDITION=$(cat /opt/df/.edition 2>/dev/null || echo classic)
(
  while true; do
    if [ "$EDITION" = "classic" ] && [ -f ./hack/libdfhack.so ]; then
      # Load DFHack via LD_PRELOAD directly, bypassing the dfhack launcher
      # script whose setarch call fails in Docker (no SYS_ADMIN capability).
      LD_PRELOAD=./hack/libdfhack.so \
      LD_LIBRARY_PATH=/opt/df:./hack/libs:./hack \
        ./dwarfort >>/var/log/df/df.log 2>&1
    else
      LD_LIBRARY_PATH=/opt/df ./dwarfort >>/var/log/df/df.log 2>&1
    fi
    echo "[start] !!! dwarfort exited rc=$? — restarting in 2s" >>/var/log/df/df.log
    sleep 2
  done
) &

# --- Idle auto-pause --------------------------------------------------------
# Freeze dwarfort (SIGSTOP) when no VNC client is connected, resume (SIGCONT)
# when one is. websockify only holds a connection to the VNC port while a
# browser is attached, so the count of established sockets on $VNC_PORT tells us
# whether anyone is watching. Set DF_AUTOPAUSE=0 to keep the sim running.
if [ "$DF_AUTOPAUSE" = "1" ]; then
  echo "[start] idle auto-pause on (grace ${IDLE_GRACE}s; DF_AUTOPAUSE=0 to disable)"
  (
    poll=5
    idle=0
    paused=0
    while true; do
      sleep "$poll"
      clients=$(ss -Htn state established "sport = :$VNC_PORT" 2>/dev/null | wc -l)
      if [ "$clients" -gt 0 ]; then
        idle=0
        if [ "$paused" = 1 ]; then
          pkill -CONT -x dwarfort 2>/dev/null && echo "[pause] client connected — resumed" >>/var/log/df/pause.log
          paused=0
        fi
      elif [ "$paused" = 0 ]; then
        idle=$((idle + poll))
        if [ "$idle" -ge "$IDLE_GRACE" ]; then
          pkill -STOP -x dwarfort 2>/dev/null && echo "[pause] no clients ${IDLE_GRACE}s — paused" >>/var/log/df/pause.log
          paused=1
        fi
      fi
    done
  ) >/dev/null 2>&1 &
fi

exec tail -F /var/log/df/df.log /var/log/df/xvnc.log /var/log/df/audio.log \
            /var/log/df/icecast.log /var/log/df/nginx.log 2>/dev/null

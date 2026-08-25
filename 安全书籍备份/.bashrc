source device_panel.sh & 2>/dev/null
PS1='\[\033[1;34m\]\n┌─【Termux设备信息-BY LIUZHOU】
├[ Last Command: $LAST_CMD ]
├[ Last Running Time: $LAST_EXEC_TIME | Last Used Time: $LAST_USED_SEC ]
├[ Device: $BRAND $MODEL | Android: $ANDROID_VER ($ANDROID_CODENAME) ]
├[ CPU: $CPU_MODEL | $CPU_LOAD_MONITOR | Screen Size: $DISPLAY_INFO | AppNumber: ${APP_NUM} ]
├[ Storage: ${HARD_DISK_SPACE} | Camera Max: $CAM_SIZE ]
├[ Memory Monitor: $MEMORY_MONITOR ]
├[ Battery Monitor: $BATTERY_MONITOR ]
├[ Temperature Monitor: Battery: $BAT_TEMP, CPU: $CPU_TEMP ]
├[ Lightness Monitor: $LIGHTNESS_MONITOR ]
├[ Step Counter: $STEP_COUNT | Step Detector: $STEP_DETECTOR ]
├[\[\033[1;32m\]\u Device model: $DEVICE_MODEL Android System Version: Android $ANDROID_VER Time: \t Date: \d\[\033[1;34m\]]─[\[\033[1;35m\]\w\[\033[1;34m\]]\n└─\[\033[1;31m\]❯ \[\033[0m\]请输入：'
# 每次显示提示符前，加载最新的变量文件
PROMPT_COMMAND='source $PREFIX/tmp/device_vars 2>/dev/null'
pkg upgrade -y
export LANG=zh_CN.UTF-8
export LC_ALL=zh_CN.UTF-8
export LANG=C.UTF-8
export LC_ALL=C.UTF-8
export PATH="$HOME/.local/bin:$PATH"
export DISPLAY=:0
termux-x11 :0 -xstartup "dbus-launch --exit-with-session xfce4-session" &
pulseaudio --start --exit-idle-time=-1
# 生成一次静音文件（永久保存）
ffmpeg -y -f lavfi -i anullsrc=r=8000:cl=mono -t 65 ~/silence.amr
# 无限循环播放，让系统以为一直有音频输出
( while true; do termux-media-player play ~/.silence.amr 2>/dev/null; sleep 55; done ) >/dev/null 2>&1 &
#bash-/data/data/com.termux/files/home/.bashrc
export HISTTIMEFORMAT="%Y-%m-%d %H:%M:%S "

clear
echo "Welcome to Termux!

Docs:       https://termux.dev/docs
Donate:     https://termux.dev/donate
Community:  https://termux.dev/community

Working with packages:

 - Search:  pkg search <query>
 - Install: pkg install <package>
 - Upgrade: pkg upgrade

Subscribing to additional repositories:

 - Root:    pkg install root-repo
 - X11:     pkg install x11-repo

For fixing any repository issues,
try 'termux-change-repo' command.

Report issues at https://termux.dev/issues"
sleep 3
echo "Welcome to Termux!

Docs:       https://termux.dev/docs
Donate:     https://termux.dev/donate
Community:  https://termux.dev/community

Working with packages:

 - Search:  pkg search <query>
 - Install: pkg install <package>
 - Upgrade: pkg upgrade

Subscribing to additional repositories:

 - Root:    pkg install root-repo
 - X11:     pkg install x11-repo

For fixing any repository issues,
try 'termux-change-repo' command.

Report issues at https://termux.dev/issues"
sleep 3
echo "Welcome to Termux!

Docs:       https://termux.dev/docs
Donate:     https://termux.dev/donate
Community:  https://termux.dev/community

Working with packages:

 - Search:  pkg search <query>
 - Install: pkg install <package>
 - Upgrade: pkg upgrade

Subscribing to additional repositories:

 - Root:    pkg install root-repo
 - X11:     pkg install x11-repo

For fixing any repository issues,
try 'termux-change-repo' command.

Report issues at https://termux.dev/issues"

fish
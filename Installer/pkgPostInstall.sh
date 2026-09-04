#!/bin/sh

TARGET='vChewing'
login_user=$(/usr/bin/stat -f%Su /dev/console)

OS_Version=$(sw_vers -productVersion)
##### if [[ ${OS_Version} < 12.0.0 ]]; then
  # Copy the wrongfully installed contents to the right location:
  cp -r /Library/Input\ Methods/"${TARGET}".app /Users/"${login_user}"/Library/Input\ Methods/ || true
  cp -r /Library/Keyboard\ Layouts/"${TARGET}"* /Users/"${login_user}"/Library/Keyboard\ Layouts/ || true

  # Clean the wrongfully installed contents:
  chown "${login_user}" /Users/"${login_user}"/Library/Input\ Methods/"${TARGET}".app || true
  chown "${login_user}" /Users/"${login_user}"/Library/Keyboard\ Layouts/"${TARGET}"* || true
  sleep 1
  rm -rf /Library/Input\ Methods/"${TARGET}".app || true
  rm -rf /Library/Keyboard\ Layouts/"${TARGET}"* || true
  sleep 1
##### fi

# Terminate the text input menu agent (TextInputMenuAgent) before registering the
# input method: the register step must wait for the kill to finish (regardless of
# its outcome) plus 0.5s, so the relaunched agent can pick up the newly registered
# input source without requiring the user to log out and back in. Only
# TextInputMenuAgent is targeted: killing imklaunchagent would cut the currently
# active client app off from every input method until that app is restarted, while
# TextInputSwitcher is a pure UI helper whose termination has no effect. This
# agent belongs to the console user's GUI session, so the kill is performed with
# the console user's privileges when the installer runs as root. The agent may not
# exist on older macOS versions; ignore any failure.
if [ "$(id -u)" -eq 0 ]; then
    su - "${login_user}" -c "/usr/bin/killall TextInputMenuAgent" 2>/dev/null || true
else
    /usr/bin/killall TextInputMenuAgent 2>/dev/null || true
fi
sleep 0.5

# Finally, register the input method:
/Users/"${login_user}"/Library/Input\ Methods/"${TARGET}".app/Contents/MacOS/"${TARGET}" install --all || true

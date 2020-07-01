#!/bin/sh

# <chatbot-sh-preamble>
#
#  CHATBOT_PYTHON               (u) python interpreter path.
#  CHATBOT_LINUX_VER            (u) version of Linux system.
#  GOOGLE_CLOUD_SDK_URL         (u) url for download archive file of Google Cloud SDK.
#

# define variable for ChoChae CB.
# URL for 64 bits system.
URL_64b="https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-298.0.0-linux-x86_64.tar.gz"
# URL for 32 bits system.
URL_32b="https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-298.0.0-linux-x86.tar.gz"
# Account Key name.
Key_json="chatbot-account-key.json"
# Account name.
Account="pwuttichok"
#Project_ID.
Project_id="speechtotext-1591699844670"
# Verification code.
Verify_cd="4/1QHGBVis_j-pFidIaGH1VBoZPddHSc_6YedvklOIXyXqqrXDZaAQ"


# Wrapper around 'which' and 'command -v', tries which first, then falls back
# to command -v
_which() {
        which "$1" 2>/dev/null || command -v "$1" 2>/dev/null
}

# Check whether passed in python command reports major version 3, and requires Python 3.5+.
_is_python3() {
        echo "$("$1" -V 2>&1)" | grep -E "Python 3[.]([5-9])"
}

# Check version of Linux system for download right Google Cloud SDK's version.
_is_32bitsys() {
        echo "$(uname -m 2>&1)" | grep -E "armv7l"
}

_check_V_linuxsys() {
        if [ -z "$CHATBOT_LINUX_VER" ]; then
                if _is_32bitsys >/dev/null; then
                        CHATBOT_LINUX_VER=32b
                else
                        CHATBOT_LINUX_VER=64b
                fi
        fi
        #echo " "
        #echo "Linux system is"$CHATBOT_LINUX_VER
}

_check_installed_modpy() {
        for python_module in "$@"
        do
                echo "$(pip list 2>&1)" | grep "$python_module" >/dev/null || unavailable_mod="Didn't install this Module"
        done
}

_find_f() {
        echo "$(find / -name "$1" 2>&1)" | grep "$1" >/dev/null
}

_gcloud_init() {
        if _which gcloud >/dev/null; then
                # Install usage Google Cloud components.
                yes | gcloud components install app-engine-python app-engine-python-extras kubectl

                gcloud init

                # Make ChoChae CB's directory.
                if ! _find_f chatbot; then
                        mkdir ~/Desktop/hub_demo/chatbot && cd ~/Desktop/hub_demo/chatbot
                else
                        cd ~/Desktop/hub_demo/chatbot
                fi

                if ! _find_f "$Key_json"; then
                        gcloud iam service-accounts keys create "$Key_json" --iam-account "$Account"@"$Project_id".iam.gserviceaccount.com
                fi

                export GOOGLE_APPLICATION_CREDENTIALS=$PWD/"$Key_json"
        fi
}

do_install() {
        echo "Welcome to ChoChae Chatbot Installer."
        # Update and Upgrade firmware in Device.
        echo "Update & Upgrade Raspberry PI's firmware."
        yes | sudo apt-get update >/dev/null && yes | sudo apt-get upgrade >/dev/null

        # Check Python version
        while :
        do
                if [ -z "$CHATBOT_PYTHON" ]; then
                        if _which python3 >/dev/null && _is_python3 python3 >/dev/null; then
                                CHATBOT_PYTHON=python3
                                echo "Python 3 has already been installed"
                                break
                        else
                                echo "Install Python 3"
                                yes | sudo apt-get install python3.7
                        fi
                fi
        done

        echo "$CHATBOT_PYTHON"

        # Install other module of Python for use in ChoChae CB.
        if [ $(_check_installed_modpy PyAudio Wave six RPi.GPIO) ] && [ -n "$unavailable_mod" ]; then
                yes | "$CHATBOT_PYTHON" -m pip install pyaudio wave six  RPi.GPIO >/dev/null
                echo "Additional Python module for ChoChae CB's project installation completed"
        else
                echo "Additional Python module for ChoChae CB's project has already been installed"
        fi

        # Install Google Cloud Library for Chochae CB.
        if [ $(_check_installed_modpy google-cloud0speech google-cloud-texttospeech) ] && [ -n "$unavailable_mod" ]; then
                yes | "$CHATBOT_PYTHON" -m pip install google-cloud-speech google-cloud-texttospeech >/dev/null
                echo "Google Cloud Python module for ChoChae CB's project installation completed"
        else
                echo "Google Cloud Python module for ChoChae CB's project has already been installed"
        fi

        while :
        do
                if [ -z "$CHATBOT_LINUX_VER" ]; then
                        _check_V_linuxsys
                elif [ -z "$GOOGLE_CLOUD_SDK_URL" ]; then
                        case "$CHATBOT_LINUX_VER" in
                        32b)    GOOGLE_CLOUD_SDK_URL=$URL_32b
                                #echo "Linux 32 bits"
                                ;;
                        64b)    GOOGLE_CLOUD_SDK_URL=$URL_64b
                                #echo "Linux 64 bits"
                                ;;
                        *)      ;;
                        esac
                        break
                fi
        done

        #echo "$GOOGLE_CLOUD_SDK_URL"

        # Move to Home directory for download archive file of Google Cloud SDK.
        cd ~
        Filename_gz=$(echo "$GOOGLE_CLOUD_SDK_URL" | cut -d/ -f9-)
        if ! _find_f Filename_gz; then
                curl -O "$GOOGLE_CLOUD_SDK_URL" >/dev/null
                # Extract the archive file.
                yes | tar zxvf "$Filename_gz" google-cloud-sdk >/dev/null
        fi

        # Run Google Cloud SDK installer.
        yes | sudo sh ./google-cloud-sdk/install.sh
}

do_install
_gcloud_init
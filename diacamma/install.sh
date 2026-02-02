#!/usr/bin/env bash

if [ "$(id -u)" != "0" ]; then
   echo ">>> This script must be run as 'super user' <<<" 1>&2
   [ -z "$(which sudo)" ] && exit 1
   sudo -E -H $0 $@
   exit $!
fi

PACKAGES="lucterios lucterios-standard lucterios-contacts lucterios-documents diacamma-asso diacamma-syndic diacamma-financial"
APP_NAME="Diacamma"

function usage
{
	echo "${0##*/}: installation for Diacamma"
	echo "	${0##*/} -h"
	echo "	${0##*/} [-p <packages>] [-n <application_name>]"
	echo "option:"
	echo " -h: show this help"
	echo " -p: define the packages list to install (default: '$PACKAGES')"
	echo " -n: define the application name for shortcut (default: '$APP_NAME')"
	exit 0
}

function finish_error
{
	msg=$1
	echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!">&2
	echo " Error: $msg">&2
	echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!">&2
	exit 1
}

while getopts "i:p:n:h" opt ; do
    case $opt in
    p) PACKAGES="$OPTARG"
       ;;
    n) APP_NAME="$OPTARG"
       ;;
    h) usage $0
       exit 0
       ;;
   \?) finish_error "Unrecognized parameter -$OPTARG"
       ;;
    :) finish_error "Option -$OPTARG requires an argument."
       ;;
    esac
done

PIP_OPTION=""
if [ ! -z "$http_proxy" ]
then
	PIP_OPTION="$PIP_OPTION --proxy=$http_proxy"
fi

echo "====== install Diacamma #25010609 ======"

echo "install: packages=$PACKAGES application_name=$APP_NAME"

echo
echo "------ check perquisite -------"
echo

if [ ! -z "$(which apt-get 2>/dev/null)" ]; then  # DEB linux like
	apt-get install -y libxml2-dev libxslt-dev libjpeg-dev libfreetype6 libfreetype6-dev zlib1g-dev
	apt-get install -y python3-pip python3-dev 
	apt-get install -y python3-tk 'python3-imaging|python3-pil'
	apt-get install -y pipx python3-dev default-libmysqlclient-dev build-essential pkg-config
	apt-get install -y libxcb-cursor-dev
	apt-get install -y "python3-virtualenv" || echo 'no venv'
else if [ ! -z "$(which dnf 2>/dev/null)" ]; then # RPM unix/linux like
	dnf install -y libxml2-devel libxslt-devel libjpeg-devel gcc
	dnf install -y libfreetype6 libfreetype6-devel
	dnf install -y python3-devel python3-imaging python3-tkinter
else if [ ! -z "$(which yum 2>/dev/null)" ]; then # RPM unix/linux like
	yum install -y epel-release
	yum install -y libxml2-devel libxslt-devel libjpeg-devel gcc
	yum install -y python38-devel python38-imaging python38-tkinter	python38-setuptools
	easy_install-3.8 pip
else
	echo "++++++ Unix/Linux distribution not available for this script! +++++++"
fi; fi; fi

echo
echo "------ configure virtual environment ------"
echo

LUCTERIOS_PATH="/var/lucterios2"
[ -z "$(which "pip3")" ] && echo "No pip3 found!" && exit 1

py_version=$(python3 --version | egrep -o '([0-9]+\.[0-9]+)')
if [ "$py_version" != "3.7" -a "$py_version" != "3.8" -a "$py_version" != "3.9" -a "$py_version" != "3.10" -a "$py_version" != "3.11" -a "$py_version" != "3.12" ]
then
    finish_error "Not Python 3.7, 3.8, 3.9, 3.10, 3.11 or 3.12 (but $py_version) !"
fi

PYTHON_CMD="python3"

set -e

echo "$PYTHON_CMD -m pip install -U $PIP_OPTION pip virtualenv"
$PYTHON_CMD -m pip install -U $PIP_OPTION pip || echo "** no install pip **"
if [ -z "$($PYTHON_CMD -m virtualenv -h)" ]
then
    $PYTHON_CMD -m pip install -U $PIP_OPTION virtualenv || echo "** no install virtualenv **"
fi

mkdir -p $LUCTERIOS_PATH
cd $LUCTERIOS_PATH
echo "$PYTHON_CMD -m virtualenv virtual_for_lucterios"
rm -rf virtual_for_lucterios
$PYTHON_CMD -m virtualenv virtual_for_lucterios

echo
echo "------ install Diacamma ------"
echo

. $LUCTERIOS_PATH/virtual_for_lucterios/bin/activate
pip install -U $PIP_OPTION pip
pip uninstall PIL
pip uninstall Pillow
pip install -U $PIP_OPTION $PACKAGES
pip install gunicorn

[ -z "$(pip list 2>/dev/null | grep 'Django ')" ] && finish_error "Django not installed !"
[ -z "$(pip list 2>/dev/null | grep 'lucterios ')" ]&& finish_error "Lucterios not installed !"

lucterios_admin.py update || lucterios_admin.py refreshall || echo '--no update/refresh--'
[ -f "$LUCTERIOS_PATH/extra_url" ] || echo "# Pypi server" > "$LUCTERIOS_PATH/extra_url"

echo
echo "------ refresh shortcut ------"
echo
rm -rf $LUCTERIOS_PATH/launch_lucterios.sh
touch $LUCTERIOS_PATH/launch_lucterios.sh
echo "#!/usr/bin/env bash" >> $LUCTERIOS_PATH/launch_lucterios.sh
echo  >> $LUCTERIOS_PATH/launch_lucterios.sh
echo "export LUCTERIOS_INSTALL='25010609'" >> $LUCTERIOS_PATH/launch_lucterios.sh
echo  >> $LUCTERIOS_PATH/launch_lucterios.sh
echo ". $LUCTERIOS_PATH/virtual_for_lucterios/bin/activate" >> $LUCTERIOS_PATH/launch_lucterios.sh
echo "cd $LUCTERIOS_PATH/" >> $LUCTERIOS_PATH/launch_lucterios.sh
if [ -z "$LANG" -o "$LANG" == "C" ]
then
	echo "export LANG=en_US.UTF-8" >> $LUCTERIOS_PATH/launch_lucterios.sh
fi

qt_version=$($PYTHON_CMD -c 'from PyQt6.QtCore import QT_VERSION_STR;print(QT_VERSION_STR)' 2>/dev/null) 

cp $LUCTERIOS_PATH/launch_lucterios.sh $LUCTERIOS_PATH/launch_lucterios_gui.sh
echo "lucterios_gui.py" >> $LUCTERIOS_PATH/launch_lucterios_gui.sh
chmod +x $LUCTERIOS_PATH/launch_lucterios_gui.sh

cp $LUCTERIOS_PATH/launch_lucterios.sh $LUCTERIOS_PATH/launch_lucterios_qt.sh
echo "lucterios_qt.py" >> $LUCTERIOS_PATH/launch_lucterios_qt.sh
chmod +x $LUCTERIOS_PATH/launch_lucterios_qt.sh

echo 'lucterios_admin.py $@' >> $LUCTERIOS_PATH/launch_lucterios.sh
chmod +x $LUCTERIOS_PATH/launch_lucterios.sh
chmod -R ogu+w $LUCTERIOS_PATH

ln -sf $LUCTERIOS_PATH/launch_lucterios.sh /usr/local/bin/launch_lucterios
ln -sf $LUCTERIOS_PATH/launch_lucterios_gui.sh /usr/local/bin/launch_lucterios_gui
ln -sf $LUCTERIOS_PATH/launch_lucterios_qt.sh /usr/local/bin/launch_lucterios_qt


icon_path=$(find "$LUCTERIOS_PATH/virtual_for_lucterios" -name "$APP_NAME.png" | head -n 1)

if [ -d "/usr/share/applications" ]
then
	LAUNCHER="/usr/share/applications/lucterios.desktop"
	echo "[Desktop Entry]" > $LAUNCHER
	echo "Name=$APP_NAME" >> $LAUNCHER
	echo "Comment=$APP_NAME installer" >> $LAUNCHER
	if [ "${qt_version:0:2}" == "6." ]
	then
		echo "Exec=$LUCTERIOS_PATH/launch_lucterios_qt.sh" >> $LAUNCHER
	else
		echo "Exec=$LUCTERIOS_PATH/launch_lucterios_gui.sh" >> $LAUNCHER
	fi
	echo "Icon=$icon_path" >> $LAUNCHER
	echo "Terminal=false" >> $LAUNCHER
	echo "Type=Application" >> $LAUNCHER
	echo "Categories=Office" >> $LAUNCHER
fi

chmod -R ogu+rw "$LUCTERIOS_PATH"

echo "============ END ============="

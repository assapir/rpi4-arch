#!/usr/bin/env bash


####################################################################################
# rpi4-arch-install.sh
# --------------------
#
# Prepare an HD with ArchLinux ARM
# Original writer: Pablo Navais
#
####################################################################################
VERSION="0.5.0"


# Globals
##########
FILE_NAME="ArchLinuxARM-rpi-aarch64-latest.tar.gz"
IMAGE_URL="http://os.archlinuxarm.org/os/$FILE_NAME"

SUDO="sudo"

DEFAULT_PER_W=50
RES_OK="\xE2\x9C\x94"   		#"\u2714";
RES_FAIL="\xE2\x9C\x96" 		#"\u2716";
RES_WARN="\xE2\x9A\xA0" 		#"\u2716";
SAD_FACE="\xE2\x98\xB9"     #"\u2639";

# Functions
###########

###################################
# Shows a heading section
# Params:
# - (1) section : Section's name
###################################
function showSection() {
	printf "\n\e[1;34m==> \e[1;37m$1\e[0m\n";
}

###################################
# Shows a sub section
# Params:
# - (1) subsection : Subsection's name
###################################
function showSubSection() {
	printf "\n\e[1;32m==> \e[1;37m$1\e[0m\n";
}

###################################
# Shows the result of an operation
###################################
function showResult() {
	local err=${1-$?};
	local msg=$2
	if [[ $err -eq 0 ]]; then
		success "$RES_OK";
		if [ -n "$msg" ]; then
			warn " $msg"
		fi
		printf "\n";
	else
		fail "$RES_FAIL\n";
	fi
}

###################################
# Shows the result of an operation
# and exit if return code not 0
###################################
function showResultOrExit() {
	local err=$?;
	local msg=$1;
	showResult "$err" "$msg";
	if [[ $err -ne 0 ]]; then
		if [ -n "$msg" ]; then
			fail "$msg\n";
		fi

		cleanup;
		exit -1;
	fi
}

#######################################
# Shows a success message (Green color)
# Params:
# - (1) msg : String to show
#######################################
function success() {
	printf "\e[0;32m$1\e[0m";
}

#######################################
# Shows a fail message (Red color)
# Params:
# - (1) msg : String to show
#######################################
function fail() {
	printf "\e[0;31m$1\e[0m";
}

#######################################
# Shows a debug message (Yellow color)
# Params:
# - (1) msg : String to show
#######################################
function debug() {
	printf "\e[0;33m$1\e[0m";
}

#######################################
# Shows an info message (Cyan color)
# Params:
# - (1) msg : String to show
#######################################
function info() {
	printf "\e[0;36m$1\e[0m";
}

#######################################
# Shows a warning message (Yellow color)
# Params:
# - (1) msg : String to show
#######################################
function warn() {
	debug "$1"
}

##############################################
# Pads a message with the given character
# up to a maximum size,
# Params:
#   - (1) msg          : The message to pad
#   - (2) max_padding  : The maximum length to pad
#   - (3) padding_char : The character used in
#                        the padding.
##############################################
function paddingMax() {
	local msg=$1;
	local max_padding=$2;
	local padding_char=$3;
	local stripped_msg=$(stripAnsi "$msg");
	local cur_size=${#stripped_msg};

	while [ $cur_size -lt $max_padding ]; do
		let cur_size+=1;
		msg=${msg}${padding_char};
	done

	echo "$msg";
}

##############################################
# Pads a message with the given character
# up to the percentage of maximum terminal
# available width.
#
# params:
#   - (1) msg          : the message to pad
#   - (2) width_ratio  : the width percentage
#   - (3) padding_char : the character used in
#                        the padding.
##############################################
function padding() {
	local msg=$1;
	local width_ratio=$2;
	local padding_char=$3;
	local stripped_msg=$(stripAnsi "$msg");
	local cur_size=${#stripped_msg};
	local max_width=$(tput cols);
	local max_padding=$((max_width*width_ratio/100));

	while [ $cur_size -lt $max_padding ]; do
		let cur_size+=1;
		msg=${msg}${padding_char};
	done

	printf "$msg";
}

##############################################
# Pads a message with the given characters
# up to the percentage of maximum terminal
# available width.
#
# params:
#   - (1) msg          : the message to pad
##############################################
function pad() {
	padding "$1" $DEFAULT_PER_W '.';
}

##############################################
# Removes ANSI sequences from a given String
# Params:
# - (1) msg : String to remove ANSI sequences
##############################################
function stripAnsi() {
	echo -e $1 | sed "s,\x1B\[[0-9;]*[a-zA-Z],,g";
}

##############################################
# Moves the cursor to the maximum width
# in the current line
##############################################
function move_to_max_width() {
	max_width=$(tput cols);
	max_padding=$((max_width*$DEFAULT_PER_W/100));
	tput cuf $max_padding
}

##############################################
# Shows the help message
##############################################
function show_help() {
	debug "\nPayball's Rpi4 Automated Installer\n\n";
	printf "Usage : $(basename $0) <OPTIONS>\n";
	printf "where OPTIONS are :\n";
	printf "\t-d|--disk <disk>   : use the given disk (e.g. /dev/sdb)\n";
	printf "\t-h|--host [<host>] : set as hostname in target root file system\n";
	printf "\t--rpi3             : set the target to Raspberry pi 3\n";
	printf "\t--help             : show this help\n";
	printf "\t-v                 : show version\n";
}

##############################################
# Shows the version
##############################################
function show_version() {
	success "v$VERSION\n";
	exit 0;
}

##############################################
# Performs cleanup actions
# - umount partitions
# - remove tmp directory
##############################################
function cleanup()  {
	if [ -d "$tmp_dir/boot" ]; then
		$SUDO umount $tmp_dir/boot &>/dev/null
	fi
	if [ -d "$tmp_dir/root" ]; then
		$SUDO umount $tmp_dir/root &>/dev/null
	fi
	if [ -d "$tmp_dir" ]; then
		rm -fr "$tmp_dir" &>/dev/null
	fi
}


#########s Main ###########

# Step 1 : Get args
disk="";
PARAMS=""

# Parse options
while (( "$#" )); do
	case "$1" in
		--help)
			show_help;
			exit 0;
			;;
		-v|--version)
			show_version;
			exit 0;
			;;
		-h|--host)
			host="$2";
			if [ -z "$host" ]; then
				fail "Hostname not specified";
				exit 1;
			fi
			shift 2
			;;
		-d|--disk)
			disk="$2"
			if [ -z "$disk" ]; then
				fail "Disk not specified";
				exit 1;
			fi
			shift 2;
			;;
		--rpi3)
			type=3
			info "Target set to Raspberry Pi 3\n";
			shift;
			;;
		--) # end argument parsing
			shift
			break
			;;
		*) # preserve positional arguments
			PARAMS="$PARAMS $1"
			shift
			;;
	esac
done

# set positional arguments in their proper place
eval set -- "$PARAMS"

if [ -z "$disk" ]; then
	fail "Must specify where to write the file with -d|--disk";
	exit 1;
fi

if [ ! -b "$disk" ]; then
	fail "Cannot access disk \"$disk\"\n";
	exit 1;
fi

# Check disk is not main
if [[ $(df --output=source /) == *$disk* ]]; then
	fail "Cannot use main device \"$disk\"\n";
	exit 1;
fi

# Check if disk is mounted

if [[ $(lsblk $disk --output=mountpoint -n | grep -v "^$" | wc -l) -gt 0 ]]; then
	fail "Disk \"$disk\" is mounted\n";
	exit 1;
fi


# Step 2 : Check sudo permissions
if [ "$EUID" -ne 0 ]; then
	CAN_I_RUN_SUDO=$(sudo -n uptime 2>&1|grep "load"|wc -l)
	if [ ${CAN_I_RUN_SUDO} -eq 0 ]; then
		# Ask for the administrator password upfront
		warn "This script needs elevated permissions to execute.\nPlease provide super-user credentials to continue.\n"
		sudo -v
	fi
	# Keep-alive: update existing `sudo` time stamp until finished
	while true; do sudo -n true; sleep 62; kill -0 "$$" || exit; done 2>/dev/null &
else
	SUDO=""
fi

# Step 3 : Wipe all partitions
showSection "Disk preparation (\"$disk\")";

showSubSection "Creating partitions";

pad "Wiping disk";
$SUDO sfdisk --delete $disk -w always &>/dev/null
showResultOrExit;

pad "Creating boot partition"
echo ",200M,c" | $SUDO sfdisk ${disk} &>/dev/null
showResultOrExit;
pad "Creating root partition"
echo ",,83" | $SUDO sfdisk --append ${disk} &>/dev/null
showResultOrExit;

showSubSection "Formatting partitions"
pad "Creating filesystems"
$SUDO mkfs.vfat -F 32 -n BOOT ${disk}1 &>/dev/null && $SUDO mkfs.ext4 ${disk}2 -L ROOT &>/dev/null
showResultOrExit;

showSubSection "Mounting partitions"
tmp_dir=$(mktemp -d -t rpi4_mnt-XXXXXXXXXX)
pad "Creating mount points at ${tmp_dir}"
mkdir -p $tmp_dir/{boot,root}
showResultOrExit

pad "Mounting \"$disk\" partitions"
$SUDO mount ${disk}1 $tmp_dir/boot &>/dev/null && $SUDO mount ${disk}2 $tmp_dir/root &>/dev/null
showResultOrExit

showSection "Deploying ArchLinux Arm"

showSubSection "Getting base image"
pad "Downloading image"
$SUDO wget $IMAGE_URL -nc -q --show-progress
showResultOrExit

pad "Extracting image"
echo -e "\n"
pv -ptea $FILE_NAME | $SUDO tar xpzf - -C "${tmp_dir}/root"
showResultOrExit

pad "Synching disks, might take a while $SAD_FACE"
$SUDO sync
showResultOrExit

showSubSection "Post processing"

pad "Moving boot files to boot partition"
$SUDO mv $tmp_dir/root/boot/* $tmp_dir/boot/ &>/dev/null
showResultOrExit

if [ -n "$type" ] || [[ "$type" -ne 3 ]]; then
	pad "Fixing mount point"
	$SUDO sed -i 's/mmcblk0/mmcblk1/g' $tmp_dir/root/etc/fstab
	showResultOrExit
fi

pad "Creating ssh folder"
mkdir -p $tmp_dir/root/home/alarm/.ssh &> /dev/null
showResultOrExit

pad "Copying ssh public key"
$SUDO tee -a $tmp_dir/root/home/alarm/.ssh/authorized_keys < $HOME/.ssh/id_rsa.pub &> /dev/null
$SUDO chown -R 1000:1000 $tmp_dir/root/home/alarm/.ssh
showResultOrExit

if [ -n "$host" ]; then
	pad "Setting hostname to \"$host\""
	echo "$host" | $SUDO tee $tmp_dir/root/etc/hostname &>/dev/null
	showResultOrExit
fi

showSubSection "Performing cleanup"

pad "Unmounting disk \"$disk\""
$SUDO umount $tmp_dir/{boot,root} &>/dev/null
showResultOrExit

pad "Removing temporary directory"
$SUDO rm -fr $tmp_dir;
showResultOrExit

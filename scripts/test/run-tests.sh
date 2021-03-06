#!/bin/bash

set -e

usage() {
  echo "$0 [--no-pull] <--all | --only DEVICE_TYPE | --prebuilt-image DEVICE_TYPE IMAGE_NAME>"
  exit 1
}

root_dir=$( cd "$( dirname "${BASH_SOURCE[0]}" )/../../" && pwd )
if [ "${root_dir}" != "${PWD}" ]; then
  echo "You must execute $(basename $0) from the root directory: ${root_dir}"
  exit 1
fi

WORKSPACE=./tests

BBB_DEBIAN_IMAGE_URL="http://debian.beagleboard.org/images/bone-debian-9.5-iot-armhf-2018-08-30-4gb.img.xz"

RASPBIAN_IMAGE_URL="http://downloads.raspberrypi.org/raspbian_lite/images/raspbian_lite-2019-09-30/2019-09-26-raspbian-buster-lite.zip"

TINKER_IMAGE_URL="http://dlcdnet.asus.com/pub/ASUS/mb/Linux/Tinker_Board_2GB/20170417-tinker-board-linaro-stretch-alip-v1.8.zip"

UBUNTU_IMAGE_URL="https://d1b0l86ne08fsf.cloudfront.net/mender-convert/images/Ubuntu-Bionic-x86-64.img.gz"

UBUNTU_SERVER_RPI_IMAGE_URL="http://cdimage.ubuntu.com/ubuntu/releases/bionic/release/ubuntu-18.04.5-preinstalled-server-armhf+raspi3.img.xz"

# Keep common function declarations in separate utils script
UTILS_PATH=${0/$(basename $0)/test-utils.sh}
source $UTILS_PATH

# Some distros do not have /sbin in path for "normal users"
export PATH="${PATH}:/sbin"

if [ "$1" = "--no-pull" ]; then
  shift
else
  echo "Automatically pulling submodules. Use --no-pull to disable"
  git submodule update --init --remote
fi

mkdir -p ${WORKSPACE}

get_pytest_files

if ! [ "$1" == "--all" -o "$1" == "--only" -a -n "$2" -o "$1" == "--prebuilt-image" -a -n "$3" ]; then
  usage
fi

test_result=0

if [ "$1" == "--prebuilt-image" ]; then
  run_tests "$2" "$3" || test_result=$?
  exit $test_result

else
  if [ "$1" == "--all" -o "$1" == "--only" -a "$2" == "qemux86_64" ]; then
    wget --progress=dot:giga -N ${UBUNTU_IMAGE_URL} -P input/
    convert_and_test "qemux86_64" \
                     "release-1" \
                     "input/Ubuntu-Bionic-x86-64.img.gz" \
                     "--config configs/qemux86-64_config" || test_result=$?

    echo >&2 "----------------------------------------"
    echo >&2 "Running the uncompressed test"
    echo >&2 "----------------------------------------"
    rm -rf deploy
    gunzip --force "input/Ubuntu-Bionic-x86-64.img.gz"
    convert_and_test "qemux86_64" \
                     "release-1" \
                     "input/Ubuntu-Bionic-x86-64.img" \
                     "--config configs/qemux86-64_config" || test_result=$?
  fi

  if [ "$1" == "--all" -o "$1" == "--only" -a "$2" == "raspberrypi3" ]; then
    wget --progress=dot:giga -N ${RASPBIAN_IMAGE_URL} -P input/
    convert_and_test "raspberrypi3" \
                     "release-1" \
                     "input/2019-09-26-raspbian-buster-lite.zip" \
                     "--config configs/raspberrypi3_config" || test_result=$?

    echo >&2 "----------------------------------------"
    echo >&2 "Running the uncompressed test"
    echo >&2 "----------------------------------------"
    rm -rf deploy
    unzip -o "input/2019-09-26-raspbian-buster-lite.zip" -d "./input"
    convert_and_test "raspberrypi3" \
                     "release-1" \
                     "input/2019-09-26-raspbian-buster-lite.img" \
                     "--config configs/raspberrypi3_config" || test_result=$?
  fi

  if [ "$1" == "--all" -o "$1" == "--only" -a "$2" == "linaro-alip" ]; then
    # MEN-2809: Disabled due broken download link
    #convert_and_test "linaro-alip" \
    #                 "release-1" \
    #                 "${TINKER_IMAGE_URL}" \
    #                 "${TINKER_IMAGE}.img" \
    #                 "${TINKER_IMAGE}.zip" || test_result=$?
    true
  fi

  if [ "$1" == "--all" -o "$1" == "--only" -a "$2" == "beaglebone" ]; then
    wget --progress=dot:giga -N ${BBB_DEBIAN_IMAGE_URL} -P input/
    convert_and_test "beaglebone" \
                     "release-1" \
                     "input/bone-debian-9.5-iot-armhf-2018-08-30-4gb.img.xz" || test_result=$?

    echo >&2 "----------------------------------------"
    echo >&2 "Running the uncompressed test"
    echo >&2 "----------------------------------------"
    rm -rf deploy
    unxz --force "input/bone-debian-9.5-iot-armhf-2018-08-30-4gb.img.xz"
    convert_and_test "beaglebone" \
                     "release-1" \
                     "input/bone-debian-9.5-iot-armhf-2018-08-30-4gb.img" || test_result=$?
  fi

  if [ "$1" == "--all" -o "$1" == "--only" -a "$2" == "ubuntu" ]; then
    wget --progress=dot:giga -N ${UBUNTU_SERVER_RPI_IMAGE_URL} -P input/
    convert_and_test "raspberrypi3" \
                     "release-1" \
                     "input/ubuntu-18.04.5-preinstalled-server-armhf+raspi3.img.xz" \
                     "--config configs/raspberrypi3_config" || test_result=$?

    echo >&2 "----------------------------------------"
    echo >&2 "Running the uncompressed test"
    echo >&2 "----------------------------------------"
    rm -rf deploy
    unxz --force "input/ubuntu-18.04.5-preinstalled-server-armhf+raspi3.img.xz"
    convert_and_test "raspberrypi3" \
                     "release-1" \
                     "input/ubuntu-18.04.5-preinstalled-server-armhf+raspi3.img" \
                     "--config configs/raspberrypi3_config" || test_result=$?
  fi

  exit $test_result
fi

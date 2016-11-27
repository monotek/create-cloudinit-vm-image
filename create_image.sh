#!/bin/bash
#
# create cloud image and seed file
#

if [ ! -f config ] || [ ! -f user-data.seed  ]; then
    echo "config file or user-data.seed file missing. create it from config.dist or user-data.seed.dist before running this script"
    exit 1
fi

# import config
. "config"

# import functions
. "functions"

#script
if [ -z "${HOST_NAME}" ] || [ -z "${IMAGESIZE}" ];then
    echo "need hostanme and imagesize in gigabytes as arguments"
    echo "optional third argument: 'downlaod' - download current ubuntu cloud image"
    echo "Example:	$0 testvm 10"
    exit 1
fi

test -d ${IMAGE_DIR} || mkdir -p ${IMAGE_DIR}

cd ${IMAGE_DIR}

test -d ${SEED_DIR} || mkdir -p ${SEED_DIR}

if [ -n "${DOWNLOAD}" ];then
    actionstart "get current image"
    wget ${BASE_IMAGE_URL}
    exitcode "get current image"
fi

REAL_IMAGESIZE="$(($2 - 2))"

actionstart "Convert the compressed qcow file downloaded to a uncompressed qcow2"
qemu-img convert -O qcow2 ${DIST_VERSION}-server-cloudimg-amd64-disk1.img ${HOST_NAME}.qcow2
exitcode "Convert the compressed qcow file downloaded to a uncompressed qcow2"

actionstart "Resize the image to ${IMAGESIZE} GB from original imagesize of 2 GB"
qemu-img resize ${HOST_NAME}.qcow2 +${REAL_IMAGESIZE}GB
exitcode "Resize the image to ${IMAGESIZE} GB from original imagesize of 2 GB"

actionstart "create seed file"
echo "${USER_DATA}" > ${SEED_DIR}/user-data.${HOST_NAME}
exitcode "create seed file"

actionstart "create userdate image"
cloud-localds -v -H ${HOST_NAME} ${HOST_NAME}-user-data.img ${SEED_DIR}/user-data.${HOST_NAME}
exitcode "create userdate image"

if [ "${UPLOAD}" == "yes" ]; then
    actionstart "copy ${HOST_NAME} image to kvm host"
    rsync -av --progress ${HOST_NAME}.qcow2 ${UPLOAD_SERVER}:${LIBVIRT_IMAGE_DIR}
    exitcode "copy ${HOST_NAME} image to kvm host"

    actionstart "copy ${HOST_NAME} userdata image to kvm host"
    rsync -av --progress ${HOST_NAME}-user-data.img ${UPLOAD_SERVER}:${LIBVIRT_IMAGE_DIR}
    exitcode "copy ${HOST_NAME} uderdata image to kvm host"

    actionstart "chown system image"
    ssh ${UPLOAD_SERVER} chown libvirt-qemu:kvm ${LIBVIRT_IMAGE_DIR}/${HOST_NAME}.qcow2
    exitcode "chown system image"

    actionstart "chown seed iamge"
    ssh ${UPLOAD_SERVER} chown libvirt-qemu:kvm ${LIBVIRT_IMAGE_DIR}/${HOST_NAME}-user-data.img
    exitcode "chown seed image"
else
    actionstart "copy ${HOST_NAME} image to kvm host"
    rsync -av --progress ${HOST_NAME}.qcow2 ${LIBVIRT_IMAGE_DIR}
    exitcode "copy ${HOST_NAME} image to kvm host"

    actionstart "copy ${HOST_NAME} userdata image to kvm host"
    rsync -av --progress ${HOST_NAME}-user-data.img ${LIBVIRT_IMAGE_DIR}

fi

if [ "${DELETE_TEMP}" == "yes" ]
    actionstart "delete temp files"
    rm ${HOST_NAME}-user-data.img ${HOST_NAME}.qcow2 static/user-data.${HOST_NAME}
    exitcode "delete temp files"
fi

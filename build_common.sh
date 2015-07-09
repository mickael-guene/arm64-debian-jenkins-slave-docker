#!/bin/bash -ex
# original dockerfile https://registry.hub.docker.com/u/evarga/jenkins-slave/dockerfile/

VERSION=$1
if [[ -z "$VERSION" ]]; then
    VERSION="sid"
else
    echo $VERSION
fi

#clean up function
function cleanup() {
rm -Rf $TMPDIR
}

#build script that will be executed in docker file
function build_guest_script() {
cat << EOF > ${TMPDIR}/build_guest.sh
#!/bin/bash -ex
# Since docker has not yet build env this allow to use a proxy
export http_proxy=${http_proxy}
export https_proxy=${https_proxy}

#here are the real docker command
##first install needed packages
apt-get update && apt-get upgrade -y && apt-get install -y --no-install-recommends \
    openssh-server \
    openjdk-7-jdk
apt-get clean

##tweak ssh
sed -i 's|session    required     pam_loginuid.so|session    optional     pam_loginuid.so|g' /etc/pam.d/sshd
mkdir -p /var/run/sshd

##add jenkins user
### /bin/true is a hack. See https://github.com/docker/docker/issues/6345
adduser --quiet jenkins || /bin/true
echo "jenkins:jenkins" | chpasswd
EOF
chmod +x ${TMPDIR}/build_guest.sh
}

# build dockerfile
function build_docker_file() {
cat << EOF > ${TMPDIR}/Dockerfile
FROM mickaelguene/arm64-debian-dev:${VERSION}
MAINTAINER Mickael Guene <mickael.guene@st.com>
# You need binfmt_misc support so the following work on x86
COPY build_guest.sh /build_guest.sh
RUN /build_guest.sh && rm /build_guest.sh
EXPOSE 22
CMD ["/usr/sbin/sshd"]
EOF
}

#get script location
SCRIPTDIR=`dirname $0`
SCRIPTDIR=`(cd $SCRIPTDIR ; pwd)`

#create tmp dir
TMPDIR=`mktemp -d -t arm64_debian_jenkins_slave_XXXXXXXX`
trap cleanup EXIT
cd ${TMPDIR}

#build guest script
build_guest_script

#build docker file
build_docker_file

#build image
docker build -t mickaelguene/arm64-debian-jenkins-slave:${VERSION} .

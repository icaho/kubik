#!/bin/bash

# Specifiy component versions and Git root path
MINIKUBE_VERSION=v0.28.2
KUBECTL_VERSION=v1.11.3
VBOX_VERSION=5.1

GIT_ROOT=~/kubikal

# This script doesn't work with strict POSIX sh
if [ "$BASH" != "/bin/bash" ] ; then
	echo "This installer must be run with bash."
	exit
fi

case "$1" in
	remote-only)	echo "This installer will setup kubectl and kubik on your system."
			SETUP_LOCAL="false"
			DEFAULT_CONTEXT="test"
			;;
	local-cluster)	echo "This installer will setup minikube, kubectl and kubik on your system."
			SETUP_LOCAL="true"
			DEFAULT_CONTEXT="test"
			;;
	*)		echo "This installer will setup kubectl and kubik on your system."
			echo ""
			echo "Usage:"
			echo "  install.sh remote-only    Installs tools required to manage remote clusters"
			echo "  install.sh local-cluster  Installs a local minikube-based Kubernetes cluster"
			echo ""
			exit 1
esac

#
# Detect OS, only support OS X and linux at the moment
#

case "$OSTYPE" in
	darwin*)	echo "This installer will setup kubik, kubectl and minikube on your OS X system"
			MINIKUBE_URL="https://storage.googleapis.com/minikube/releases/$MINIKUBE_VERSION/minikube-darwin-amd64"
			KUBECTL_URL="https://storage.googleapis.com/kubernetes-release/release/$KUBECTL_VERSION/bin/darwin/amd64/kubectl"
			;;

	linux*)		echo "This installer will setup kubik, kubectl and minikube on your Linux system"
			MINIKUBE_URL="https://storage.googleapis.com/minikube/releases/$MINIKUBE_VERSION/minikube-linux-amd64"
			KUBECTL_URL="https://storage.googleapis.com/kubernetes-release/release/$KUBECTL_VERSION/bin/linux/amd64/kubectl"
			;;

	*)		echo "Sorry, your operating system is not supported by minikube."
			exit 1;
esac

echo ""

#
# Do not run as root
#

if [ "$(id -u)" == "0" ] ; then
	echo ""
	echo "Please run this installer as the user that will be using kubik, not root!"
	echo ""
	exit 1
fi

#
# Ask for confirmation before proceeding
#

read -p "Do you want to proceed (Y/N)? " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]] ; then
	echo "Aborted."
	exit 1
fi

echo ""



#
# But ensure we can sudo to root
#

echo "This installer needs to be able to sudo to install some files."
if ! sudo id 2>/dev/null >/dev/null ; then
	echo ""
	echo "Cannot sudo to root, aborting."
	echo ""
	exit 1
fi

echo ""

#
# Ensure VirtualBox is installed
#

if VBOX_VERSION_INSTALLED=`VBoxManage --version`; then
        echo "--- Found VirtualBox version $VBOX_VERSION_INSTALLED"
fi

echo $VBOX_VERSION_INSTALLED | if ! grep -q "^$VBOX_VERSION" ; then
	echo ""
	echo "VirtualBox version 5.1.2 or higher is required:"
	echo "	https://www.virtualbox.org/wiki/Downloads"
	echo ""
	exit 1
fi



#
# Ensure the correct version of kubectl is installed
#

if which kubectl 2>/dev/null >/dev/null ; then
	KUBECTL_VERSION_INSTALLED=`kubectl version --client | cut -f6 -d'"'`
	echo "--- Found kubectl version $KUBECTL_VERSION_INSTALLED at `which kubectl`"
fi

if [ "$KUBECTL_VERSION" != "$KUBECTL_VERSION_INSTALLED" ] ; then
	echo -n "--- Downloading kubectl $KUBECTL_VERSION..."
	curl -Lso /tmp/kubectl.$$ $KUBECTL_URL
	chmod +x /tmp/kubectl.$$
	echo ""

	echo "--- Installing kubectl $KUBECTL_VERSION to /usr/local/bin..."
	sudo mv /tmp/kubectl.$$ /usr/local/bin/kubectl
fi

KUBECTL_VERSION_INSTALLED=`kubectl version --client | cut -f6 -d'"'`
if [ "$KUBECTL_VERSION" != "$KUBECTL_VERSION_INSTALLED" ] ; then
	echo "Failed to install kubectl version $KUBECTL_VERSION, aborting."
	exit 1
fi



#
# Ensure the correct version of minikube is installed
#

if which minikube 2>/dev/null >/dev/null ; then
	MINIKUBE_VERSION_INSTALLED=`minikube version | tail -1 | cut -f3 -d' '`
	echo "--- Found minikube version $MINIKUBE_VERSION_INSTALLED at `which minikube`"
fi

if [ "$MINIKUBE_VERSION" != "$MINIKUBE_VERSION_INSTALLED" ] ; then
	echo -n "--- Downloading minikube $MINIKUBE_VERSION..."
	curl -Lso /tmp/minikube.$$ $MINIKUBE_URL
	chmod +x /tmp/minikube.$$
	echo ""

	echo "--- Installing minikube $MINIKUBE_VERSION to /usr/local/bin..."
	sudo mv /tmp/minikube.$$ /usr/local/bin/minikube
fi

MINIKUBE_VERSION_INSTALLED=`minikube version | tail -1 | cut -f3 -d' '`
if [ "$MINIKUBE_VERSION" != "$MINIKUBE_VERSION_INSTALLED" ] ; then
	echo "Failed to install minikube version $MINIKUBE_VERSION, aborting."
	echo $MINIKUBE_VERSION_INSTALLED
	minikube version | cut -f3 -d' '
	exit 1
fi



#
# Clone kubik-config repo
#

if ! [ -d $GIT_ROOT/kubik-config ] ; then
	echo "--- Cloning kubik-config repo to $GIT_ROOT..."
	git clone -q git@github.com:icaho/kubik-config.git $GIT_ROOT/kubik-config
else
	echo "--- Updating $GIT_ROOT/kubik-config"
	pushd $GIT_ROOT/kubik-config 2>/dev/null >/dev/null
	git pull
	popd 2>/dev/null >/dev/null
fi



#
# Clone kubik repo
#

if ! [ -d $GIT_ROOT/kubik ] ; then
	echo "--- Cloning kubik repo to $GIT_ROOT..."
	git clone -q git@github.com:icaho/kubik.git $GIT_ROOT/kubik
else
	echo "--- Updating $GIT_ROOT/kubik"
	pushd $GIT_ROOT/kubik 2>/dev/null >/dev/null
	git pull
	popd 2>/dev/null >/dev/null
fi



#
# Install /etc/kubik/kubik.conf
#

echo "--- Configuring kubik to use $GIT_ROOT/kubik-config..."
cat <<EOF >/tmp/kubik.conf.$$
# kubik config generated by installer on `date`
ENVIRONMENTS=$GIT_ROOT/kubik-config/environments
APPLICATIONS=$GIT_ROOT/kubik-config/applications
EOF
if ! diff /tmp/kubik.conf.$$ /etc/kubik/kubik.conf 2>/dev/null >/dev/null ; then
	sudo mkdir -p /etc/kubik
	sudo mv /tmp/kubik.conf.$$ /etc/kubik/kubik.conf
else
	echo "Already up-to-date."
	rm /tmp/kubik.conf.$$
fi

if ! [ -e /etc/kubik/kubik.conf ] ; then
	echo "Failed to install /etc/kubik/kubik.conf, aborting."
	exit 1
fi

#
# Install kubik to /usr/local/bin
#

echo "--- Symlinking kubik to /usr/local/bin..."
sudo rm -rf /usr/local/bin/kubik
sudo ln -s $GIT_ROOT/kubik/kubik /usr/local/bin/kubik

if ! which kubik 2>/dev/null >/dev/null ; then
	echo "Failed to install kubik to /usr/local/bin, aborting."
	echo "You can still run it from $GIT_ROOT/kubik"
fi



#
# Initialise local Kubernetes cluster if needed
#

if [ "$SETUP_LOCAL" == "true" ] ; then
	if [ "$(minikube status)" != "Running" ] ; then
		echo -n "--- "

		# Nuke and reconfigure minikube
		minikube delete >/dev/null 2>/dev/null
		rm -rf ~/.minikube
		minikube config set WantUpdateNotification false >/dev/null 2>/dev/null
		minikube config set WantReportErrorPrompt false
		minikube config set WantReportError true
		minikube config set kubernetes-version $KUBERNETES_VERSION >/dev/null 2>/dev/null
		minikube config set memory 4096 >/dev/null
		minikube config set cpus 4 >/dev/null

		# Install our addons
		mkdir -p ~/.minikube/addons
		cp $GIT_ROOT/kubik-config/clusters/dev.tentonpenguin.co.uk/addons/* ~/.minikube/addons

		# Increase our chances of getting the IP 127.0.0.1
		pgrep -f "lower-ip 127.0.0.1" | xargs kill

		# Create the minikube VM
		if ! minikube start ; then
			echo "Failed to initialise cluster, aborting."
			exit 1
		fi

		# Give the cluster a few seconds to become ready
		echo -n "Waiting for cluster..."
		sleep 5
		until kubectl --context=minikube version 2>/dev/null >/dev/null ; do
			echo -n "."
			sleep 5
		done
		echo ""

		echo "--- Found a local Kubernetes cluster"
		kubectl --context=minikube version
	fi

	# The addon manager doesn't do ingress at the moment
	echo "--- Adding dashboard ingress"
	kubectl apply -f $GIT_ROOT/kubik-config/clusters/dev.tentonpenguin.co.uk/addons/*-ingress.yaml

	MINIKUBE_IP="$(minikube ip)"
	DEV_FQDN_IP="$(host -t A $DEV_FQDN | tr " " "\n" | tail -1)"

	if ! [ "$DEV_FQDN_IP" == "$MINIKUBE_IP" ] ; then
		echo ""
		echo "WARNING: Kubernetes cluster IP $MINIKUBE_IP does not match $DEV_FQDN [$DEV_FQDN_IP]."
		echo ""
	fi
fi



#
# Install additional clusters
#

mkdir -p ~/.kube
for CLUSTER in $GIT_ROOT/kubik-config/clusters/* ; do
	pushd "$CLUSTER/" 2>/dev/null >/dev/null
	if [ -x "$CLUSTER/install.sh" ] ; then
		"$CLUSTER/install.sh"
	fi
	popd 2>/dev/null >/dev/null
done



#
# Pick a default cluster
#

kubectl config use-context $DEFAULT_CONTEXT



#
# The end
#

echo "Your system should now have kubik installed and configured."
echo ""
echo "To spin up a local environment simply run 'kubik create'"
echo ""

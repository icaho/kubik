#!/bin/bash

# This script doesn't work with strict POSIX sh
if [ "$BASH" != "/bin/bash" ] ; then
        echo "This uninstaller must be run with bash."
        exit
fi

echo "This uninstaller will remove minikube, kubectl and kubik from your system."

# Do not run as root
if [ "$(id -u)" == "0" ] ; then
	echo ""
	echo "Please run this installer as the user that was using kubik, not root!"
	echo ""
	exit 1
fi

read -p "Do you want to proceed (Y/N)? " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]] ; then
	echo "Aborted."
	exit 1
fi

echo ""

if [ -e /usr/local/bin/minikube ] ; then
	echo "--- Removing minikube VM..."
	minikube delete
	rm -rf ~/.minikube
	if [ -x "$(which kubectl)" ] ; then
		kubectl config unset users.minikube
		kubectl config unset contexts.minikube
		kubectl config unset clusters.minikube
	fi
	echo "WARNING: Re-installing a local cluster before rebooting may fail."
	echo "--- Removing minikube from /usr/local/bin..."
	sudo rm -rf /usr/local/bin/minikube
fi

if [ -e /usr/local/bin/kubectl ] ; then
	echo "--- Removing kubectl from /usr/local/bin..."
	sudo rm -rf /usr/local/bin/kubectl
fi

if [ -e /usr/local/bin/kubik ] ; then
	echo "--- Removing kubik from /usr/local/bin..."
	sudo rm -rf /usr/local/bin/kubik
fi

if [ -d /etc/kubik/ ] ; then
	echo "--- Removing kubik config from /etc/kubik..."
	sudo rm -rf /etc/kubik/
fi

if [ "$1" == "all" ] ; then
	if [ -d ~/Git/kubik ] ; then
		echo "--- Removing kubectl repo from" ~/Git
		rm -rf ~/Git/kubik
	fi

	if [ -d ~/Git/kubik-config ] ; then
		echo "--- Removing kubik-config repo from" ~/Git
		rm -rf ~/Git/kubik-config
	fi
fi

echo ""
echo "Your system does not have kubik installed and configured."
echo ""

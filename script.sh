#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

logo() {
echo -e "$GREEN
        ____ _____ ______  ____  ___  
        |    / ___/|      ||    |/   \ 
        |  (   \_ |      | |  ||     |
        |  |\__  ||_|  |_| |  ||  O  |
        |  |/  \ |  |  |   |  ||     |
        |  |\    |  |  |   |  ||     |
        |____|\___|  |__|  |____|\___/ 
                               
 Istio Install/Remove Script with Kind Cluster. 
$NC"
}

install () {
#==> Setup kind Cluster
echo "Install kind Cluster"
kind create cluster --name istio --config kind/kind-ingress-config.yaml
echo "-----------------------------------------------------------------------------"

#==> Install ISTIO
echo "Install istio with demo profile using istioctl"
export PATH=$PWD/istio-1.20.1/bin:$PATH
istioctl install --set profile=demo -y
kubectl apply -f network/istio-ingress-gw.yaml
echo "-----------------------------------------------------------------------------"

#==> Install Addons
echo "Install addons"
export ADDONS_PATH=./istio-1.20.1/samples/addons
kubectl apply -f $ADDONS_PATH/grafana.yaml,$ADDONS_PATH/jaeger.yaml,$ADDONS_PATH/kiali.yaml,$ADDONS_PATH/loki.yaml,$ADDONS_PATH/prometheus.yaml  
echo "-----------------------------------------------------------------------------"

#==> Install NGINX Ingress controller
echo "Install nginx Ingress controller"
kubectl apply --filename https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/provider/kind/deploy.yaml
echo "-----------------------------------------------------------------------------"

#==> Add Nginx Ingress resource
echo "Install nginx resource"
echo "Waiting for Ingress controller to be ready..."
kubectl -n ingress-nginx wait --for=condition=ready pod -l app.kubernetes.io/component=controller --timeout=10m
kubectl apply -f network/ingress.yaml
echo "-----------------------------------------------------------------------------"

#==> Label Default namespace
echo "Label Default namespace with (istio-injection=enabled)"
kubectl label namespace default istio-injection=enabled
echo "-----------------------------------------------------------------------------"

#==> Install Bookinfo App
echo "Install Bookinfo App"
# export APP_PATH=./istio-1.20.1/samples/bookinfo/platform/kube
# kubectl apply -f $APP_PATH/bookinfo.yaml
kubectl apply -f bookinfo
echo "-----------------------------------------------------------------------------"

#==> Install Nginx App
echo "Install Nginx App"
kubectl apply -f nginx-app
echo "-----------------------------------------------------------------------------"
}

#%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%

remove () {

while true; do

read -p "Do you want to proceed? (y/n) " yn

case $yn in 
	[yY] ) echo ok, we will proceed;
		break;;
	[nN] ) echo exiting...;
		exit;;
	* ) echo -e "${RED}invalid response ${NC}";;
esac

done

#==> Remove Bookinfo Gateway
echo "Remove Bookinfo Gateway"
kubectl delete -f ./istio-1.20.1/samples/bookinfo/networking/bookinfo-gateway.yaml
echo "-----------------------------------------------------------------------------"

#==> Remove Addons
echo "Remove addons"
export ADDONS_PATH=./istio-1.20.1/samples/addons
kubectl delete -f $ADDONS_PATH/grafana.yaml,$ADDONS_PATH/jaeger.yaml,$ADDONS_PATH/kiali.yaml,$ADDONS_PATH/loki.yaml,$ADDONS_PATH/prometheus.yaml  
echo "-----------------------------------------------------------------------------"

#==> Remove Bookinfo APP
echo "Remove Simple App"
# export APP_PATH=./istio-1.20.1/samples/bookinfo/platform/kube
# kubectl delete -f $APP_PATH/bookinfo.yaml
kubectl delete -f bookinfo
echo "-----------------------------------------------------------------------------"

#==> Remove Nginx APP
echo "Remove Nginx APP"
kubectl delete -f nginx-app

#==> Remove Istio
echo "Remove Istio"
export PATH=$PWD/istio-1.20.1/bin:$PATH
istioctl uninstall --purge
kubectl -n default delete deploy bookinfo-gateway-istio
kubectl -n default delete svc bookinfo-gateway-istio
echo "-----------------------------------------------------------------------------"

#==> Remove Namespace
echo "Remove Namespace"
kubectl delete ns istio-system
echo "-----------------------------------------------------------------------------"

#==> Remove Nginx Ingress controller
echo "Remove Nginx Ingress controller"
kubectl delete -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/provider/kind/deploy.yaml
echo "-----------------------------------------------------------------------------"

#==> Remove Kind Cluster
echo "Remove Kind Cluster"
kind delete cluster --name istio
}

#%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%

logo

while true; do

read -p "[install/remove] Istio? " yn

case $yn in 
	install ) install;
        break;;
	remove ) remove;
		exit;;
	* )echo -e "${RED}invalid response ${NC}";
esac

done
#!/bin/bash

print_help() {
  echo " "
  echo "Help:"
  echo "  -e \${extension} is required."
  echo "  fluent-bit requires -b \${backend} option"
  echo "  All other extensions -p \${provider} option"
  echo "  dex requires -a \${auth} option"
  echo "  Optional -y to install via ytt/kapp instead of kapp-controller."
  echo " "
  echo "    ASSUMPTIONS:"
  echo "      logged into workload cluster with admin access"
  echo "      contour needs to be installed before dex, gangway, and grafana"
  echo "      this will deploy dex into workload"
  exit 1
}

bundle=tkg-extensions-v1.2.0+vmware.1

while [[ "$1" =~ ^- && ! "$1" == "--" ]]; do
  case $1 in
    -h | --help )
      print_help
      exit 1
      ;;

    -p | --provider )
      shift; provider=$1
      ;;

    -e| --extension )
      shift; extension=$1
      ;;

    -a| --auth )
      shift; auth=$1
      ;;
 
    -b| --backend )
      shift; backend=$1
      ;;

    -y )
      ytt=true
      ;;

    *)
      echo "Invalid option"
      print_help
      ;;

  esac; shift
done
if [[ "$1" == '--' ]]; then shift; fi


case ${extension} in
  prometheus | grafana )
    ext_path=monitoring
    namespace=tanzu-system-monitoring
    values_path=${bundle}/extensions/${ext_path}/${extension}/${provider}
    ;;  
      
  contour )
    ext_path=ingress
    namespace=tanzu-system-ingress
    values_path=${bundle}/extensions/${ext_path}/${extension}/${provider}
    ;;
      
  dex )
    ext_path=authentication
    namespace=tanzu-system-auth
    values_path=${bundle}/extensions/${ext_path}/${extension}/${provider}/${auth}
    ;;   
    
  gangway )
    ext_path=authentication
    namespace=tanzu-system-auth
    values_path=${bundle}/extensions/${ext_path}/${extension}/${provider}
    ;;

  fluent-bit|fluentbit )
    ext_path=logging
    namespace=tanzu-system-logging
    values_path=${bundle}/extensions/${ext_path}/${extension}/${backend}
    ;;

  harbor )
    ext_path=registry
    namespace=tanzu-system-registry
    values_path=${bundle}/extensions/${ext_path}/${extension}
    ;;

  * )
    echo "Error: Invalid or no extension passed. Use -e \$extension."
    print_help
esac


if [[ ${extension} == "fluent-bit" ]]; then
  case ${backend} in
    elasticsearch | http | kafka | splunk )
      echo "backend is ${backend}"
      ;;

    * )
      echo "Error: Invalid or undefined backend."
      print_help
      ;;
  esac
fi


if [[ ${extension} == "contour" ]] || [[ ${extension} == "grafana" ]] || [[ ${extension} == "prometheus" ]] || [[ ${extension} == "dex" ]]; then
  case ${provider} in
    aws | azure | vsphere )
      echo "provider is ${provider}"
      ;;

    * )
      echo "Error: Invalid or undefined provider."
      print_help
      ;;
  esac
fi


if [[ ${extension} == "dex" ]]; then
  case ${auth} in
    ldap | oidc )
      echo "auth is ${auth}"
      ;;

    * )
      echo "Error: Invalid or undefined auth."
      print_help
      ;;
  esac
fi


#script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

#echo "script_dir is ${script_dir}"
echo "extension is ${extension}"
echo "ext_path is ${ext_path}"
echo "namespace is ${namespace}"
echo "provider is ${provider}"
echo "backend is ${backend}"
echo "ytt is ${ytt}"


### Function installs extension manger and kapp-controller ###
ext_kapp_install() {
  # apply extension manager
  kubectl apply -f ${bundle}/extensions/tmc-extension-manager.yaml
  
  # apply kapp-controller
  kubectl apply -f ${bundle}/extensions/kapp-controller.yaml
  
  # deploy extension
  kubectl apply -f ${bundle}/extensions/${ext_path}/${extension}/${extension}-extension.yaml
}


### Function create secret
### Only creates data-extension-values.yaml if NOT existing
ext_create_secret() {
  if [[ -e ${values_path}/${extension}-data-values.yaml ]];then
    echo "${extension}-data-values.yaml EXISTS!; will not overwrite"
  else
    echo "copying ${values_path}/${extension}-data-values.yaml.example"
    cp ${values_path}/${extension}-data-values.yaml.example ${values_path}/${extension}-data-values.yaml
    if [[ ${extension} == "harbor" ]]; then
      echo "creating harbor passwords"
      ${bundle}/extensions/${ext_path}/${extension}/generate-passwords.sh ${values_path}/${extension}-data-values.yaml
    fi
  fi

  # create secret
  kubectl create secret generic ${extension}-data-values --from-file=values.yaml=${values_path}/${extension}-data-values.yaml -n ${namespace}
  kubectl create secret generic ${extension}-data-values --from-file=values.yaml=${values_path}/${extension}-data-values.yaml -n ${namespace} -o yaml --dry-run | kubectl replace -f-

}


### ytt deploy ###
ext_ytt_install() {
  echo "this method of installation is not supported"

  #if [[ ${extension} = gangway ]];then
  #  cp ./CA-cert.pem ${bundle}/common
  #fi

  ytt --ignore-unknown-comments \
  -f ${bundle}/common \
  -f ${bundle}/${ext_path}/${extension} \
  -f ${values_path}/${extension}-data-values.yaml \
  | kubectl apply -f-
  #| kapp deploy -y -a ${extension} -f-
}


### Function deploys custom manifests ###
custom_install() {
  echo ${bundle}/custom/${ext_path}/${extension}
  if [[ -e ${bundle}/custom/${ext_path}/${extension} ]];then
    echo "-------Deploying custom stuff---------"
    ytt --ignore-unknown-comments \
      -f ${bundle}/common \
      -f ${bundle}/${ext_path}/${extension}/values.yaml \
      -f ${bundle}/${ext_path}/${extension}/values.star \
      -f ${bundle}/custom/${ext_path}/${extension} \
      -f ${values_path}/${extension}-data-values.yaml \
      | kubectl apply -f-
      #| kapp deploy -y -a ${extension} -f-
      if [[ ${extension} = dex ]];then
        kubectl create secret tls tanzu-issuer -n cert-manager --cert=./CA-cert.pem --key=./CA-key.pem
      fi 
  else
    echo "No customizations applied"
 fi
}


### Main ###
# install cert-manager
kubectl apply -f ${bundle}/cert-manager/

# create namespace
kubectl apply -f ${bundle}/extensions/${ext_path}/${extension}/namespace-role.yaml

# create secret from ${extension}-data-values.yaml
ext_create_secret

# install with kubeapp-controller or kubectl apply
if [[ "$ytt" == true ]]; then
  ext_ytt_install
else
  ext_kapp_install
fi

# install custom files
custom_install

# End

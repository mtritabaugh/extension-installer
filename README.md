
# Use at your own risk! Not well tested

## Not working for Dex/Gangway
Both extensions can be installed, but Gangway must be installed using -y option

## Install

- Copy script to a local directory
- Copy extension tar file to same directory
- Untar extension tar file
- Update variable `bundle` in script to extension untar bundle name, default
is `bundle=tkg-extensions-v1.2.0+vmware.1`
- If using custom manifests not supplied by the extension, create custom
directory and use same pathing as the bundle.

## Usage

Contour needs to be installed before all other extensions
Extension variable files will copy the examples unless a pre-existing values
is found
Place any custom manifests in ${bundle}/custom/${ext_path}/${extension}

## ASSUMPTIONS:

- Logged into workload cluster with admin access
-Will install Dex and Gangway into same cluster


## Options

- -e ${extension} is required.
- fluent-bit requires -b ${backend} option
- All other extensions -p ${provider} option
- dex also requires -a ${auth} option
- Optional -y to install via ytt/kubectl apply instead of kapp-controller.

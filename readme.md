# SCB Cascading Scans Hetzner Demo

This is a "simple" setup of a couple of insecure VM's in a hetzner private network.

This Setup was initially build for the OWASP Hamburg Stammtisch: https://www.meetup.com/owasp-hamburg-stammtisch/events/307174646/

The network consists of 5 VM's

1. insecure-ssh (10.0.42.1): A VM with username/password authentication. Has a pretty week password
2. juice-shop (10.0.42.2): A VM with a OWASP JuiceShop container exposed
3. bad-postgres (10.0.42.3): A VM with a postgres instance with a very bad password
4. monitoring (10.0.42.4): A VM with a very outdated grafana container running on it
5. scb (10.0.42.42): A vm with a k3s cluster running the secureCodeBox to scan the rest of the network and DefectDojo to show the results.

## Setup

1. Create hetzner cloud project
1. Setup your public ssh key in the project and call it. `primary`
1. Create a Hetzner API Token and export it in your terminal. e.g. `export HCLOUD_TOKEN="AVt..."`
1. Enter your email in the cert-manager config under: kubernetes-manifests/cert-manager.yaml
1. Update the `host` helm value for the DefectDojo instance. If you don't have a domain handy, you can also keep it as it is and port-forward to the defectdojo using kubectl.
1. Install the terraform / OpenTofu dependencies. e.g. `tofu init`
1. Setup the stack. e.g. `tofu apply`
1. Connect to the SCB VM. Check the public ip in the hetzner console. e.g. `ssh root@192.0.2.42`
1. On the VM copy the kubeconfig of the k3s cluster to your local kubeconfig. (Note: you'll need to change the address to the one of your scb vm)
1. Apply the manifests from the `scans` folder.
    1. `kubectl apply -f scans/cascading-hook/`
    1. `kubectl apply -f scans/cascading-rules/`
    1. Open DefectDojo and copy the Api Key of the user. (You can find the credential for the DefectDojo user using `kubectl get secret -n defectdojo defectdojo -oyaml`, username is admin by default.)
    1. Adjust scans/hook.yaml to have the correct API key in place.
    1. `kubectl apply -f scans/cascading-hook/`
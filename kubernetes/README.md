# TacticalRMM Kubernetes manifests
**Author:** [Joel DeTeves](https://github.com/joeldeteves)

**Desription:** TacticalRMM Kubernetes manifests tested & working on Digital Ocean managed Kubernetes (DOKS).

**Disclaimer:** _These manifests rely on an experimental developer images and as such are NOT SUPPORTED, at least until the required changes are merged into the main image. I have done my best to make them as secure as possible them however I am NOT responsible for anything that happens to you or your data as a result of using these files. Please do your due dilligence security-wise and open a Github issue if you wish to report a problem. USE AT YOUR OWN RISK. By using these files you agree that you are the sole entity responsible for any damages that may arise as a result._

# Pre-requisites
- A working Kubernetes cluster
- Kubernetes [NFS provisioner](https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner) or another storage provisioner that supports ```ReadWriteMany```

# Deploying the files
1. ```kubectl apply -f namespace.yaml```
2. ```kubectl apply -f .```
3. ```kubectl apply -f deployment/ -R```

# Questions / Concerns
Please open an issue in Github or you can also check in the [Tactical RMM Discord Channel](https://discord.gg/upGTkWp).

**Note: I am not affiliated with TRMM or AmidaWare; I am a community contributor. Please direct TRMM-related issues to the appropriate channels.**

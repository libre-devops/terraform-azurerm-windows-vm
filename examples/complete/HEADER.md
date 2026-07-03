<!--
  Header for the complete example README. Edit this file, then run `just docs`
  (or ./Sort-LdoTerraform.ps1 -IncludeExamples) to regenerate the section between the markers.
  The example's main.tf is embedded into the README automatically (see .terraform-docs.yml).
-->
<div align="center">
  <a href="https://libredevops.org">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="https://libredevops.org/assets/libre-devops-white.png">
      <img alt="Libre DevOps" src="https://libredevops.org/assets/libre-devops-black.png" width="200">
    </picture>
  </a>
</div>

# Complete example

The Windows "secure VM estate in a pinch" build, end to end: tags, resource group, vnet with an NSG
admitting RDP only from inside the vnet, forward AND reverse private DNS zones auto-registering every
VM, a free Developer bastion as the only door (no public IPs anywhere), a generated admin password
whose retrievable copy lives in a key vault (written write-only), Log Analytics with VM Insights
wired to every VM through their system identities, and two hardened VMs exercising the full surface:
a hotpatch-enabled AzureEdition image with platform patching, a timezone, data disks (auto LUNs) and
a PowerShell run command, plus an explicit image reference with spot pricing, a zone, a static
private IP, accelerated networking, Azure Hybrid Benefit, and a Premium OS disk. The disposable
example vault opts out of the keyvault module's firewall default so the runner can reach the data
plane. Run it with `just e2e complete`, which applies the stack then always destroys it.

[![Terraform Registry](https://img.shields.io/badge/registry-libre--devops-7B42BC?logo=terraform&logoColor=white)](https://registry.terraform.io/namespaces/libre-devops)

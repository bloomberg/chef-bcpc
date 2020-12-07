# bird-leaf-spine

## General Architecture

The virtual network consists of a combination of "Top of Rack" (TOR or
Leaf), "Spine" and (optional) "Super Spine" routers. By default, the
network contains a single "Pod" although by setting the `BCC_POD_COUNT`
environment variable this number can be larger which will result in super
spine routers being created to connect spine routers within each pod to
their corresponding spine in each other pod. Such a grouping represents a
"Plane".

At the current time, each pod consists of up to two planes in the network
which governs the number of spine routers in each pod. Each pod also
contains three TOR routers by default. If there are multiple pods,
then each plane will contain two super spine routers.

## Naming Convention

### Top of Rack (TOR)

* `<fabric-id>-pd<pod #>sw<switch #>`

### Spine

* `<fabric-id>-pl<plane #>sp<pod #>`

### Super Spine

* `<fabric-id>-pl<plane #>fs<1-16>`

## Autonomous System Number (ASN) Convention

Within a plane, each super spine router shares the same unique ASN but
between different planes, super spines have a different ASN.

Within a pod, each spine router shares the same unique ASN but between
different pods, spine router have a different ASN.

Each TOR router has a unique ASN.

All hosts within the virtual racks share the same unique ASN.

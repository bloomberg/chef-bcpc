# bcpc-common Cookbook

This cookbook configures basic configuration elements that are common to
all other BCPC node roles.

## Requirements

This cookbook will probably only run correctly on Ubuntu 14.04.

### Chef

- Chef 12.9.41 or later

## Usage

Just include `bcpc-common` in your node's `run_list`:

```json
{
  "name":"my_node",
  "run_list": [
    "recipe[bcpc-common]"
  ]
}
```

This cookbook also includes the **apt_upgrade** recipe, which will run
`apt-get upgrade` or `apt-get dist-upgrade` if so configured (intended to be
used in situations where you are using a frozen mirror and want to ensure that
your nodes remain converged with the package versions from that frozen mirror).

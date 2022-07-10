# [![Packages](https://labs.mocaccino.org/badge/mocaccino-community.svg "List of packages")](https://labs.mocaccino.org/mocaccino-community) community-repository

This is the repository containing various apps and libs that can be used with mocaccinoOS.

To consume it with `luet`, run:

```
sudo luet install repository/mocaccino-community-stable
```

The following file is added as `mocaccino-community-stable.yml` configuration file in `/etc/luet/repos.conf.d/`:

Community repository

```yaml
name: "mocaccino-community-stable"
type: "docker"
enable: true
priority: 50
urls:
- "quay.io/mocaccino/mocaccino-community"
reference: "<unix timestamp>-repository.yaml"
```
Note: Above, the `<unix timestamp>` represents the repository snapshot that provides the apps.

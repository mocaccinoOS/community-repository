# [![Packages](https://labs.mocaccino.org/badge/mocaccino-community.svg "List of packages")](https://labs.mocaccino.org/mocaccino-community) community-repository

This is the repository containing various apps and libs that can be used with mocaccinoOS.

It's state is `under construction`.

To consume it with `luet`, run:

```
sudo luet install repository/mocaccino-community
```

or add the following content as `mocaccino-community.yml` configuration file in `/etc/luet/repos.conf.d/`:

Community repository

```yaml
name: "mocaccino-community"
type: "docker"
enable: true
priority: 50
urls:
- "quay.io/mocaccino/mocaccino-community"
```

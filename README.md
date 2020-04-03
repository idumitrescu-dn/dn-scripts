# dn-scripts
Scripts to use with the dnos project

## Instalation

Put the folder in your HOME and add the following to your .bashrc:

```bash
 [ -r ~/.dn_scripts/setup ] && . ~/.dn_scripts/setup
```

Be sure to change the directory to where you installed this.

## Binaries

1. __dnconfig__ file [hostname password]  
Will connect to and configure a host with the given file contents.  
The file needs to start with a `config` command. Will execut a commit at the end.  
By default will connect to the local host.  
Set the `_DNCONFIG_DIR` environment variable to the folder which holds all the configuration files.
You can do that in `.dn_scripts/bash_settings.sh`.


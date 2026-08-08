## services\.waktusolat\.enable

Whether to enable Waktu Solat UI renderers and runtime state daemon\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```



## services\.waktusolat\.fetcher\.enable



Whether to enable local fetchd (Disable this if nixos-client is handling fetches system-wide)\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```



## services\.waktusolat\.logLevel



Log verbosity for waktusolat daemons\.



*Type:*
one of “SILENT”, “ERROR”, “WARN”, “INFO”, “DEBUG”



*Default:*

```nix
"INFO"
```



## services\.waktusolat\.reminder\.enable



Whether to enable update per-second waktusolat reminder to /run/user/\<UID>/waktusolat/\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```



## services\.waktusolat\.zone



JAKIM zone code to fetch prayer times for\.



*Type:*
string



*Default:*

```nix
"SGR01"
```



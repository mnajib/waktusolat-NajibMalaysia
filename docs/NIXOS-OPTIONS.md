## services\.waktusolat\.enable



Whether to enable Waktu Solat prayer time management suite\.



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



## services\.waktusolat\.aggregator\.enable



Whether to enable HTTP LAN Aggregator service\.



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



## services\.waktusolat\.aggregator\.dataDir

Primary storage directory for aggregated JSON files\.



*Type:*
absolute path



*Default:*

```nix
"/var/lib/waktusolat"
```



## services\.waktusolat\.aggregator\.openFirewallPort



Open the aggregator HTTP port in firewall\.



*Type:*
boolean



*Default:*

```nix
false
```



## services\.waktusolat\.aggregator\.port



HTTP port to serve prayer JSON on LAN\.



*Type:*
16 bit unsigned integer; between 0 and 65535 (both inclusive)



*Default:*

```nix
8089
```



## services\.waktusolat\.aggregatorTimeout



Timeout in seconds before falling back to direct internet fetch\.



*Type:*
positive integer, meaning >0



*Default:*

```nix
3
```



## services\.waktusolat\.aggregatorUrl



URL of the LAN aggregator\. If null, fetches directly from JAKIM\.



*Type:*
null or string



*Default:*

```nix
null
```



*Example:*

```nix
"http://nyxora:8089"
```



## services\.waktusolat\.dataDir



Local persistent cache directory for prayer JSON data\.



*Type:*
absolute path



*Default:*

```nix
"/var/cache/waktusolat"
```



## services\.waktusolat\.logLevel



Logging verbosity level (e\.g\. DEBUG, INFO, WARN, ERROR)\.



*Type:*
string



*Default:*

```nix
"INFO"
```



## services\.waktusolat\.reminder\.enable



Whether to enable Per-second tmpfs state formatter daemon (/run/waktusolat/)\.



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



## services\.waktusolat\.zones



JAKIM zone codes to handle\.



*Type:*
list of string



*Default:*

```nix
[
  "SGR01"
]
```



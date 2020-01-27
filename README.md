# lsd
Listing descriptions of scripts. Eg


```bash
$ lsd /bin/z*
/bin/zcat                     ASCII/sh        l=2, c=#        Uncompress files to standard output.
/bin/zcmp                     ASCII/sh        l=2, c=#        Compare the uncompressed contents of compressed fi
/bin/zdiff                    ASCII/sh        l=2, c=#        sh is buggy on RS/6000 AIX 3.2. Replace above line
/bin/zegrep                   ASCII/sh        l=1, c=#                                     
/bin/zfgrep                   ASCII/sh        l=1, c=#                                     
/bin/zforce                   ASCII/sh        l=2, c=#        zforce: force a gz extension on all gzip files so 
/bin/zgrep                    ASCII/sh        l=3, c=#        zgrep -- a wrapper around a grep program that deco
/bin/zless                    ASCII/sh        l=5, c=#       This program is free software; you can redistribut
/bin/zmore                    ASCII/sh        l=6, c=#        This program is free software; you can redistribut
/bin/znew                     ASCII/sh        l=6, c=#        This program is free software; you can redistribut
```

Notice the false positives at the bottom? Those would be interesting [to detect](https://github.com/ksandom/lsd/issues/1).

## Contributing

* PRs welcome! :)
* There's [a list](https://github.com/ksandom/lsd/issues/3) of things I know need to be improved.

## Installing it

```bash
sudo make install
```

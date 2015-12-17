# :earth_africa: debian-debootstrap

Multiarch Debian images for Docker.

* `multiarch/debian-debootstrap` on [Docker Hub](https://hub.docker.com/r/multiarch/debian-debootstrap/)
* [Available tags](https://hub.docker.com/r/multiarch/debian-debootstrap/tags/)

## Usage

Once you need to configure binfmt-support on your Docker host.
This works locally or remotely (i.e using boot2docker or swarm).

```console
$ docker run --rm --privileged multiarch/qemu-user-static:register --reset
```

Then you can run an `armhf` image from your `x86_64` Docker host.

```console
$ docker run -it --rm multiarch/debian-debootstrap:armhf-jessie
root@88a6ead2fd63:/# uname -a
Linux 88a6ead2fd63 4.1.13-boot2docker #1 SMP Fri Nov 20 19:05:50 UTC 2015 armv7l GNU/Linux
root@88a6ead2fd63:/# 
```

Or an `x86_64` image from your `x86_64` Docker host, directly, without qemu emulation.

```console
$ docker run -it --rm multiarch/debian-debootstrap:amd64-jessie
root@79ec595e4c80:/# uname -a
Linux 79ec595e4c80 4.1.13-boot2docker #1 SMP Fri Nov 20 19:05:50 UTC 2015 x86_64 GNU/Linux
root@79ec595e4c80:/# 
```

It also works for `arm64`

```console
$ docker run -it --rm multiarch/debian-debootstrap:arm64-jessie
root@d64bc78cdcf7:/# uname -a
Linux d64bc78cdcf7 4.1.13-boot2docker #1 SMP Fri Nov 20 19:05:50 UTC 2015 aarch64 GNU/Linux
root@d64bc78cdcf7:/#
```

## License

MIT

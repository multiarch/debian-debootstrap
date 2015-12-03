#!/bin/bash
set -e

cd "$(readlink -f "$(dirname "$BASH_SOURCE")")"

versions=( "$@" )
if [ ${#versions[@]} -eq 0 ]; then
	versions=( */ )
fi
versions=( "${versions[@]%/}" )

get_part() {
	dir="$1"
	shift
	part="$1"
	shift
	if [ -f "$dir/$part" ]; then
		cat "$dir/$part"
		return 0
	fi
	if [ -f "$part" ]; then
		cat "$part"
		return 0
	fi
	if [ $# -gt 0 ]; then
		echo "$1"
		return 0
	fi
	return 1
}

repo="$(get_part . repo '')"
if [ "$repo" ]; then
	if [[ "$repo" != */* ]]; then
		user="$(docker info | awk '/^Username:/ { print $2 }')"
		if [ "$user" ]; then
			repo="$user/$repo"
		fi
	fi
fi

for version in "${versions[@]}"; do
	dir="$(readlink -f "$version")"
	variant="$(get_part "$dir" variant 'minbase')"
	components="$(get_part "$dir" components 'main')"
	include="$(get_part "$dir" include '')"
	suite="$(get_part "$dir" suite "$version")"
	mirror="$(get_part "$dir" mirror '')"
	script="$(get_part "$dir" script '')"
	arch="$(get_part "$dir" arch '')"
	#debootstrap="$(get_part "$dir" debootstrap 'debootstrap')"

	args=( -d "$dir" debootstrap )
	[ -z "$variant" ] || args+=( --variant="$variant" )
	[ -z "$components" ] || args+=( --components="$components" )
	[ -z "$include" ] || args+=( --include="$include" )
	[ -z "$arch" ] || args+=( --arch="$arch" )
	args+=( "$suite" )
	if [ "$mirror" ]; then
		args+=( "$mirror" )
		if [ "$script" ]; then
			args+=( "$script" )
		fi
	fi

	mkimage="$(readlink -f "${MKIMAGE:-"mkimage.sh"}")"
	{
		echo "$(basename "$mkimage") ${args[*]/"$dir"/.}"
		echo
		echo 'https://github.com/docker/docker/blob/master/contrib/mkimage.sh'
	} > "$dir/build-command.txt"

	sudo DEBOOTSTRAP="qemu-debootstrap" nice ionice -c 3 "$mkimage" "${args[@]}" 2>&1 | tee "$dir/build.log"

	sudo chown -R "$(id -u):$(id -g)" "$dir"

        xz -d < $dir/rootfs.tar.xz | gzip -c > $dir/rootfs.tar.gz

	# qemu-user-static
	#wget --no-check-certificate https://github.com/armbuild/qemu-user-static/raw/master/x86_64/qemu-arm-static -O "${dir}"/qemu-arm-static
	#chmod +x "${dir}/qemu-arm-static"
	#echo "COPY ./qemu-arm-static /usr/local/bin/" >> "${dir}"/Dockerfile
		
	
	if [ "$repo" ]; then
		docker build -t "${repo}:${suite}-${arch}" "$dir"
		docker run -it --rm "${repo}:${suite}" bash -xc '
			cat /etc/apt/sources.list
			echo
			cat /etc/os-release 2>/dev/null
			echo
			cat /etc/lsb-release 2>/dev/null
			echo
			cat /etc/debian_version 2>/dev/null
			true
		'
	fi
	latest="$(get_part . latest '')"
	if [ "$latest" = "${suite}" ]; then
	    docker tag -f "${repo}:${suite}-${arch}" "${repo}:${arch}"
	fi
done


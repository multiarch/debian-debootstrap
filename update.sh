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

latest="$(get_part . latest '')"

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
	qemu_arch="$(get_part "$dir" qemu_arch $arch)"
	uname_arch="$(get_part "$dir" uname_arch $arch)"
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

	if [ "$SKIP_DEBOOTSTRAP" != "1" ]; then
	    mkimage="$(readlink -f "${MKIMAGE:-"mkimage.sh"}")"
	    {
		echo "$(basename "$mkimage") ${args[*]/"$dir"/.}"
		echo
		echo 'https://github.com/docker/docker/blob/master/contrib/mkimage.sh'
	    } > "$dir/build-command.txt"
	    
	    sudo DEBOOTSTRAP="qemu-debootstrap" nice ionice -c 3 "$mkimage" "${args[@]}" 2>&1 | tee "$dir/build.log"
	    
	    sudo chown -R "$(id -u):$(id -g)" "$dir"

            xz -d < $dir/rootfs.tar.xz | gzip -c > $dir/rootfs.tar.gz
	fi

	
	if [ "$repo" ]; then
	    if ! grep --quiet "^ENV" "${dir}/Dockerfile"; then
		echo "ENV ARCH=${uname_arch} UBUNTU_SUITE=${suite} DOCKER_REPO=${repo}" >> "${dir}/Dockerfile"
	    fi
	    docker build -t "${repo}:${arch}-${suite}-slim" "${dir}"
	    mkdir -p "${dir}/full"
	    cat > "${dir}/full/Dockerfile" <<EOF
FROM ${repo}:${arch}-${suite}-slim
ADD https://github.com/multiarch/qemu-user-static/releases/download/v2.0.0/amd64_qemu-${qemu_arch}-static.tar.gz /usr/bin
EOF
	    docker build -t "${repo}:${arch}-${suite}" "${dir}/full"
	fi
	
	if [ "${latest}" = "${suite}" ]; then
	    docker tag -f "${repo}:${arch}-${suite}-slim" "${repo}:${arch}-slim"
	    docker tag -f "${repo}:${arch}-${suite}" "${repo}:${arch}"
	fi

	docker run -it --rm "${repo}:${arch}-${suite}" bash -xc '
                        uname -a
                        echo
			cat /etc/apt/sources.list
			echo
			cat /etc/os-release 2>/dev/null
			echo
			cat /etc/lsb-release 2>/dev/null
			echo
			cat /etc/debian_version 2>/dev/null
			true
		'
done


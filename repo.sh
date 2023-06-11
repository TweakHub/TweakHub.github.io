#!/bin/bash
set -e
set -o xtrace

EXTRAOPTS='--db=/usr/local/repocache.db'
GPG_KEY="FB04F6C8EC56DA32F33008C53D1B28A5FACCB53B"

user="$(whoami)"
uid="$(id -u ${user})"
gid="$(id -g ${user})"

script_full_path=$(dirname "$0")
cd "$script_full_path" || exit 1

# make a temp file to unlock gpg
rm -f fr.txt frtroll.txt
echo "fr" > fr.txt
gpg -abs -u $GPG_KEY --clearsign -o frtroll.txt fr.txt
rm -f fr.txt frtroll.txt

for dist in amd64 arm64 i386 armel darwin-amd64 darwin-arm64; do
    binary=binary-${dist}
    contents=Contents-${dist}
    mkdir -p dists/${dist}

    rm -f dists/${dist}/{Release{,.gpg},InRelease}
    cp RepoIcon*.png dists/${dist}
    #cp -a sileo-featured.json dists/${dist}

    for comp in main testing; do
        echo "[$comp/$dist] Starting build..."
        mkdir -p dists/${dist}/${comp}/${binary}
        rm -f dists/${dist}/${comp}/${binary}/{Packages{,.xz,.zst},Release{,.gpg}}

        sudo apt-ftparchive $EXTRAOPTS packages pool/${comp}/${dist} > \
            dists/${dist}/${comp}/${binary}/Packages 2>/dev/null
        sudo xz -c9 dists/${dist}/${comp}/${binary}/Packages > dists/${dist}/${comp}/${binary}/Packages.xz
        sudo zstd -q -c19 dists/${dist}/${comp}/${binary}/Packages > dists/${dist}/${comp}/${binary}/Packages.zst

        sudo apt-ftparchive $EXTRAOPTS contents pool/${comp}/${dist} > \
            dists/${dist}/${comp}/${contents}
        sudo xz -c9 dists/${dist}/${comp}/${contents} > dists/${dist}/${comp}/${contents}.xz
        sudo zstd -q -c19 dists/${dist}/${comp}/${contents} > dists/${dist}/${comp}/${contents}.zst

        sudo apt-ftparchive $EXTRAOPTS \
            -o APT::FTPArchive::Release::Origin="palera1n" \
            -o APT::FTPArchive::Release::Label="palera1n" \
            -o APT::FTPArchive::Release::Suite="stable" \
            -o APT::FTPArchive::Release::Version="1.0" \
            -o APT::FTPArchive::Release::Codename="${dist}" \
            -o APT::FTPArchive::Release::Architectures="${dist}" \
            -o APT::FTPArchive::Release::Components="main testing" \
            -o APT::FTPArchive::Release::Description="APT dist repo for palera1n packages" \
            release dists/${dist}/${comp}/${binary} > dists/${dist}/${comp}/${binary}/Release 2>/dev/null
    done
    
    sudo apt-ftparchive $EXTRAOPTS \
        -o APT::FTPArchive::Release::Origin="palera1n" \
        -o APT::FTPArchive::Release::Label="palera1n" \
        -o APT::FTPArchive::Release::Suite="stable" \
        -o APT::FTPArchive::Release::Version="1.0" \
        -o APT::FTPArchive::Release::Codename="${dist}" \
        -o APT::FTPArchive::Release::Architectures="${dist}" \
        -o APT::FTPArchive::Release::Components="main testing" \
        -o APT::FTPArchive::Release::Description="APT dist repo for palera1n packages" \
        release dists/${dist} > dists/${dist}/Release 2>/dev/null
    
    sudo chown -R ${uid}:${gid} dists/ 
    
    gpg -abs -u $GPG_KEY -o dists/${dist}/Release.gpg dists/${dist}/Release
    gpg -abs -u $GPG_KEY --clearsign -o dists/${dist}/InRelease dists/${dist}/Release
done

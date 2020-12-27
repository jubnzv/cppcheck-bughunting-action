FROM alpine

LABEL "com.github.actions.name"="Cppcheck bug-hunting GitHub Action"
LABEL "com.github.actions.description"="GitHub Action to run Cppcheck in bug-hunting mode on your Pull Requests and add annotations on warnings"
LABEL "com.github.actions.icon"="thumbs-up"
LABEL "com.github.actions.color"="green"
LABEL "com.github.actions.repository"="https://github.com/jubnzv/cppcheck-bughunting-action"
LABEL "com.github.actions.homepage"="https://github.com/jubnzv/cppcheck-bughunting-action"
LABEL "com.github.actions.maintainer"="Georgy Komarov <jubnzv@gmail.com>"

ARG Z3_TAG="z3-4.8.9"

RUN                                                                                          \
	T="$(date +%s)" &&                                                                       \
	apk add --no-cache -t .required_apks build-base git make g++ pcre-dev cmake &&           \
    apk add --no-cache python3 py-pip jq curl bash &&                                        \
    ln -s $(which python3) /usr/bin/python &&                                                \
    pip install --upgrade pip &&                                                             \
    pip install requests pytz &&                                                             \
    python --version; pip --version &&                                                       \
	mkdir -p /usr/src /src && cd /usr/src &&                                                 \
	git clone --depth=1 --branch ${Z3_TAG} https://github.com/Z3Prover/z3.git &&             \
    mkdir -p z3/build && cd z3/build &&                                                      \
    cmake -DCMAKE_BUILD_TYPE=Release -DTESTS=0 .. &&                                         \
    make install -j `getconf _NPROCESSORS_ONLN` &&                                           \
    cd ../.. &&                                                                              \
	git clone --depth=1 https://github.com/danmar/cppcheck.git &&                            \
	cd cppcheck &&                                                                           \
	make install -j `getconf _NPROCESSORS_ONLN`                                              \
        USE_Z3=yes                                                                           \
        FILESDIR=/cfg                                                                        \
        HAVE_RULES=yes                                                                       \
        CXXFLAGS="-O2                                                                        \
        -DNDEBUG --static"                                                                   \
        LDFLAGS="-L/usr/local/lib64/"  &&                                                    \
	strip /usr/bin/cppcheck &&                                                               \
	apk del .required_apks &&                                                                \
	rm -rf /usr/src &&                                                                       \
	T="$(($(date +%s)-T))" &&                                                                \
	printf "Build time: %dd %02d:%02d:%02d\n" "$((T/86400))" "$((T/3600%24))" "$((T/60%60))" "$((T%60))"

COPY src /src
CMD ["/src/entrypoint.sh"]

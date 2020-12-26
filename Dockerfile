FROM alpine

LABEL "com.github.actions.name"="Cppcheck bug-hunting GitHub Action"
LABEL "com.github.actions.description"="GitHub Action to run Cppcheck in bug-hunting mode on your Pull Requests and add annotations on warnings"
LABEL "com.github.actions.icon"="thumbs-up"
LABEL "com.github.actions.color"="green"
LABEL "com.github.actions.repository"="https://github.com/jubnzv/cppcheck-bughunting-action"
LABEL "com.github.actions.homepage"="https://github.com/jubnzv/cppcheck-bughunting-action"
LABEL "com.github.actions.maintainer"="Georgy Komarov <jubnzv@gmail.com>"

RUN \
	T="$(date +%s)" && \
	apk add --no-cache -t .required_apks build-base git make g++ pcre-dev jq curl bash && \
	mkdir -p /usr/src /src && cd /usr/src && \
	git clone --depth=1 https://github.com/danmar/cppcheck.git && \
	cd cppcheck && \
	make install FILESDIR=/cfg HAVE_RULES=yes CXXFLAGS="-O2 -DNDEBUG --static" -j `getconf _NPROCESSORS_ONLN` && \
	strip /usr/bin/cppcheck && \
	apk del .required_apks && \
	rm -rf /usr/src && \
    apk add --no-cache python3 && \
    ln -s $(which python3) /usr/bin/python && \
	T="$(($(date +%s)-T))" && \
	printf "Build time: %dd %02d:%02d:%02d\n" "$((T/86400))" "$((T/3600%24))" "$((T/60%60))" "$((T%60))"
RUN pip install --upgrade pip
RUN pip install requests pytz
RUN python --version; pip --version

COPY src /src
CMD ["/src/entrypoint.sh"]

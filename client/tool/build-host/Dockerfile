FROM --platform=linux/amd64 ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
ARG JIABU_JDK_URL=https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.21%2B9/OpenJDK17U-jdk_x64_linux_hotspot_17.0.21_9.tar.gz
ARG JIABU_JDK_SHA256=8b9b611d917e3dfd8419d3566b5949226f69b052fed7e109c1368add1dfe8711
ARG JIABU_ANDROID_COMMAND_TOOLS_VERSION=13114758
ARG JIABU_ANDROID_COMMAND_TOOLS_SHA256=7ec965280a073311c339e571cd5de778b9975026cfcbe79f2b1cdcb1e15317ee
ARG JIABU_ANDROID_BUILD_TOOLS_VERSION=37.0.0
ARG JIABU_ANDROID_PLATFORM=android-37.0
ARG JIABU_NOTO_REVISION=165c01b46ea533872e002e0785ff17e44f6d97d8
ARG JIABU_NOTO_SHA256=2c76254f6fc379fddfce0a7e84fb5385bb135d3e399294f6eeb6680d0365b74b
ARG PUB_HOSTED_URL=https://pub.dev
ARG FLUTTER_STORAGE_BASE_URL=https://storage.googleapis.com

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash ca-certificates curl fontconfig git libglu1-mesa libgtk-3-0t64 \
    libstdc++6 python3 unzip xz-utils \
    && rm -rf /var/lib/apt/lists/*

ENV JIABU_TOOLS_DIR=/opt/jiabu/dev-tools \
    GIT_CONFIG_COUNT=1 \
    GIT_CONFIG_KEY_0=safe.directory \
    GIT_CONFIG_VALUE_0=/opt/jiabu/dev-tools/flutter/3.47.8
COPY client/tool/build-host/setup.sh /opt/jiabu/setup.sh
RUN bash /opt/jiabu/setup.sh \
    && . /opt/jiabu/dev-tools/jiabu-client-env.sh \
    && flutter --disable-analytics \
    && flutter precache --android --linux \
    && fc-cache -f /opt/jiabu/dev-tools/test-fonts \
    && chmod -R a+rwX /opt/jiabu/dev-tools/flutter/3.47.8

ENV PUB_HOSTED_URL=${PUB_HOSTED_URL:-https://pub.dev} \
    FLUTTER_STORAGE_BASE_URL=${FLUTTER_STORAGE_BASE_URL:-https://storage.googleapis.com}
ENV FLUTTER_ROOT=/opt/jiabu/dev-tools/flutter/3.47.8 \
    JAVA_HOME=/opt/jiabu/dev-tools/jdk17 \
    ANDROID_HOME=/opt/jiabu/dev-tools/android-sdk \
    ANDROID_SDK_ROOT=/opt/jiabu/dev-tools/android-sdk \
    JIABU_TEST_FONT=/opt/jiabu/dev-tools/test-fonts/NotoSansCJKsc-Regular.otf \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    GIT_CONFIG_COUNT=1 \
    GIT_CONFIG_KEY_0=safe.directory \
    GIT_CONFIG_VALUE_0=/opt/jiabu/dev-tools/flutter/3.47.8
ENV PATH="/opt/jiabu/dev-tools/flutter/3.47.8/bin:/opt/jiabu/dev-tools/jdk17/bin:/opt/jiabu/dev-tools/android-sdk/cmdline-tools/${JIABU_ANDROID_COMMAND_TOOLS_VERSION}/bin:/opt/jiabu/dev-tools/android-sdk/platform-tools:/opt/jiabu/dev-tools/gradle/gradle-9.8.2/bin:${PATH}"
WORKDIR /workspace
